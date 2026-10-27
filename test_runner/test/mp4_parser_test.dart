import 'dart:typed_data';
import 'package:test/test.dart';
import '../../lib/services/mp4_parser.dart';

Uint8List createMvhdBox({
  required int timescale,
  required int duration,
  int version = 0,
}) {
  if (version == 0) {
    final bytes = Uint8List(32);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, 32);
    bytes.setRange(4, 8, 'mvhd'.codeUnits);
    data.setUint8(8, 0); // version
    data.setUint8(9, 0);
    data.setUint8(10, 0);
    data.setUint8(11, 0);
    data.setUint32(12, 0); // creation time
    data.setUint32(16, 0); // mod time
    data.setUint32(20, timescale);
    data.setUint32(24, duration);
    return bytes;
  } else {
    final bytes = Uint8List(44);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, 44);
    bytes.setRange(4, 8, 'mvhd'.codeUnits);
    data.setUint8(8, 1); // version 1
    data.setUint8(9, 0);
    data.setUint8(10, 0);
    data.setUint8(11, 0);
    data.setUint64(12, 0);
    data.setUint64(20, 0);
    data.setUint32(28, timescale);
    data.setUint64(32, duration);
    return bytes;
  }
}

Uint8List createMoovBox(Uint8List childBox) {
  final totalSize = 8 + childBox.length;
  final bytes = Uint8List(totalSize);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, totalSize);
  bytes.setRange(4, 8, 'moov'.codeUnits);
  bytes.setRange(8, totalSize, childBox);
  return bytes;
}

Uint8List createFtypBox() {
  final bytes = Uint8List(16);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, 16);
  bytes.setRange(4, 8, 'ftyp'.codeUnits);
  bytes.setRange(8, 12, 'isom'.codeUnits);
  data.setUint32(12, 512);
  return bytes;
}

void main() {
  test('Reads duration from an extended-size mvhd box', () {
    final bytes = Uint8List(36);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, 1);
    bytes.setRange(4, 8, 'mvhd'.codeUnits);
    data.setUint64(8, bytes.length);
    data.setUint32(28, 1000);
    data.setUint32(32, 180000);
    expect(Mp4Parser.parse(bytes)!.durationSeconds, 180);
  });
  group('Mp4Parser Tests', () {
    test('Correctly parses fast-start MP4 with version 0 mvhd (duration = 180s / 3m)', () {
      final ftyp = createFtypBox();
      final mvhd = createMvhdBox(timescale: 1000, duration: 180000); // 180s
      final moov = createMoovBox(mvhd);

      final buffer = Uint8List(ftyp.length + moov.length);
      buffer.setRange(0, ftyp.length, ftyp);
      buffer.setRange(ftyp.length, buffer.length, moov);

      final result = Mp4Parser.parse(buffer);
      expect(result, isNotNull);
      expect(result!.durationSeconds, closeTo(180.0, 0.001));
    });

    test('Correctly parses MP4 with version 1 64-bit mvhd (duration = 360s / 6m)', () {
      final mvhd = createMvhdBox(timescale: 600, duration: 216000, version: 1); // 360s
      final moov = createMoovBox(mvhd);

      final result = Mp4Parser.parse(moov);
      expect(result, isNotNull);
      expect(result!.durationSeconds, closeTo(360.0, 0.001));
    });

    test('Fallback pattern scan recovers duration when slice begins mid-box', () {
      final mvhd = createMvhdBox(timescale: 1000, duration: 150000); // 150s = 2m30s
      final dummy = Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD, 0xEE]);
      final buffer = Uint8List(dummy.length + mvhd.length);
      buffer.setRange(0, dummy.length, dummy);
      buffer.setRange(dummy.length, buffer.length, mvhd);

      final result = Mp4Parser.parse(buffer);
      expect(result, isNotNull);
      expect(result!.durationSeconds, closeTo(150.0, 0.001));
    });

    test('Returns null for empty or corrupted buffer without crashing', () {
      expect(Mp4Parser.parse(Uint8List(0)), isNull);
      expect(Mp4Parser.parse(Uint8List(10)), isNull);
      expect(Mp4Parser.parse(Uint8List.fromList([0, 0, 0, 1, 0, 0, 0, 0])), isNull);
    });

    test('Safely handles corrupt 64-bit extended box sizes without infinite looping', () {
      // Box size 1 (64-bit size follows), but size64 is 4 (less than 16 byte header)
      final corrupt = Uint8List(24);
      final data = ByteData.sublistView(corrupt);
      data.setUint32(0, 1);
      corrupt.setRange(4, 8, 'free'.codeUnits);
      data.setUint64(8, 4); // invalid small size64

      final result = Mp4Parser.parse(corrupt);
      expect(result, isNull);
    });
  });
}
