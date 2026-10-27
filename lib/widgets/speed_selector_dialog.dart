import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';

class SpeedSelectorDialog extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;

  const SpeedSelectorDialog({
    super.key,
    required this.currentSpeed,
    required this.onSpeedSelected,
  });

  static const List<double> speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        AppStrings.of(context).isRu ? 'Скорость воспроизведения' : 'Playback Speed',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: speeds.map((spd) {
          final isSelected = (currentSpeed - spd).abs() < 0.01;
          return ListTile(
            title: Text(
              '${spd}x',
              style: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.muted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check, color: AppTheme.accent)
                : null,
            onTap: () {
              onSpeedSelected(spd);
              Navigator.pop(context);
            },
          );
        }).toList(),
      )),
    );
  }
}
