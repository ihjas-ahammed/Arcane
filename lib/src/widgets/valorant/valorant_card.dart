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
  final double cornerCut;

  const ValorantCard({
    super.key,
    required this.child,
    this.borderColor,
    this.backgroundColor,
    this.isSelected = false,
    this.onTap,
    this.padding,
    this.margin,
    this.cornerCut = 12.0, // Size of the corner cut
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppTheme.fhBorderColor.withValues(alpha: 0.3);
    final effectiveBgColor = backgroundColor ?? AppTheme.fhBgDark.withValues(alpha: 0.6);

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          // Custom shape for ink splash to match beveled border
          customBorder: BeveledRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(cornerCut),
              bottomRight: Radius.circular(cornerCut),
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
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(cornerCut),
                  bottomRight: Radius.circular(cornerCut),
                ),
              ),
            ),
            child: Stack(
              children: [
                child,
                // Decorative squares for selected/active state
                if (isSelected) ...[
                  Positioned(
                    top: 0, left: 0,
                    child: Container(width: 6, height: 6, color: borderColor),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(width: 6, height: 6, color: borderColor),
                  ),
                ] else ...[
                   // Subtle decoration for normal state
                   Positioned(
                    top: 0, left: 0,
                    child: Container(width: 4, height: 4, color: AppTheme.fhBorderColor),
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