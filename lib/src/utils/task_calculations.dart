import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/app_state_models.dart';

class TaskCalculations {
  /// Calculates the total time spent on a subtask for the current day (local time).
  /// Includes completed sessions from today and the current elapsed time of an active timer if running.
  static double getTodaySeconds(SubTask subTask, ActiveTimerInfo? activeTimer) {
    final now = DateTime.now();
    double totalSeconds = getHistoricalTodaySeconds(subTask);

    // 2. Add active timer if it started today or is running into today
    if (activeTimer != null && activeTimer.isRunning) {
      // Calculate portion of active timer that falls within today
      final midnight = DateTime(now.year, now.month, now.day);
      final effectiveStart = activeTimer.startTime.isBefore(midnight) 
          ? midnight 
          : activeTimer.startTime;
      
      final elapsedToday = now.difference(effectiveStart).inSeconds.toDouble();
      if (elapsedToday > 0) {
        totalSeconds += elapsedToday;
      }
    }

    return totalSeconds;
  }

  /// Calculates only the sum of completed sessions for today.
  static double getHistoricalTodaySeconds(SubTask subTask) {
    final now = DateTime.now();
    double totalSeconds = 0;
    
    for (var session in subTask.sessions) {
      if (_isSameDay(session.startTime, now)) {
        totalSeconds += session.durationSeconds;
      }
    }
    return totalSeconds;
  }

  /// The next checkpoint to tick off for [subTask]: the first (in order)
  /// incomplete checkable node, descending into nested substeps so the
  /// *lowest* actionable leaf in the hierarchy is returned. Returns null when
  /// nothing is left to check.
  static SubSubTask? nextCheckpoint(SubTask subTask) =>
      _firstIncompleteLeaf(subTask.subSubTasks);

  static SubSubTask? _firstIncompleteLeaf(List<SubSubTask> nodes) {
    for (final n in nodes) {
      if (n.type == 'info') continue;
      final checkableChildren =
          n.substeps.where((c) => c.type != 'info').toList();
      if (checkableChildren.isNotEmpty) {
        final leaf = _firstIncompleteLeaf(n.substeps);
        if (leaf != null) return leaf;
        if (!n.completed) return n; // children done but parent still open
      } else if (!n.completed) {
        return n;
      }
    }
    return null;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Median session duration in minutes from at least 3 historical sessions,
  /// or null when there is not enough data to project.
  static int? medianSessionMinutes(SubTask subTask) {
    final mins = subTask.sessions
        .map((s) => s.durationMinutes)
        .where((m) => m > 0)
        .toList()
      ..sort();
    if (mins.length < 3) return null;
    final mid = mins.length ~/ 2;
    return mins.length.isOdd ? mins[mid] : ((mins[mid - 1] + mins[mid]) / 2).round();
  }

  static const int defaultSubtaskMinutes = 30;
  static const int defaultCheckpointMinutes = 15;
}