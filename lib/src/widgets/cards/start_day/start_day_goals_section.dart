import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/goal_briefing_helper.dart';
import 'package:missions/src/widgets/ui/task_progress_snapshot_view.dart';

class StartDayGoalsSection extends StatelessWidget {
  final AppProvider provider;
  final DateTime reportDate;

  const StartDayGoalsSection({
    super.key,
    required this.provider,
    required this.reportDate,
  });

  @override
  Widget build(BuildContext context) {
    final yesterdayCompleted = GoalBriefingHelper.getYesterdayCompletedGoals(provider, reportDate);
    final todayToComplete = GoalBriefingHelper.getTodayGoalsToComplete(provider, reportDate);
    final weeklyGoals = provider.getGoalsForDate(reportDate, GoalScope.weekly);
    final monthlyGoals = provider.getGoalsForDate(reportDate, GoalScope.monthly);
    final periodGoals = [...weeklyGoals, ...monthlyGoals];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            Container(width: 3, height: 10, color: JweTheme.accentCyan),
            const SizedBox(width: 8),
            Text(
              'GOAL INTEL & EXPECTED INCREMENTS',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentCyan,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: JweTheme.bgDeep.withValues(alpha: 0.65),
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

              // 2. Today's Daily Goals
              Row(
                children: [
                  Icon(MdiIcons.target, size: 13, color: JweTheme.accentCyan),
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
              const SizedBox(height: 6),
              if (todayToComplete.isNotEmpty)
                Column(
                  children: todayToComplete.map((g) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(MdiIcons.checkboxBlankOutline, size: 13, color: JweTheme.accentCyan),
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
                          if (g.targetValue > 1)
                            Text(
                              'Target: ${g.targetValue % 1 == 0 ? g.targetValue.toInt() : g.targetValue}',
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
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
                    'All daily goals completed or no daily goals set for today.',
                    style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),

              // 3. Active Weekly & Monthly Goals
              if (periodGoals.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: JweTheme.accentCyan.withValues(alpha: 0.15), height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(MdiIcons.chartTimelineVariant, size: 13, color: JweTheme.accentAmber),
                    const SizedBox(width: 6),
                    Text(
                      "PERIOD GOALS",
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentAmber,
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
                    final expInfo = GoalBriefingHelper.getExpectedDailyIncrement(provider, g, reportDate);
                    final currentRatio = g.getProgressRatio();
                    final expectedDelta = expInfo.ratioIncrement.clamp(0.0, 1.0 - currentRatio);
                    final projectedRatio = (currentRatio + expectedDelta).clamp(0.0, 1.0);
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
                              Text(
                                '${(currentRatio * 100).round()}%',
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
                            liveProgress: projectedRatio,
                            delta: expectedDelta,
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
