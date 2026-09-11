import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'tac_colors.dart';

/// Tactical Segmented / Glowing Progress Bar (Matching HTML hud-bar-track & hud-bar-fill)
class TacticalProgressBar extends StatelessWidget {
  final double progress;
  final double width;
  final double height;
  final Color? accent;

  const TacticalProgressBar({
    super.key,
    required this.progress,
    this.width = double.infinity,
    this.height = 4.0,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final effectiveAccent = accent ?? TacColors.primaryRed;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: TacColors.trackBg,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: TacColors.trackBorder, width: 1),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: clamped,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [
                JweTheme.isLight ? const Color(0xFFA51325) : const Color(0xFFE62035),
                effectiveAccent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: effectiveAccent.withValues(alpha: JweTheme.isLight ? 0.35 : 0.55),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
