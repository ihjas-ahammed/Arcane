import 'package:flutter/material.dart' show Color;
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/app_state_models.dart';

class ResolvedDayPlanItem {
  final String compoundId; // original ID in plan (e.g. taskId|subTaskId or taskId|subTaskId|subSubTaskId)
  final String name;       // lowest level task/checkpoint name if nested, else subtask name
  final String parentName; // parent task/subtask name(s)
  final Color color;
  final bool isPhoenix;
  final String mainTaskId;
  final String subTaskId;
  final String? checkpointId; // original checkpoint ID if it was a checkpoint entry
  final String? targetCheckpointId; // lowest level checkpoint ID if nested, else null
  final int totalCheckpoints;
  final int completedCheckpoints;
  final int durationMinutes;
  final bool isRunning;

  ResolvedDayPlanItem({
    required this.compoundId,
    required this.name,
    required this.parentName,
    required this.color,
    this.isPhoenix = false,
    required this.mainTaskId,
    required this.subTaskId,
    this.checkpointId,
    this.targetCheckpointId,
    this.totalCheckpoints = 0,
    this.completedCheckpoints = 0,
    this.durationMinutes = 0,
    this.isRunning = false,
  });
}

class TaskCalculations {
  /// Calculates the total time spent on a subtask for the current day (local time).
  /// Includes completed sessions from today and the current elapsed time of an active timer if running.
  static double getTodaySeconds(SubTask subTask, ActiveTimerInfo? activeTimer, [List<MainTask>? allTasks]) {
    final now = DateTime.now();
    double totalSeconds = getHistoricalTodaySeconds(subTask, allTasks);

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
  /// If [allTasks] is passed, overlapping concurrent sessions are averaged.
  static double getHistoricalTodaySeconds(SubTask subTask, [List<MainTask>? allTasks]) {
    final now = DateTime.now();
    if (allTasks != null) {
      final recalibrated = recalculateAllTimeLogs(allTasks);
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      return (recalibrated.dailySubtaskTimes[todayStr]?[subTask.id] ?? 0).toDouble();
    }

    double totalSeconds = 0;
    for (var session in subTask.sessions) {
      if (_isSameDay(session.startTime, now)) {
        totalSeconds += session.durationSeconds;
      }
    }
    return totalSeconds;
  }

  /// The next checkpoint to tick off for [subTask]: the first (in order)
  /// incomplete checkable node, descending into nested substeps up to [maxDepth]
  /// (or [subTask.depth], defaulting to lowest leaf when null/max).
  /// Returns null when nothing is left to check.
  static SubSubTask? nextCheckpoint(SubTask subTask, {int? maxDepth}) =>
      firstIncompleteCheckpoint(subTask.subSubTasks, maxDepth: maxDepth ?? subTask.depth);

  static SubSubTask? firstIncompleteCheckpoint(
    List<SubSubTask> nodes, {
    int? maxDepth,
    int currentDepth = 1,
  }) {
    for (final n in nodes) {
      if (n.type == 'info') continue;
      final checkableChildren =
          n.substeps.where((c) => c.type != 'info').toList();

      final canDescend = (maxDepth == null || maxDepth <= 0 || currentDepth < maxDepth) &&
          checkableChildren.isNotEmpty;

      if (canDescend) {
        final child = firstIncompleteCheckpoint(
          n.substeps,
          maxDepth: maxDepth,
          currentDepth: currentDepth + 1,
        );
        if (child != null) return child;
        if (!n.completed) return n;
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

  static List<ResolvedDayPlanItem> resolveTopFiveDayPlanTasks({
    required List<MainTask> mainTasks,
    required List<String> plan,
    String? phoenixId,
  }) {
    final List<ResolvedDayPlanItem> resolved = [];
    final Set<String> processedCompoundIds = {};

    ResolvedDayPlanItem? resolveItem(String compoundId) {
      final parts = compoundId.split('|');
      if (parts.length < 2) return null;
      final mTask = mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
      final sTask = mTask?.subTasks.firstWhereOrNull((s) => s.id == parts[1] && !s.isDeleted);
      if (mTask == null || sTask == null || sTask.completed) return null;

      if (parts.length == 3) {
        // It's a checkpoint
        final cp = sTask.findCheckpoint(parts[2]);
        if (cp == null || cp.completed) return null;

        // Resolve nested checkable child respecting subtask depth
        final cpDepth = findCheckpointDepth(sTask.subSubTasks, parts[2]) ?? 1;
        final targetCp = findTargetIncompleteCheckpoint(cp, maxDepth: sTask.depth, currentDepth: cpDepth);
        final targetCpId = (targetCp != null && targetCp.id != cp.id) ? targetCp.id : null;
        final displayName = targetCp?.name ?? cp.name;

        return ResolvedDayPlanItem(
          compoundId: compoundId,
          name: displayName,
          parentName: '${mTask.name} · ${sTask.name}',
          color: mTask.taskColor,
          mainTaskId: mTask.id,
          subTaskId: sTask.id,
          checkpointId: cp.id,
          targetCheckpointId: targetCpId,
        );
      } else {
        // It's a subtask
        // Resolve nested checkable child respecting subtask depth
        final lowestCp = nextCheckpoint(sTask);
        final targetCpId = lowestCp?.id;
        final displayName = lowestCp?.name ?? sTask.name;

        return ResolvedDayPlanItem(
          compoundId: compoundId,
          name: displayName,
          parentName: mTask.name,
          color: mTask.taskColor,
          mainTaskId: mTask.id,
          subTaskId: sTask.id,
          checkpointId: null,
          targetCheckpointId: targetCpId,
        );
      }
    }

    for (final idPair in plan) {
      if (processedCompoundIds.contains(idPair)) continue;
      final item = resolveItem(idPair);
      if (item != null) {
        resolved.add(item);
        processedCompoundIds.add(idPair);
      }
    }

    return resolved.take(5).toList();
  }

  static List<ResolvedDayPlanItem> resolveDayPlanItems({
    required List<MainTask> mainTasks,
    required List<String> compoundIds,
    String? phoenixId,
    Map<String, ActiveTimerInfo>? activeTimers,
  }) {
    final List<ResolvedDayPlanItem> resolved = [];
    for (final compoundId in compoundIds) {
      final parts = compoundId.split('|');
      if (parts.length < 2) continue;

      final mTask = mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
      final sTask = mTask?.subTasks.firstWhereOrNull((s) => s.id == parts[1] && !s.isDeleted);
      if (mTask == null || sTask == null) continue;

      final isRunning = activeTimers?[sTask.id]?.isRunning ?? false;
      final checkables = sTask.getCheckpointsAtDepth();
      final totalCp = checkables.length;
      final completedCp = checkables.where((sst) => sst.completed).length;

      if (parts.length == 3) {
        final cp = sTask.findCheckpoint(parts[2]);
        if (cp == null) continue;
        final cpDepth = findCheckpointDepth(sTask.subSubTasks, parts[2]) ?? 1;
        final targetCp = findTargetIncompleteCheckpoint(cp, maxDepth: sTask.depth, currentDepth: cpDepth);
        final targetCpId = (targetCp != null && targetCp.id != cp.id) ? targetCp.id : null;
        final displayName = targetCp?.name ?? cp.name;

        resolved.add(ResolvedDayPlanItem(
          compoundId: compoundId,
          name: displayName,
          parentName: '${mTask.name} · ${sTask.name}',
          color: mTask.taskColor,
          mainTaskId: mTask.id,
          subTaskId: sTask.id,
          checkpointId: cp.id,
          targetCheckpointId: targetCpId,
          totalCheckpoints: cp.substeps.where((sst) => sst.isActive && sst.type != 'info').length,
          completedCheckpoints: cp.substeps.where((sst) => sst.isActive && sst.type != 'info' && sst.completed).length,
          durationMinutes: defaultCheckpointMinutes,
          isRunning: isRunning,
        ));
      } else {
        final lowestCp = nextCheckpoint(sTask);
        resolved.add(ResolvedDayPlanItem(
          compoundId: compoundId,
          name: lowestCp?.name ?? sTask.name,
          parentName: mTask.name,
          color: mTask.taskColor,
          mainTaskId: mTask.id,
          subTaskId: sTask.id,
          checkpointId: null,
          targetCheckpointId: lowestCp?.id,
          totalCheckpoints: totalCp,
          completedCheckpoints: completedCp,
          durationMinutes: defaultSubtaskMinutes,
          isRunning: isRunning,
        ));
      }
    }
    return resolved;
  }

  static SubSubTask? findTargetIncompleteCheckpoint(
    SubSubTask parent, {
    int? maxDepth,
    int currentDepth = 1,
  }) {
    final checkable = parent.substeps.where((c) => c.type != 'info').toList();
    final canDescend = (maxDepth == null || maxDepth <= 0 || currentDepth < maxDepth) &&
        checkable.isNotEmpty;
    if (!canDescend) {
      return parent.completed ? null : parent;
    }
    for (final child in checkable) {
      final target = findTargetIncompleteCheckpoint(
        child,
        maxDepth: maxDepth,
        currentDepth: currentDepth + 1,
      );
      if (target != null) return target;
    }
    return parent.completed ? null : parent;
  }

  static int? findCheckpointDepth(List<SubSubTask> nodes, String targetId, [int depth = 1]) {
    for (final n in nodes) {
      if (n.id == targetId) return depth;
      final childDepth = findCheckpointDepth(n.substeps, targetId, depth + 1);
      if (childDepth != null) return childDepth;
    }
    return null;
  }

  static const int defaultSubtaskMinutes = 30;
  static const int defaultCheckpointMinutes = 15;

  /// Recalculates all daily and lifetime time logs across all tasks.
  /// When multiple sessions overlap in time (e.g. concurrent sessions on the same day),
  /// the overlapping duration is split evenly (averaged) among the active sessions,
  /// ensuring the total time spent never exceeds the real elapsed wall-clock time.
  static RecalibratedTimeData recalculateAllTimeLogs(List<MainTask> allTasks) {
    final Map<String, Map<String, int>> dailyTaskTimes = {};
    final Map<String, Map<String, int>> dailySubtaskTimes = {};
    final Map<String, int> subtaskLifetimeSeconds = {};
    final Map<String, int> sessionEffectiveSeconds = {};

    // 1. Flatten all valid sessions
    final List<_SessionInterval> intervals = [];
    for (var task in allTasks) {
      for (var sub in task.subTasks) {
        for (var session in sub.sessions) {
          if (session.endTime.isAfter(session.startTime)) {
            intervals.add(_SessionInterval(
              sessionId: session.id,
              subTaskId: sub.id,
              mainTaskId: task.id,
              startTime: session.startTime,
              endTime: session.endTime,
            ));
          }
        }
      }
    }

    if (intervals.isEmpty) {
      return RecalibratedTimeData(
        dailyTaskTimes: dailyTaskTimes,
        dailySubtaskTimes: dailySubtaskTimes,
        subtaskLifetimeSeconds: subtaskLifetimeSeconds,
        sessionEffectiveSeconds: sessionEffectiveSeconds,
      );
    }

    // 2. Collect all boundaries including midnight transitions
    final Set<DateTime> boundarySet = {};
    for (var item in intervals) {
      boundarySet.add(item.startTime);
      boundarySet.add(item.endTime);

      DateTime cursor = DateTime(item.startTime.year, item.startTime.month, item.startTime.day).add(const Duration(days: 1));
      while (cursor.isBefore(item.endTime)) {
        boundarySet.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
    }

    final List<DateTime> sortedPoints = boundarySet.toList()..sort();

    // 3. Process each consecutive non-empty slice [tStart, tEnd]
    for (int i = 0; i < sortedPoints.length - 1; i++) {
      final tStart = sortedPoints[i];
      final tEnd = sortedPoints[i + 1];
      final sliceSeconds = tEnd.difference(tStart).inSeconds;
      if (sliceSeconds <= 0) continue;

      // Find all sessions active during [tStart, tEnd]
      final active = intervals.where((s) =>
        !s.startTime.isAfter(tStart) && !s.endTime.isBefore(tEnd)
      ).toList();

      if (active.isEmpty) continue;

      final count = active.length;
      final base = sliceSeconds ~/ count;
      final remainder = sliceSeconds % count;
      final dateStr = DateFormat('yyyy-MM-dd').format(tStart);

      if (!dailyTaskTimes.containsKey(dateStr)) {
        dailyTaskTimes[dateStr] = {};
      }
      if (!dailySubtaskTimes.containsKey(dateStr)) {
        dailySubtaskTimes[dateStr] = {};
      }

      for (int j = 0; j < count; j++) {
        final s = active[j];
        final allocated = base + (j < remainder ? 1 : 0);

        sessionEffectiveSeconds[s.sessionId] = (sessionEffectiveSeconds[s.sessionId] ?? 0) + allocated;
        subtaskLifetimeSeconds[s.subTaskId] = (subtaskLifetimeSeconds[s.subTaskId] ?? 0) + allocated;
        dailyTaskTimes[dateStr]![s.mainTaskId] = (dailyTaskTimes[dateStr]![s.mainTaskId] ?? 0) + allocated;
        dailySubtaskTimes[dateStr]![s.subTaskId] = (dailySubtaskTimes[dateStr]![s.subTaskId] ?? 0) + allocated;
      }
    }

    return RecalibratedTimeData(
      dailyTaskTimes: dailyTaskTimes,
      dailySubtaskTimes: dailySubtaskTimes,
      subtaskLifetimeSeconds: subtaskLifetimeSeconds,
      sessionEffectiveSeconds: sessionEffectiveSeconds,
    );
  }
}

class RecalibratedTimeData {
  /// Date (yyyy-MM-dd) -> MainTaskId -> seconds spent on that day
  final Map<String, Map<String, int>> dailyTaskTimes;

  /// Date (yyyy-MM-dd) -> SubTaskId -> seconds spent on that day
  final Map<String, Map<String, int>> dailySubtaskTimes;

  /// SubTaskId -> total lifetime seconds spent
  final Map<String, int> subtaskLifetimeSeconds;

  /// SessionId -> total lifetime seconds spent
  final Map<String, int> sessionEffectiveSeconds;

  const RecalibratedTimeData({
    required this.dailyTaskTimes,
    required this.dailySubtaskTimes,
    required this.subtaskLifetimeSeconds,
    required this.sessionEffectiveSeconds,
  });
}

class _SessionInterval {
  final String sessionId;
  final String subTaskId;
  final String mainTaskId;
  final DateTime startTime;
  final DateTime endTime;

  _SessionInterval({
    required this.sessionId,
    required this.subTaskId,
    required this.mainTaskId,
    required this.startTime,
    required this.endTime,
  });
}