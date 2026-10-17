class VideoMetadata {
  final int postId;
  final String fileUrl;
  final double durationSeconds;
  final int width;
  final int height;
  final String format;
  final int checkedAt;

  VideoMetadata({
    required this.postId,
    required this.fileUrl,
    required this.durationSeconds,
    this.width = 0,
    this.height = 0,
    this.format = 'unknown',
    required this.checkedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'post_id': postId,
      'file_url': fileUrl,
      'duration_seconds': durationSeconds,
      'width': width,
      'height': height,
      'format': format,
      'checked_at': checkedAt,
    };
  }

  factory VideoMetadata.fromMap(Map<String, dynamic> map) {
    return VideoMetadata(
      postId: (map['post_id'] is int)
          ? map['post_id']
          : int.tryParse(map['post_id'].toString()) ?? 0,
      fileUrl: (map['file_url'] ?? '').toString(),
      durationSeconds: (map['duration_seconds'] is num)
          ? (map['duration_seconds'] as num).toDouble()
          : double.tryParse(map['duration_seconds'].toString()) ?? 0.0,
      width: (map['width'] is int)
          ? map['width']
          : int.tryParse(map['width']?.toString() ?? '0') ?? 0,
      height: (map['height'] is int)
          ? map['height']
          : int.tryParse(map['height']?.toString() ?? '0') ?? 0,
      format: (map['format'] ?? 'unknown').toString(),
      checkedAt: (map['checked_at'] is int)
          ? map['checked_at']
          : int.tryParse(map['checked_at']?.toString() ?? '0') ?? 0,
    );
  }
}
