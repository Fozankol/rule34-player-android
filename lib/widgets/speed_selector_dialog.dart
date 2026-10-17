import 'package:flutter/material.dart';

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
      backgroundColor: const Color(0xFF1F1F28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Скорость воспроизведения',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: speeds.map((spd) {
          final isSelected = (currentSpeed - spd).abs() < 0.01;
          return ListTile(
            title: Text(
              '${spd}x',
              style: TextStyle(
                color: isSelected ? Colors.greenAccent : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check, color: Colors.greenAccent)
                : null,
            onTap: () {
              onSpeedSelected(spd);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}
