// lib/src/providers/actions/timer_actions.dart
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/models/game_models.dart';

class TimerActions {
  final GameProvider _provider;

  TimerActions(this._provider);

  void startTimer(String id, String type, String mainTaskId) {
    Map<String, ActiveTimerInfo> updatedActiveTimers =
        Map.from(_provider.activeTimers);

    // Pause any other running timer
    for (var entry in updatedActiveTimers.entries) {
      final timerId = entry.key;
      final timerInfo = entry.value;
      if (timerInfo.isRunning && timerId != id) {
        final double elapsed =
            (DateTime.now().difference(timerInfo.startTime).inMilliseconds) /
                1000.0;
        updatedActiveTimers[timerId] = ActiveTimerInfo(
          startTime: timerInfo.startTime,
          accumulatedDisplayTime: timerInfo.accumulatedDisplayTime + elapsed,
          isRunning: false,
          type: timerInfo.type,
          mainTaskId: timerInfo.mainTaskId,
        );
      }
    }

    // Start or resume the selected timer
    final existingTimer = updatedActiveTimers[id];
    updatedActiveTimers[id] = ActiveTimerInfo(
      startTime: DateTime.now(),
      accumulatedDisplayTime:
          existingTimer?.accumulatedDisplayTime ?? 0, // Retain accumulated time
      isRunning: true,
      type: type,
      mainTaskId: mainTaskId,
    );
    _provider.setProviderState(activeTimers: updatedActiveTimers);
  }

  void pauseTimer(String id) {
    final timer = _provider.activeTimers[id];
    if (timer != null && timer.isRunning) {
      final double elapsed =
          (DateTime.now().difference(timer.startTime).inMilliseconds) / 1000.0;
      final newActiveTimers =
          Map<String, ActiveTimerInfo>.from(_provider.activeTimers);
      newActiveTimers[id] = ActiveTimerInfo(
        startTime: timer
            .startTime, // Keep original startTime, elapsed time is added to accumulated
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
      double totalSecondsToLog = timer.accumulatedDisplayTime;
      if (timer.isRunning) {
        totalSecondsToLog +=
            (DateTime.now().difference(timer.startTime).inMilliseconds) /
                1000.0;
      }
      final int minutesToLog = (totalSecondsToLog / 60).round();

      if (minutesToLog > 0) {
        if (timer.type == 'subtask') {
          final MainTask currentMainTask = _provider.mainTasks.firstWhere(
              (t) => t.id == timer.mainTaskId,
              orElse: () =>
                  MainTask(id: '', name: '', description: '', theme: ''));
          if (currentMainTask.id.isNotEmpty) {
            final SubTask subtask = currentMainTask.subTasks.firstWhere(
                (st) => st.id == id,
                orElse: () => SubTask(id: '', name: ''));
            if (subtask.id.isNotEmpty) {
              // Update the subtask's currentTimeSpent
              // This will also trigger daily goal checks and energy regen in updateSubtask
              _provider.updateSubtask(timer.mainTaskId, id, {
                'currentTimeSpent': subtask.currentTimeSpent + minutesToLog
              });
            }
          }
        }
        // Process park time for the logged minutes if park features are active
        _provider.parkActions.processParkTime(minutesToLog);
      }

      final newActiveTimers =
          Map<String, ActiveTimerInfo>.from(_provider.activeTimers);
      newActiveTimers.remove(id);
      _provider.setProviderState(activeTimers: newActiveTimers);
    }
  }
}
