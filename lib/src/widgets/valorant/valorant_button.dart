import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';

class ValorantButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isPrimary;
  final Color? color;

  const ValorantButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? (isPrimary ? AppTheme.fhAccentRed : AppTheme.fhBgDark);
    final textColor = isPrimary ? AppTheme.fhTextPrimary : AppTheme.fhTextPrimary;
    final borderColor = isPrimary ? Colors.transparent : AppTheme.fhBorderColor;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: effectiveColor,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: const BeveledRectangleBorder(
          side: BorderSide(width: 1), // Will be overridden by style logic if needed
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(6),
            bottomRight: Radius.circular(6)
          )
        ).copyWith(side: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: AppTheme.fontDisplay,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 16
            ),
          ),
        ],
      ),
    );
  }
}