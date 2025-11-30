import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/services/ai_service.dart';

class ProjectActions {
  final AppProvider _provider;
  final AIService _aiService = AIService();

  ProjectActions(this._provider);

  // Updated: Now accepts optional mainTaskId. If null, tries to find a default or active task.
  void addProject(String title, String description, {String? mainTaskId}) {
    // If no specific task is targeted, use the currently selected one, or the first one.
    final targetTaskId = mainTaskId ?? _provider.selectedTaskId ?? _provider.mainTasks.firstOrNull?.id;
    
    if (targetTaskId == null) {
      debugPrint("Error: No MainTask available to assign project to.");
      return;
    }

    final newProject = Project(
      id: const Uuid().v4(),
      title: title,
      description: description,
      linkedMainTaskId: targetTaskId,
    );

    _updateMainTaskProjects(targetTaskId, (projects) {
      return [...projects, newProject];
    });
  }

  void updateProject(String mainTaskId, Project updatedProject) {
    updatedProject.calculateProgress();
    _updateMainTaskProjects(mainTaskId, (projects) {
      return projects.map((p) => p.id == updatedProject.id ? updatedProject : p).toList();
    });
  }

  void deleteProject(String mainTaskId, String projectId) {
    _updateMainTaskProjects(mainTaskId, (projects) {
      return projects.where((p) => p.id != projectId).toList();
    });
  }

  void _updateMainTaskProjects(String mainTaskId, List<Project> Function(List<Project>) updateFn) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        final updatedProjects = updateFn(task.projects);
        return MainTask(
          id: task.id,
          name: task.name,
          description: task.description,
          theme: task.theme,
          colorHex: task.colorHex,
          dailyTimeSpent: task.dailyTimeSpent,
          lastWorkedDate: task.lastWorkedDate,
          subTasks: task.subTasks,
          weeklyCompletionStatus: task.weeklyCompletionStatus,
          projects: updatedProjects,
        );
      }
      return task;
    }).toList();

    _provider.setProviderState(mainTasks: newMainTasks);
  }

  // --- Step Management ---

  void addRootStep(String mainTaskId, String projectId, String title) {
    final newStep = ProjectStep(
      id: const Uuid().v4(),
      title: title,
      description: '',
    );
    _performStepAction(mainTaskId, projectId, (project) {
      project.steps.add(newStep);
    });
  }

  void updateStep(String mainTaskId, String projectId, ProjectStep updatedStep) {
    _performStepAction(mainTaskId, projectId, (project) {
       _updateStepRecursive(project.steps, updatedStep);
    });
  }

  bool _updateStepRecursive(List<ProjectStep> steps, ProjectStep updatedStep) {
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].id == updatedStep.id) {
        steps[i] = updatedStep;
        return true;
      }
      if (_updateStepRecursive(steps[i].substeps, updatedStep)) {
        return true;
      }
    }
    return false;
  }

  void deleteStep(String mainTaskId, String projectId, String stepId) {
    _performStepAction(mainTaskId, projectId, (project) {
      _deleteStepRecursive(project.steps, stepId);
    });
  }

  void _deleteStepRecursive(List<ProjectStep> steps, String stepId) {
    steps.removeWhere((s) => s.id == stepId);
    for (var s in steps) {
      _deleteStepRecursive(s.substeps, stepId);
    }
  }

  void addSubstep(String mainTaskId, String projectId, String parentStepId, String title) {
    final newStep = ProjectStep(
      id: const Uuid().v4(),
      title: title,
      description: '',
    );
    _performStepAction(mainTaskId, projectId, (project) {
       _addSubstepRecursive(project.steps, parentStepId, newStep);
    });
  }

  bool _addSubstepRecursive(List<ProjectStep> steps, String parentId, ProjectStep newStep) {
    for (var s in steps) {
      if (s.id == parentId) {
        s.substeps.add(newStep);
        s.isCompleted = false; 
        return true;
      }
      if (_addSubstepRecursive(s.substeps, parentId, newStep)) return true;
    }
    return false;
  }
  
  void _performStepAction(String mainTaskId, String projectId, Function(Project) action) {
    Project? targetProject;
    for (var t in _provider.mainTasks) {
      if (t.id == mainTaskId) {
        for (var p in t.projects) {
          if (p.id == projectId) targetProject = p;
        }
      }
    }
    if (targetProject != null) {
      action(targetProject);
      updateProject(mainTaskId, targetProject);
    }
  }

  // --- Integration ---

  void promoteStepToSubmission(String mainTaskId, ProjectStep step) {
    _provider.addSubtask(mainTaskId, {
      'name': step.title,
      'isCountable': false,
      'subSubTasksData': <Map<String, dynamic>>[] 
    });
  }

  // --- AI Generation ---

  Future<void> generateProjectStructure(String mainTaskId, String userPrompt) async {
    _provider.setProviderAISubquestLoading(true);
    try {
      final projectData = await _aiService.generateProjectFromPrompt(
        modelName: _provider.settings.aiModelName,
        userPrompt: userPrompt,
        currentApiKeyIndex: _provider.apiKeyIndex,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[ProjectAI] $msg"),
      );

      final newProject = Project.fromJson(projectData);
      newProject.id = const Uuid().v4();
      newProject.linkedMainTaskId = mainTaskId;
      
      _updateMainTaskProjects(mainTaskId, (projects) => [...projects, newProject]);
    } catch (e) {
      debugPrint("Error generating project: $e");
    } finally {
      _provider.setProviderAISubquestLoading(false);
    }
  }
}