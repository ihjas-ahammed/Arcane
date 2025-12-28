import 'package:flutter/material.dart';
import 'package:arcane/theme/valorant_theme.dart';

class ValorantButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final IconData? icon;

  const ValorantButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isPrimary ? ValorantColors.red : Colors.transparent,
            border: Border.all(
              color: isPrimary
                  ? ValorantColors.red
                  : ValorantColors.white.withOpacity(0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: ValorantColors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label.toUpperCase(),
                style: ValorantTextStyles.subHeader.copyWith(
                  fontSize: 16,
                  color: ValorantColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
