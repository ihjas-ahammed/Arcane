import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/task_calculations.dart';

int calculateProjectStreak(Project project, AppProvider provider) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final recalibrated = TaskCalculations.recalculateAllTimeLogs(provider.mainTasks);
  final Map<String, double> dailySeconds = {};

  for (final key in project.linkedTaskKeys) {
    final parts = key.split('|');
    if (parts.length < 2) continue;
    final subId = parts[1];

    recalibrated.dailySubtaskTimes.forEach((dateStr, subMap) {
      final sSec = subMap[subId] ?? 0;
      if (sSec > 0) {
        dailySeconds[dateStr] = (dailySeconds[dateStr] ?? 0.0) + sSec;
      }
    });

    final timer = provider.activeTimers[subId];
    if (timer != null && timer.isRunning) {
      final elapsed = DateTime.now().difference(timer.startTime).inSeconds;
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      dailySeconds[dateStr] = (dailySeconds[dateStr] ?? 0.0) + elapsed;
    }
  }

  final Set<DateTime> activeDates = {};
  dailySeconds.forEach((dateStr, seconds) {
    if (seconds >= 900.0) {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) {
        activeDates.add(DateTime(parsed.year, parsed.month, parsed.day));
      }
    }
  });

  if (activeDates.isEmpty) return 0;

  int streak = 0;
  DateTime checkDate = today;

  if (activeDates.contains(today)) {
    streak = 1;
    checkDate = today.subtract(const Duration(days: 1));
    while (activeDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
  } else if (activeDates.contains(today.subtract(const Duration(days: 1)))) {
    streak = 1;
    checkDate = today.subtract(const Duration(days: 2));
    while (activeDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
  }

  return streak;
}

ResolvedDayPlanItem? resolveNextProjectTask(Project project, AppProvider provider) {
  for (final key in project.linkedTaskKeys) {
    final parts = key.split('|');
    if (parts.length < 2) continue;
    final mainId = parts[0];
    final subId = parts[1];

    final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == mainId);
    final sub = mainTask?.subTasks.firstWhereOrNull((s) => s.id == subId);
    if (mainTask == null || sub == null || sub.completed) continue;

    final cp = TaskCalculations.nextCheckpoint(sub);
    if (cp != null) {
      return ResolvedDayPlanItem(
        compoundId: '$mainId|$subId|${cp.id}',
        name: cp.name,
        parentName: '${mainTask.name} > ${sub.name}',
        color: mainTask.taskColor,
        isPhoenix: false,
        mainTaskId: mainId,
        subTaskId: subId,
        targetCheckpointId: cp.id,
      );
    } else {
      return ResolvedDayPlanItem(
        compoundId: '$mainId|$subId',
        name: sub.name,
        parentName: mainTask.name,
        color: mainTask.taskColor,
        isPhoenix: false,
        mainTaskId: mainId,
        subTaskId: subId,
      );
    }
  }
  return null;
}
