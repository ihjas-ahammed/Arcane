// lib/src/providers/actions/timer_actions.dart
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/app_state_models.dart';

class TimerActions {
  final AppProvider _provider;

  TimerActions(this._provider);

  void startTimer(String id, String type, String mainTaskId) {
    // PREVENT MULTIPLE TIMERS
    // If any timer is currently running, do not start a new one.
    // This forces the user to stop the previous timer first.
    final anyRunning = _provider.activeTimers.values.any((t) => t.isRunning);
    if (anyRunning) {
      // Ideally, throw exception or handle in UI.
      // Since this is a void action, we assume UI checks before calling,
      // but for safety, we simply return here to enforce the rule.
      return;
    }

    Map<String, ActiveTimerInfo> updatedActiveTimers =
        Map.from(_provider.activeTimers);

    // Double-check pause logic for safety, though 'anyRunning' check above makes this mostly redundant for 'start'
    for (var entry in updatedActiveTimers.entries) {
      final timerId = entry.key;
      final timerInfo = entry.value;
      if (timerInfo.isRunning && timerId != id) {
        _commitSessionAndPause(timerId, timerInfo);
        updatedActiveTimers[timerId] = ActiveTimerInfo(
          startTime: DateTime.now(), 
          accumulatedDisplayTime: timerInfo.accumulatedDisplayTime + (DateTime.now().difference(timerInfo.startTime).inMilliseconds / 1000.0),
          isRunning: false,
          type: timerInfo.type,
          mainTaskId: timerInfo.mainTaskId,
        );
      }
    }

    final existingTimer = updatedActiveTimers[id];
    updatedActiveTimers[id] = ActiveTimerInfo(
      startTime: DateTime.now(),
      accumulatedDisplayTime: existingTimer?.accumulatedDisplayTime ?? 0,
      isRunning: true,
      type: type,
      mainTaskId: mainTaskId,
    );
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