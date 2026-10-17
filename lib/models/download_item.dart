enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  paused,
}

class DownloadItem {
  final int postId;
  final String fileUrl;
  final String localPath;
  int totalBytes;
  int downloadedBytes;
  DownloadStatus status;
  String? errorMessage;
  final int createdAt;

  DownloadItem({
    required this.postId,
    required this.fileUrl,
    required this.localPath,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.queued,
    this.errorMessage,
    required this.createdAt,
  });

  double get progress {
    if (totalBytes <= 0) return 0.0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get formattedProgress {
    if (totalBytes <= 0) return '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    final currentMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final percent = (progress * 100).toInt();
    return '$currentMb / $totalMb MB ($percent%)';
  }

  Map<String, dynamic> toMap() {
    return {
      'post_id': postId,
      'file_url': fileUrl,
      'local_path': localPath,
      'total_bytes': totalBytes,
      'downloaded_bytes': downloadedBytes,
      'status': status.name,
      'error_message': errorMessage,
      'created_at': createdAt,
    };
  }

  factory DownloadItem.fromMap(Map<String, dynamic> map) {
    return DownloadItem(
      postId: (map['post_id'] is int)
          ? map['post_id']
          : int.tryParse(map['post_id'].toString()) ?? 0,
      fileUrl: (map['file_url'] ?? '').toString(),
      localPath: (map['local_path'] ?? '').toString(),
      totalBytes: (map['total_bytes'] is int)
          ? map['total_bytes']
          : int.tryParse(map['total_bytes']?.toString() ?? '0') ?? 0,
      downloadedBytes: (map['downloaded_bytes'] is int)
          ? map['downloaded_bytes']
          : int.tryParse(map['downloaded_bytes']?.toString() ?? '0') ?? 0,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DownloadStatus.queued,
      ),
      errorMessage: map['error_message']?.toString(),
      createdAt: (map['created_at'] is int)
          ? map['created_at']
          : int.tryParse(map['created_at']?.toString() ?? '0') ?? 0,
    );
  }
}
