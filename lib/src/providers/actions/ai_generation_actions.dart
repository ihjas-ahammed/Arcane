// lib/src/providers/actions/ai_generation_actions.dart
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/services/ai_service.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:flutter/foundation.dart'; 

class AIGenerationActions {
  final AppProvider _provider;
  final AIService _aiService = AIService();

  AIGenerationActions(this._provider);

  void _logToApp(String logMessage) {
    if (kDebugMode) debugPrint("[AIActions - _logToApp]: $logMessage");
  }

  Future<void> triggerAISubquestGeneration(MainTask mainTaskForSubquests,
      String generationMode, String userInput, int numSubquests) async {
    if (_provider.isGeneratingSubquests) {
      debugPrint(
          "[AIActions] triggerAISubquestGeneration skipped, already in progress for task '${mainTaskForSubquests.name}'.");
      return;
    }
    _provider.setProviderAISubquestLoading(true);

    try {
      final generatedSubquestsRaw = await _aiService.generateAISubquests(
        modelName: _provider.settings.aiModelName,
        mainTaskName: mainTaskForSubquests.name,
        mainTaskDescription: mainTaskForSubquests.description,
        mainTaskTheme: mainTaskForSubquests.theme,
        generationMode: generationMode,
        userInput: userInput,
        numSubquests: numSubquests,
        currentApiKeyIndex: _provider.apiKeyIndex,
        onNewApiKeyIndex: (newIndex) {
          _provider.setProviderApiKeyIndex(newIndex);
        },
        onLog: _logToApp,
      );

      final List<SubTask> newSubTasksForParent = [];
      for (var subquestData in generatedSubquestsRaw) {
        if (subquestData is! Map<String, dynamic>) {
          continue;
        }

        final List<Map<String, dynamic>> subSubTasksDataList =
            (subquestData['subSubTasksData'] as List<dynamic>? ?? [])
                .map((item) =>
                    item is Map<String, dynamic> ? item : null)
                .nonNulls
                .toList();

        final List<SubSubTask> currentSubSubTasks = [];
        for (int i = 0; i < subSubTasksDataList.length; i++) {
          final sssData = subSubTasksDataList[i];
          currentSubSubTasks.add(SubSubTask(
            id:
                'ssub_${DateTime.now().millisecondsSinceEpoch}_${newSubTasksForParent.length}_$i',
            name: sssData['name'] as String? ?? 'Unnamed Sub-Sub-Task',
            isCountable: sssData['isCountable'] as bool? ?? false,
            targetCount: (sssData['isCountable'] as bool? ?? false)
                ? (sssData['targetCount'] as int? ?? 1)
                : 0,
          ));
        }

        final newSubTask = SubTask(
          id:
              'sub_${DateTime.now().millisecondsSinceEpoch}_${newSubTasksForParent.length}',
          name: subquestData['name'] as String? ?? 'Unnamed Sub-Task',
          isCountable: subquestData['isCountable'] as bool? ?? false,
          targetCount: (subquestData['isCountable'] as bool? ?? false)
              ? (subquestData['targetCount'] as int? ?? 1)
              : 0,
          subSubTasks: currentSubSubTasks,
        );
        newSubTasksForParent.add(newSubTask);
      }

      final newMainTasks = _provider.mainTasks.map((task) {
        if (task.id == mainTaskForSubquests.id) {
          return MainTask(
            id: task.id,
            name: task.name,
            description: task.description,
            theme: task.theme,
            colorHex: task.colorHex,
            streak: task.streak,
            weeklyStreak: task.weeklyStreak,
            dailyTimeSpent: task.dailyTimeSpent,
            lastWorkedDate: task.lastWorkedDate,
            subTasks: [...task.subTasks, ...newSubTasksForParent],
            weeklyCompletionStatus: task.weeklyCompletionStatus,
          );
        }
        return task;
      }).toList();

      _provider.setProviderState(mainTasks: newMainTasks);
    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      debugPrint(
          "[AIActions] CRITICAL ERROR in triggerAISubquestGeneration for task '${mainTaskForSubquests.name}': $errorMessage");
      if (kDebugMode) {
        debugPrint(
            "[AIActions] StackTrace for triggerAISubquestGeneration error: $stackTrace");
      }
    } finally {
      _provider.setProviderAISubquestLoading(false);
    }
  }
}