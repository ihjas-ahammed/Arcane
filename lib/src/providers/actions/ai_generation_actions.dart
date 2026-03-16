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
        modelCandidates: _provider.settings.liteModels,
        mainTaskName: mainTaskForSubquests.name,
        mainTaskDescription: mainTaskForSubquests.description,
        mainTaskTheme: mainTaskForSubquests.theme,
        generationMode: generationMode,
        userInput: userInput,
        numSubquests: numSubquests,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (newIndex) {
          _provider.setProviderApiKeyIndex(newIndex);
        },
        onLog: _logToApp,
      );

      final List<SubTask> newSubTasksForParent = [];
      for (var subquestData in generatedSubquestsRaw) {
        final List<Map<String, dynamic>> subSubTasksDataList =
            (subquestData['subSubTasksData'] as List<dynamic>? ?? [])
                .map((item) => item is Map<String, dynamic> ? item : null)
                .nonNulls
                .toList();

        final List<SubSubTask> currentSubSubTasks = [];
        for (int i = 0; i < subSubTasksDataList.length; i++) {
          final sssData = subSubTasksDataList[i];
          currentSubSubTasks.add(SubSubTask(
            id: 'ssub_${DateTime.now().millisecondsSinceEpoch}_${newSubTasksForParent.length}_$i',
            name: sssData['name'] as String? ?? 'Unnamed Sub-Sub-Task',
            isCountable: sssData['isCountable'] as bool? ?? false,
            targetCount: (sssData['isCountable'] as bool? ?? false)
                ? (sssData['targetCount'] as int? ?? 1)
                : 0,
          ));
        }

        final newSubTask = SubTask(
          id: 'sub_${DateTime.now().millisecondsSinceEpoch}_${newSubTasksForParent.length}',
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
          return task.copyWith(
            subTasks: [...task.subTasks, ...newSubTasksForParent],
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

  Future<void> generateCheckpointsForSubtask(
      String mainTaskId, String subTaskId, String userPrompt) async {
    _provider.setProviderAISubquestLoading(true);
    _provider.setLoadingTask("Generating Checkpoints...");

    try {
      final mainTask = _provider.mainTasks.firstWhere((t) => t.id == mainTaskId);
      final subTask = mainTask.subTasks.firstWhere((s) => s.id == subTaskId);
      final existingCheckpoints = subTask.subSubTasks.map((s) => s.name).toList();

      final newCheckpoints = await _aiService.generateCheckpointsForSubtask(
        subtaskName: subTask.name,
        parentTaskName: mainTask.name,
        existingCheckpoints: existingCheckpoints,
        userPrompt: userPrompt,
        modelCandidates: _provider.settings.liteModels,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: _logToApp,
      );

      for (var cpData in newCheckpoints) {
        _provider.addSubSubtask(mainTaskId, subTaskId, {
          'name': cpData['name'] ?? 'New Checkpoint',
          'isCountable': false,
          'targetCount': 0,
        });
      }

    } catch (e) {
      debugPrint("Error generating checkpoints: $e");
    } finally {
      _provider.setProviderAISubquestLoading(false);
      _provider.setLoadingTask(null);
    }
  }

  Future<void> generateActionPlanSteps(
      String mainTaskId, String subTaskId, String why, String userPrompt) async {
    _provider.setProviderAISubquestLoading(true);
    _provider.setLoadingTask("Generating Strategy...");

    try {
      final mainTask = _provider.mainTasks.firstWhere((t) => t.id == mainTaskId);
      final subTask = mainTask.subTasks.firstWhere((s) => s.id == subTaskId);

      final result = await _aiService.generateActionPlanSteps(
        taskName: subTask.name,
        why: why,
        userPrompt: userPrompt,
        modelCandidates: _provider.settings.liteModels,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: _logToApp,
      );

      final steps = (result['steps'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      final what = result['what'] as String? ?? '';

      // Update Subtask with "What"
      _provider.taskActions.updateSubtask(mainTaskId, subTaskId, {'what': what});

      // Add Steps
      for (var step in steps) {
        _provider.addSubSubtask(mainTaskId, subTaskId, {
          'name': step['name'] ?? 'Action Step',
          'isCountable': false,
          'targetCount': 0,
        });
      }

    } catch (e) {
      debugPrint("Error generating action plan: $e");
    } finally {
      _provider.setProviderAISubquestLoading(false);
      _provider.setLoadingTask(null);
    }
  }
}