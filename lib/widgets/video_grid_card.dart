import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import 'duration_badge.dart';
import '../theme/app_theme.dart';

class VideoGridCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;

  const VideoGridCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValidPreview =
        post.previewUrl.isNotEmpty && post.previewUrl.startsWith('http');

    final imageHeaders = getMediaHeaders(
      post.previewUrl.isNotEmpty ? post.previewUrl : post.fileUrl,
      userAgent: 'Rule34VideoPlayer/1.0',
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppTheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail Image
            if (hasValidPreview)
              CachedNetworkImage(
                imageUrl: post.previewUrl,
                fit: BoxFit.cover,
                httpHeaders: imageHeaders,
                placeholder: (context, url) => Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(Icons.image_outlined, size: 30, color: AppTheme.muted),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.black45,
                  child: Center(
                    child: Icon(
                      post.isVideo ? Icons.videocam_off : Icons.broken_image,
                      color: Colors.white38,
                    ),
                  ),
                ),
              )
            else
              Container(
                color: Colors.black45,
                child: Center(
                  child: Icon(
                    post.isVideo ? Icons.movie_outlined : Icons.image_outlined,
                    size: 40,
                    color: Colors.white30,
                  ),
                ),
              ),

            // Top gradient overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 48,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),

            // Score Badge (Top Left)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, size: 12, color: AppTheme.error),
                    const SizedBox(width: 3),
                    Text(
                      post.hasExactScore
                          ? '${post.score}'
                          : (post.score > 0 ? '${post.score}+' : '...'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Format / Resolution Badge (Top Right)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  post.fileExtension.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Bottom gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 56,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),

            // Duration Badge or Photo Badge (Bottom Right)
            Positioned(
              bottom: 6,
              right: 6,
              child: post.isVideo
                  ? DurationBadge(post: post)
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.muted.withAlpha(128), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image, size: 11, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'ФОТО',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Post ID (Bottom Left)
            Positioned(
              bottom: 6,
              left: 6,
              child: Text(
                '#${post.id}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
