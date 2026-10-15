import 'package:collection/collection.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/services/stopped_task_memory.dart';
import 'package:missions/src/tasks/task_store.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/utils/task_calculations.dart';

/// The task buttons shared by the widgets, the floating timer, the planner and the headless
/// engine. Written against [TaskStore] only, so the same code runs inside the app and in the
/// background without a window.
///
/// Side effects that belong to the host (toasts, widget redraws) are passed in as callbacks.
class TaskCommands {
  TaskCommands(
    this.store, {
    this.onMessage,
    this.onRepublish,
    this.onSessionEnded,
    this.shownPlanIds,
  });

  final TaskStore store;

  /// Short user-facing message ("✓ Checked: …"). Null in the background, where there is no UI.
  final void Function(String message)? onMessage;

  /// Asks the host to redraw the task widgets right away.
  final void Function()? onRepublish;

  /// Called when a running session ends for good, so the floating button does not linger paused.
  final void Function()? onSessionEnded;

  /// Plan ids as the widget last drew them. Used to refuse a tap that would hit a different task
  /// than the one shown. Null or empty means no check.
  final List<String> Function()? shownPlanIds;

  void _say(String message) => onMessage?.call(message);

  /// HUD and notification "pause". Only acts when a task is running, so a stale tap cannot start it.
  void pause() {
    final r = resolveActive();
    final s = r.subTask;
    if (!r.isRunning || s == null) return;
    StoppedTaskMemory.subTaskId = s.id;
    store.timerActions.pauseTimer(s.id);
    store.timerActions.logTimerAndReset(s.id);
    onRepublish?.call();
  }

  /// HUD and notification "start". Starts the next planned task that was not just stopped, and only
  /// when nothing is running, so a stale tap cannot pause a running task.
  void start() {
    final r = resolveActive(skipStopped: true);
    final m = r.mainTask;
    final s = r.subTask;
    if (r.isRunning || m == null || s == null) return;
    StoppedTaskMemory.subTaskId = null;
    store.timerActions.startTimer(s.id, 'subtask', m.id);
    onRepublish?.call();
  }

  void toggle() {
    final r = resolveActive();
    final m = r.mainTask;
    final s = r.subTask;
    if (m == null || s == null) return;
    if (r.isRunning) {
      StoppedTaskMemory.subTaskId = s.id;
      store.timerActions.pauseTimer(s.id);
      store.timerActions.logTimerAndReset(s.id);
    } else {
      store.timerActions.startTimer(s.id, 'subtask', m.id);
    }
  }

  /// Ticks the current checkpoint and adds [name] on the same level right after it.
  void checkAndAdd(String name) {
    final r = resolveActive();
    final m = r.mainTask;
    final s = r.subTask;
    if (m == null || s == null) return;
    final newName = name.trim();
    final checked = store.taskActions.checkCurrentAndAddNext(m.id, s.id, newName);
    if (checked != null && newName.isNotEmpty) {
      _say('✓ $checked  →  next: $newName');
    } else if (checked != null) {
      _say('✓ Checked: $checked');
    } else if (newName.isNotEmpty) {
      _say('Checkpoint added: $newName');
    }
  }

  void checkNext() {
    final r = resolveActive();
    final m = r.mainTask;
    final s = r.subTask;
    if (m == null || s == null) return;
    final cp = TaskCalculations.nextCheckpoint(s);
    if (cp == null) {
      _say('No checkpoints left to check');
      return;
    }
    store.taskActions.completeSubSubtask(m.id, s.id, cp.id);
    _say('✓ Checked: ${cp.name}');
  }

  void checkAtPlanIndex(int index) {
    final today = helper.getTodayDateString();
    final topFive = TaskCalculations.resolveTopFiveDayPlanTasks(
      mainTasks: store.mainTasks,
      plan: store.taskActions.getDayPlan(today),
    );
    if (index >= topFive.length) return;
    final item = topFive[index];
    final shown = shownPlanIds?.call() ?? const <String>[];
    if (index < shown.length && shown[index] != item.compoundId) {
      // The plan changed since the widget last drew; ticking by position would hit another task.
      _say('Plan changed — widget refreshed, tap again');
      onRepublish?.call();
      return;
    }
    if (item.targetCheckpointId != null) {
      store.taskActions.completeSubSubtask(item.mainTaskId, item.subTaskId, item.targetCheckpointId!);
      _say('✓ Checked: ${item.name}');
    } else {
      final recurring = store.mainTasks
              .firstWhereOrNull((t) => t.id == item.mainTaskId)
              ?.subTasks
              .firstWhereOrNull((s) => s.id == item.subTaskId)
              ?.isRecurring ==
          true;
      store.taskActions.tickPlanSubtask(item.mainTaskId, item.subTaskId);
      _say(recurring ? '✓ Completed: ${item.name}' : 'Off today\'s plan: ${item.name}');
    }

    // Also remove from day plan
    final currentPlan = List<String>.from(store.taskActions.getDayPlan(today));
    currentPlan.remove(item.compoundId);
    store.taskActions.updateDayPlan(today, currentPlan);
  }

  void finish() {
    final r = resolveActive();
    final m = r.mainTask;
    final s = r.subTask;
    final cp = r.checkpoint;
    final queueId = r.queueId;
    if (m == null || s == null) return;
    if (r.isRunning && cp == null) onSessionEnded?.call();

    if (cp != null) {
      store.taskActions.completeSubSubtask(m.id, s.id, cp.id);
    } else {
      store.taskActions.completeSubtask(m.id, s.id);
    }

    if (queueId != null) {
      final plan = List<String>.from(
        store.taskActions.getDayPlan(helper.getTodayDateString()),
      )..remove(queueId);
      store.taskActions.updateDayPlan(helper.getTodayDateString(), plan);
    }
  }

  /// The task the buttons act on: the running one if any, otherwise the next planned one.
  ({
    MainTask? mainTask,
    SubTask? subTask,
    SubSubTask? checkpoint,
    bool isRunning,
    String? queueId,
  }) resolveActive({bool skipStopped = false}) {
    final today = helper.getTodayDateString();
    final plan = List<String>.from(store.taskActions.getDayPlan(today));

    final runningEntry = store.activeTimers.entries
        .firstWhereOrNull((e) => e.value.isRunning && e.value.type == 'subtask');
    if (runningEntry != null) {
      final m = store.mainTasks.firstWhereOrNull(
        (t) => t.id == runningEntry.value.mainTaskId && !t.isDeleted,
      );
      final s = m?.subTasks.firstWhereOrNull(
        (st) => st.id == runningEntry.key && !st.isDeleted,
      );
      if (m != null && s != null && !s.completed) {
        String? queueId;
        SubSubTask? cp;
        final inPlan = plan.firstWhereOrNull((p) {
          final parts = p.split('|');
          return parts.length >= 2 && parts[0] == m.id && parts[1] == s.id;
        });
        if (inPlan != null) {
          queueId = inPlan;
          final parts = inPlan.split('|');
          if (parts.length == 3) {
            cp = s.findCheckpoint(parts[2]);
          }
        }
        return (mainTask: m, subTask: s, checkpoint: cp, isRunning: true, queueId: queueId);
      }
    }

    for (final idPair in plan) {
      final parts = idPair.split('|');
      if (parts.length < 2) continue;
      final m = store.mainTasks.firstWhereOrNull(
        (t) => t.id == parts[0] && !t.isDeleted,
      );
      final s = m?.subTasks.firstWhereOrNull(
        (st) => st.id == parts[1] && !st.isDeleted,
      );
      if (m == null || s == null || s.completed) continue;
      if (skipStopped && s.id == StoppedTaskMemory.subTaskId) continue;
      if (parts.length == 3) {
        final cp = s.findCheckpoint(parts[2]);
        if (cp == null || cp.completed) continue;
        return (mainTask: m, subTask: s, checkpoint: cp, isRunning: false, queueId: idPair);
      }
      return (mainTask: m, subTask: s, checkpoint: null, isRunning: false, queueId: idPair);
    }

    return (mainTask: null, subTask: null, checkpoint: null, isRunning: false, queueId: null);
  }
}
