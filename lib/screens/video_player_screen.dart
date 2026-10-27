import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../providers/feed_provider.dart';
import '../widgets/reels_player_item.dart';
import '../services/video_preload_service.dart';
import '../l10n/app_strings.dart';

class VideoPlayerScreen extends StatefulWidget {
  final List<PostModel> posts;
  final int initialIndex;
  final bool isFromFeed;
  final Function(String tag)? onTagSelected;

  const VideoPlayerScreen({super.key, required this.posts, required this.initialIndex,
    this.isFromFeed = true, this.onTagSelected});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  final List<PostModel> _posts = [];

  @override
  void initState() {
    super.initState();
    _posts.addAll(widget.posts);
    _currentIndex = _posts.isEmpty ? 0 : widget.initialIndex.clamp(0, _posts.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _preloadAdjacentVideos();
  }

  void _preloadAdjacentVideos() {
    if (_currentIndex + 1 < _posts.length) {
      VideoPreloadService().preloadVideo(_posts[_currentIndex + 1]);
    }
    if (_currentIndex + 2 < _posts.length) {
      VideoPreloadService().preloadVideo(_posts[_currentIndex + 2]);
    }
  }

  void _loadMore() {
    if (!widget.isFromFeed || _currentIndex < _posts.length - 4) return;
    context.read<FeedProvider>().loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppStrings.of(context);
    if (widget.isFromFeed) {
      final feed = context.watch<FeedProvider>();
      // Duration probing can reorder the feed. Keep already opened videos in
      // place so background updates cannot replace the video being watched.
      final urls = _posts.map((post) => post.fileUrl).toSet();
      for (final post in feed.posts) {
        if (post.isVideo && urls.add(post.fileUrl)) _posts.add(post);
      }
    }
    return Scaffold(backgroundColor: Colors.black,
      body: _posts.isEmpty
        ? Center(child: Text(tr.noVideosAvailable, style: const TextStyle(color: Colors.white70)))
        : PageView.builder(
            controller: _pageController, scrollDirection: Axis.vertical,
            itemCount: _posts.length,
            // Adjacent widgets are cheap; only the current page owns a decoder.
            allowImplicitScrolling: false,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _loadMore();
              _preloadAdjacentVideos();
            },
            itemBuilder: (context, index) => ReelsPlayerItem(
              key: ValueKey(_posts[index].fileUrl),
              post: _posts[index], isCurrent: index == _currentIndex,
              pageLabel: '${index + 1} / ${_posts.length}',
              onBack: () => Navigator.pop(context),
              onNext: index + 1 < _posts.length ? () => _pageController.nextPage(
                duration: const Duration(milliseconds: 220), curve: Curves.easeOut) : null,
              onTagSelected: (tag) {
                Navigator.pop(context);
                widget.onTagSelected?.call(tag);
              },
            ),
          ),
    );
  }

  @override
  void dispose() {
    VideoPreloadService().cancelAll();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }
}
