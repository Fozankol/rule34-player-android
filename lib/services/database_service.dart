import 'dart:async';
import '../models/video_metadata.dart';
import '../models/post_model.dart';
import '../models/download_item.dart';

abstract class DatabaseStorage {
  Future<void> saveMetadata(VideoMetadata meta);
  Future<VideoMetadata?> getMetadata(int postId);
  Future<Map<int, VideoMetadata>> getMetadataBatch(List<int> postIds);

  Future<void> saveFavorite(PostModel post);
  Future<void> removeFavorite(int postId);
  Future<bool> isFavorite(int postId);
  Future<List<PostModel>> getFavorites();

  Future<void> saveDownload(DownloadItem item);
  Future<void> updateDownload(DownloadItem item);
  Future<List<DownloadItem>> getDownloads();
  Future<void> removeDownload(int postId);

  Future<void> addSearchQuery(String query);
  Future<List<String>> getSearchHistory();

  Future<void> clearMetadataCache();
}

class InMemoryDatabaseStorage implements DatabaseStorage {
  final Map<int, VideoMetadata> _memMetadata = {};
  final Map<int, PostModel> _memFavorites = {};
  final Map<int, DownloadItem> _memDownloads = {};
  final List<String> _memHistory = [];

  @override
  Future<void> saveMetadata(VideoMetadata meta) async {
    _memMetadata[meta.postId] = meta;
  }

  @override
  Future<VideoMetadata?> getMetadata(int postId) async {
    return _memMetadata[postId];
  }

  @override
  Future<Map<int, VideoMetadata>> getMetadataBatch(List<int> postIds) async {
    final Map<int, VideoMetadata> map = {};
    for (final id in postIds) {
      if (_memMetadata.containsKey(id)) {
        map[id] = _memMetadata[id]!;
      }
    }
    return map;
  }

  @override
  Future<void> saveFavorite(PostModel post) async {
    post.isFavorite = true;
    _memFavorites[post.id] = post;
  }

  @override
  Future<void> removeFavorite(int postId) async {
    _memFavorites.remove(postId);
  }

  @override
  Future<bool> isFavorite(int postId) async {
    return _memFavorites.containsKey(postId);
  }

  @override
  Future<List<PostModel>> getFavorites() async {
    return _memFavorites.values.toList();
  }

  @override
  Future<void> saveDownload(DownloadItem item) async {
    _memDownloads[item.postId] = item;
  }

  @override
  Future<void> updateDownload(DownloadItem item) async {
    _memDownloads[item.postId] = item;
  }

  @override
  Future<List<DownloadItem>> getDownloads() async {
    return _memDownloads.values.toList();
  }

  @override
  Future<void> removeDownload(int postId) async {
    _memDownloads.remove(postId);
  }

  @override
  Future<void> addSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _memHistory.remove(trimmed);
    _memHistory.insert(0, trimmed);
  }

  @override
  Future<List<String>> getSearchHistory() async {
    return List.unmodifiable(_memHistory);
  }

  @override
  Future<void> clearMetadataCache() async {
    _memMetadata.clear();
  }
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static DatabaseStorage? _storage;

  static void setStorage(DatabaseStorage storage) {
    _storage = storage;
  }

  DatabaseStorage get storage => _storage ??= InMemoryDatabaseStorage();

  void enableInMemoryTestMode() {
    _storage = InMemoryDatabaseStorage();
  }

  // --- Metadata Cache Methods ---

  Future<void> saveMetadata(VideoMetadata meta) => storage.saveMetadata(meta);

  Future<VideoMetadata?> getMetadata(int postId) => storage.getMetadata(postId);

  Future<Map<int, VideoMetadata>> getMetadataBatch(List<int> postIds) =>
      storage.getMetadataBatch(postIds);

  // --- Favorites Methods ---

  Future<void> saveFavorite(PostModel post) => storage.saveFavorite(post);

  Future<void> removeFavorite(int postId) => storage.removeFavorite(postId);

  Future<bool> isFavorite(int postId) => storage.isFavorite(postId);

  Future<List<PostModel>> getFavorites() => storage.getFavorites();

  // --- Downloads Methods ---

  Future<void> saveDownload(DownloadItem item) => storage.saveDownload(item);

  Future<void> updateDownload(DownloadItem item) => storage.updateDownload(item);

  Future<List<DownloadItem>> getDownloads() => storage.getDownloads();

  Future<void> removeDownload(int postId) => storage.removeDownload(postId);

  // --- Search History ---

  Future<void> addSearchQuery(String query) => storage.addSearchQuery(query);

  Future<List<String>> getSearchHistory() => storage.getSearchHistory();

  // --- Cache Clearing ---

  Future<void> clearMetadataCache() => storage.clearMetadataCache();
}
