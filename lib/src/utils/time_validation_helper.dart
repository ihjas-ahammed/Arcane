import 'package:missions/src/models/task_models.dart';

class TimeValidationHelper {
  /// Checks if the proposed time range [start, end] overlaps with any existing session.
  /// 
  /// [allTasks] is the list of all MainTasks to check against global overlap.
  /// [excludeSessionId] is used when updating a session to ignore itself.
  /// Returns `true` if an overlap is found.
  static bool hasOverlap({
    required DateTime start,
    required DateTime end,
    required List<MainTask> allTasks,
    String? excludeSessionId,
  }) {
    for (var task in allTasks) {
      for (var sub in task.subTasks) {
        for (var session in sub.sessions) {
          if (excludeSessionId != null && session.id == excludeSessionId) {
            continue;
          }
          
          // Check for overlap
          // Overlap exists if (StartA < EndB) and (EndA > StartB)
          if (start.isBefore(session.endTime) && end.isAfter(session.startTime)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Extracts the timestamp from a session ID (format: sess_TIMESTAMP[_random])
  static int getCreationTimestamp(String sessionId) {
    try {
      final parts = sessionId.split('_');
      if (parts.length >= 2) {
        return int.parse(parts[1]);
      }
    } catch (_) {}
    return 0;
  }
}