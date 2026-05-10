import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/theme/wellbeing_theme.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class ChartDataHelper {
  static Map<String, dynamic> prepareWeeklyData(
      AppProvider provider,
      String? selectedDate,
      String? selectedTaskFilter,
      String? selectedVirtueFilter) {
    final today = DateTime.now();
    final Map<int, double> activityData = {};
    final Map<int, Color> activityColors = {};
    final Map<int, double> virtueData = {};
    final Map<int, Color> virtueColors = {};

    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final isToday =
          dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());

      // --- Activity Data Calculation ---
      double totalMins = 0;
      Color dominantColor = JweTheme.border;
      double maxMinsForTask = 0;

      if (isToday) {
        for (var task in provider.mainTasks) {
          if (selectedTaskFilter != null && task.name != selectedTaskFilter) {
            continue;
          }

          final mins = calculateDailyTimeFromSessions(task, today).toDouble();
          totalMins += mins;
          if (mins > maxMinsForTask) {
            maxMinsForTask = mins;
            dominantColor = task.taskColor;
          }
        }
      } else {
        final dayData = provider.completedByDay[dateStr];
        if (dayData != null && dayData['taskTimes'] != null) {
          final taskTimes = dayData['taskTimes'] as Map<String, dynamic>;
          taskTimes.forEach((taskId, time) {
            final task = provider.mainTasks.firstWhere(
              (t) => t.id == taskId,
              orElse: () =>
                  MainTask(id: '', name: 'Unknown', description: '', theme: ''),
            );

            if (selectedTaskFilter != null && task.name != selectedTaskFilter) {
              return;
            }

            final mins = (time as num).toDouble() / 60.0;
            totalMins += mins;
            if (mins > maxMinsForTask) {
              maxMinsForTask = mins;
              dominantColor = task.taskColor;
            }
          });
        }
      }
      activityData[i] = totalMins;
      activityColors[i] = dominantColor;

      // --- Virtue Data Calculation ---
      final reflections = provider.reflectionLogs.where((l) {
        return l.timestamp.year == date.year &&
            l.timestamp.month == date.month &&
            l.timestamp.day == date.day;
      });

      double totalXp = 0;
      Map<String, int> virtueTotals = {};

      for (var ref in reflections) {
        ref.xpGained.forEach((k, v) {
          if (selectedVirtueFilter != null && k != selectedVirtueFilter) {
            return;
          }
          virtueTotals[k] = (virtueTotals[k] ?? 0) + v;
          totalXp += v;
        });
      }
      virtueData[i] = totalXp;

      Color dominantVirtueColor = JweTheme.accentAmber; // Default JWE Gold/Amber
      if (virtueTotals.isNotEmpty) {
        var maxVirtue =
            virtueTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
        dominantVirtueColor = WellbeingTheme.getColor(maxVirtue.key);
      }
      virtueColors[i] = dominantVirtueColor;
    }

    // --- Daily Breakdown Data (Pie Chart) ---
    Map<String, double> dailyTaskTimeData = {};
    Map<String, Color> taskColors = {};

    if (selectedDate != null) {
      final isToday =
          selectedDate == DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (isToday) {
        for (var task in provider.mainTasks) {
          final mins = calculateDailyTimeFromSessions(task, today).toDouble();
          if (mins > 0) {
            dailyTaskTimeData[task.name] = mins;
            taskColors[task.name] = task.taskColor;
          }
        }
      } else {
        final summaryData = provider.completedByDay[selectedDate];
        if (summaryData != null && summaryData['taskTimes'] != null) {
          (summaryData['taskTimes'] as Map<String, dynamic>)
              .forEach((taskId, time) {
            final task =
                provider.mainTasks.firstWhereOrNull((t) => t.id == taskId);
            final String name = task?.name ?? "Unknown";
            dailyTaskTimeData[name] = (time as num).toDouble() / 60.0;
            taskColors[name] = task?.taskColor ?? JweTheme.accentCyan;
          });
        }
      }
    }

    return {
      'activityData': activityData,
      'activityColors': activityColors,
      'virtueData': virtueData,
      'virtueColors': virtueColors,
      'dailyTaskTimeData': dailyTaskTimeData,
      'taskColors': taskColors,
    };
  }

  static int calculateDailyTimeFromSessions(
      MainTask task, DateTime startOfDay) {
    int totalMinutes = 0;
    for (var sub in task.subTasks) {
      for (var session in sub.sessions) {
        if (session.startTime.year == startOfDay.year &&
            session.startTime.month == startOfDay.month &&
            session.startTime.day == startOfDay.day) {
          totalMinutes += session.durationMinutes;
        }
      }
    }
    return totalMinutes;
  }
}