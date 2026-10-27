import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/filter_options.dart';
import '../providers/feed_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/video_grid_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../theme/app_theme.dart';
import 'video_player_screen.dart';
import 'photo_viewer_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'downloads_screen.dart';
import 'settings_screen.dart';
import '../l10n/app_strings.dart';

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
    final tr = AppStrings.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
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
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.raised,
        onDestinationSelected: (idx) {
          setState(() {
            _selectedTabIndex = idx;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined, color: Colors.white70),
            selectedIcon: const Icon(Icons.explore, color: AppTheme.accent),
            label: tr.feed,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline, color: Colors.white70),
            selectedIcon: const Icon(Icons.favorite, color: Colors.redAccent),
            label: tr.favorites,
          ),
          NavigationDestination(
            icon: const Icon(Icons.download_outlined, color: Colors.white70),
            selectedIcon: const Icon(Icons.download, color: AppTheme.accent),
            label: tr.downloads,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            selectedIcon: const Icon(Icons.settings, color: AppTheme.accent),
            label: tr.settings,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedTab() {
    final tr = AppStrings.of(context);
    final feed = context.watch<FeedProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final filter = feed.filterOptions;
    final posts = feed.posts;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            const Icon(Icons.play_circle_outline_rounded, color: AppTheme.accent, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr.library, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text(const {'rule34': 'Rule34', 'realbooru': 'Realbooru', 'gelbooru': 'Gelbooru',
                'tbib': 'TBIB', 'safebooru': 'Safebooru'}[settings.booruSource] ?? settings.booruSource,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            ])),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: tr.searchTags,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            tooltip: tr.filters,
            onPressed: _openFilterBottomSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              for (final type in ContentTypeFilter.values)
                Padding(padding: const EdgeInsets.only(right: 8), child: _buildTypeSegmentButton(
                  label: [tr.all, tr.videos, tr.photos][type.index], type: type,
                  current: filter.contentType, onTap: () => feed.setContentType(type))),
              const SizedBox(width: 8),
              ActionChip(avatar: const Icon(Icons.tune_rounded, size: 16),
                label: Text(filter.minScore > 0 ? '${filter.minScore}+ лайков' : 'Фильтры'),
                onPressed: _openFilterBottomSheet),
              if (filter.contentType != ContentTypeFilter.photoOnly) ...[
                const SizedBox(width: 8),
                ActionChip(avatar: const Icon(Icons.timer_outlined, size: 16),
                  label: Text(_getPresetLabel(filter.preset, filter.minDurationSeconds)),
                  onPressed: _openFilterBottomSheet),
              ],
            ])),
        ),
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
              color: AppTheme.surface,
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feed.deepScanStatus,
                      style: const TextStyle(
                        color: AppTheme.accent,
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
                border: Border.all(color: Colors.amberAccent.withAlpha(153), width: 0.8),
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
                ? Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.accent),
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
                          'Подбираем публикации по вашим фильтрам',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ))
                : feed.errorMessage != null && posts.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
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
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: const Color(0xFF211B43),
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
                            child: SingleChildScrollView(
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
                                          backgroundColor: AppTheme.accent,
                                          foregroundColor: const Color(0xFF211B43),
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
                            color: AppTheme.accent,
                            backgroundColor: const Color(0xFF1B1B22),
                            onRefresh: () => feed.refresh(),
                            child: GridView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(12),
                              physics: const AlwaysScrollableScrollPhysics(),
                              gridDelegate:
                                   SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: (MediaQuery.of(context).size.width / 180).floor().clamp(2, 5),
                                childAspectRatio: 0.72,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
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
                                        color: AppTheme.accent,
                                      ),
                                    ),
                                  );
                                }

                                final post = posts[index];
                                return VideoGridCard(
                                  post: post,
                                  onTap: () async {
                                    if (post.isVideo) {
                                      final videoList = posts.where((p) => p.isVideo).toList();
                                      final vIndex = videoList.indexOf(post);
                                      await Navigator.push(
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
                                      if (mounted) setState(() {});
                                    } else {
                                      final photoList = posts.where((p) => !p.isVideo).toList();
                                      final pIndex = photoList.indexOf(post);
                                      await Navigator.push(
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
                                      if (mounted) setState(() {});
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
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
