import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/download_item.dart';
import '../models/post_model.dart';
import 'database_service.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  final Map<int, CancelToken> _cancelTokens = {};
  final StreamController<DownloadItem> _progressController =
      StreamController<DownloadItem>.broadcast();

  Stream<DownloadItem> get onProgress => _progressController.stream;

  Future<String> _getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final moviesDir = Directory(p.join(externalDir.path, 'R34Videos'));
          if (!await moviesDir.exists()) {
            await moviesDir.create(recursive: true);
          }
          return moviesDir.path;
        }
      }
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory(p.join(appDir.path, 'videos'));
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }
      return videosDir.path;
    } catch (_) {
      // Fallback for desktop / unit testing
      final temp = Directory.systemTemp.createTempSync('r34_downloads');
      return temp.path;
    }
  }

  Future<DownloadItem> startDownload(
    PostModel post, {
    DatabaseService? dbService,
  }) async {
    final db = dbService ?? DatabaseService();
    final downloadDir = await _getDownloadDirectory();
    final ext = post.fileExtension;
    final fileName = 'r34_${post.id}.$ext';
    final savePath = p.join(downloadDir, fileName);

    final item = DownloadItem(
      postId: post.id,
      fileUrl: post.fileUrl,
      localPath: savePath,
      status: DownloadStatus.downloading,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await db.saveDownload(item);

    final cancelToken = CancelToken();
    _cancelTokens[post.id] = cancelToken;

    _dio.download(
      post.fileUrl,
      savePath,
      cancelToken: cancelToken,
      options: Options(headers: getMediaHeaders(
        post.fileUrl,
        userAgent: 'Rule34VideoPlayer/1.0 (Android Downloader)',
      )),
      onReceiveProgress: (received, total) {
        item.downloadedBytes = received;
        item.totalBytes = total;
        item.status = DownloadStatus.downloading;
        _progressController.add(item);
        db.updateDownload(item);
      },
    ).then((_) async {
      item.status = DownloadStatus.completed;
      item.downloadedBytes = item.totalBytes;
      post.isDownloaded = true;
      post.localFilePath = savePath;
      await db.updateDownload(item);
      _progressController.add(item);
    }).catchError((error) async {
      if (error is DioException && CancelToken.isCancel(error)) {
        item.status = DownloadStatus.paused;
      } else {
        item.status = DownloadStatus.failed;
        item.errorMessage = error.toString();
      }
      await db.updateDownload(item);
      _progressController.add(item);
    }).whenComplete(() {
      _cancelTokens.remove(post.id);
    });

    return item;
  }

  void cancelDownload(int postId) {
    final token = _cancelTokens[postId];
    if (token != null && !token.isCancelled) {
      token.cancel('Cancelled by user');
    }
  }

  void dispose() {
    _progressController.close();
    _dio.close();
  }
}
