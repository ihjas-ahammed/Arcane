import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/charts/weekly_line_charts.dart';
import 'package:arcane/src/widgets/ui/jwe_panel.dart';

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

      weeklyData[i] = dailySeconds / 60.0; 
      weeklyColors[i] = accentColor;
    }

    final bool hasData = weeklyData.values.any((v) => v > 0);

    return JwePanel(
      title: "7-DAY ACTIVITY",
      accentColor: accentColor,
      child: SizedBox(
        height: 140,
        child: hasData
            ? WeeklyActivityLineChart(
                weeklyData: weeklyData,
                dominantColors: weeklyColors,
                isVirtue: false,
              )
            : const Center(
                child: Text(
                  "NO RECENT ACTIVITY",
                  style: TextStyle(
                    color: JweTheme.textMuted,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
      ),
    );
  }
}