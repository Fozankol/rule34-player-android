import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/post_model.dart';

class VideoPreloadService {
  static final VideoPreloadService _instance = VideoPreloadService._internal();
  factory VideoPreloadService() => _instance;
  VideoPreloadService._internal();

  final Dio _dio = Dio();
  final Map<int, CancelToken> _activePreloads = {};
  final List<int> _cachedOrder = [];
  static const int _maxCachedFiles = 6;
  Directory? _cacheDir;

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final temp = await getTemporaryDirectory();
    final dir = Directory(p.join(temp.path, 'video_preloads'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  void cancelAll() {
    for (final token in _activePreloads.values) {
      token.cancel();
    }
    _activePreloads.clear();
  }

  Future<void> preloadVideo(PostModel post) async {
    if (!post.isVideo || post.fileUrl.isEmpty) return;
    if (post.localFilePath != null && File(post.localFilePath!).existsSync()) return;
    if (_activePreloads.containsKey(post.id)) return;

    try {
      final dir = await _getCacheDir();
      final ext = post.fileExtension.isNotEmpty ? post.fileExtension : 'mp4';
      final savePath = p.join(dir.path, 'preload_${post.id}.$ext');
      final file = File(savePath);

      if (file.existsSync() && file.lengthSync() > 100000) {
        post.localFilePath = savePath;
        return;
      }

      final cancelToken = CancelToken();
      _activePreloads[post.id] = cancelToken;

      final headers = getMediaHeaders(post.fileUrl, userAgent: 'Rule34VideoPlayer/1.0 (Preloader)');

      await _dio.download(
        post.fileUrl,
        savePath,
        cancelToken: cancelToken,
        options: Options(headers: headers),
      );

      _activePreloads.remove(post.id);

      if (file.existsSync() && file.lengthSync() > 0) {
        post.localFilePath = savePath;
        _cachedOrder.remove(post.id);
        _cachedOrder.add(post.id);
        _pruneCache();
      }
    } catch (_) {
      _activePreloads.remove(post.id);
    }
  }

  void _pruneCache() {
    while (_cachedOrder.length > _maxCachedFiles) {
      final oldestId = _cachedOrder.removeAt(0);
      try {
        final dir = _cacheDir;
        if (dir != null) {
          final files = dir.listSync().whereType<File>().where((f) => f.path.contains('preload_$oldestId.'));
          for (final f in files) {
            f.deleteSync();
          }
        }
      } catch (_) {}
    }
  }

  Future<void> clearAll() async {
    cancelAll();
    _cachedOrder.clear();
    try {
      final dir = await _getCacheDir();
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
      _cacheDir = null;
    } catch (_) {}
  }
}
