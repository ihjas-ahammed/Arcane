import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/app_state_models.dart';

class TaskCalculations {
  /// Calculates the total time spent on a subtask for the current day (local time).
  /// Includes completed sessions from today and the current elapsed time of an active timer if running.
  static double getTodaySeconds(SubTask subTask, ActiveTimerInfo? activeTimer) {
    final now = DateTime.now();
    double totalSeconds = 0;

    // 1. Sum up historical sessions for today
    for (var session in subTask.sessions) {
      if (_isSameDay(session.startTime, now)) {
        totalSeconds += session.durationSeconds;
      }
    }

    // 2. Add active timer if it started today
    if (activeTimer != null) {
      // If the timer is running, calculate elapsed time since start + accumulated paused time (if logic allows)
      if (_isSameDay(activeTimer.startTime, now)) {
        if (activeTimer.isRunning) {
           final currentSessionDuration = (now.difference(activeTimer.startTime).inMilliseconds / 1000.0);
           totalSeconds += activeTimer.accumulatedDisplayTime + currentSessionDuration;
        } else {
           totalSeconds += activeTimer.accumulatedDisplayTime;
        }
      }
    }

    return totalSeconds;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Calculates the average daily time spent on this subtask over the last 7 days (excluding today).
  /// Used for setting reasonable goals.
  static double getWeeklyAverageSeconds(SubTask subTask) {
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    
    // We want days strictly before today to not skew average with partial today data
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(seconds: 1));

    double totalSeconds = 0;
    int activeDays = 0;
    
    // Map to store seconds per day to count active days properly
    Map<String, double> dailyTotals = {};

    for (var session in subTask.sessions) {
      if (session.startTime.isAfter(oneWeekAgo) && session.startTime.isBefore(yesterday)) {
        final key = "${session.startTime.year}-${session.startTime.month}-${session.startTime.day}";
        dailyTotals[key] = (dailyTotals[key] ?? 0) + session.durationSeconds;
      }
    }

    if (dailyTotals.isEmpty) return 0;

    dailyTotals.forEach((key, val) {
      if (val > 0) {
        totalSeconds += val;
        activeDays++;
      }
    });

    if (activeDays == 0) return 0;
    
    // Return average over active days, or maybe over 7 days if we want consistency?
    // "Last weeks average" typically implies total / 7, but for sparse tasks active days is better.
    // Let's use active days for better "session" target.
    return totalSeconds / activeDays;
  }
}