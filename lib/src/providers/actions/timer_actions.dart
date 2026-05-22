import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:collection/collection.dart';

class TimerActions {
  final AppProvider _provider;

  TimerActions(this._provider);

  void startTimer(String id, String type, String mainTaskId) {
    final mainTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    if (mainTask == null) return; 

    if (type == 'subtask') {
      final subTask = mainTask.subTasks.firstWhereOrNull((s) => s.id == id);
      if (subTask == null) return;
      if (subTask.completed) return; 
    }

    final runningTimerIds = _provider.activeTimers.entries
        .where((e) => e.value.isRunning && e.key != id)
        .map((e) => e.key)
        .toList();

    for (var timerId in runningTimerIds) {
      pauseTimer(timerId); 
    }

    // Auto-add engaged task to Day Plan (Top) to sync with the dashboard
    if (type == 'subtask') {
      final dateStr = helper.getTodayDateString();
      final currentPlan = List<String>.from(_provider.taskActions.getDayPlan(dateStr));
      final compoundId = "$mainTaskId|$id";
      
      // Remove if it exists to move it to the top
      currentPlan.remove(compoundId);
      currentPlan.insert(0, compoundId);
      
      _provider.taskActions.updateDayPlan(dateStr, currentPlan);
    }

    Map<String, ActiveTimerInfo> updatedActiveTimers = Map.from(_provider.activeTimers);

    final existingTimer = updatedActiveTimers[id];
    updatedActiveTimers[id] = ActiveTimerInfo(
      startTime: DateTime.now(),
      accumulatedDisplayTime: existingTimer?.accumulatedDisplayTime ?? 0,
      isRunning: true,
      type: type,
      mainTaskId: mainTaskId,
    );
    
    _provider.setProviderState(activeTimers: updatedActiveTimers);

    if (_provider.settings.autoSaveEnabled) {
      _provider.manuallySaveToCloud();
    }
  }

  void pauseTimer(String id) {
    final timer = _provider.activeTimers[id];
    if (timer != null && timer.isRunning) {
      // Optimistic: flip to paused immediately so UI responds without waiting for I/O
      final double elapsed = (DateTime.now().difference(timer.startTime).inMilliseconds) / 1000.0;
      final newActiveTimers = Map<String, ActiveTimerInfo>.from(_provider.activeTimers);
      newActiveTimers[id] = ActiveTimerInfo(
        startTime: timer.startTime,
        accumulatedDisplayTime: timer.accumulatedDisplayTime + elapsed,
        isRunning: false,
        type: timer.type,
        mainTaskId: timer.mainTaskId,
      );
      _provider.setProviderState(activeTimers: newActiveTimers);

      if (timer.type == 'subtask') {
        _provider.taskActions.removeFromDayPlan("${timer.mainTaskId}|$id");
      }

      // Defer session commit + cloud save off the hot path
      Future.microtask(() {
        _commitSessionAndPause(id, timer);
        if (_provider.settings.autoSaveEnabled) {
          _provider.manuallySaveToCloud();
        }
      });
    }
  }

  void logTimerAndReset(String id) {
    final timer = _provider.activeTimers[id];
    if (timer != null) {
      // Optimistic: remove timer immediately so UI responds without waiting for I/O
      final newActiveTimers = Map<String, ActiveTimerInfo>.from(_provider.activeTimers);
      newActiveTimers.remove(id);
      _provider.setProviderState(activeTimers: newActiveTimers);

      if (timer.type == 'subtask') {
        _provider.taskActions.removeFromDayPlan("${timer.mainTaskId}|$id");
      }

      // Defer session commit + cloud save off the hot path
      Future.microtask(() {
        if (timer.isRunning) {
          _commitSessionAndPause(id, timer);
        }
        if (_provider.settings.autoSaveEnabled) {
          _provider.manuallySaveToCloud();
        }
      });
    }
  }

  void _commitSessionAndPause(String id, ActiveTimerInfo timer) {
    final now = DateTime.now();
    DateTime start = timer.startTime;

    if (now.difference(start).inHours >= 12) {
      start = now.subtract(const Duration(hours: 1)); 
    }

    if (now.isAfter(start)) {
      if (timer.type == 'subtask') {
        _provider.addSessionToSubtask(timer.mainTaskId, id, start, now);
      }
    }
  }
}