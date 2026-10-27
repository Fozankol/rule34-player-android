Map<String, String> getMediaHeaders(String url, {String? userAgent}) {
  final headers = <String, String>{};
  headers['User-Agent'] = userAgent ??
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';
  final lower = url.toLowerCase();
  if (lower.contains('realbooru.com')) {
    headers['Referer'] = 'https://realbooru.com/';
  } else if (lower.contains('gelbooru.com')) {
    headers['Referer'] = 'https://gelbooru.com/';
  }
  return headers;
}

String? getMediaReferer(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('realbooru.com')) {
    return 'https://realbooru.com/';
  } else if (lower.contains('gelbooru.com')) {
    return 'https://gelbooru.com/';
  }
  return null;
}

class PostModel {
  final int id;
  int score;
  bool hasExactScore;
  String fileUrl;
  String previewUrl;
  String sampleUrl;
  List<String> tags;
  final int width;
  final int height;
  final String createdAt;
  double? duration; // Duration in seconds, null if not yet probed
  bool isProbing;
  bool isFavorite;
  bool isDownloaded;
  String? localFilePath;

  PostModel({
    required this.id,
    required this.score,
    this.hasExactScore = true,
    required this.fileUrl,
    required this.previewUrl,
    required this.sampleUrl,
    required this.tags,
    required this.width,
    required this.height,
    this.createdAt = '',
    this.duration,
    this.isProbing = false,
    this.isFavorite = false,
    this.isDownloaded = false,
    this.localFilePath,
  });

  bool get isVideo {
    final ext = fileExtension;
    return ext == 'mp4' || ext == 'webm' || ext == 'mkv' || ext == 'mov';
  }

  String get fileExtension {
    final uri = Uri.tryParse(fileUrl);
    final path = uri?.path ?? fileUrl;
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex != -1) {
      return path.substring(dotIndex + 1).toLowerCase();
    }
    return '';
  }

  String get formattedDuration {
    if (duration == null) return '--:--';
    final totalSeconds = duration!.toInt();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  factory PostModel.fromJson(Map<String, dynamic> json, {String source = 'rule34'}) {
    List<String> parsedTags = [];
    if (json['tags'] != null) {
      if (json['tags'] is String) {
        parsedTags = (json['tags'] as String)
            .split(' ')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      } else if (json['tags'] is List) {
        parsedTags = (json['tags'] as List).map((t) => t.toString()).toList();
      }
    }

    int parseId = 0;
    if (json['id'] is int) {
      parseId = json['id'];
    } else if (json['id'] is String) {
      parseId = int.tryParse(json['id']) ?? 0;
    }

    int parseScore = 0;
    if (json['score'] is int) {
      parseScore = json['score'];
    } else if (json['score'] is String) {
      parseScore = int.tryParse(json['score']) ?? 0;
    }

    int parseWidth = 0;
    if (json['width'] is int) {
      parseWidth = json['width'];
    } else if (json['width'] is String) {
      parseWidth = int.tryParse(json['width']) ?? 0;
    }

    int parseHeight = 0;
    if (json['height'] is int) {
      parseHeight = json['height'];
    } else if (json['height'] is String) {
      parseHeight = int.tryParse(json['height']) ?? 0;
    }

    double? parseDuration;
    if (json['duration'] != null) {
      if (json['duration'] is num) {
        parseDuration = (json['duration'] as num).toDouble();
      } else if (json['duration'] is String) {
        parseDuration = double.tryParse(json['duration']);
      }
    }

    String fileUrl = (json['file_url'] ?? '').toString();
    String previewUrl = (json['preview_url'] ?? '').toString();
    String sampleUrl = (json['sample_url'] ?? '').toString();

    final image = (json['image'] ?? '').toString();
    final directory = (json['directory'] ?? '').toString();

    if (fileUrl.isEmpty && image.isNotEmpty) {
      final domain = source == 'gelbooru'
          ? 'https://img4.gelbooru.com'
          : source == 'tbib'
          ? 'https://tbib.org'
          : source == 'safebooru'
              ? 'https://safebooru.org'
              : 'https://wimg.rule34.xxx';
      if (directory.isNotEmpty) {
        fileUrl = '$domain/images/$directory/$image';
        previewUrl = '$domain/thumbnails/$directory/thumbnail_$image';
      } else {
        fileUrl = '$domain/images/$image';
        previewUrl = '$domain/thumbnails/thumbnail_$image';
      }
      sampleUrl = fileUrl;
    }

    if (previewUrl.isEmpty && fileUrl.isNotEmpty) {
      previewUrl = fileUrl;
    }

    return PostModel(
      id: parseId,
      score: parseScore,
      hasExactScore: json['has_exact_score'] != null
          ? (json['has_exact_score'] == true || json['has_exact_score'] == 1)
          : (source != 'realbooru'),
      fileUrl: fileUrl,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      tags: parsedTags,
      width: parseWidth,
      height: parseHeight,
      createdAt: (json['created_at'] ?? '').toString(),
      duration: parseDuration,
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
      isDownloaded: json['is_downloaded'] == true || json['is_downloaded'] == 1,
      localFilePath: json['local_file_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'score': score,
      'has_exact_score': hasExactScore ? 1 : 0,
      'file_url': fileUrl,
      'preview_url': previewUrl,
      'sample_url': sampleUrl,
      'tags': tags.join(' '),
      'width': width,
      'height': height,
      'created_at': createdAt,
      'duration': duration,
      'is_favorite': isFavorite ? 1 : 0,
      'is_downloaded': isDownloaded ? 1 : 0,
      'local_file_path': localFilePath,
    };
  }

  PostModel copyWith({
    int? id,
    int? score,
    bool? hasExactScore,
    String? fileUrl,
    String? previewUrl,
    String? sampleUrl,
    List<String>? tags,
    int? width,
    int? height,
    String? createdAt,
    double? duration,
    bool? isProbing,
    bool? isFavorite,
    bool? isDownloaded,
    String? localFilePath,
  }) {
    return PostModel(
      id: id ?? this.id,
      score: score ?? this.score,
      hasExactScore: hasExactScore ?? this.hasExactScore,
      fileUrl: fileUrl ?? this.fileUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      sampleUrl: sampleUrl ?? this.sampleUrl,
      tags: tags ?? this.tags,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
      isProbing: isProbing ?? this.isProbing,
      isFavorite: isFavorite ?? this.isFavorite,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }
}
