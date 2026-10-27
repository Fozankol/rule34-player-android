import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import '../../lib/models/post_model.dart';
import '../../lib/services/mp4_parser.dart';
import '../../lib/services/metadata_prober.dart';
import '../../lib/services/database_service.dart';
import '../../lib/models/video_metadata.dart';

Uint8List buildMp4Buffer(int durationSeconds) {
  // mvhd box: 32 bytes
  final mvhd = Uint8List(32);
  final mvhdData = ByteData.sublistView(mvhd);
  mvhdData.setUint32(0, 32);
  mvhd.setRange(4, 8, 'mvhd'.codeUnits);
  mvhdData.setUint32(20, 1000); // timescale = 1000
  mvhdData.setUint32(24, durationSeconds * 1000); // duration in timescale

  // moov box: 8 + 32 = 40 bytes
  final moov = Uint8List(40);
  final moovData = ByteData.sublistView(moov);
  moovData.setUint32(0, 40);
  moov.setRange(4, 8, 'moov'.codeUnits);
  moov.setRange(8, 40, mvhd);

  // ftyp box: 16 bytes
  final ftyp = Uint8List(16);
  final ftypData = ByteData.sublistView(ftyp);
  ftypData.setUint32(0, 16);
  ftyp.setRange(4, 8, 'ftyp'.codeUnits);

  final result = Uint8List(ftyp.length + moov.length);
  result.setRange(0, ftyp.length, ftyp);
  result.setRange(ftyp.length, result.length, moov);
  return result;
}

void main() {
  group('HTTP Range & Video Prober Network Tests', () {
    late HttpServer server;
    late String serverUrl;
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService();
      dbService.enableInMemoryTestMode();

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://${server.address.host}:${server.port}';

      server.listen((HttpRequest request) async {
        final path = request.uri.path;
        final mp4Data = buildMp4Buffer(195); // 195 seconds = 3m 15s

        if (path == '/large200.mp4') {
          // Simulates a server that returns 200 OK with full 1MB payload
          // even when client requested range. Prober must stop reading after 128KB!
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set('Content-Type', 'video/mp4');
          request.response.headers.set('Content-Length', '1048576');
          request.response.add(mp4Data);
          // Pad with dummy data up to 1MB
          final dummy = Uint8List(1048576 - mp4Data.length);
          request.response.add(dummy);
          await request.response.close();
          return;
        }

        final rangeHeader = request.headers.value('range');
        if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set('Content-Range', 'bytes 0-131071/${mp4Data.length}');
          request.response.headers.set('Content-Type', 'video/mp4');
          request.response.add(mp4Data);
        } else {
          request.response.statusCode = HttpStatus.ok;
          request.response.add(mp4Data);
        }
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('Local HTTP Range response is parsed and duration is accurately extracted', () async {
      final client = HttpClient();
      final uri = Uri.parse('$serverUrl/video.mp4');

      final req = await client.getUrl(uri);
      req.headers.set('Range', 'bytes=0-131071');
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.partialContent));

      final bytesBuilder = BytesBuilder();
      await for (final chunk in resp) {
        bytesBuilder.add(chunk);
      }
      final bytes = bytesBuilder.toBytes();

      final parsed = Mp4Parser.parse(bytes);
      expect(parsed, isNotNull);
      expect(parsed!.durationSeconds, equals(195.0));

      final post = PostModel(
        id: 5555,
        score: 100,
        fileUrl: '$serverUrl/video.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: ['video', 'animation'],
        width: 1920,
        height: 1080,
      );

      post.duration = parsed.durationSeconds;
      expect(post.formattedDuration, equals('03:15'));
      expect(post.duration! >= 120.0, isTrue); // meets user's > 2min requirement

      client.close();
    });

    test('MetadataProber probeDuration extracts duration and caches it in DatabaseService', () async {
      final prober = MetadataProber();
      final post = PostModel(
        id: 7777,
        score: 200,
        fileUrl: '$serverUrl/video.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: ['video'],
        width: 1920,
        height: 1080,
      );

      final dur = await prober.probeDuration(post, dbService: dbService);
      expect(dur, equals(195.0));
      expect(post.duration, equals(195.0));

      // Verify cached in SQLite / in-memory storage
      final cached = await dbService.getMetadata(7777);
      expect(cached, isNotNull);
      expect(cached!.durationSeconds, equals(195.0));
    });

    test('Cached duration from another source with the same ID is ignored', () async {
      await dbService.saveMetadata(VideoMetadata(
        postId: 999,
        fileUrl: 'https://other.example/video.mp4',
        durationSeconds: 600,
        checkedAt: 0,
      ));
      final post = PostModel(
        id: 999, score: 0, fileUrl: '$serverUrl/video.mp4',
        previewUrl: '', sampleUrl: '', tags: [], width: 0, height: 0,
      );
      await MetadataProber().probeBatch([post], dbService: dbService);
      expect(post.duration, 195);
    });

    test('Batch rejects zero concurrency instead of hanging', () async {
      await expectLater(
        MetadataProber().probeBatch([], concurrency: 0),
        throwsArgumentError,
      );
    });

    test('Batch propagates callback failures', () async {
      final post = PostModel(
        id: 998, score: 0, fileUrl: '$serverUrl/video.mp4',
        previewUrl: '', sampleUrl: '', tags: [], width: 0, height: 0,
      );
      await expectLater(MetadataProber().probeBatch(
        [post],
        dbService: dbService,
        onProbed: (_) => throw StateError('callback failed'),
      ), throwsStateError);
    });

    test('MetadataProber safely handles HTTP 200 OK without downloading the full large file', () async {
      final prober = MetadataProber();
      final post = PostModel(
        id: 8888,
        score: 50,
        fileUrl: '$serverUrl/large200.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: ['video'],
        width: 1920,
        height: 1080,
      );

      final dur = await prober.probeDuration(post, dbService: dbService);
      expect(dur, equals(195.0));
      expect(post.duration, equals(195.0));
    });
  });
}
