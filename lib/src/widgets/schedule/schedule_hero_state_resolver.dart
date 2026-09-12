import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/day_budget_helper.dart';
import 'package:missions/src/utils/task_calculations.dart';

class ScheduleHeroResolvedState {
  final String? nextQueueId;
  final SubTask? nextSubTask;
  final MainTask? nextMainTask;
  final SubSubTask? nextCheckpoint;
  final bool isRunning;
  final double accumulatedTodaySeconds;
  final DateTime? sessionStart;
  final int plannedMin;
  final int realisticMin;
  final List<ResolvedDayPlanItem> topFiveTasks;
  final List<ResolvedDayPlanItem> multitaskItems;

  const ScheduleHeroResolvedState({
    required this.nextQueueId,
    required this.nextSubTask,
    required this.nextMainTask,
    required this.nextCheckpoint,
    required this.isRunning,
    required this.accumulatedTodaySeconds,
    required this.sessionStart,
    required this.plannedMin,
    required this.realisticMin,
    required this.topFiveTasks,
    required this.multitaskItems,
  });
}

class ScheduleHeroStateResolver {
  static ScheduleHeroResolvedState resolve({
    required AppProvider provider,
    required DateTime selectedDate,
  }) {
    String? nextQueueId;
    SubTask? nextSubTask;
    MainTask? nextMainTask;
    SubSubTask? nextCheckpoint;

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final plan = List<String>.from(provider.taskActions.getDayPlan(selectedDateStr));

    // PRIORITY 1 — a live, running session always claims the hero spot.
    final runningEntry = provider.activeTimers.entries
        .firstWhereOrNull((e) => e.value.isRunning && e.value.type == 'subtask');
    if (runningEntry != null) {
      final m = provider.mainTasks.firstWhereOrNull(
          (t) => t.id == runningEntry.value.mainTaskId && !t.isDeleted);
      final s = m?.subTasks
          .firstWhereOrNull((st) => st.id == runningEntry.key && !st.isDeleted);
      if (m != null && s != null && !s.completed) {
        nextMainTask = m;
        nextSubTask = s;
        // If this task is in selected date's plan, retain its queue id so the
        // "FINISH" button still drops it from the plan.
        final inPlan = plan.firstWhereOrNull((p) {
          final parts = p.split('|');
          return parts.length >= 2 && parts[0] == m.id && parts[1] == s.id;
        });
        if (inPlan != null) {
          nextQueueId = inPlan;
          final parts = inPlan.split('|');
          if (parts.length == 3) {
            final cp = s.findCheckpoint(parts[2]);
            if (cp != null) {
              final cpDepth = TaskCalculations.findCheckpointDepth(s.subSubTasks, parts[2]) ?? 1;
              nextCheckpoint = TaskCalculations.findTargetIncompleteCheckpoint(cp, maxDepth: s.depth, currentDepth: cpDepth) ?? cp;
            }
          } else {
            nextCheckpoint = TaskCalculations.nextCheckpoint(s);
          }
        } else {
          nextCheckpoint = TaskCalculations.nextCheckpoint(s);
        }
      }
    }

    // PRIORITY 2 — fall back to the next uncompleted entry in the day plan.
    if (nextSubTask == null) {
      for (String idPair in plan) {
        final parts = idPair.split('|');
        if (parts.length >= 2) {
          final mTask = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
          final sTask = mTask?.subTasks.firstWhereOrNull((s) => s.id == parts[1] && !s.isDeleted);

          if (sTask != null && !sTask.completed) {
            if (parts.length == 3) {
              // It's a checkpoint
              final cp = sTask.findCheckpoint(parts[2]);
              if (cp != null && !cp.completed) {
                final cpDepth = TaskCalculations.findCheckpointDepth(sTask.subSubTasks, parts[2]) ?? 1;
                nextQueueId = idPair;
                nextMainTask = mTask;
                nextSubTask = sTask;
                nextCheckpoint = TaskCalculations.findTargetIncompleteCheckpoint(cp, maxDepth: sTask.depth, currentDepth: cpDepth) ?? cp;
                break;
              }
            } else {
              // It's a subtask
              nextQueueId = idPair;
              nextMainTask = mTask;
              nextSubTask = sTask;
              nextCheckpoint = TaskCalculations.nextCheckpoint(sTask);
              break;
            }
          }
        }
      }
    }

    final activeTimer = nextSubTask == null ? null : provider.activeTimers[nextSubTask.id];
    final isRunning = activeTimer?.isRunning == true;
    final accumulatedTodaySeconds = nextSubTask != null
        ? TaskCalculations.getHistoricalTodaySeconds(nextSubTask, provider.mainTasks)
        : 0.0;
    final sessionStart = isRunning ? activeTimer?.startTime : null;

    final now = DateTime.now();
    final dayWindow = resolveDayWindow(provider, now);
    final plannedMin =
        provider.taskActions.plannedMinutesForDay(selectedDateStr);
    final realisticMin = dayWindow.realisticMinutes(now);

    final topFiveTasks = TaskCalculations.resolveTopFiveDayPlanTasks(
      mainTasks: provider.mainTasks,
      plan: plan,
    );

    final planRows = provider.taskActions.getDayPlanRows(selectedDateStr);
    List<String> activeRowCompoundIds = [];
    if (nextSubTask != null) {
      final activeSubId = nextSubTask.id;
      for (final row in planRows) {
        if (row.any((id) {
          final parts = id.split('|');
          return parts.length >= 2 && parts[1] == activeSubId;
        })) {
          activeRowCompoundIds = row;
          break;
        }
      }
    }
    if (activeRowCompoundIds.isEmpty) {
      for (final row in planRows) {
        bool hasUncompleted = false;
        for (final id in row) {
          final parts = id.split('|');
          if (parts.length >= 2) {
            final m = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
            final s = m?.subTasks.firstWhereOrNull((st) => st.id == parts[1] && !st.isDeleted);
            if (s != null && !s.completed) {
              if (parts.length == 3) {
                final cp = s.findCheckpoint(parts[2]);
                if (cp != null && !cp.completed) {
                  hasUncompleted = true;
                  break;
                }
              } else {
                hasUncompleted = true;
                break;
              }
            }
          }
        }
        if (hasUncompleted) {
          activeRowCompoundIds = row;
          break;
        }
      }
    }
    final multitaskItems = TaskCalculations.resolveDayPlanItems(
      mainTasks: provider.mainTasks,
      compoundIds: activeRowCompoundIds,
    );

    return ScheduleHeroResolvedState(
      nextQueueId: nextQueueId,
      nextSubTask: nextSubTask,
      nextMainTask: nextMainTask,
      nextCheckpoint: nextCheckpoint,
      isRunning: isRunning,
      accumulatedTodaySeconds: accumulatedTodaySeconds,
      sessionStart: sessionStart,
      plannedMin: plannedMin,
      realisticMin: realisticMin,
      topFiveTasks: topFiveTasks,
      multitaskItems: multitaskItems,
    );
  }
}
