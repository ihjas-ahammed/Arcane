import 'package:intl/intl.dart';
import 'package:missions/src/models/task_models.dart';

class HistoryHelper {
  /// Generates a formatted string of session logs from the last [days] days.
  /// 
  /// Iterates through all tasks and subtasks to collect sessions within the timeframe.
  /// Returns a string suitable for AI context.
  static String getSessionHistoryString(List<MainTask> tasks, int days) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    final buffer = StringBuffer();

    // Flatten all sessions
    List<Map<String, dynamic>> allSessions = [];

    for (var task in tasks) {
      for (var sub in task.subTasks) {
        for (var session in sub.sessions) {
          if (session.startTime.isAfter(cutoff) && session.startTime.isBefore(now)) {
            allSessions.add({
              'session': session,
              'taskName': task.name,
              'subTaskName': sub.name,
            });
          }
        }
      }
    }

    // Sort chronologically (oldest first usually better for history sequence)
    allSessions.sort((a, b) {
      final sA = a['session'] as TaskSession;
      final sB = b['session'] as TaskSession;
      return sA.startTime.compareTo(sB.startTime);
    });

    if (allSessions.isEmpty) {
      return "No session history recorded in the last $days days.";
    }

    for (var item in allSessions) {
      final s = item['session'] as TaskSession;
      final day = DateFormat('EEE').format(s.startTime);
      final date = DateFormat('MM/dd').format(s.startTime);
      final start = DateFormat('HH:mm').format(s.startTime);
      final end = DateFormat('HH:mm').format(s.endTime);
      
      buffer.writeln("[$day $date $start - $end] ${item['taskName']} (${item['subTaskName']})");
    }

    return buffer.toString();
  }
}