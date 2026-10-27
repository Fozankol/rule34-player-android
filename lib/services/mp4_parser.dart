import 'dart:typed_data';

class Mp4MetadataResult {
  final double durationSeconds;
  final int width;
  final int height;

  const Mp4MetadataResult({
    required this.durationSeconds,
    this.width = 0,
    this.height = 0,
  });
}

class Mp4Parser {
  /// Attempts to parse MP4 container metadata (duration, width, height)
  /// from a buffer (typically 64KB - 128KB).
  /// Supports both structured box walking and pattern fallback for sliced chunks.
  static Mp4MetadataResult? parse(Uint8List bytes) {
    if (bytes.length < 16) return null;

    final byteData = ByteData.sublistView(bytes);

    // 1. Try structured box traversal
    final structured = _parseBoxes(byteData, 0, bytes.length);
    if (structured != null && structured.durationSeconds > 0) {
      return structured;
    }

    // 2. Fallback: Search for 'mvhd' atom directly in the buffer
    // Useful when reading the tail of a file (where box boundaries may be offset)
    final scanned = _scanForMvhd(byteData, bytes);
    if (scanned != null && scanned.durationSeconds > 0) {
      return scanned;
    }

    return null;
  }

  static Mp4MetadataResult? _parseBoxes(ByteData data, int start, int end) {
    int offset = start;
    double? duration;
    int width = 0;
    int height = 0;

    while (offset + 8 <= end) {
      int boxSize = data.getUint32(offset);
      final boxType = _readString(data, offset + 4, 4);

      int headerSize = 8;
      int payloadSize = boxSize - 8;

      if (boxSize == 1) {
        // 64-bit size
        if (offset + 16 > end) break;
        final size64 = data.getUint64(offset + 8);
        if (size64 < 16) break;
        headerSize = 16;
        payloadSize = size64 - 16;
        boxSize = size64;
      } else if (boxSize == 0) {
        // Box extends to end of available buffer
        payloadSize = end - (offset + headerSize);
      }

      if (boxSize < 0 || (boxSize > 0 && boxSize < headerSize)) {
        // Invalid box size
        break;
      }

      final boxEnd = (offset + headerSize + payloadSize).clamp(0, end);

      if (boxType == 'moov' || boxType == 'trak' || boxType == 'mdia') {
        // Container box, recurse inside
        final subResult = _parseBoxes(data, offset + headerSize, boxEnd);
        if (subResult != null) {
          if (subResult.durationSeconds > 0) {
            duration = subResult.durationSeconds;
          }
          if (subResult.width > 0) width = subResult.width;
          if (subResult.height > 0) height = subResult.height;
        }
      } else if (boxType == 'mvhd') {
        // Movie Header Box
        final dur = _parseMvhd(data, offset + headerSize, boxEnd);
        if (dur != null && dur > 0) {
          duration = dur;
        }
      } else if (boxType == 'mdhd' && (duration == null || duration <= 0)) {
        // Media Header Box (fallback duration from track)
        final dur = _parseMdhd(data, offset + headerSize, boxEnd);
        if (dur != null && dur > 0) {
          duration = dur;
        }
      } else if (boxType == 'tkhd') {
        // Track Header Box (extract width & height)
        final dims = _parseTkhd(data, offset + headerSize, boxEnd);
        if (dims != null) {
          if (dims[0] > 0) width = dims[0];
          if (dims[1] > 0) height = dims[1];
        }
      }

      if (boxSize == 0) break;
      final step = (boxSize == 1 ? (headerSize + payloadSize) : boxSize);
      if (step <= 0) break;
      offset += step;
    }

    if (duration != null && duration > 0) {
      return Mp4MetadataResult(
        durationSeconds: duration,
        width: width,
        height: height,
      );
    }
    return null;
  }

  static double? _parseMvhd(ByteData data, int start, int end) {
    if (start + 20 > end) return null;
    final version = data.getUint8(start);

    int timescale;
    int duration;

    if (version == 0) {
      if (start + 20 > end) return null;
      // offset + 0: version (1) + flags (3)
      // offset + 4: creation_time (4)
      // offset + 8: modification_time (4)
      // offset + 12: timescale (4)
      // offset + 16: duration (4)
      timescale = data.getUint32(start + 12);
      duration = data.getUint32(start + 16);
    } else if (version == 1) {
      if (start + 32 > end) return null;
      // offset + 0: version (1) + flags (3)
      // offset + 4: creation_time (8)
      // offset + 12: modification_time (8)
      // offset + 20: timescale (4)
      // offset + 24: duration (8)
      timescale = data.getUint32(start + 20);
      duration = data.getUint64(start + 24);
    } else {
      return null;
    }

    if (timescale > 0 && duration > 0) {
      return duration / timescale;
    }
    return null;
  }

  static double? _parseMdhd(ByteData data, int start, int end) {
    if (start + 20 > end) return null;
    final version = data.getUint8(start);

    int timescale;
    int duration;

    if (version == 0) {
      if (start + 20 > end) return null;
      timescale = data.getUint32(start + 12);
      duration = data.getUint32(start + 16);
    } else if (version == 1) {
      if (start + 32 > end) return null;
      timescale = data.getUint32(start + 20);
      duration = data.getUint64(start + 24);
    } else {
      return null;
    }

    if (timescale > 0 && duration > 0) {
      return duration / timescale;
    }
    return null;
  }

  static List<int>? _parseTkhd(ByteData data, int start, int end) {
    if (start + 84 > end) return null;
    final version = data.getUint8(start);

    int widthOffset;
    int heightOffset;

    if (version == 0) {
      widthOffset = start + 76;
      heightOffset = start + 80;
    } else if (version == 1) {
      widthOffset = start + 88;
      heightOffset = start + 92;
    } else {
      return null;
    }

    if (heightOffset + 4 > end) return null;

    // Width and height are 16.16 fixed point numbers (high 16 bits = integer)
    final widthInt = data.getUint32(widthOffset) >> 16;
    final heightInt = data.getUint32(heightOffset) >> 16;

    if (widthInt > 0 && heightInt > 0) {
      return [widthInt, heightInt];
    }
    return null;
  }

  static Mp4MetadataResult? _scanForMvhd(ByteData data, Uint8List bytes) {
    // Search for ASCII 'mvhd' = [0x6D, 0x76, 0x68, 0x64]
    final len = bytes.length;
    for (int i = 0; i <= len - 24; i++) {
      if (bytes[i] == 0x6D &&
          bytes[i + 1] == 0x76 &&
          bytes[i + 2] == 0x68 &&
          bytes[i + 3] == 0x64) {
        // Potential mvhd box! The box payload starts at i + 4
        final dur = _parseMvhd(data, i + 4, len);
        if (dur != null && dur > 0 && dur < 86400 * 30) {
          return Mp4MetadataResult(durationSeconds: dur);
        }
      }
    }
    return null;
  }

  static String _readString(ByteData data, int offset, int length) {
    final chars = <int>[];
    for (int i = 0; i < length; i++) {
      chars.add(data.getUint8(offset + i));
    }
    return String.fromCharCodes(chars);
  }
}
