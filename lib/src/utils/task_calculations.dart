import 'package:flutter/material.dart' show Color;
import 'package:collection/collection.dart';
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

  ResolvedDayPlanItem({
    required this.compoundId,
    required this.name,
    required this.parentName,
    required this.color,
    required this.isPhoenix,
    required this.mainTaskId,
    required this.subTaskId,
    this.checkpointId,
    this.targetCheckpointId,
  });
}

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

  static List<ResolvedDayPlanItem> resolveTopFiveDayPlanTasks({
    required List<MainTask> mainTasks,
    required List<String> plan,
    required String? phoenixId,
  }) {
    final List<ResolvedDayPlanItem> resolved = [];
    final Set<String> processedCompoundIds = {};

    ResolvedDayPlanItem? resolveItem(String compoundId, bool isPhoenix) {
      final parts = compoundId.split('|');
      if (parts.length < 2) return null;
      final mTask = mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
      final sTask = mTask?.subTasks.firstWhereOrNull((s) => s.id == parts[1] && !s.isDeleted);
      if (mTask == null || sTask == null || sTask.completed) return null;

      if (parts.length == 3) {
        // It's a checkpoint
        final cp = sTask.findCheckpoint(parts[2]);
        if (cp == null || cp.completed) return null;

        // Resolve nested checkable child
        final lowestCp = _findLowestIncompleteSubSubTask(cp);
        final targetCpId = (lowestCp != null && lowestCp.id != cp.id) ? lowestCp.id : null;
        final displayName = lowestCp?.name ?? cp.name;

        return ResolvedDayPlanItem(
          compoundId: compoundId,
          name: displayName,
          parentName: '${mTask.name} · ${sTask.name}',
          color: mTask.taskColor,
          isPhoenix: isPhoenix,
          mainTaskId: mTask.id,
          subTaskId: sTask.id,
          checkpointId: cp.id,
          targetCheckpointId: targetCpId,
        );
      } else {
        // It's a subtask
        // Resolve nested checkable child
        final lowestCp = nextCheckpoint(sTask);
        final targetCpId = lowestCp?.id;
        final displayName = lowestCp?.name ?? sTask.name;

        return ResolvedDayPlanItem(
          compoundId: compoundId,
          name: displayName,
          parentName: mTask.name,
          color: mTask.taskColor,
          isPhoenix: isPhoenix,
          mainTaskId: mTask.id,
          subTaskId: sTask.id,
          checkpointId: null,
          targetCheckpointId: targetCpId,
        );
      }
    }

    // 1. Resolve Phoenix first
    if (phoenixId != null) {
      final resolvedPhx = resolveItem(phoenixId, true);
      if (resolvedPhx != null) {
        resolved.add(resolvedPhx);
        processedCompoundIds.add(phoenixId);
      }
    }

    // 2. Resolve other plan items
    for (final idPair in plan) {
      if (processedCompoundIds.contains(idPair)) continue;
      final item = resolveItem(idPair, false);
      if (item != null) {
        resolved.add(item);
        processedCompoundIds.add(idPair);
      }
    }

    return resolved.take(5).toList();
  }

  static SubSubTask? _findLowestIncompleteSubSubTask(SubSubTask parent) {
    final checkable = parent.substeps.where((c) => c.type != 'info').toList();
    if (checkable.isEmpty) {
      return parent.completed ? null : parent;
    }
    for (final child in checkable) {
      final leaf = _findLowestIncompleteSubSubTask(child);
      if (leaf != null) return leaf;
    }
    return parent.completed ? null : parent;
  }

  static const int defaultSubtaskMinutes = 30;
  static const int defaultCheckpointMinutes = 15;
}