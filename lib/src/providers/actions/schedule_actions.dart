import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class ScheduleActions {
  final AppProvider _provider;

  ScheduleActions(this._provider);

  Future<List<TimelineEntry>> predictSchedule() async {
    final historyLogs = _provider.getLast7DaysData()['sessions'] as String;
    final availableTasks = _provider.mainTasks
        .where((t) => !t.isDeleted && t.isActive)
        .map((t) => "${t.name}: ${t.subTasks.where((s) => !s.isDeleted && s.isActive && !s.completed).map((s) => s.name).join(', ')}")
        .join("\n");
    final reflectionLogs = _provider.getLast30DaysReflectionLogsContext();
    final uncompletedPlan = _provider.getTodayUncompletedPlanContext();
    final now = DateTime.now();

    // Use Pro AI models first (heavyModels), with fallback to liteModels
    final proModels = _provider.settings.heavyModels.isNotEmpty
        ? _provider.settings.heavyModels
        : AppSettings.defaultHeavyModels;
    final liteModels = _provider.settings.liteModels.isNotEmpty
        ? _provider.settings.liteModels
        : AppSettings.defaultLiteModels;
    final modelCandidates = <String>[
      ...proModels,
      ...liteModels.where((m) => !proModels.contains(m)),
    ];

    try {
      final predictions = await _provider.aiService.generateSchedulePrediction(
        sessionHistory: historyLogs,
        currentTime: DateFormat('HH:mm').format(now),
        availableTasksContext: availableTasks,
        reflectionLogsContext: reflectionLogs,
        uncompletedPlanContext: uncompletedPlan,
        modelCandidates: modelCandidates,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (i) => _provider.setApiKeyIndex(i),
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

      _provider.addAiLog(
        action: 'Schedule Prediction',
        model: modelCandidates.first,
        promptSnippet: 'Predicted ${newEntries.length} schedule entries using Pro AI model, reflection logs & today uncompleted plan',
        status: 'SUCCESS',
      );

      return newEntries;
    } catch (e) {
      _provider.addAiLog(
        action: 'Schedule Prediction',
        model: modelCandidates.first,
        promptSnippet: 'Failed schedule prediction: $e',
        status: 'ERROR',
      );
      debugPrint("Schedule Prediction Error: $e");
      rethrow;
    }
  }
}