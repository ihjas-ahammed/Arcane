import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/charts/weekly_bar_charts.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';

class SubtaskWeeklyChart extends StatelessWidget {
  final SubTask subTask;
  final Color accentColor;

  const SubtaskWeeklyChart({
    super.key,
    required this.subTask,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Data
    final Map<int, double> weeklyData = {};
    final Map<int, Color> weeklyColors = {};
    final now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      double dailySeconds = 0;

      for (var session in subTask.sessions) {
        if (session.startTime.year == date.year &&
            session.startTime.month == date.month &&
            session.startTime.day == date.day) {
          dailySeconds += session.durationSeconds;
        }
      }

      weeklyData[i] = dailySeconds / 60.0; // Minutes
      weeklyColors[i] = accentColor;
    }

    // 2. Check if empty
    final bool hasData = weeklyData.values.any((v) => v > 0);

    return ValorantCard(
      borderColor: accentColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "PERFORMANCE HISTORY (7 DAYS)",
            style: TextStyle(
              color: AppTheme.fhTextSecondary,
              fontFamily: AppTheme.fontDisplay,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: hasData
                ? WeeklyActivityBarChart(
                    weeklyData: weeklyData,
                    dominantColors: weeklyColors,
                    isVirtue: false,
                  )
                : Center(
                    child: Text(
                      "NO RECENT ACTIVITY",
                      style: TextStyle(
                        color: AppTheme.fhTextDisabled,
                        fontFamily: AppTheme.fontDisplay,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}