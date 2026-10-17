import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/filter_options.dart';
import '../providers/feed_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/video_grid_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import 'video_player_screen.dart';
import 'photo_viewer_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'downloads_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().loadInitial();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      context.read<FeedProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilterBottomSheet(),
    );
  }

  String _getPresetLabel(DurationFilterPreset preset, double minSec) {
    switch (preset) {
      case DurationFilterPreset.all:
        return 'Любая длина';
      case DurationFilterPreset.gt2min:
        return '> 2 мин';
      case DurationFilterPreset.gt5min:
        return '> 5 мин';
      case DurationFilterPreset.gt10min:
        return '> 10 мин';
      case DurationFilterPreset.custom:
        return '> ${(minSec / 60).toStringAsFixed(1)}м';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121217),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _buildFeedTab(),
          const FavoritesScreen(),
          const DownloadsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        backgroundColor: const Color(0xFF1B1B22),
        indicatorColor: const Color(0xFF00C853).withOpacity(0.25),
        onDestinationSelected: (idx) {
          setState(() {
            _selectedTabIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.explore, color: Color(0xFF00C853)),
            label: 'Лента',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline, color: Colors.white70),
            selectedIcon: Icon(Icons.favorite, color: Colors.redAccent),
            label: 'Избранное',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.download, color: Color(0xFF00C853)),
            label: 'Загрузки',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.settings, color: Color(0xFF00C853)),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }

  Widget _buildFeedTab() {
    final feed = context.watch<FeedProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final filter = feed.filterOptions;
    final posts = feed.posts;

    return Scaffold(
      backgroundColor: const Color(0xFF121217),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B22),
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            const Icon(Icons.movie_filter_rounded, color: Color(0xFF00C853), size: 24),
            const SizedBox(width: 8),
            const Text(
              'R34',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 12),

            // Content Type Segment Pill (Все / Видео / Фото)
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF282834),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTypeSegmentButton(
                    label: 'Все',
                    type: ContentTypeFilter.all,
                    current: filter.contentType,
                    onTap: () => feed.setContentType(ContentTypeFilter.all),
                  ),
                  _buildTypeSegmentButton(
                    label: 'Видео',
                    type: ContentTypeFilter.videoOnly,
                    current: filter.contentType,
                    onTap: () => feed.setContentType(ContentTypeFilter.videoOnly),
                  ),
                  _buildTypeSegmentButton(
                    label: 'Фото',
                    type: ContentTypeFilter.photoOnly,
                    current: filter.contentType,
                    onTap: () => feed.setContentType(ContentTypeFilter.photoOnly),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Duration Filter Quick Pill (only when videos are included)
          if (filter.contentType != ContentTypeFilter.photoOnly)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: GestureDetector(
                onTap: _openFilterBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00C853), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF00E676)),
                      const SizedBox(width: 4),
                      Text(
                        _getPresetLabel(filter.preset, filter.minDurationSeconds),
                        style: const TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: 'Поиск по тегам',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            tooltip: 'Фильтры',
            onPressed: _openFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Search Tags Chips
          if (filter.searchTags.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: const Color(0xFF17171F),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filter.searchTags.map((tag) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        backgroundColor: const Color(0xFF282834),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        label: Text(
                          tag,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 13, color: Colors.white54),
                        onDeleted: () => feed.removeSearchTag(tag),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Deep Scanning Live Status Banner
          if (feed.isDeepScanning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              color: const Color(0xFF1E281F),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feed.deepScanStatus,
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Missing API Key Banner for Rule34
          if (settings.booruSource == 'rule34' &&
              (settings.r34UserId.isEmpty || settings.r34ApiKey.isEmpty))
            Container(
              margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF332005),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.6), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_rounded, color: Colors.amberAccent, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Требуется бесплатный API-ключ',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Rule34.xxx закрыл доступ без ключа. Введите его в Настройках или переключите на Realbooru/TBIB.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedTabIndex = 3;
                      });
                    },
                    child: const Text('Ввести', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),

          // Main Grid Content
          Expanded(
            child: feed.isLoading && posts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF00C853)),
                        const SizedBox(height: 16),
                        Text(
                          'Ищем контент (${_getPresetLabel(filter.preset, filter.minDurationSeconds)})...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Глубокое сканирование и проверка контейнеров...',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : feed.errorMessage != null && posts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off_rounded, size: 54, color: Colors.white24),
                              const SizedBox(height: 12),
                              Text(
                                feed.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00C853),
                                ),
                                onPressed: () {
                                  if (feed.errorMessage!.contains('API-ключ') ||
                                      feed.errorMessage!.contains('Настройки')) {
                                    setState(() {
                                      _selectedTabIndex = 3;
                                    });
                                  } else {
                                    feed.loadInitial();
                                  }
                                },
                                child: Text(
                                  feed.errorMessage!.contains('API-ключ') ||
                                          feed.errorMessage!.contains('Настройки')
                                      ? 'Открыть Настройки'
                                      : 'Повторить попытку',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : posts.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.hourglass_empty_rounded,
                                      size: 54, color: Colors.white24),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Нет постов, подходящих под фильтр',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Текущий фильтр: ${_getPresetLabel(filter.preset, filter.minDurationSeconds)}. Проверено ${feed.allPosts.length} постов.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                                  ),
                                  const SizedBox(height: 18),
                                  Wrap(
                                    spacing: 10,
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF282834),
                                        ),
                                        onPressed: () => feed.loadMore(),
                                        child: const Text('Искать дальше'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF00C853),
                                        ),
                                        onPressed: () => feed.setDurationPreset(DurationFilterPreset.all),
                                        child: const Text('Сбросить длительность'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF00C853),
                            backgroundColor: const Color(0xFF1B1B22),
                            onRefresh: () => feed.refresh(),
                            child: GridView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(8),
                              physics: const AlwaysScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.72,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: posts.length + (feed.isLoadingMore ? 2 : 0),
                              itemBuilder: (context, index) {
                                if (index >= posts.length) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E24),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF00C853),
                                      ),
                                    ),
                                  );
                                }

                                final post = posts[index];
                                return VideoGridCard(
                                  post: post,
                                  onTap: () {
                                    if (post.isVideo) {
                                      final videoList = posts.where((p) => p.isVideo).toList();
                                      final vIndex = videoList.indexOf(post);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => VideoPlayerScreen(
                                            posts: videoList,
                                            initialIndex: vIndex != -1 ? vIndex : 0,
                                            isFromFeed: true,
                                            onTagSelected: (tag) {
                                              feed.addSearchTag(tag);
                                            },
                                          ),
                                        ),
                                      );
                                    } else {
                                      final photoList = posts.where((p) => !p.isVideo).toList();
                                      final pIndex = photoList.indexOf(post);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PhotoViewerScreen(
                                            posts: photoList,
                                            initialIndex: pIndex != -1 ? pIndex : 0,
                                            onTagSelected: (tag) {
                                              feed.addSearchTag(tag);
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSegmentButton({
    required String label,
    required ContentTypeFilter type,
    required ContentTypeFilter current,
    required VoidCallback onTap,
  }) {
    final isSelected = type == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C853) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
