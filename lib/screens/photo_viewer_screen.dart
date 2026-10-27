import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/downloads_provider.dart';
import '../services/realbooru_service.dart';
import '../l10n/app_strings.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<PostModel> posts;
  final int initialIndex;
  final Function(String tag)? onTagSelected;

  const PhotoViewerScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
    this.onTagSelected,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _checkEnrichment(_currentIndex);
  }

  void _checkEnrichment(int index) {
    if (index >= 0 && index < widget.posts.length) {
      final post = widget.posts[index];
      if (post.fileUrl.contains('realbooru.com')) {
        RealbooruService().getDetails(post).then((detailed) {
          if (mounted && _currentIndex == index) {
            post.score = detailed.score;
            post.hasExactScore = true;
            if (detailed.tags.isNotEmpty) post.tags = detailed.tags;
            if (detailed.fileUrl != post.fileUrl) {
              setState(() {
                post.fileUrl = detailed.fileUrl;
              });
            }
          }
        }).catchError((_) {});
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  void _showTagsSheet(PostModel post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1B24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Теги арт #${post.id} (${post.tags.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: post.tags.map((tag) {
                      return ActionChip(
                        backgroundColor: const Color(0xFF282834),
                        label: Text(
                          tag,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                          widget.onTagSelected?.call(tag);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Нет фото для отображения', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final currentPost = widget.posts[_currentIndex];
    final favProvider = context.watch<FavoritesProvider>();
    final isFav = favProvider.isFavorite(currentPost.id);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Horizontal PageView for photos
          PageView.builder(
            controller: _pageController,
            itemCount: widget.posts.length,
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
              });
              _checkEnrichment(idx);
            },
            itemBuilder: (context, index) {
              final post = widget.posts[index];
              final headers = getMediaHeaders(post.fileUrl.isNotEmpty ? post.fileUrl : post.previewUrl);
              final previewHeaders = getMediaHeaders(post.previewUrl.isNotEmpty ? post.previewUrl : post.fileUrl);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
                  });
                },
                child: Center(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: CachedNetworkImage(
                      imageUrl: post.fileUrl.isNotEmpty ? post.fileUrl : post.previewUrl,
                      httpHeaders: headers.isNotEmpty ? headers : null,
                      fit: BoxFit.contain,
                      placeholder: (ctx, url) => Center(
                        child: CachedNetworkImage(
                          imageUrl: post.previewUrl,
                          httpHeaders: previewHeaders.isNotEmpty ? previewHeaders : null,
                          fit: BoxFit.contain,
                        ),
                      ),
                      errorWidget: (ctx, url, err) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image_rounded, size: 48, color: Colors.white30),
                            const SizedBox(height: 8),
                            Text(AppStrings.of(context).imageLoadError, style: const TextStyle(color: Colors.white54)),
                            TextButton(
                              onPressed: () => setState(() {}),
                              child: Text(AppStrings.of(context).retry, style: const TextStyle(color: Color(0xFF00C853))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Top App Bar Controls
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showControls ? MediaQuery.of(context).padding.top + 8 : -80,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(153),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    '${_currentIndex + 1} / ${widget.posts.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${currentPost.score}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          // Bottom Action Bar Controls
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showControls ? MediaQuery.of(context).padding.bottom + 16 : -100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(179),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.redAccent : Colors.white,
                      size: 26,
                    ),
                    onPressed: () {
                      favProvider.toggleFavorite(currentPost);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white, size: 26),
                    onPressed: () {
                      context.read<DownloadsProvider>().startDownload(currentPost);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Скачивание изображения начато'),
                          backgroundColor: Color(0xFF00C853),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.sell_outlined, color: Colors.white, size: 24),
                    onPressed: () => _showTagsSheet(currentPost),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
