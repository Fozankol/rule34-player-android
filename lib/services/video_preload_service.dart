import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/post_model.dart';

class CacheEntry {
  final int postId;
  final String filePath;
  int size;
  DateTime lastAccessed;
  int accessSequence;

  CacheEntry({
    required this.postId,
    required this.filePath,
    required this.size,
    required this.lastAccessed,
    this.accessSequence = 0,
  });
}

class VideoPreloadService {
  static VideoPreloadService _instance = VideoPreloadService._internal();
  factory VideoPreloadService() => _instance;
  VideoPreloadService._internal() {
    _init();
  }

  Dio _dio = Dio();
  int _accessCounter = 0;
  final Map<int, CancelToken> _activePreloads = {};
  final Map<int, CacheEntry> _cacheEntries = {};
  final List<int> _watchedHistory = [];
  Set<int> _aheadPostIds = {};
  int? _currentPlayingId;

  // 500 MB disk cache limit (up to ~25–30 booru videos)
  static const int defaultMaxCacheSizeBytes = 500 * 1024 * 1024;
  int maxCacheSizeBytes = defaultMaxCacheSizeBytes;
  static const int maxWatchedHistory = 5;

  Directory? _cacheDir;
  Future<Directory>? _cacheDirFuture;

  void _init() {
    _getCacheDir().catchError((_) => Directory.systemTemp);
  }

  Future<Directory> _getCacheDir() {
    if (_cacheDir != null) return Future.value(_cacheDir!);
    if (_cacheDirFuture != null) return _cacheDirFuture!;

    _cacheDirFuture = () async {
      Directory temp;
      try {
        temp = await getTemporaryDirectory();
      } catch (_) {
        temp = Directory.systemTemp;
      }
      final dir = Directory(p.join(temp.path, 'video_cache'));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _cacheDir = dir;
      _indexExistingCacheFiles(dir);
      return dir;
    }();

    return _cacheDirFuture!;
  }

  void _indexExistingCacheFiles(Directory dir) {
    try {
      if (!dir.existsSync()) return;
      final files = dir.listSync().whereType<File>();
      for (final file in files) {
        final filename = p.basename(file.path);
        // Clean up incomplete / aborted downloads
        if (filename.endsWith('.tmp')) {
          try {
            file.deleteSync();
          } catch (_) {}
          continue;
        }

        final match = RegExp(r'^(?:video|preload)_(\d+)\.').firstMatch(filename);
        if (match != null) {
          final id = int.tryParse(match.group(1)!);
          if (id != null && file.existsSync()) {
            final len = file.lengthSync();
            if (len > 0) {
              final lastMod = file.lastModifiedSync();
              if (_cacheEntries.containsKey(id)) {
                final existing = _cacheEntries[id]!;
                if (lastMod.isAfter(existing.lastAccessed)) {
                  try {
                    File(existing.filePath).deleteSync();
                  } catch (_) {}
                  _cacheEntries[id] = CacheEntry(
                    postId: id,
                    filePath: file.path,
                    size: len,
                    lastAccessed: lastMod,
                    accessSequence: ++_accessCounter,
                  );
                } else {
                  try {
                    file.deleteSync();
                  } catch (_) {}
                }
              } else {
                _cacheEntries[id] = CacheEntry(
                  postId: id,
                  filePath: file.path,
                  size: len,
                  lastAccessed: lastMod,
                  accessSequence: ++_accessCounter,
                );
              }
            } else {
              try {
                file.deleteSync();
              } catch (_) {}
            }
          }
        }
      }
      _evictIfNeeded();
    } catch (_) {}
  }

  int get totalCacheSizeBytes {
    int total = 0;
    for (final entry in _cacheEntries.values) {
      total += entry.size;
    }
    return total;
  }

  void _touch(int postId) {
    final entry = _cacheEntries[postId];
    if (entry != null) {
      entry.lastAccessed = DateTime.now();
      entry.accessSequence = ++_accessCounter;
      try {
        final file = File(entry.filePath);
        if (file.existsSync()) {
          file.setLastModifiedSync(DateTime.now());
        }
      } catch (_) {}
    }
  }

  void _recordWatched(PostModel post) {
    if (!post.isVideo) return;
    _currentPlayingId = post.id;
    _watchedHistory.remove(post.id);
    _watchedHistory.add(post.id);
    while (_watchedHistory.length > maxWatchedHistory) {
      _watchedHistory.removeAt(0);
    }
    _touch(post.id);
  }

  Future<File?> getCachedFileAsync(PostModel post) async {
    if (_cacheDir == null) {
      await _getCacheDir();
    }
    return getCachedFile(post);
  }

  Future<bool> isCachedAsync(PostModel post) async {
    final file = await getCachedFileAsync(post);
    return file != null;
  }

  File? getCachedFile(PostModel post) {
    // 1. Check in-memory index
    final entry = _cacheEntries[post.id];
    if (entry != null) {
      final file = File(entry.filePath);
      if (file.existsSync() && file.lengthSync() > 0) {
        _touch(post.id);
        post.localFilePath = file.path;
        return file;
      } else {
        _cacheEntries.remove(post.id);
      }
    }

    // 2. Check post.localFilePath
    if (post.localFilePath != null) {
      final file = File(post.localFilePath!);
      if (file.existsSync() && file.lengthSync() > 0) {
        if (_cacheDir != null && p.isWithin(_cacheDir!.path, file.path)) {
          _registerCachedFile(post.id, file.path, file.lengthSync());
        }
        return file;
      }
    }

    // 3. Check cache directory directly
    final dir = _cacheDir;
    if (dir != null && dir.existsSync()) {
      final ext = post.fileExtension.isNotEmpty ? post.fileExtension : 'mp4';
      for (final prefix in ['video_', 'preload_']) {
        final f = File(p.join(dir.path, '$prefix${post.id}.$ext'));
        if (f.existsSync() && f.lengthSync() > 0) {
          _registerCachedFile(post.id, f.path, f.lengthSync());
          post.localFilePath = f.path;
          return f;
        }
      }
    }

    return null;
  }

  bool isCached(PostModel post) => getCachedFile(post) != null;

  void _registerCachedFile(int postId, String filePath, int size) {
    _cacheEntries[postId] = CacheEntry(
      postId: postId,
      filePath: filePath,
      size: size,
      lastAccessed: DateTime.now(),
      accessSequence: ++_accessCounter,
    );
  }

  int _compareLru(CacheEntry a, CacheEntry b) {
    final cmp = a.lastAccessed.compareTo(b.lastAccessed);
    if (cmp != 0) return cmp;
    return a.accessSequence.compareTo(b.accessSequence);
  }

  void _evictIfNeeded() {
    if (totalCacheSizeBytes <= maxCacheSizeBytes) return;

    // Protected IDs: currently playing, last 5 watched, and upcoming 3 ahead
    final protectedIds = <int>{
      if (_currentPlayingId != null) _currentPlayingId!,
      ..._watchedHistory,
      ..._aheadPostIds,
    };

    // 1. Evict candidates outside the protected set, oldest accessed first (LRU)
    final nonProtectedCandidates = _cacheEntries.values
        .where((e) => !protectedIds.contains(e.postId))
        .toList()
      ..sort(_compareLru);

    for (final entry in nonProtectedCandidates) {
      if (totalCacheSizeBytes <= maxCacheSizeBytes) break;
      _deleteEntry(entry);
    }

    // 2. If still over limit, evict speculative ahead preloads first
    // (unplayed speculative items must not displace user's watched history).
    if (totalCacheSizeBytes > maxCacheSizeBytes) {
      final aheadCandidates = _cacheEntries.values
          .where((e) =>
              _aheadPostIds.contains(e.postId) &&
              !_watchedHistory.contains(e.postId) &&
              e.postId != _currentPlayingId)
          .toList()
        ..sort(_compareLru);

      for (final entry in aheadCandidates) {
        if (totalCacheSizeBytes <= maxCacheSizeBytes) break;
        _aheadPostIds.remove(entry.postId);
        _deleteEntry(entry);
      }
    }

    // 3. If still over limit (extreme cache constraint), evict from watched history
    // in LRU order (oldest watched first), preserving the currently active video.
    if (totalCacheSizeBytes > maxCacheSizeBytes) {
      final historyCandidates = _cacheEntries.values
          .where((e) => _watchedHistory.contains(e.postId) && e.postId != _currentPlayingId)
          .toList()
        ..sort(_compareLru);

      for (final entry in historyCandidates) {
        if (totalCacheSizeBytes <= maxCacheSizeBytes) break;
        _watchedHistory.remove(entry.postId);
        _deleteEntry(entry);
      }
    }
  }

  void _deleteEntry(CacheEntry entry) {
    try {
      final file = File(entry.filePath);
      final cacheDir = _cacheDir;
      // Safety check: Never delete any file outside the designated cache directory!
      if (cacheDir == null || !p.isWithin(cacheDir.path, file.path)) {
        _cacheEntries.remove(entry.postId);
        return;
      }
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
    _cacheEntries.remove(entry.postId);
  }

  void evict(int postId) {
    final entry = _cacheEntries[postId];
    if (entry != null) {
      _deleteEntry(entry);
    } else {
      final dir = _cacheDir;
      if (dir != null && dir.existsSync()) {
        try {
          final matches = dir.listSync().whereType<File>().where((f) {
            final name = p.basename(f.path);
            return name.startsWith('video_${postId}.') || name.startsWith('preload_${postId}.');
          });
          for (final f in matches) {
            try {
              f.deleteSync();
            } catch (_) {}
          }
        } catch (_) {}
      }
    }
    _watchedHistory.remove(postId);
  }

  void onPlaybackStopped() {
    cancelAll();
    _aheadPostIds.clear();
    _currentPlayingId = null;
  }

  void onVideoActive(PostModel post) {
    if (!post.isVideo) return;
    _recordWatched(post);
    if (!isCached(post)) {
      preloadVideo(post, isHighPriority: true);
    }
  }

  void updateSlidingWindow({
    required List<PostModel> posts,
    required int currentIndex,
  }) {
    if (posts.isEmpty || currentIndex < 0 || currentIndex >= posts.length) {
      return;
    }

    final currentPost = posts[currentIndex];
    onVideoActive(currentPost);

    // Collect next 3 upcoming videos ahead (skipping non-videos)
    final aheadPosts = <PostModel>[];
    for (int i = currentIndex + 1; i < posts.length && aheadPosts.length < 3; i++) {
      final post = posts[i];
      if (post.isVideo) {
        aheadPosts.add(post);
      }
    }
    _aheadPostIds = aheadPosts.map((p) => p.id).toSet();

    // Preload next 3 videos ahead
    for (final post in aheadPosts) {
      if (!isCached(post)) {
        preloadVideo(post);
      }
    }

    // Cancel active preloads that are outside the sliding window
    // (not current, not in ahead next 3, and not in last 5 watched history)
    final allowedIds = <int>{
      if (currentPost.isVideo) currentPost.id,
      ..._aheadPostIds,
      ..._watchedHistory,
    };

    final toCancel = <int>[];
    for (final id in _activePreloads.keys) {
      if (!allowedIds.contains(id)) {
        toCancel.add(id);
      }
    }
    for (final id in toCancel) {
      cancelPreload(id);
    }
  }

  Future<void> preloadVideo(PostModel post, {bool isHighPriority = false}) async {
    if (!post.isVideo || post.fileUrl.isEmpty) return;
    if (isCached(post)) return;
    if (_activePreloads.containsKey(post.id)) return;

    final cancelToken = CancelToken();
    _activePreloads[post.id] = cancelToken;

    File? tempFile;
    try {
      final dir = await _getCacheDir();
      final ext = post.fileExtension.isNotEmpty ? post.fileExtension : 'mp4';
      final savePath = p.join(dir.path, 'video_${post.id}.$ext');
      final tempPath = '$savePath.${DateTime.now().microsecondsSinceEpoch}.tmp';
      tempFile = File(tempPath);
      final finalFile = File(savePath);

      if (finalFile.existsSync() && finalFile.lengthSync() > 0) {
        post.localFilePath = savePath;
        _registerCachedFile(post.id, savePath, finalFile.lengthSync());
        return;
      }

      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }

      final headers = getMediaHeaders(
        post.fileUrl,
        userAgent: 'Rule34VideoPlayer/1.0 (Preloader)',
      );

      await _dio.download(
        post.fileUrl,
        tempPath,
        cancelToken: cancelToken,
        options: Options(headers: headers),
      );

      if (tempFile.existsSync() && tempFile.lengthSync() > 0) {
        if (finalFile.existsSync()) {
          try {
            finalFile.deleteSync();
          } catch (_) {}
        }
        try {
          tempFile.renameSync(savePath);
        } catch (_) {
          try {
            tempFile.copySync(savePath);
            tempFile.deleteSync();
          } catch (_) {}
        }
        if (finalFile.existsSync() && finalFile.lengthSync() > 0) {
          post.localFilePath = savePath;
          _registerCachedFile(post.id, savePath, finalFile.lengthSync());
          _evictIfNeeded();
        }
      } else if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    } catch (e) {
      try {
        if (tempFile != null && tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      } catch (_) {}
    } finally {
      if (_activePreloads[post.id] == cancelToken) {
        _activePreloads.remove(post.id);
      }
    }
  }

  void cancelPreload(int postId) {
    final token = _activePreloads.remove(postId);
    if (token != null) {
      try {
        token.cancel('Far away from current window');
      } catch (_) {}
    }
  }

  void cancelAll() {
    for (final token in _activePreloads.values) {
      try {
        token.cancel('Cancel all preloads');
      } catch (_) {}
    }
    _activePreloads.clear();
  }

  Future<void> clearAll() async {
    cancelAll();
    _watchedHistory.clear();
    _cacheEntries.clear();
    _aheadPostIds.clear();
    _currentPlayingId = null;
    try {
      final dir = await _getCacheDir();
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
      _cacheDir = null;
      _cacheDirFuture = null;
    } catch (_) {}
  }

  // Testing helpers
  int get activePreloadsCount => _activePreloads.length;
  int get cachedEntriesCount => _cacheEntries.length;
  List<int> get watchedHistory => List.unmodifiable(_watchedHistory);
  Set<int> get aheadPostIds => Set.unmodifiable(_aheadPostIds);
  int? get currentPlayingId => _currentPlayingId;

  void setCacheDirForTesting(Directory dir) {
    _cacheDir = dir;
    _cacheDirFuture = Future.value(dir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _cacheEntries.clear();
    _indexExistingCacheFiles(dir);
  }

  void setDioForTesting(Dio dio) {
    _dio = dio;
  }

  void resetForTesting() {
    cancelAll();
    _cacheEntries.clear();
    _watchedHistory.clear();
    _aheadPostIds.clear();
    _currentPlayingId = null;
    _accessCounter = 0;
    maxCacheSizeBytes = defaultMaxCacheSizeBytes;
    _cacheDir = null;
    _cacheDirFuture = null;
    _dio = Dio();
  }

  void setEntryTimestampForTesting(int postId, DateTime timestamp) {
    final entry = _cacheEntries[postId];
    if (entry != null) {
      entry.lastAccessed = timestamp;
    }
  }
}
