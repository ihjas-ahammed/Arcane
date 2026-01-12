import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/services/ai_service.dart';
import 'package:collection/collection.dart';

class ProjectActions {
  final AppProvider _provider;
  final AIService _aiService = AIService();

  ProjectActions(this._provider);

  // --- Core Project Management ---

  void addProject(String title, String description, {String? mainTaskId}) {
    final targetTaskId = mainTaskId ??
        _provider.selectedTaskId ??
        _provider.mainTasks.firstOrNull?.id;

    if (targetTaskId == null) {
      debugPrint("Error: No MainTask available to assign project to.");
      return;
    }

    final newProject = Project(
      id: const Uuid().v4(),
      title: title,
      description: description,
      linkedMainTaskId: targetTaskId,
      isActive: true,
      sortOrder: DateTime.now().millisecondsSinceEpoch,
    );

    _updateMainTaskProjects(targetTaskId, (projects) {
      return [...projects, newProject];
    });
  }

  void updateProjectDetails(
      String mainTaskId, String projectId, String title, String description) {
    _updateMainTaskProjects(mainTaskId, (projects) {
      return projects.map((p) {
        if (p.id == projectId) {
          p.title = title;
          p.description = description;
        }
        return p;
      }).toList();
    });
  }

  void updateProject(String mainTaskId, Project updatedProject) {
    updatedProject.calculateProgress();
    _updateMainTaskProjects(mainTaskId, (projects) {
      return projects
          .map((p) => p.id == updatedProject.id ? updatedProject : p)
          .toList();
    });
  }

  void deleteProject(String mainTaskId, String projectId) {
    _updateMainTaskProjects(mainTaskId, (projects) {
      return projects.where((p) => p.id != projectId).toList();
    });
  }

  // --- New Feature: Status & Agent Changes ---

  void toggleProjectStatus(String mainTaskId, String projectId, bool isActive) {
    _updateMainTaskProjects(mainTaskId, (projects) {
      return projects.map((p) {
        if (p.id == projectId) {
          p.isActive = isActive;
        }
        return p;
      }).toList();
    });
  }

  void changeProjectAgent(
      String currentMainTaskId, String newMainTaskId, String projectId) {
    if (currentMainTaskId == newMainTaskId) return;

    Project? projectToMove;

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == currentMainTaskId) {
        final existingProject =
            task.projects.firstWhereOrNull((p) => p.id == projectId);
        if (existingProject != null) {
          projectToMove = existingProject;
          projectToMove!.linkedMainTaskId = newMainTaskId;
          return task.copyWith(
            projects: task.projects.where((p) => p.id != projectId).toList(),
          );
        }
      }
      return task;
    }).toList();

    if (projectToMove == null) {
      debugPrint("Project not found in source task");
      return;
    }

    final finalMainTasks = newMainTasks.map((task) {
      if (task.id == newMainTaskId) {
        return task.copyWith(
          projects: [...task.projects, projectToMove!],
        );
      }
      return task;
    }).toList();

    _provider.setProviderState(mainTasks: finalMainTasks);
  }

  void reorderProjectsGlobal(List<Project> reorderedList) {
    final Map<String, int> sortUpdates = {};
    for (int i = 0; i < reorderedList.length; i++) {
      sortUpdates[reorderedList[i].id] = i;
    }

    final newMainTasks = _provider.mainTasks.map((task) {
      bool taskUpdated = false;
      final updatedProjects = task.projects.map((p) {
        if (sortUpdates.containsKey(p.id)) {
          taskUpdated = true;
          p.sortOrder = sortUpdates[p.id]!;
          return p;
        }
        return p;
      }).toList();

      if (taskUpdated) {
        return task.copyWith(projects: updatedProjects);
      }
      return task;
    }).toList();

    _provider.setProviderState(mainTasks: newMainTasks);
  }

  // --- Step Management ---

  void addRootStep(
      String mainTaskId, String projectId, String title, String description) {
    final newStep = ProjectStep(
      id: const Uuid().v4(),
      title: title,
      description: description,
    );
    _performStepAction(mainTaskId, projectId, (project) {
      project.steps.add(newStep);
    });
  }

  void updateStep(
      String mainTaskId, String projectId, ProjectStep updatedStep) {
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

  void addSubstep(String mainTaskId, String projectId, String parentStepId,
      String title, String description) {
    final newStep = ProjectStep(
      id: const Uuid().v4(),
      title: title,
      description: description,
    );
    _performStepAction(mainTaskId, projectId, (project) {
      _addSubstepRecursive(project.steps, parentStepId, newStep);
    });
  }

  bool _addSubstepRecursive(
      List<ProjectStep> steps, String parentId, ProjectStep newStep) {
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

  void reorderRootSteps(
      String mainTaskId, String projectId, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    _performStepAction(mainTaskId, projectId, (project) {
      if (oldIndex >= 0 &&
          oldIndex < project.steps.length &&
          newIndex >= 0 &&
          newIndex < project.steps.length) {
        final ProjectStep item = project.steps.removeAt(oldIndex);
        project.steps.insert(newIndex, item);
      }
    });
  }

  void reorderSubSteps(String mainTaskId, String projectId, String parentStepId,
      int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    _performStepAction(mainTaskId, projectId, (project) {
      _reorderSubStepRecursive(project.steps, parentStepId, oldIndex, newIndex);
    });
  }

  bool _reorderSubStepRecursive(
      List<ProjectStep> steps, String parentId, int oldIndex, int newIndex) {
    for (var s in steps) {
      if (s.id == parentId) {
        if (oldIndex >= 0 &&
            oldIndex < s.substeps.length &&
            newIndex >= 0 &&
            newIndex < s.substeps.length) {
          final ProjectStep item = s.substeps.removeAt(oldIndex);
          s.substeps.insert(newIndex, item);
          return true;
        }
      }
      if (_reorderSubStepRecursive(s.substeps, parentId, oldIndex, newIndex)) {
        return true;
      }
    }
    return false;
  }

  void _performStepAction(
      String mainTaskId, String projectId, Function(Project) action) {
    Project? targetProject;
    final mainTask =
        _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    if (mainTask != null) {
      targetProject =
          mainTask.projects.firstWhereOrNull((p) => p.id == projectId);
    }

    if (targetProject != null) {
      action(targetProject);
      updateProject(mainTaskId, targetProject);
    } else {
      debugPrint("Project not found for action.");
    }
  }

  void promoteStepToSubmission(String mainTaskId, ProjectStep step) {
    _provider.addSubtask(mainTaskId, {
      'name': step.title,
      'isCountable': false,
      'subSubTasksData': <Map<String, dynamic>>[]
    });
  }

  // --- AI Generation ---

  Future<void> generateProjectStructure(
      String mainTaskId, String userPrompt) async {
    _provider.setProviderAISubquestLoading(true);
    _provider.setLoadingTask("Generating Project...");
    try {
      final projectData = await _aiService.generateProjectFromPrompt(
        modelCandidates: _provider.settings.heavyModels,
        userPrompt: userPrompt,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[ProjectAI] $msg"),
      );

      final newProject = Project.fromJson(projectData);
      newProject.id = const Uuid().v4();
      newProject.linkedMainTaskId = mainTaskId;
      newProject.isActive = true;
      newProject.sortOrder = DateTime.now().millisecondsSinceEpoch;

      _updateMainTaskProjects(
          mainTaskId, (projects) => [...projects, newProject]);
    } catch (e) {
      debugPrint("Error generating project: $e");
    } finally {
      _provider.setProviderAISubquestLoading(false);
      _provider.setLoadingTask(null);
    }
  }

  Future<void> generateStepsForProject(
      String mainTaskId, String projectId, String userPrompt) async {
    final mainTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    final project = mainTask?.projects.firstWhereOrNull((p) => p.id == projectId);
    
    if (project == null) return;

    _provider.setProviderAISubquestLoading(true);
    _provider.setLoadingTask("Generating Steps...");
    try {
      final existingStepTitles = project.steps.map((s) => s.title).toList();
      
      final newStepsData = await _aiService.generateStepsForProject(
        projectTitle: project.title,
        projectDescription: project.description,
        existingSteps: existingStepTitles,
        userPrompt: userPrompt,
        modelCandidates: _provider.settings.heavyModels, // Use heavy for better planning
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[StepAI] $msg"),
      );

      _performStepAction(mainTaskId, projectId, (proj) {
        for (var stepData in newStepsData) {
          proj.steps.add(ProjectStep(
            id: const Uuid().v4(),
            title: stepData['title'] ?? 'New Step',
            description: stepData['description'] ?? '',
          ));
        }
      });

    } catch (e) {
      debugPrint("Error generating steps: $e");
    } finally {
      _provider.setProviderAISubquestLoading(false);
      _provider.setLoadingTask(null);
    }
  }

  void _updateMainTaskProjects(
      String mainTaskId, List<Project> Function(List<Project>) updateFn) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        final updatedProjects = updateFn(task.projects);
        return task.copyWith(
          projects: updatedProjects,
        );
      }
      return task;
    }).toList();

    _provider.setProviderState(mainTasks: newMainTasks);
  }
}
