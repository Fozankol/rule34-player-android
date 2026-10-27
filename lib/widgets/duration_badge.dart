import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../theme/app_theme.dart';

class DurationBadge extends StatelessWidget {
  final PostModel post;
  final double fontSize;

  const DurationBadge({
    super.key,
    required this.post,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    if (post.isProbing && post.duration == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(191),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Проверяем',
              style: TextStyle(
                color: Colors.amberAccent,
                fontSize: fontSize - 2,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (post.duration == null) {
      return const SizedBox.shrink();
    }

    final isLongVideo = post.duration! >= 120.0; // >= 2 minutes
    final isVeryLongVideo = post.duration! >= 600.0; // >= 10 minutes

    Color badgeColor = Colors.black.withAlpha(191);
    Color textColor = Colors.white;
    Color borderColor = Colors.white24;

    if (isVeryLongVideo) {
      badgeColor = AppTheme.raised;
      textColor = AppTheme.accent;
      borderColor = AppTheme.accent.withAlpha(102);
    } else if (isLongVideo) {
      badgeColor = AppTheme.surface;
      textColor = AppTheme.text;
      borderColor = Colors.white24;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow_rounded,
            size: fontSize + 2,
            color: textColor,
          ),
          const SizedBox(width: 2),
          Text(
            post.formattedDuration,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
