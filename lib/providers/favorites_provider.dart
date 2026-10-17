import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import '../services/database_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final List<PostModel> _favorites = [];
  bool _isLoading = false;

  List<PostModel> get favorites => _favorites;
  bool get isLoading => _isLoading;

  FavoritesProvider() {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      final list = await _dbService.getFavorites();
      _favorites.clear();
      _favorites.addAll(list);
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  bool isFavorite(int postId) {
    return _favorites.any((p) => p.id == postId);
  }

  Future<void> toggleFavorite(PostModel post) async {
    final already = isFavorite(post.id);
    if (already) {
      _favorites.removeWhere((p) => p.id == post.id);
      post.isFavorite = false;
      await _dbService.removeFavorite(post.id);
    } else {
      post.isFavorite = true;
      _favorites.insert(0, post);
      await _dbService.saveFavorite(post);
    }
    notifyListeners();
  }
}
