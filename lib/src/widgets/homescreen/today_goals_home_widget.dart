import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// Tactical home-screen widget displaying today's active directives (daily goals).
/// Adapts strictly to dual themes (JweTheme light/dark mode).
class TodayGoalsHomeWidget extends StatelessWidget {
  final List<GoalModel> goals;
  final double progress;
  final int earnedXp;
  final int totalXp;
  final ValueChanged<GoalModel>? onGoalTap;
  final VoidCallback? onOpenArcane;

  const TodayGoalsHomeWidget({
    super.key,
    required this.goals,
    this.progress = 0.0,
    this.earnedXp = 0,
    this.totalXp = 0,
    this.onGoalTap,
    this.onOpenArcane,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = JweTheme.isLight;
    final bgPanel = isLight ? JweTheme.panel : const Color(0xFF0D1426);
    final accentAmber = JweTheme.accentAmber;
    final accentCyan = JweTheme.accentCyan;
    final textWhite = JweTheme.textWhite;
    final textMid = JweTheme.textMid;
    final textMuted = JweTheme.textMuted;

    final completedCount = goals.where((g) => g.getIsEffectiveCompleted()).length;
    final totalCount = goals.length;
    final clampedProgress = totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : progress.clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenArcane,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 400,
          height: 200,
          child: ClipPath(
            clipper: const Chamfer4CornerClipper(chamfer: 10),
            child: CustomPaint(
              foregroundPainter: TacticalCardBorderPainter(
                themeColor: accentAmber,
                chamfer: 10,
                bracketSize: 12,
                leftBarWidth: 3.0,
              ),
              child: Container(
                color: bgPanel,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Row: Tag + XP Badge ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 4, height: 12, color: accentAmber),
                            const SizedBox(width: 8),
                            Text(
                              totalCount > 0
                                  ? '[ DIRECTIVES // 0$completedCount/0$totalCount COMPLETED ]'
                                  : '[ DIRECTIVES // STANDBY ]',
                              style: GoogleFonts.jetBrainsMono(
                                color: accentAmber,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: accentAmber.withValues(alpha: isLight ? 0.12 : 0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: accentAmber.withValues(alpha: 0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(MdiIcons.lightningBolt, size: 11, color: accentAmber),
                              const SizedBox(width: 3),
                              Text(
                                totalXp > 0 ? '+$earnedXp / +$totalXp XP' : '+50 XP / GOAL',
                                style: GoogleFonts.jetBrainsMono(
                                  color: accentAmber,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ── Tactical Progress Bar ──
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: SizedBox(
                              height: 4,
                              child: LinearProgressIndicator(
                                value: clampedProgress,
                                backgroundColor: isLight ? const Color(0xFFE5DFD5) : const Color(0xFF162032),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  clampedProgress >= 1.0 ? JweTheme.accentTeal : accentAmber,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(clampedProgress * 100).toInt()}%',
                          style: GoogleFonts.jetBrainsMono(
                            color: textMuted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── Directives List or Standby State ──
                    Expanded(
                      child: totalCount == 0
                          ? _buildStandbyState(isLight, textWhite, textMuted, accentCyan)
                          : _buildGoalsList(isLight, textWhite, textMid, textMuted, accentAmber, accentCyan),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandbyState(bool isLight, Color textWhite, Color textMuted, Color accentCyan) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(MdiIcons.targetVariant, size: 28, color: accentCyan.withValues(alpha: 0.7)),
          const SizedBox(height: 6),
          Text(
            'NO DIRECTIVES LOGGED FOR TODAY',
            style: GoogleFonts.jetBrainsMono(
              color: textWhite,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'INITIALIZE MISSIONS IN ARCANE GOALS SUITE',
            style: GoogleFonts.jetBrainsMono(
              color: textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsList(
    bool isLight,
    Color textWhite,
    Color textMid,
    Color textMuted,
    Color accentAmber,
    Color accentCyan,
  ) {
    final displayGoals = goals.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final goal in displayGoals)
          _buildGoalItem(goal, isLight, textWhite, textMid, textMuted, accentAmber, accentCyan),
      ],
    );
  }

  Widget _buildGoalItem(
    GoalModel goal,
    bool isLight,
    Color textWhite,
    Color textMid,
    Color textMuted,
    Color accentAmber,
    Color accentCyan,
  ) {
    final isDone = goal.getIsEffectiveCompleted();
    final subTotal = goal.subChecklist.length;
    final subDone = goal.subChecklist.where((s) => s.isCompleted).length;

    String? metaTag;
    if (goal.metricType == GoalMetricType.timeCounter) {
      metaTag = '${goal.currentValue.toInt()}/${goal.targetValue.toInt()}m';
    } else if (subTotal > 0) {
      metaTag = '$subDone/$subTotal CHECKS';
    } else if (goal.metricType == GoalMetricType.counter) {
      metaTag = '${goal.currentValue.toInt()}/${goal.targetValue.toInt()}';
    }

    return InkWell(
      onTap: onGoalTap != null ? () => onGoalTap!(goal) : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.5),
        child: Row(
          children: [
            // Checkbox indicator
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isDone
                    ? accentAmber.withValues(alpha: isLight ? 0.2 : 0.3)
                    : Colors.transparent,
                border: Border.all(
                  color: isDone ? accentAmber : textMuted.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: isDone
                  ? Icon(MdiIcons.check, size: 12, color: accentAmber)
                  : null,
            ),
            const SizedBox(width: 10),
            // Title
            Expanded(
              child: Text(
                goal.title.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  color: isDone ? textMuted : textWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  decorationColor: textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Optional metadata badge (metric / checklist)
            if (metaTag != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: isLight ? Colors.black12 : Colors.white12,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  metaTag,
                  style: GoogleFonts.jetBrainsMono(
                    color: isDone ? textMuted : accentCyan,
                    fontSize: 9.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            // XP pill
            const SizedBox(width: 6),
            Text(
              '+${goal.xpReward}XP',
              style: GoogleFonts.jetBrainsMono(
                color: isDone ? textMuted : accentAmber,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
