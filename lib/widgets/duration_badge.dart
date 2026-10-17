import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/post_model.dart';

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
          color: Colors.black.withOpacity(0.75),
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
              'PROBING',
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

    Color badgeColor = Colors.black.withOpacity(0.75);
    Color textColor = Colors.white;
    Color borderColor = Colors.white24;

    if (isVeryLongVideo) {
      badgeColor = const Color(0xFF6200EA).withOpacity(0.85); // Deep Purple
      textColor = const Color(0xFFFFD700); // Gold
      borderColor = Colors.amberAccent.withOpacity(0.6);
    } else if (isLongVideo) {
      badgeColor = const Color(0xFF004D40).withOpacity(0.85); // Emerald Green
      textColor = const Color(0xFF69F0AE);
      borderColor = Colors.greenAccent.withOpacity(0.5);
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
