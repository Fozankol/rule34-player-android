import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../providers/favorites_provider.dart';
import '../widgets/video_grid_card.dart';
import 'video_player_screen.dart';
import 'photo_viewer_screen.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  int _selectedFilterIndex = 0; // 0 = Все, 1 = Видео, 2 = Фото

  @override
  Widget build(BuildContext context) {
    final favProvider = context.watch<FavoritesProvider>();
    final allFavs = favProvider.favorites;

    List<PostModel> displayedFavs;
    if (_selectedFilterIndex == 1) {
      displayedFavs = allFavs.where((p) => p.isVideo).toList();
    } else if (_selectedFilterIndex == 2) {
      displayedFavs = allFavs.where((p) => !p.isVideo).toList();
    } else {
      displayedFavs = allFavs;
    }

    final tr = AppStrings.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(
          '${tr.favorites} (${allFavs.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                _buildFilterChip('${tr.all} (${allFavs.length})', 0),
                const SizedBox(width: 8),
                _buildFilterChip('${tr.videos} (${allFavs.where((p) => p.isVideo).length})', 1),
                const SizedBox(width: 8),
                _buildFilterChip('${tr.photos} (${allFavs.where((p) => !p.isVideo).length})', 2),
              ],
            ),
          )),
        ),
      ),
      body: favProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : displayedFavs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_border, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text(
                        tr.noFavoritesYet,
                        style: const TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Нажмите на сердечко, чтобы сохранить в коллекцию',
                        style: TextStyle(color: Colors.white30, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.accent,
                  backgroundColor: AppTheme.surface,
                  onRefresh: () => favProvider.loadFavorites(),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: (MediaQuery.of(context).size.width / 180).floor().clamp(2, 5),
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: displayedFavs.length,
                    itemBuilder: (context, index) {
                      final post = displayedFavs[index];
                      return VideoGridCard(
                        post: post,
                        onTap: () {
                          if (post.isVideo) {
                            final videoList = displayedFavs.where((p) => p.isVideo).toList();
                            final vIdx = videoList.indexOf(post);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VideoPlayerScreen(
                                  posts: videoList,
                                  initialIndex: vIdx != -1 ? vIdx : 0,
                                  isFromFeed: false,
                                ),
                              ),
                            );
                          } else {
                            final photoList = displayedFavs.where((p) => !p.isVideo).toList();
                            final pIdx = photoList.indexOf(post);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PhotoViewerScreen(
                                  posts: photoList,
                                  initialIndex: pIdx != -1 ? pIdx : 0,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF211B43) : AppTheme.muted,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
