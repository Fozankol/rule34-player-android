import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/download_item.dart';
import '../models/post_model.dart';
import '../services/download_service.dart';
import '../services/database_service.dart';

class DownloadsProvider extends ChangeNotifier {
  final DownloadService _downloadService = DownloadService();
  final DatabaseService _dbService = DatabaseService();

  final List<DownloadItem> _downloads = [];
  StreamSubscription<DownloadItem>? _progressSub;
  bool _isLoading = false;

  List<DownloadItem> get downloads => _downloads;
  bool get isLoading => _isLoading;

  DownloadsProvider() {
    _init();
  }

  void _init() {
    loadDownloads();
    _progressSub = _downloadService.onProgress.listen((item) {
      final index = _downloads.indexWhere((d) => d.postId == item.postId);
      if (index != -1) {
        _downloads[index] = item;
      } else {
        _downloads.insert(0, item);
      }
      notifyListeners();
    });
  }

  Future<void> loadDownloads() async {
    _isLoading = true;
    notifyListeners();

    try {
      final list = await _dbService.getDownloads();
      _downloads.clear();
      _downloads.addAll(list);
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  bool isDownloaded(int postId) {
    return _downloads.any(
      (d) => d.postId == postId && d.status == DownloadStatus.completed,
    );
  }

  DownloadItem? getItem(int postId) {
    try {
      return _downloads.firstWhere((d) => d.postId == postId);
    } catch (_) {
      return null;
    }
  }

  Future<void> startDownload(PostModel post) async {
    final item = await _downloadService.startDownload(post, dbService: _dbService);
    final index = _downloads.indexWhere((d) => d.postId == item.postId);
    if (index != -1) {
      _downloads[index] = item;
    } else {
      _downloads.insert(0, item);
    }
    notifyListeners();
  }

  void cancelDownload(int postId) {
    _downloadService.cancelDownload(postId);
  }

  Future<void> removeDownload(int postId) async {
    _downloads.removeWhere((d) => d.postId == postId);
    await _dbService.removeDownload(postId);
    notifyListeners();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }
}
