import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart' as helper;

class StartDayRecommendedTasks extends StatelessWidget {
  final AppProvider provider;

  const StartDayRecommendedTasks({
    super.key,
    required this.provider,
  });

  static List<({MainTask task, SubTask sub})> getRecommendedTasks(AppProvider provider) {
    final list = <({MainTask task, SubTask sub})>[];
    final todayStr = helper.getTodayDateString();

    for (final task in provider.mainTasks) {
      if (task.isDeleted || !task.isActive) continue;

      final uncompletedSubs = task.subTasks.where((sub) {
        if (sub.isDeleted || !sub.isActive) return false;
        if (sub.isRecurring && sub.completed) {
          if (sub.completedDate == todayStr) return false;
        }
        return !sub.completed;
      }).toList();

      if (uncompletedSubs.isEmpty) continue;

      uncompletedSubs.sort((a, b) {
        int scoreA = 0;
        if (a.isRecurring) scoreA += 10;
        if (a.calculateProgress() > 0.0 || a.currentTimeSpent > 0) scoreA += 5;
        if (a.why.isNotEmpty || a.what.isNotEmpty) scoreA += 2;

        int scoreB = 0;
        if (b.isRecurring) scoreB += 10;
        if (b.calculateProgress() > 0.0 || b.currentTimeSpent > 0) scoreB += 5;
        if (b.why.isNotEmpty || b.what.isNotEmpty) scoreB += 2;

        return scoreB.compareTo(scoreA);
      });

      final countToTake = uncompletedSubs.length >= 2 ? 2 : uncompletedSubs.length;
      for (int i = 0; i < countToTake; i++) {
        list.add((task: task, sub: uncompletedSubs[i]));
      }
    }

    list.sort((a, b) {
      int scoreA = 0;
      if (a.sub.isRecurring) scoreA += 10;
      if (a.sub.calculateProgress() > 0.0 || a.sub.currentTimeSpent > 0) scoreA += 5;

      int scoreB = 0;
      if (b.sub.isRecurring) scoreB += 10;
      if (b.sub.calculateProgress() > 0.0 || b.sub.currentTimeSpent > 0) scoreB += 5;

      return scoreB.compareTo(scoreA);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = getRecommendedTasks(provider);
    final todayStr = helper.getTodayDateString();
    final plan = List<String>.from(provider.taskActions.getDayPlan(todayStr));

    if (recommendations.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 10, color: JweTheme.accentWarn),
            const SizedBox(width: 8),
            Icon(MdiIcons.starOutline, size: 11, color: JweTheme.accentWarn),
            const SizedBox(width: 5),
            Text(
              'TACTICAL RECOMMENDATIONS',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentWarn,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JweTheme.bgBase,
              border: Border.all(color: JweTheme.border),
            ),
            child: Text(
              'No recommendations available. All tasks completed!',
              style: GoogleFonts.inter(
                color: JweTheme.textMuted,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 10, color: JweTheme.accentWarn),
          const SizedBox(width: 8),
          Icon(MdiIcons.starOutline, size: 11, color: JweTheme.accentWarn),
          const SizedBox(width: 5),
          Text(
            'TACTICAL RECOMMENDATIONS',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.accentWarn,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: JweTheme.bgBase,
            border: Border.all(color: JweTheme.border),
          ),
          child: Column(
            children: List.generate(recommendations.length, (index) {
              final rec = recommendations[index];
              final task = rec.task;
              final sub = rec.sub;
              final color = Color(int.parse('0xFF${task.colorHex}'));

              final compoundId = '${task.id}|${sub.id}';
              final isQueued = plan.contains(compoundId);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Row(
                      children: [
                        Container(width: 4, height: 12, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sub.name,
                                style: GoogleFonts.inter(
                                  color: JweTheme.textWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    task.name.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      color: color,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (sub.isRecurring) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: JweTheme.accentCyan.withValues(alpha: 0.1),
                                        border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        'RECURRING',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.accentCyan,
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (sub.calculateProgress() > 0.0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: JweTheme.accentTeal.withValues(alpha: 0.1),
                                        border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        '${(sub.calculateProgress() * 100).toInt()}% DONE',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.accentTeal,
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            isQueued ? MdiIcons.minus : MdiIcons.plus,
                            size: 16,
                            color: isQueued ? JweTheme.accentRed : JweTheme.accentCyan,
                          ),
                          tooltip: isQueued ? 'Remove from Day Plan' : 'Add to Day Plan',
                          style: IconButton.styleFrom(
                            backgroundColor: (isQueued ? JweTheme.accentRed : JweTheme.accentCyan).withValues(alpha: 0.08),
                            padding: const EdgeInsets.all(6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            if (isQueued) {
                              plan.remove(compoundId);
                            } else {
                              plan.add(compoundId);
                            }
                            provider.taskActions.updateDayPlan(todayStr, plan);
                          },
                        ),
                      ],
                    ),
                  ),
                  if (index < recommendations.length - 1)
                    Divider(color: JweTheme.lineSoft, height: 1),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
