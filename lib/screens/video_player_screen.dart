import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../providers/feed_provider.dart';
import '../widgets/reels_player_item.dart';

class VideoPlayerScreen extends StatefulWidget {
  final List<PostModel> posts;
  final int initialIndex;
  final bool isFromFeed;
  final Function(String tag)? onTagSelected;

  const VideoPlayerScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
    this.isFromFeed = true,
    this.onTagSelected,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  void _checkAutoLoadMore(int currentIndex, int totalCount) {
    if (widget.isFromFeed && currentIndex >= totalCount - 4) {
      final feed = context.read<FeedProvider>();
      if (!feed.isLoadingMore && feed.hasMore) {
        feed.loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If opened from main feed, observe reactive posts so dynamically loaded pages appear automatically
    List<PostModel> currentPosts = widget.posts;
    if (widget.isFromFeed) {
      final feedPosts = context.watch<FeedProvider>().posts.where((p) => p.isVideo).toList();
      if (feedPosts.isNotEmpty) {
        currentPosts = feedPosts;
      }
    }

    if (currentPosts.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Нет доступных видео',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final safeIndex = _currentIndex.clamp(0, currentPosts.length - 1);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Reels vertical page view with implicit scrolling for instant pre-buffering
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: true,
            itemCount: currentPosts.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              _checkAutoLoadMore(index, currentPosts.length);
            },
            itemBuilder: (context, index) {
              final isCurrent = index == safeIndex;
              final isPreload = index == safeIndex + 1;

              return ReelsPlayerItem(
                post: currentPosts[index],
                isCurrent: isCurrent,
                isPreload: isPreload,
                onTagSelected: (tag) {
                  Navigator.pop(context);
                  widget.onTagSelected?.call(tag);
                },
              );
            },
          ),

          // Top navigation bar overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${safeIndex + 1} / ${currentPosts.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Balance spacing
              ],
            ),
          ),
        ],
      ),
    );
  }
}
