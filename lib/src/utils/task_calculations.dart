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
      // Note: activeTimer.accumulatedDisplayTime usually stores time for the *current session* being recorded.
      // If the timer spans across days (started yesterday, still running), strictly speaking, 
      // we should only count the portion after midnight. 
      // For simplicity in this context, if the timer started today, we count it.
      
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
}