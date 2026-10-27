import 'dart:typed_data';
import 'package:test/test.dart';
import '../../lib/services/webm_parser.dart';

Uint8List createWebmDurationElement(double durationMs) {
  final bytes = Uint8List(7);
  bytes[0] = 0x44;
  bytes[1] = 0x89;
  bytes[2] = 0x84;
  final data = ByteData.sublistView(bytes);
  data.setFloat32(3, durationMs);
  return bytes;
}

Uint8List createWebmInfoElement({
  required double durationMs,
  int timestampScale = 1000000,
  bool durationFirst = false,
}) {
  final durElem = createWebmDurationElement(durationMs);

  final tsElem = Uint8List(8);
  tsElem[0] = 0x2A;
  tsElem[1] = 0xD7;
  tsElem[2] = 0xB1;
  tsElem[3] = 0x84;
  final tsData = ByteData.sublistView(tsElem);
  tsData.setUint32(4, timestampScale);

  final infoPayload = Uint8List(tsElem.length + durElem.length);
  if (durationFirst) {
    infoPayload.setRange(0, durElem.length, durElem);
    infoPayload.setRange(durElem.length, infoPayload.length, tsElem);
  } else {
    infoPayload.setRange(0, tsElem.length, tsElem);
    infoPayload.setRange(tsElem.length, infoPayload.length, durElem);
  }

  final infoBytes = Uint8List(5 + infoPayload.length);
  infoBytes[0] = 0x15;
  infoBytes[1] = 0x49;
  infoBytes[2] = 0xA9;
  infoBytes[3] = 0x66;
  infoBytes[4] = 0x80 | infoPayload.length;
  infoBytes.setRange(5, infoBytes.length, infoPayload);
  return infoBytes;
}

void main() {
  group('WebmParser Tests', () {
    test('Uses non-default TimestampScale inside nested Info', () {
      final info = createWebmInfoElement(
        durationMs: 90000,
        timestampScale: 2000000,
        durationFirst: true,
      );
      final segment = Uint8List.fromList([
        0x18, 0x53, 0x80, 0x67, 0xFF, ...info,
      ]);
      expect(WebmParser.parse(segment)!.durationSeconds, closeTo(180, 0.01));
    });

    test('Unknown-size integer element does not read outside its payload', () {
      expect(WebmParser.parse(Uint8List.fromList([
        0x2A, 0xD7, 0xB1, 0xFF, 0, 0, 0,
      ])), isNull);
    });
    test('Correctly parses WebM Info element with Duration and TimestampScale', () {
      final info = createWebmInfoElement(durationMs: 240000.0, timestampScale: 1000000);
      final result = WebmParser.parse(info);
      expect(result, isNotNull);
      expect(result!.durationSeconds, closeTo(240.0, 0.01));
    });

    test('Correctly parses WebM Info when Duration appears before TimestampScale', () {
      final info = createWebmInfoElement(
        durationMs: 180000.0,
        timestampScale: 1000000,
        durationFirst: true,
      );
      final result = WebmParser.parse(info);
      expect(result, isNotNull);
      expect(result!.durationSeconds, closeTo(180.0, 0.01));
    });

    test('Fallback pattern scan recovers duration from raw Duration tag', () {
      final durElem = createWebmDurationElement(130000.0);
      final dummy = Uint8List.fromList([0x1F, 0x43, 0xB6, 0x75, 0x01, 0x02]);
      final buffer = Uint8List(dummy.length + durElem.length);
      buffer.setRange(0, dummy.length, dummy);
      buffer.setRange(dummy.length, buffer.length, durElem);

      final result = WebmParser.parse(buffer);
      expect(result, isNotNull);
      expect(result!.durationSeconds, closeTo(130.0, 0.01));
    });

    test('Returns null on empty or non-WebM buffer safely', () {
      expect(WebmParser.parse(Uint8List(0)), isNull);
      expect(WebmParser.parse(Uint8List(8)), isNull);
    });
  });
}
