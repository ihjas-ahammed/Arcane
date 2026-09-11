import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/goal_briefing_helper.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/ui/task_progress_snapshot_view.dart';

class TacticalGoalsBriefingSection extends StatelessWidget {
  final DateTime briefingDate;

  const TacticalGoalsBriefingSection({
    super.key,
    required this.briefingDate,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final yesterdayCompleted = GoalBriefingHelper.getYesterdayCompletedGoals(provider, briefingDate);
    final todayGoalsMap = GoalBriefingHelper.getTodayGoalsForBriefing(provider, briefingDate);
    final completedToday = todayGoalsMap['completed']!;
    final inProgressToday = todayGoalsMap['inProgress']!;
    final weeklyGoals = provider.getGoalsForDate(briefingDate, GoalScope.weekly);
    final monthlyGoals = provider.getGoalsForDate(briefingDate, GoalScope.monthly);
    final periodGoals = [...weeklyGoals, ...monthlyGoals];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        HudSectionHead(
          label: 'GOAL TACTICAL INTEL',
          accent: HudTone.cyan,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: JweTheme.bgDeep.withValues(alpha: 0.6),
            border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Yesterday's Completed Goals
              Row(
                children: [
                  Icon(MdiIcons.trophyOutline, size: 13, color: JweTheme.accentTeal),
                  const SizedBox(width: 6),
                  Text(
                    "YESTERDAY'S COMPLETED",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentTeal,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (yesterdayCompleted.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: yesterdayCompleted.map((g) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: JweTheme.accentTeal.withValues(alpha: 0.12),
                        border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MdiIcons.checkDecagram, size: 12, color: JweTheme.accentTeal),
                          const SizedBox(width: 5),
                          Text(
                            g.title,
                            style: GoogleFonts.saira(
                              color: JweTheme.textWhite,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    'No completed goals recorded from yesterday.',
                    style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 10),
              Divider(color: JweTheme.accentCyan.withValues(alpha: 0.15), height: 1),
              const SizedBox(height: 10),

              // 2. Today's Goals
              Row(
                children: [
                  Icon(MdiIcons.bullseyeArrow, size: 13, color: JweTheme.accentCyan),
                  const SizedBox(width: 6),
                  Text(
                    "TODAY'S GOALS",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentCyan,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Completed goals FIRST
              if (completedToday.isNotEmpty) ...[
                ...completedToday.map((g) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: JweTheme.accentTeal.withValues(alpha: 0.1),
                    border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    children: [
                      Icon(MdiIcons.checkCircleOutline, size: 14, color: JweTheme.accentTeal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          g.title,
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: JweTheme.accentTeal,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: JweTheme.accentTeal.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '100% DONE',
                          style: GoogleFonts.jetBrainsMono(color: JweTheme.accentTeal, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )),
              ],

              // In-Progress goals SECOND
              if (inProgressToday.isNotEmpty) ...[
                ...inProgressToday.map((g) {
                  final ratio = g.getProgressRatio();
                  final pctStr = (ratio * 100).toStringAsFixed(0);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: JweTheme.accentAmber.withValues(alpha: 0.05),
                      border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(MdiIcons.progressClock, size: 13, color: JweTheme.accentAmber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                g.title,
                                style: GoogleFonts.saira(
                                  color: JweTheme.textWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              '$pctStr%',
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TaskDeltaProgressBar(
                          liveProgress: ratio,
                          delta: 0.0,
                          defaultColor: JweTheme.accentAmber,
                          segments: 20,
                          height: 5,
                        ),
                      ],
                    ),
                  );
                }),
              ],

              if (completedToday.isEmpty && inProgressToday.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    'No daily goals set for today.',
                    style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),

              // 3. Weekly & Monthly Goals (Today's Increment)
              if (periodGoals.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: JweTheme.accentCyan.withValues(alpha: 0.15), height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(MdiIcons.trendingUp, size: 13, color: JweTheme.accentCyan),
                    const SizedBox(width: 6),
                    Text(
                      "PERIOD GOALS",
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Column(
                  children: periodGoals.map((g) {
                    final incInfo = GoalBriefingHelper.getDailyBriefingIncrement(provider, g, briefingDate);
                    final liveProgress = g.getProgressRatio();
                    final delta = incInfo.ratioIncrement;
                    final defaultColor = g.scope == GoalScope.weekly ? JweTheme.accentCyan : JweTheme.accentAmber;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: JweTheme.bgDeep.withValues(alpha: 0.4),
                        border: Border.all(color: defaultColor.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: defaultColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  g.scope.name.toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: defaultColor,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  g.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.saira(
                                    color: JweTheme.textWhite,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (delta > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(
                                    '+${(delta * 100).round()}%',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.accentTeal,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Text(
                                '${(liveProgress * 100).round()}%',
                                style: GoogleFonts.jetBrainsMono(
                                  color: defaultColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          TaskDeltaProgressBar(
                            liveProgress: liveProgress,
                            delta: delta,
                            defaultColor: defaultColor,
                            segments: 20,
                            height: 4,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
