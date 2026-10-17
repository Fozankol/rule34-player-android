import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/post_model.dart';
import '../models/video_metadata.dart';
import 'mp4_parser.dart';
import 'webm_parser.dart';
import 'database_service.dart';

class MetadataProber {
  static final MetadataProber _instance = MetadataProber._internal();
  factory MetadataProber() => _instance;
  MetadataProber._internal();

  final http.Client _client = http.Client();
  final Set<int> _activeProbes = {};

  static const String _defaultUserAgent =
      'Rule34VideoPlayer/1.0 (Android; client-side duration prober)';
  static const int _chunkSize = 131072; // 128 KB

  /// Safely reads at most maxBytes from the stream, immediately aborting the connection
  /// to avoid downloading the full video if the server sends 200 OK instead of 206 Partial Content.
  static Future<Uint8List> _readUpTo(
    http.ByteStream stream,
    int maxBytes, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final builder = BytesBuilder(copy: false);
    int total = 0;
    final completer = Completer<Uint8List>();
    late StreamSubscription<List<int>> sub;
    Timer? timer;

    void finish() {
      timer?.cancel();
      sub.cancel();
      if (!completer.isCompleted) {
        completer.complete(builder.takeBytes());
      }
    }

    timer = Timer(timeout, () {
      finish();
    });

    sub = stream.listen(
      (chunk) {
        final remaining = maxBytes - total;
        if (chunk.length <= remaining) {
          builder.add(chunk);
          total += chunk.length;
        } else {
          builder.add(chunk.sublist(0, remaining));
          total += remaining;
        }

        if (total >= maxBytes) {
          finish();
        }
      },
      onError: (err) {
        timer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(err);
        }
      },
      onDone: () {
        timer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(builder.takeBytes());
        }
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  /// Probes duration and metadata for a single post.
  /// First checks local DB cache. If not cached, performs HTTP Range request.
  Future<double?> probeDuration(
    PostModel post, {
    DatabaseService? dbService,
  }) async {
    // 1. If already known on post model
    if (post.duration != null && post.duration! > 0) {
      return post.duration;
    }

    final db = dbService ?? DatabaseService();

    // 2. Check local SQLite cache
    final cached = await db.getMetadata(post.id);
    if (cached != null && cached.durationSeconds > 0) {
      post.duration = cached.durationSeconds;
      return cached.durationSeconds;
    }

    if (!post.isVideo || post.fileUrl.isEmpty) {
      return null;
    }

    // Avoid duplicate requests for the same post ID
    if (_activeProbes.contains(post.id)) {
      return null;
    }

    _activeProbes.add(post.id);
    post.isProbing = true;

    try {
      final uri = Uri.parse(post.fileUrl);
      final isWebm = post.fileExtension == 'webm' || post.fileExtension == 'mkv';

      // 3. Request first 128 KB
      final request = http.Request('GET', uri);
      request.headers['User-Agent'] = _defaultUserAgent;
      request.headers['Range'] = 'bytes=0-${_chunkSize - 1}';
      if (post.fileUrl.contains('realbooru.com')) {
        request.headers['Referer'] = 'https://realbooru.com/';
      }

      final streamedResponse = await _client.send(request).timeout(
            const Duration(seconds: 12),
          );

      if (streamedResponse.statusCode != 200 &&
          streamedResponse.statusCode != 206) {
        return null;
      }

      final contentRange = streamedResponse.headers['content-range'];
      int? totalFileSize;
      bool supportsRange = streamedResponse.statusCode == 206;
      if (contentRange != null) {
        // e.g. "bytes 0-131071/5829104"
        final slashIndex = contentRange.lastIndexOf('/');
        if (slashIndex != -1) {
          totalFileSize = int.tryParse(contentRange.substring(slashIndex + 1));
          supportsRange = true;
        }
      } else if (streamedResponse.headers['content-length'] != null) {
        totalFileSize = int.tryParse(streamedResponse.headers['content-length']!);
      }

      // Read at most _chunkSize bytes even if server sends 200 OK with full file!
      final initialBytes = await _readUpTo(
        streamedResponse.stream,
        _chunkSize,
        timeout: const Duration(seconds: 10),
      );

      double? duration;
      int width = post.width;
      int height = post.height;
      String format = isWebm ? 'webm' : 'mp4';

      if (isWebm) {
        final webmRes = WebmParser.parse(initialBytes);
        if (webmRes != null && webmRes.durationSeconds > 0) {
          duration = webmRes.durationSeconds;
          if (webmRes.width > 0) width = webmRes.width;
          if (webmRes.height > 0) height = webmRes.height;
        }
      } else {
        // MP4
        final mp4Res = Mp4Parser.parse(initialBytes);
        if (mp4Res != null && mp4Res.durationSeconds > 0) {
          duration = mp4Res.durationSeconds;
          if (mp4Res.width > 0) width = mp4Res.width;
          if (mp4Res.height > 0) height = mp4Res.height;
        } else if (supportsRange && totalFileSize != null && totalFileSize > _chunkSize) {
          // If moov atom was not in head and server supports Range, probe tail (last 128 KB)
          final tailStart = (totalFileSize - _chunkSize).clamp(0, totalFileSize);
          final tailRequest = http.Request('GET', uri);
          tailRequest.headers['User-Agent'] = _defaultUserAgent;
          tailRequest.headers['Range'] = 'bytes=$tailStart-${totalFileSize - 1}';
          if (post.fileUrl.contains('realbooru.com')) {
            tailRequest.headers['Referer'] = 'https://realbooru.com/';
          }

          try {
            final tailResponse = await _client.send(tailRequest).timeout(
                  const Duration(seconds: 10),
                );
            if (tailResponse.statusCode == 206) {
              final tailBytes = await _readUpTo(
                tailResponse.stream,
                _chunkSize,
                timeout: const Duration(seconds: 10),
              );
              final tailRes = Mp4Parser.parse(tailBytes);
              if (tailRes != null && tailRes.durationSeconds > 0) {
                duration = tailRes.durationSeconds;
                if (tailRes.width > 0) width = tailRes.width;
                if (tailRes.height > 0) height = tailRes.height;
              }
            } else {
              // Server did not return partial content; cancel stream immediately
              final _ = tailResponse.stream.listen(null)..cancel();
            }
          } catch (_) {}
        }
      }

      if (duration != null && duration > 0) {
        post.duration = duration;
        // Save to SQLite
        await db.saveMetadata(
          VideoMetadata(
            postId: post.id,
            fileUrl: post.fileUrl,
            durationSeconds: duration,
            width: width,
            height: height,
            format: format,
            checkedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        return duration;
      }
    } catch (_) {
      // Network error, timeout or range unsupported
    } finally {
      post.isProbing = false;
      _activeProbes.remove(post.id);
    }

    return null;
  }

  /// Batch probes duration for a list of posts with concurrency limit
  Future<void> probeBatch(
    List<PostModel> posts, {
    int concurrency = 3,
    Function(PostModel)? onProbed,
    DatabaseService? dbService,
  }) async {
    final unprobed = posts
        .where((p) => p.isVideo && p.duration == null && !_activeProbes.contains(p.id))
        .toList();

    if (unprobed.isEmpty) return;

    final db = dbService ?? DatabaseService();

    // Check DB cache in batch first
    final ids = unprobed.map((p) => p.id).toList();
    final cachedMap = await db.getMetadataBatch(ids);

    final remaining = <PostModel>[];
    for (final post in unprobed) {
      if (cachedMap.containsKey(post.id)) {
        post.duration = cachedMap[post.id]!.durationSeconds;
        onProbed?.call(post);
      } else {
        remaining.add(post);
      }
    }

    if (remaining.isEmpty) return;

    // Concurrently process remaining items
    int running = 0;
    int index = 0;
    final completer = Completer<void>();

    void next() {
      if (index >= remaining.length && running == 0) {
        if (!completer.isCompleted) completer.complete();
        return;
      }

      while (running < concurrency && index < remaining.length) {
        final currentPost = remaining[index++];
        running++;
        probeDuration(currentPost, dbService: db).then((dur) {
          if (dur != null) {
            onProbed?.call(currentPost);
          }
        }).whenComplete(() {
          running--;
          next();
        });
      }
    }

    next();
    await completer.future;
  }

  void dispose() {
    _client.close();
  }
}
