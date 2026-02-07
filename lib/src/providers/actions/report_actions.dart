import 'package:flutter/foundation.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/services/ai_service.dart';
import 'package:arcane/src/utils/ai_context_helper.dart';
import 'package:arcane/src/utils/helpers.dart';
import 'package:intl/intl.dart';

class ReportActions {
  final AppProvider _provider;
  final AIService _aiService;

  ReportActions(this._provider) : _aiService = _provider.aiService;

  Future<List<Map<String, dynamic>>> generateStartDayReport() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    // Gather Reflections Context
    final recentLogs = _provider.reflectionLogs.where((l) => l.timestamp.isAfter(sevenDaysAgo)).toList();
    final reflectionsStr = recentLogs.map((l) => "[${DateFormat('MM-dd').format(l.timestamp)}] ${l.trigger} -> ${l.emotion}").join("\n");

    // Gather Sessions Context
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

    final valuesContext = AiContextHelper.serializeValues(_provider.lifeValues);

    _provider.setLoadingTask("Generating Startup Report...");
    
    try {
      final result = await _aiService.generateStartDayReport(
        reflectionsList: reflectionsStr,
        sessionsList: sessionsStrBuffer.toString(),
        userValues: valuesContext,
        modelCandidates: _provider.settings.liteModels,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[ReportAI] $msg"),
      );

      // Save report to today's history via Provider method
      final today = getTodayDateString();
      _provider.saveStartDayReport(today, result);

      return (result['value_updates'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

    } catch (e) {
      debugPrint("Error generating start day report: $e");
      rethrow;
    } finally {
      _provider.setLoadingTask(null);
    }
  }
}