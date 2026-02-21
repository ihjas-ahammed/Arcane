import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/timeline_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class ScheduleActions {
  final AppProvider _provider;

  ScheduleActions(this._provider);

  Future<List<TimelineEntry>> predictSchedule() async {
    // Use the new 'sessions' key which contains actual session logs instead of reflections
    final historyLogs = _provider.getLast7DaysData()['sessions'] as String;
    final availableTasks = _provider.mainTasks.map((t) => t.name).join(", ");
    final now = DateTime.now();

    try {
      final predictions = await _provider.aiService.generateSchedulePrediction(
        sessionHistory: historyLogs,
        currentTime: DateFormat('HH:mm').format(now),
        availableTasksContext: availableTasks,
        modelCandidates: _provider.settings.liteModels,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (i) => _provider.setProviderApiKeyIndex(i),
        onLog: (m) => debugPrint(m),
      );

      final List<TimelineEntry> newEntries = [];
      for (var p in predictions) {
        final offset = p['startOffsetMinutes'] as int? ?? 0;
        final duration = p['durationMinutes'] as int? ?? 30;
        final taskName = p['taskName'] as String? ?? "Predicted";

        final start = now.add(Duration(minutes: offset));
        final end = start.add(Duration(minutes: duration));

        Color c = AppTheme.fhTextDisabled;
        final matchedTask = _provider.mainTasks.firstWhereOrNull(
            (t) => t.name.toLowerCase().contains(taskName.toLowerCase()));
        if (matchedTask != null) c = matchedTask.taskColor;

        newEntries.add(TimelineEntry(
          id: "pred_${DateTime.now().millisecondsSinceEpoch}_${newEntries.length}",
          startTime: start,
          endTime: end,
          title: p['subTaskName'] ?? "Predicted Session",
          subtitle: taskName,
          color: c,
          isPredicted: true,
          isEditable: true,
        ));
      }
      return newEntries;
    } catch (e) {
      debugPrint("Schedule Prediction Error: $e");
      rethrow;
    }
  }
}