// lib/src/providers/actions/timer_actions.dart
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/app_state_models.dart';
import 'package:collection/collection.dart';

class TimerActions {
  final AppProvider _provider;

  TimerActions(this._provider);

  void startTimer(String id, String type, String mainTaskId) {
    // 1. Validation: Prevent starting timer on completed tasks or invalid IDs
    final mainTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    if (mainTask == null) return; 

    if (type == 'subtask') {
      final subTask = mainTask.subTasks.firstWhereOrNull((s) => s.id == id);
      if (subTask == null) return;
      if (subTask.completed) {
         // Cannot start timer on completed task
         return; 
      }
    }

    // 2. Enforce Single Timer Rule: Stop OTHER running timers
    // We iterate through a copy of active timers to safely modify state
    final runningTimerIds = _provider.activeTimers.entries
        .where((e) => e.value.isRunning && e.key != id)
        .map((e) => e.key)
        .toList();

    for (var timerId in runningTimerIds) {
      // Pause acts as "stop and save" for running session
      pauseTimer(timerId); 
    }

    // 3. Start New Timer
    Map<String, ActiveTimerInfo> updatedActiveTimers =
        Map.from(_provider.activeTimers);

    final existingTimer = updatedActiveTimers[id];
    updatedActiveTimers[id] = ActiveTimerInfo(
      startTime: DateTime.now(),
      accumulatedDisplayTime: existingTimer?.accumulatedDisplayTime ?? 0,
      isRunning: true,
      type: type,
      mainTaskId: mainTaskId,
    );
    
    // This triggers notifyListeners and saves via AppProvider
    _provider.setProviderState(activeTimers: updatedActiveTimers);
  }

  void pauseTimer(String id) {
    final timer = _provider.activeTimers[id];
    if (timer != null && timer.isRunning) {
      // 1. Commit the current active session to log
      _commitSessionAndPause(id, timer);

      // 2. Update timer state to paused
      final double elapsed =
          (DateTime.now().difference(timer.startTime).inMilliseconds) / 1000.0;
      final newActiveTimers =
          Map<String, ActiveTimerInfo>.from(_provider.activeTimers);
      newActiveTimers[id] = ActiveTimerInfo(
        startTime: DateTime.now(), // Reset start for next resume
        accumulatedDisplayTime: timer.accumulatedDisplayTime + elapsed,
        isRunning: false,
        type: timer.type,
        mainTaskId: timer.mainTaskId,
      );
      _provider.setProviderState(activeTimers: newActiveTimers);
    }
  }

  void logTimerAndReset(String id) {
    final timer = _provider.activeTimers[id];
    if (timer != null) {
      // If running, log the final chunk
      if (timer.isRunning) {
        _commitSessionAndPause(id, timer);
      }

      // Remove the active timer state entirely (Reset)
      final newActiveTimers =
          Map<String, ActiveTimerInfo>.from(_provider.activeTimers);
      newActiveTimers.remove(id);
      _provider.setProviderState(activeTimers: newActiveTimers);
    }
  }

  // Helper to push the session to the task log
  void _commitSessionAndPause(String id, ActiveTimerInfo timer) {
    final now = DateTime.now();
    final start = timer.startTime;

    // Only log if there's actual time elapsed (> 0ms, effectively)
    if (now.isAfter(start)) {
      if (timer.type == 'subtask') {
        _provider.addSessionToSubtask(timer.mainTaskId, id, start, now);
      }
    }
  }
}