// lib/src/widgets/cards/task_header_card.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TaskHeaderCard extends StatelessWidget {
  final MainTask task;
  final int yesterdayTime; // Passed from provider logic
  final List<bool> weeklyCompletion;

  const TaskHeaderCard({
    super.key,
    required this.task,
    required this.yesterdayTime,
    required this.weeklyCompletion,
  });

  String _formatMinutesToHHMM(int totalMinutes) {
    final hours = (totalMinutes / 60).floor();
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Comparison: Today vs Yesterday
    final double maxTime = yesterdayTime > 0 ? yesterdayTime.toDouble() : 60.0; // Fallback to 1h if yesterday was 0
    final double progress = task.dailyTimeSpent / maxTime;
    final String timeSpentFormatted = _formatMinutesToHHMM(task.dailyTimeSpent);
    final String maxTimeFormatted = _formatMinutesToHHMM(maxTime.toInt());

    final int daysCompleted = weeklyCompletion.where((c) => c).length;
    final String weeklyText = "WEEKLY PROGRESS";

    return Card(
      color: AppTheme.fhBgMedium,
      margin: const EdgeInsets.only(bottom: 16, left: 0, right: 0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
            color: AppTheme.fhBorderColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.shieldOutline, color: task.taskColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${task.theme.toUpperCase()} PROTOCOL',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: task.taskColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(task.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.fhTextPrimary,
                    fontSize: 24,
                    fontFamily: AppTheme.fontDisplay,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(task.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 14,
                    height: 1.5)),
            const SizedBox(height: 20),
            
            // TIME PROGRESS BAR
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDeepDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.fhBorderColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "TIME ELAPSED (vs Yesterday)",
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.fhTextSecondary,
                            fontWeight: FontWeight.bold)),
                      Text(
                        "$timeSpentFormatted / $maxTimeFormatted",
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.fhTextPrimary,
                            fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    height: 8,
                    decoration: const BoxDecoration(
                      borderRadius:
                          BorderRadius.all(Radius.circular(4)),
                      color: AppTheme.fhBgMedium,
                    ),
                    child: FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.fhAccentTeal.withValues(alpha: 0.7),
                              AppTheme.fhAccentTeal,
                            ],
                          ),
                          boxShadow: [BoxShadow(color: AppTheme.fhAccentTeal.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)]
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // WEEKLY COMPLETION PANEL (Replaces Streak Panel)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDeepDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.fhBorderColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(weeklyText,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.fhTextSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final isComplete =
                          weeklyCompletion.length > index &&
                              weeklyCompletion[index];
                      return Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isComplete ? AppTheme.fhAccentGold.withValues(alpha: 0.2) : Colors.transparent,
                          border: Border.all(color: isComplete ? AppTheme.fhAccentGold : AppTheme.fhTextDisabled.withValues(alpha: 0.3))
                        ),
                        child: isComplete ?  Icon(MdiIcons.check, size: 16, color: AppTheme.fhAccentGold) : null,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}