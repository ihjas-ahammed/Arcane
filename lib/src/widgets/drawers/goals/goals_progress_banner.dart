import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/drawers/goals/tactical_goal_painters.dart';

class GoalsProgressBanner extends StatelessWidget {
  final GoalScope activeScope;
  final Color themeColor;
  final bool isLight;
  final double progressRatio;
  final int completedCount;
  final int totalCount;

  const GoalsProgressBanner({
    super.key,
    required this.activeScope,
    required this.themeColor,
    required this.isLight,
    required this.progressRatio,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF12131C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.1)
                : JweTheme.lineSoft.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${activeScope.name.toUpperCase()} PROGRESS',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.orbitron(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isLight ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$completedCount / $totalCount COMPLETED (${(progressRatio * 100).toInt()}%)',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 8,
              width: double.infinity,
              child: CustomPaint(
                painter: TacticalProgressBarPainter(
                  progress: progressRatio,
                  activeColor: themeColor,
                  isLight: isLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
