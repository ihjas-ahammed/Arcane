import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';

class ValorantCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final Color? backgroundColor;
  final bool isSelected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ValorantCard({
    super.key,
    required this.child,
    this.borderColor,
    this.backgroundColor,
    this.isSelected = false,
    this.onTap,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = isSelected
        ? AppTheme.fhAccentTeal
        : (borderColor ?? AppTheme.fhBorderColor.withValues(alpha: 0.3));
    
    final effectiveBgColor = backgroundColor ?? AppTheme.fhBgDark.withValues(alpha: 0.6);

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          // Custom shape for ink splash to match beveled border
          customBorder: const BeveledRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: ShapeDecoration(
              color: effectiveBgColor,
              shape: BeveledRectangleBorder(
                side: BorderSide(
                  color: effectiveBorderColor,
                  width: isSelected ? 1.5 : 1.0,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ),
            child: Stack(
              children: [
                child,
                // Decorative corner accents for selected state
                if (isSelected) ...[
                  Positioned(
                    top: 0, left: 0,
                    child: Container(width: 8, height: 8, color: AppTheme.fhAccentTeal),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(width: 8, height: 8, color: AppTheme.fhAccentTeal),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}