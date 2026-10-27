import 'dart:typed_data';

class WebmMetadataResult {
  final double durationSeconds;
  final int width;
  final int height;

  const WebmMetadataResult({
    required this.durationSeconds,
    this.width = 0,
    this.height = 0,
  });
}

class WebmParser {
  // EBML Element IDs
  static const int idEbml = 0x1A45DFA3;
  static const int idSegment = 0x18538067;
  static const int idInfo = 0x1549A966;
  static const int idTimestampScale = 0x2AD7B1;
  static const int idDuration = 0x4489;
  static const int idTracks = 0x1654AE6B;
  static const int idTrackEntry = 0xAE;
  static const int idVideo = 0xE0;
  static const int idPixelWidth = 0xB0;
  static const int idPixelHeight = 0xBA;

  /// Attempts to parse WebM/Matroska container metadata
  /// from a buffer (typically 32KB - 128KB).
  static WebmMetadataResult? parse(Uint8List bytes) {
    if (bytes.length < 7) return null;

    final byteData = ByteData.sublistView(bytes);

    // 1. Try structured EBML parsing
    final structured = _parseEbml(byteData, bytes, 0, bytes.length);
    if (structured != null && structured.durationSeconds > 0) {
      return structured;
    }

    // 2. Fallback: Scan directly for Duration tag [0x44, 0x89]
    final scanned = _scanForDuration(byteData, bytes);
    if (scanned != null && scanned.durationSeconds > 0) {
      return scanned;
    }

    return null;
  }

  static WebmMetadataResult? _parseEbml(
    ByteData data,
    Uint8List bytes,
    int start,
    int end, {
    int? inheritedTimestampScale,
  }) {
    int offset = start;
    double? finalDurationSeconds;
    double? rawDuration;
    int timestampScale = inheritedTimestampScale ?? 1000000; // default 1ms
    int width = 0;
    int height = 0;

    while (offset < end - 2) {
      final elementIdInfo = _readVint(bytes, offset, maskLength: false);
      if (elementIdInfo == null) break;
      final elementId = elementIdInfo[0];
      offset += elementIdInfo[1];

      final sizeInfo = _readVint(bytes, offset, maskLength: true);
      if (sizeInfo == null) break;
      final elementSize = sizeInfo[0];
      offset += sizeInfo[1];

      final elementEnd = elementSize < 0
          ? end
          : (offset + elementSize).clamp(offset, end);

      if (elementId == idEbml ||
          elementId == idSegment ||
          elementId == idInfo ||
          elementId == idTracks ||
          elementId == idTrackEntry ||
          elementId == idVideo) {
        // Container element: recurse into children
        final sub = _parseEbml(
          data,
          bytes,
          offset,
          elementEnd,
          inheritedTimestampScale: timestampScale,
        );
        if (sub != null) {
          if (sub.durationSeconds > 0) {
            finalDurationSeconds = sub.durationSeconds;
          }
          if (sub.width > 0) width = sub.width;
          if (sub.height > 0) height = sub.height;
        }
      } else if (elementId == idTimestampScale) {
        final scale = _readUint(data, offset, elementSize);
        if (scale > 0) {
          timestampScale = scale;
          if (rawDuration != null && rawDuration > 0) {
            finalDurationSeconds = (rawDuration * timestampScale) / 1000000000.0;
          }
        }
      } else if (elementId == idDuration) {
        double? rawDur;
        if (elementSize == 4 && offset + 4 <= end) {
          rawDur = data.getFloat32(offset);
        } else if (elementSize == 8 && offset + 8 <= end) {
          rawDur = data.getFloat64(offset);
        }
        if (rawDur != null && rawDur.isFinite && rawDur > 0) {
          rawDuration = rawDur;
          finalDurationSeconds = (rawDur * timestampScale) / 1000000000.0;
        }
      } else if (elementId == idPixelWidth) {
        width = _readUint(data, offset, elementSize);
      } else if (elementId == idPixelHeight) {
        height = _readUint(data, offset, elementSize);
      }

      if (elementSize < 0) break;
      offset = elementEnd;
    }

    if (finalDurationSeconds != null && finalDurationSeconds > 0) {
      return WebmMetadataResult(
        durationSeconds: finalDurationSeconds,
        width: width,
        height: height,
      );
    }

    if (width > 0 || height > 0) {
      return WebmMetadataResult(
        durationSeconds: 0,
        width: width,
        height: height,
      );
    }

    return null;
  }

  /// Scans for EBML tag 0x44 0x89 (Duration)
  static WebmMetadataResult? _scanForDuration(ByteData data, Uint8List bytes) {
    final len = bytes.length;
    for (int i = 0; i <= len - 7; i++) {
      if (bytes[i] == 0x44 && bytes[i + 1] == 0x89) {
        final sizeByte = bytes[i + 2];
        if (sizeByte == 0x84 && i + 7 <= len) {
          // 4-byte float (0x80 | 4 = 0x84)
          final dur = data.getFloat32(i + 3);
          final durSec = dur / 1000.0;
          if (durSec > 0 && durSec < 86400 * 30) {
            return WebmMetadataResult(durationSeconds: durSec);
          }
        } else if (sizeByte == 0x88 && i + 11 <= len) {
          // 8-byte double (0x80 | 8 = 0x88)
          final dur = data.getFloat64(i + 3);
          final durSec = dur / 1000.0;
          if (durSec > 0 && durSec < 86400 * 30) {
            return WebmMetadataResult(durationSeconds: durSec);
          }
        }
      }
    }
    return null;
  }

  /// Reads EBML Variable-Length Integer (VINT)
  /// Returns [value, lengthInBytes] or null on invalid/EOF.
  static List<int>? _readVint(Uint8List bytes, int offset,
      {required bool maskLength}) {
    if (offset >= bytes.length) return null;

    final firstByte = bytes[offset];
    int length = 0;
    int mask = 0;

    for (int i = 0; i < 8; i++) {
      if ((firstByte & (0x80 >> i)) != 0) {
        length = i + 1;
        mask = (1 << (7 - i)) - 1;
        break;
      }
    }

    if (length == 0 || offset + length > bytes.length) {
      return null;
    }

    int value = maskLength ? (firstByte & mask) : firstByte;

    // Check for "all ones" (unknown size)
    bool isAllOnes = maskLength && (firstByte & mask) == mask;

    for (int i = 1; i < length; i++) {
      final b = bytes[offset + i];
      if (b != 0xFF) isAllOnes = false;
      value = (value << 8) | b;
    }

    if (maskLength && isAllOnes) {
      return [-1, length]; // -1 represents unknown size
    }

    return [value, length];
  }

  static int _readUint(ByteData data, int offset, int size) {
    if (size <= 0 || size > 8 || offset + size > data.lengthInBytes) return 0;
    int val = 0;
    for (int i = 0; i < size; i++) {
      val = (val << 8) | data.getUint8(offset + i);
    }
    return val;
  }
}
