import 'dart:convert';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleActions {
  final AppProvider _provider;
  final Map<String, List<TimelineEntry>> _cachedPredictedEntries = {};

  ScheduleActions(this._provider);

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _ensureLoaded(DateTime date) async {
    final key = _dateKey(date);
    if (_cachedPredictedEntries.containsKey(key)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('predicted_schedule_$key');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final list = <TimelineEntry>[];
        for (var item in decoded) {
          if (item is Map) {
            final start = DateTime.tryParse(item['startTime'] ?? '');
            final end = DateTime.tryParse(item['endTime'] ?? '');
            if (start != null && end != null) {
              final colorHex = item['colorHex'] as String?;
              Color c = AppTheme.fhTextDisabled;
              if (colorHex != null && colorHex.isNotEmpty) {
                try {
                  c = Color(int.parse(colorHex, radix: 16));
                } catch (_) {}
              }
              list.add(TimelineEntry(
                id: item['id'] ?? 'pred_${start.millisecondsSinceEpoch}',
                startTime: start,
                endTime: end,
                title: item['title'] ?? 'Predicted Session',
                subtitle: item['subtitle'],
                color: c,
                isPredicted: true,
                isEditable: false,
              ));
            }
          }
        }
        _cachedPredictedEntries[key] = list;
      } else {
        _cachedPredictedEntries[key] = [];
      }
    } catch (e) {
      debugPrint("Error loading predicted schedule for $key: $e");
      _cachedPredictedEntries[key] = [];
    }
  }

  List<TimelineEntry> getPredictedEntriesForDate(DateTime date) {
    final key = _dateKey(date);
    if (!_cachedPredictedEntries.containsKey(key)) {
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      _ensureLoaded(date).then((_) => _provider.notifyListeners());
      return [];
    }
    return List.unmodifiable(_cachedPredictedEntries[key] ?? []);
  }

  Future<void> setPredictedEntriesForDate(DateTime date, List<TimelineEntry> entries) async {
    final key = _dateKey(date);
    final nonEditable = entries.map((e) => e.copyWith(isPredicted: true, isEditable: false)).toList();
    _cachedPredictedEntries[key] = nonEditable;
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = nonEditable.map((e) => {
        'id': e.id,
        'startTime': e.startTime.toIso8601String(),
        'endTime': e.endTime.toIso8601String(),
        'title': e.title,
        'subtitle': e.subtitle,
        'colorHex': e.color.toARGB32().toRadixString(16).padLeft(8, '0'),
        'isPredicted': true,
        'isEditable': false,
      }).toList();
      await prefs.setString('predicted_schedule_$key', jsonEncode(serialized));
    } catch (e) {
      debugPrint("Error saving predicted schedule for $key: $e");
    }
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    _provider.notifyListeners();
  }

  Future<void> clearPredictedEntriesForDate(DateTime date) async {
    final key = _dateKey(date);
    _cachedPredictedEntries[key] = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('predicted_schedule_$key');
    } catch (_) {}
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    _provider.notifyListeners();
  }

  Future<void> removePredictedEntry(DateTime date, String entryId) async {
    final key = _dateKey(date);
    final list = _cachedPredictedEntries[key];
    if (list != null) {
      final updated = list.where((e) => e.id != entryId).toList();
      await setPredictedEntriesForDate(date, updated);
    }
  }

  Future<List<TimelineEntry>> predictSchedule({
    DateTime? targetDate,
    TimeOfDay? startTime,
  }) async {
    final effectiveDate = targetDate ?? DateTime.now();
    final now = DateTime.now();
    final isToday = effectiveDate.year == now.year &&
        effectiveDate.month == now.month &&
        effectiveDate.day == now.day;
    final effectiveStartTime = startTime ?? (isToday ? TimeOfDay.now() : const TimeOfDay(hour: 8, minute: 0));
    final startHourStr = effectiveStartTime.hour.toString().padLeft(2, '0');
    final startMinStr = effectiveStartTime.minute.toString().padLeft(2, '0');
    final currentTimeStr = "$startHourStr:$startMinStr";
    final targetDateStr = DateFormat('yyyy-MM-dd').format(effectiveDate);

    final historyLogs = _provider.getLast7DaysData()['sessions'] as String;
    final availableTasks = _provider.mainTasks
        .where((t) => !t.isDeleted && t.isActive)
        .map((t) => "${t.name}: ${t.subTasks.where((s) => !s.isDeleted && s.isActive && !s.completed).map((s) => s.name).join(', ')}")
        .join("\n");
    final reflectionLogs = _provider.getLast30DaysReflectionLogsContext();
    final uncompletedPlan = _provider.getTodayUncompletedPlanContext();

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
        currentTime: currentTimeStr,
        targetDate: targetDateStr,
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
      final baseAnchor = DateTime(
        effectiveDate.year,
        effectiveDate.month,
        effectiveDate.day,
        effectiveStartTime.hour,
        effectiveStartTime.minute,
      );

      for (int i = 0; i < predictions.length; i++) {
        final p = predictions[i];
        final taskName = p['taskName'] as String? ?? "Predicted";
        final subTaskName = p['subTaskName'] as String? ?? "Predicted Session";
        final startStr = p['startTime']?.toString();
        final endStr = p['endTime']?.toString();

        DateTime? start;
        DateTime? end;

        if (startStr != null && startStr.contains(':')) {
          final parts = startStr.split(':');
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            start = DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day, h, m);
          }
        }

        if (endStr != null && endStr.contains(':')) {
          final parts = endStr.split(':');
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            end = DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day, h, m);
          }
        }

        final offset = p['startOffsetMinutes'] as int?;
        final duration = p['durationMinutes'] as int? ?? 30;

        if (start == null && offset != null) {
          start = baseAnchor.add(Duration(minutes: offset));
        }
        start ??= baseAnchor.add(Duration(minutes: i * 45));

        end ??= start.add(Duration(minutes: duration.clamp(5, 240)));
        if (!end.isAfter(start)) {
          end = start.add(const Duration(minutes: 30));
        }

        Color c = AppTheme.fhTextDisabled;
        final matchedTask = _provider.mainTasks.firstWhereOrNull(
            (t) => t.name.toLowerCase().contains(taskName.toLowerCase()));
        if (matchedTask != null) c = matchedTask.taskColor;

        newEntries.add(TimelineEntry(
          id: "pred_${effectiveDate.millisecondsSinceEpoch}_${newEntries.length}_${DateTime.now().microsecondsSinceEpoch}",
          startTime: start,
          endTime: end,
          title: subTaskName,
          subtitle: taskName,
          color: c,
          isPredicted: true,
          isEditable: false,
        ));
      }

      await setPredictedEntriesForDate(effectiveDate, newEntries);

      _provider.addAiLog(
        action: 'Schedule Prediction',
        model: modelCandidates.first,
        promptSnippet: 'Predicted ${newEntries.length} schedule entries for $targetDateStr using Pro AI model, reflection logs & plan',
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