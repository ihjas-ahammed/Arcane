import 'package:collection/collection.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/providers/app_provider.dart';

class ScheduleEntryResolver {
  static List<TimelineEntry> buildEntries({
    required AppProvider provider,
    required DateTime selectedDate,
    required List<TimelineEntry> predictedEntries,
  }) {
    final List<TimelineEntry> entries = [];
    final dayStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // 1. Process standard recorded sessions
    // We explicitly DON'T filter deleted tasks here because we want historical records to remain intact!
    for (var task in provider.mainTasks) {
      for (var sub in task.subTasks) {
        for (var session in sub.sessions) {
          if (session.startTime.isBefore(dayEnd) && session.endTime.isAfter(dayStart)) {
            DateTime displayStart = session.startTime.isBefore(dayStart) ? dayStart : session.startTime;
            DateTime displayEnd = session.endTime.isAfter(dayEnd) ? dayEnd : session.endTime;

            entries.add(TimelineEntry(
              id: session.id,
              startTime: displayStart,
              endTime: displayEnd,
              title: sub.name,
              subtitle: task.name,
              color: task.taskColor,
              isEditable: true,
              originalObject: session,
            ));
          }
        }
      }
    }

    // 2. Inject currently running (LIVE) sessions
    provider.activeTimers.forEach((subTaskId, timerState) {
      if (timerState.isRunning && timerState.type == 'subtask') {
        final task = provider.mainTasks.firstWhereOrNull((t) => t.id == timerState.mainTaskId);
        final sub = task?.subTasks.firstWhereOrNull((s) => s.id == subTaskId);
        if (task != null && sub != null) {
          final now = DateTime.now();
          if (timerState.startTime.isBefore(dayEnd) && now.isAfter(dayStart)) {
            DateTime displayStart = timerState.startTime.isBefore(dayStart) ? dayStart : timerState.startTime;
            DateTime displayEnd = now.isAfter(dayEnd) ? dayEnd : now;

            if (displayEnd.isAfter(displayStart)) {
              entries.add(TimelineEntry(
                id: 'live_$subTaskId',
                startTime: displayStart,
                endTime: displayEnd,
                title: sub.name,
                subtitle: "${task.name} (LIVE)",
                color: task.taskColor,
                isEditable: false,
              ));
            }
          }
        }
      }
    });

    // 3. Process predicted entries (ensure no overlap unless all lessons are less than 5 minutes)
    for (var pred in predictedEntries) {
      bool overlaps = false;
      for (var real in entries) {
        if (pred.startTime.isBefore(real.endTime) && pred.endTime.isAfter(real.startTime)) {
          final predIsShort = pred.endTime.difference(pred.startTime) < const Duration(minutes: 5);
          final realIsShort = real.endTime.difference(real.startTime) < const Duration(minutes: 5);
          if (!(predIsShort && realIsShort)) {
            overlaps = true;
            break;
          }
        }
      }
      if (!overlaps) entries.add(pred);
    }

    return entries;
  }
}
