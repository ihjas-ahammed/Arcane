import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';

class ValorantAbilitySlot extends StatelessWidget {
  final String label; // e.g. "TIME"
  final String value; // e.g. "01:45"
  final IconData icon;
  final String hotkey; // e.g. "Q"
  final bool isActive;
  final VoidCallback? onTap;

  const ValorantAbilitySlot({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.hotkey,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive
        ? AppTheme.fhAccentTeal
        : AppTheme.fhBorderColor.withValues(alpha: 0.5);
    final bgColor = isActive
        ? AppTheme.fhAccentTeal.withValues(alpha: 0.1)
        : AppTheme.fhTextPrimary.withValues(alpha: 0.08);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The Icon Box
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 1.5),
              borderRadius: BorderRadius.zero, // Sharp edges for Valorant style
            ),
            child: Stack(
              children: [
                // Hotkey Label (Top Left)
                Positioned(
                  top: 2,
                  left: 4,
                  child: Text(
                    hotkey,
                    style: TextStyle(
                      color: AppTheme.fhTextSecondary.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppTheme.fontDisplay,
                    ),
                  ),
                ),
                // Main Icon
                Center(
                  child: Icon(
                    icon,
                    color: isActive ? AppTheme.fhTextPrimary : AppTheme.fhTextSecondary,
                    size: 24,
                  ),
                ),
                // Bottom Value Overlay (Optional, if we want value inside)
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Label and Value Text
          Text(
            label.toUpperCase(),
            style:   TextStyle(
              color: AppTheme.fhTextSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style:   TextStyle(
              color: AppTheme.fhTextPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: AppTheme.fontDisplay,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
