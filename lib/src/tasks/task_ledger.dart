import 'dart:async';
import 'dart:convert';

import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/services/app_action_ledger_service.dart';

/// Records CREATE/UPDATE/DELETE ledger entries for task and subtask changes. Shared by the app
/// and the headless engine, so both record the same history.
void recordTaskLedgerDelta(List<MainTask> oldList, List<MainTask> newList) {
  try {
    final oldMap = {for (final t in oldList) t.id: t};
    final newMap = {for (final t in newList) t.id: t};

    for (final t in newList) {
      if (!oldMap.containsKey(t.id)) {
        unawaited(AppActionLedgerService.instance.recordAction(
          actionType: 'CREATE',
          collection: 'task',
          entityId: t.id,
          title: t.name,
          summary: 'Created mission "${t.name}"',
          before: null,
          after: t.toJson(),
        ));
      }
    }

    for (final t in oldList) {
      if (!newMap.containsKey(t.id)) {
        unawaited(AppActionLedgerService.instance.recordAction(
          actionType: 'DELETE',
          collection: 'task',
          entityId: t.id,
          title: t.name,
          summary: 'Deleted mission "${t.name}"',
          before: t.toJson(),
          after: null,
        ));
      }
    }

    for (final t in newList) {
      if (oldMap.containsKey(t.id)) {
        final oldTask = oldMap[t.id]!;
        // Untouched tasks/subtasks keep their identity across copyWith, so skip the (expensive)
        // serialize-and-compare for everything except what an action actually replaced.
        if (!identical(oldTask, t) && jsonEncode(oldTask.toJson()) != jsonEncode(t.toJson())) {
          final oldSubMap = {for (final s in oldTask.subTasks) s.id: s};
          final newSubMap = {for (final s in t.subTasks) s.id: s};

          for (final s in t.subTasks) {
            if (!oldSubMap.containsKey(s.id)) {
              unawaited(AppActionLedgerService.instance.recordAction(
                actionType: 'CREATE',
                collection: 'subtask',
                entityId: '${t.id}:${s.id}',
                title: s.name,
                summary: 'Added subtask "${s.name}" to "${t.name}"',
                before: null,
                after: s.toJson(),
              ));
            } else {
              final oldS = oldSubMap[s.id]!;
              if (!identical(oldS, s) && jsonEncode(oldS.toJson()) != jsonEncode(s.toJson())) {
                final action = (oldS.completed != s.completed) ? (s.completed ? 'COMPLETE' : 'INCOMPLETE') : 'UPDATE';
                unawaited(AppActionLedgerService.instance.recordAction(
                  actionType: action,
                  collection: 'subtask',
                  entityId: '${t.id}:${s.id}',
                  title: s.name,
                  summary: '${action == 'COMPLETE' ? 'Completed' : 'Updated'} subtask "${s.name}" in "${t.name}"',
                  before: oldS.toJson(),
                  after: s.toJson(),
                ));
              }
            }
          }

          for (final s in oldTask.subTasks) {
            if (!newSubMap.containsKey(s.id)) {
              unawaited(AppActionLedgerService.instance.recordAction(
                actionType: 'DELETE',
                collection: 'subtask',
                entityId: '${t.id}:${s.id}',
                title: s.name,
                summary: 'Deleted subtask "${s.name}" from "${t.name}"',
                before: s.toJson(),
                after: null,
              ));
            }
          }
        }
      }
    }
  } catch (_) {}
}
