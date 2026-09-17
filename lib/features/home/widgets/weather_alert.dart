import 'package:flutter/material.dart';
import 'package:agrinova/core/constants/colors.dart';

class WeatherAlert extends StatelessWidget {
  final String message;

  const WeatherAlert({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // Define severity based on message content
    final isCritical = message.toLowerCase().contains('badai petir') ||
        message.toLowerCase().contains('tornado') ||
        message.toLowerCase().contains('abu vulkanik') ||
        message.toLowerCase().contains('sangat tinggi') ||
        message.toLowerCase().contains('sangat rendah');

    final bgColor = isCritical ? AppColors.lightRed : Colors.orange.shade50;
    final borderColor = isCritical ? AppColors.red : Colors.orange;
    final iconColor = isCritical ? AppColors.red : Colors.orange.shade800;
    final textColor = isCritical ? Colors.red.shade900 : Colors.orange.shade900;
    final title = isCritical ? 'PERINGATAN BAHAYA!' : 'PERHATIAN CUACA';
    final icon = isCritical ? Icons.warning_amber_rounded : Icons.info_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
