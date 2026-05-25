import 'package:flutter/foundation.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/ai_service.dart';
import 'package:missions/src/utils/helpers.dart';
import 'package:intl/intl.dart';

class ReportActions {
  final AppProvider _provider;
  final AIService _aiService;

  ReportActions(this._provider) : _aiService = _provider.aiService;

  Future<List<Map<String, dynamic>>> generateStartDayReport() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final recentLogs = _provider.reflectionLogs.where((l) => l.timestamp.isAfter(sevenDaysAgo)).toList();
    final reflectionsStr = recentLogs.map((l) => "[${DateFormat('MM-dd').format(l.timestamp)}] ${l.trigger} -> ${l.emotion}").join("\n");

    final sessionsStrBuffer = StringBuffer();
    for (var task in _provider.mainTasks) {
      for (var sub in task.subTasks) {
        for (var session in sub.sessions) {
          if (session.startTime.isAfter(sevenDaysAgo)) {
            sessionsStrBuffer.writeln("[${DateFormat('MM-dd').format(session.startTime)}] ${task.name} - ${sub.name}: ${session.durationMinutes}m");
          }
        }
      }
    }

    // Snapshot current task progress before generating report
    final taskSnapshot = <String, dynamic>{};
    for (var task in _provider.mainTasks) {
      if (task.isDeleted || !task.isActive) continue;
      final subtaskData = <String, dynamic>{};
      for (var sub in task.subTasks) {
        if (sub.isDeleted || !sub.isActive) continue;
        subtaskData[sub.id] = {
          'name': sub.name,
          'progress': sub.calculateProgress(),
          'time_spent': sub.currentTimeSpent,
          'completed': sub.completed,
        };
      }
      taskSnapshot[task.id] = {
        'name': task.name,
        'color_hex': task.colorHex,
        'subtasks': subtaskData,
      };
    }

    _provider.setLoadingTask("Generating Startup Report...");

    try {
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
      final startOfTodayMinus7 = startOfToday.subtract(const Duration(days: 7));
      final startOfYesterdayMinus7 = startOfYesterday.subtract(const Duration(days: 7));

      Map<String, int> todayMetricsMap = {};
      Map<String, int> yesterdayMetricsMap = {};

      for (var log in _provider.reflectionLogs) {
        if (log.timestamp.isAfter(startOfTodayMinus7) && log.timestamp.isBefore(startOfToday)) {
          log.xpGained.forEach((k, v) => todayMetricsMap[k] = (todayMetricsMap[k] ?? 0) + v);
        }
        if (log.timestamp.isAfter(startOfYesterdayMinus7) && log.timestamp.isBefore(startOfYesterday)) {
          log.xpGained.forEach((k, v) => yesterdayMetricsMap[k] = (yesterdayMetricsMap[k] ?? 0) + v);
        }
      }

      List<Map<String, dynamic>> metrics = [];
      for (var skill in _provider.getBaseWellbeingSkills()) {
        final t = todayMetricsMap[skill.name] ?? 0;
        final y = yesterdayMetricsMap[skill.name] ?? 0;
        metrics.add({'name': skill.name, 'today': t, 'yesterday': y, 'delta': t - y});
      }

      final aiResult = await _aiService.generateStartDayReport(
        reflectionsList: reflectionsStr,
        sessionsList: sessionsStrBuffer.toString(),
        modelCandidates: _provider.settings.heavyModels,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[ReportAI] $msg"),
      );

      final result = Map<String, dynamic>.from(aiResult);
      result['metrics'] = metrics;
      result['task_snapshot'] = taskSnapshot;
      result['snapshot_time'] = now.toIso8601String();

      final today = getTodayDateString();
      _provider.saveStartDayReport(today, result);

      return [];
    } catch (e) {
      debugPrint("Error generating start day report: $e");
      rethrow;
    } finally {
      _provider.setLoadingTask(null);
    }
  }
}