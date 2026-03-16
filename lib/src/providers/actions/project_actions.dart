import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/services/ai_service.dart';
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';

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
      createdAt: DateTime.now(),
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

    if (projectToMove == null) return;

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

  // --- Snapshot Management ---

  void captureProjectSnapshot(String mainTaskId, String projectId, String? note) {
    final mainTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    if (mainTask == null) return;

    final project = mainTask.projects.firstWhereOrNull((p) => p.id == projectId);
    if (project == null) return;

    final int totalSeconds = project.calculateTotalTimeSeconds(_provider.mainTasks);
    final double progress = project.calculateProgress();

    final newSnapshot = ProjectSnapshot(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      totalSecondsInvested: totalSeconds,
      progress: progress,
      note: note,
    );

    _updateMainTaskProjects(mainTaskId, (projects) {
      return projects.map((p) {
        if (p.id == projectId) {
          p.snapshots.add(newSnapshot);
          // Keep snapshots sorted by date
          p.snapshots.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }
        return p;
      }).toList();
    });
  }

  void deleteSnapshot(String mainTaskId, String projectId, String snapshotId) {
    _updateMainTaskProjects(mainTaskId, (projects) {
      return projects.map((p) {
        if (p.id == projectId) {
          p.snapshots.removeWhere((s) => s.id == snapshotId);
        }
        return p;
      }).toList();
    });
  }

  void updateSnapshot(String mainTaskId, String projectId, String snapshotId, String? newNote) {
    _updateMainTaskProjects(mainTaskId, (projects) {
      return projects.map((p) {
        if (p.id == projectId) {
          final snap = p.snapshots.firstWhereOrNull((s) => s.id == snapshotId);
          if (snap != null) {
            snap.note = newNote;
          }
        }
        return p;
      }).toList();
    });
  }

  // --- Step Management & Linking ---

  void linkStepToTask(String mainTaskId, String projectId, String stepId,
      String targetTaskId, String type, String targetParentId) {

    // 1. Update Project Step
    _performStepAction(mainTaskId, projectId, (project) {
      _findAndUpdateStep(project.steps, stepId, (step) {
        step.linkedTaskType = type;
        step.linkedTaskId = targetTaskId;
        step.linkedParentTaskId = targetParentId;
      });
    });

    // 2. Sync Status: If target task is already done, mark step done
    bool targetIsCompleted = false;
    final targetMainTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == targetParentId);

    if (targetMainTask != null) {
      if (type == 'subtask') {
        final st = targetMainTask.subTasks.firstWhereOrNull((s) => s.id == targetTaskId);
        if (st != null) targetIsCompleted = st.completed;
      } else if (type == 'checkpoint') {
        for (var sub in targetMainTask.subTasks) {
          final sst = sub.subSubTasks.firstWhereOrNull((s) => s.id == targetTaskId);
          if (sst != null) {
            targetIsCompleted = sst.completed;
            break;
          }
        }
      }
    }

    if (targetIsCompleted) {
      // Sync step to completed
      _performStepAction(mainTaskId, projectId, (project) {
        _findAndUpdateStep(project.steps, stepId, (step) {
          step.isCompleted = true;
          step.completedAt = DateTime.now();
        });
      });
    }
  }

  void unlinkStep(String mainTaskId, String projectId, String stepId) {
    _performStepAction(mainTaskId, projectId, (project) {
      _findAndUpdateStep(project.steps, stepId, (step) {
        step.linkedTaskType = null;
        step.linkedTaskId = null;
        step.linkedParentTaskId = null;
      });
    });
  }

  bool _findAndUpdateStep(
      List<ProjectStep> steps, String stepId, Function(ProjectStep) updateFn) {
    for (var s in steps) {
      if (s.id == stepId) {
        updateFn(s);
        return true;
      }
      if (_findAndUpdateStep(s.substeps, stepId, updateFn)) return true;
    }
    return false;
  }

  void addRootStep(
      String mainTaskId, String projectId, String title, String description) {
    final newStep = ProjectStep(
      id: const Uuid().v4(),
      title: title,
      description: description,
      createdAt: DateTime.now(),
    );
    _performStepAction(mainTaskId, projectId, (project) {
      project.steps.add(newStep);
    });
  }

  void updateStep(String mainTaskId, String projectId, ProjectStep updatedStep) {
    // 1. Update the step itself
    _performStepAction(mainTaskId, projectId, (project) {
      _updateStepRecursive(project.steps, updatedStep);
    });

    // 2. Sync linked task if exists
    if (updatedStep.linkedTaskId != null && updatedStep.linkedParentTaskId != null) {
      final targetMainTaskId = updatedStep.linkedParentTaskId!;
      final targetId = updatedStep.linkedTaskId!;
      final isDone = updatedStep.isCompleted;

      // Avoid infinite loop by using fromSync flag in TaskActions
      if (updatedStep.linkedTaskType == 'subtask') {
        if (isDone) {
          _provider.taskActions.completeSubtask(targetMainTaskId, targetId, fromSync: true);
        } else {
          _provider.taskActions.uncompleteSubtask(targetMainTaskId, targetId, fromSync: true);
        }
      } else if (updatedStep.linkedTaskType == 'checkpoint') {
        // Need to find parent subtask ID for checkpoint
        final mainTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == targetMainTaskId);
        if (mainTask != null) {
          String? parentSubId;
          for (var sub in mainTask.subTasks) {
            if (sub.subSubTasks.any((sst) => sst.id == targetId)) {
              parentSubId = sub.id;
              break;
            }
          }
          if (parentSubId != null) {
            if (isDone) {
              _provider.taskActions.completeSubSubtask(targetMainTaskId, parentSubId, targetId, fromSync: true);
            } else {
              _provider.taskActions.uncompleteSubSubtask(targetMainTaskId, parentSubId, targetId, fromSync: true);
            }
          }
        }
      }
    }
  }

  bool _updateStepRecursive(List<ProjectStep> steps, ProjectStep updatedStep) {
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].id == updatedStep.id) {
        steps[i] = updatedStep;
        if (updatedStep.isCompleted && updatedStep.completedAt == null) {
          updatedStep.completedAt = DateTime.now();
        } else if (!updatedStep.isCompleted) {
          updatedStep.completedAt = null;
        }
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
      createdAt: DateTime.now(),
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
        s.isCompleted = false; // Reset parent completion if new child added
        s.completedAt = null;
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

  // --- External Sync Methods (called by TaskActions) ---

  void syncProjectStepFromTaskCompletion(String taskId, bool isCompleted) {
    // Iterate all projects to find linked steps
    for (var mainTask in _provider.mainTasks) {
      for (var project in mainTask.projects) {
        bool changed = false;
        _syncStepRecursive(project.steps, taskId, isCompleted, () => changed = true);
        if (changed) {
          updateProject(mainTask.id, project);
        }
      }
    }
  }

  void _syncStepRecursive(List<ProjectStep> steps, String linkedId, bool isCompleted, VoidCallback onChanged) {
    for (var step in steps) {
      if (step.linkedTaskId == linkedId) {
        if (step.isCompleted != isCompleted) {
          step.isCompleted = isCompleted;
          step.completedAt = isCompleted ? DateTime.now() : null;
          onChanged();
        }
      }
      _syncStepRecursive(step.substeps, linkedId, isCompleted, onChanged);
    }
  }

  // --- AI & Advanced Linking ---

  Future<void> promoteStepToSubmission(String mainTaskId, ProjectStep step) async {
    // 1. Create Subtask
    final newSubTaskId = _provider.taskActions.addSubtask(mainTaskId, {
      'name': step.title,
      'isCountable': false,
      'subSubTasksData': <Map<String, dynamic>>[]
    });

    // 2. Find project ID for step
    String? projectId;
    final mainTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    if (mainTask != null) {
      for (var p in mainTask.projects) {
        if (_containsStep(p.steps, step.id)) {
          projectId = p.id;
          break;
        }
      }
    }

    if (projectId != null) {
      // 3. Link Parent Step
      linkStepToTask(mainTaskId, projectId, step.id, newSubTaskId, 'subtask', mainTaskId);

      // 4. Auto-create & Link Child Checkpoints
      for (var substep in step.substeps) {
        // Create Checkpoint in the NEW subtask
        final newCheckPointId = _provider.taskActions.addSubSubtask(mainTaskId, newSubTaskId, {
          'name': substep.title,
          'isCountable': false,
          'targetCount': 0
        });

        // Link the substep to this new checkpoint
        if (newCheckPointId.isNotEmpty) {
          linkStepToTask(mainTaskId, projectId, substep.id, newCheckPointId, 'checkpoint', mainTaskId);
        }
      }
    }
  }

  Future<void> promoteStepToCheckpoint(String mainTaskId, String subTaskId, ProjectStep step) async {
    // Create Checkpoint
    final newSubSubTaskId = _provider.taskActions.addSubSubtask(mainTaskId, subTaskId, {
      'name': step.title,
      'isCountable': false,
      'targetCount': 0,
    });

    // Find project ID for step
    String? projectId;
    final mainTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    if (mainTask != null) {
      for (var p in mainTask.projects) {
        if (_containsStep(p.steps, step.id)) {
          projectId = p.id;
          break;
        }
      }
    }

    if (projectId != null && newSubSubTaskId.isNotEmpty) {
      linkStepToTask(mainTaskId, projectId, step.id, newSubSubTaskId, 'checkpoint', mainTaskId);
    }
  }

  bool _containsStep(List<ProjectStep> steps, String id) {
    for (var s in steps) {
      if (s.id == id) return true;
      if (_containsStep(s.substeps, id)) return true;
    }
    return false;
  }

  Future<void> generateProjectStructure(String mainTaskId, String userPrompt, {List<XFile>? images}) async {
    _provider.setProviderAISubquestLoading(true);
    _provider.setLoadingTask("Generating Project...");
    try {
      final projectData = await _aiService.generateProjectFromPrompt(
        modelCandidates: _provider.settings.heavyModels,
        userPrompt: userPrompt,
        images: images,
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
      newProject.createdAt = DateTime.now();

      _updateMainTaskProjects(
          mainTaskId, (projects) => [...projects, newProject]);
    } catch (e) {
      debugPrint("Error generating project: $e");
    } finally {
      _provider.setProviderAISubquestLoading(false);
      _provider.setLoadingTask(null);
    }
  }

  Future<void> generateStepsForProject(String mainTaskId, String projectId, String userPrompt) async {
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
        modelCandidates: _provider.settings.heavyModels,
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
            createdAt: DateTime.now(),
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

  Future<void> generateSubstepsForStep(String mainTaskId, String projectId, String stepId, String userPrompt) async {
    final mainTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    final project = mainTask?.projects.firstWhereOrNull((p) => p.id == projectId);
    if (project == null) return;

    ProjectStep? findStep(List<ProjectStep> steps, String id) {
      for (var s in steps) {
        if (s.id == id) return s;
        final found = findStep(s.substeps, id);
        if (found != null) return found;
      }
      return null;
    }

    final parentStep = findStep(project.steps, stepId);
    if (parentStep == null) return;

    _provider.setProviderAISubquestLoading(true);
    _provider.setLoadingTask("Generating Sub-steps...");

    try {
      final existingSubstepTitles = parentStep.substeps.map((s) => s.title).toList();
      final newStepsData = await _aiService.generateSubstepsForStep(
        parentStepTitle: parentStep.title,
        parentStepDescription: parentStep.description,
        existingSubsteps: existingSubstepTitles,
        userPrompt: userPrompt,
        modelCandidates: _provider.settings.liteModels,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[SubStepAI] $msg"),
      );

      _performStepAction(mainTaskId, projectId, (proj) {
        ProjectStep? targetStep = findStep(proj.steps, stepId);
        if (targetStep != null) {
          for (var stepData in newStepsData) {
            targetStep.substeps.add(ProjectStep(
              id: const Uuid().v4(),
              title: stepData['title'] ?? 'New Sub-step',
              description: stepData['description'] ?? '',
              createdAt: DateTime.now(),
            ));
          }
          targetStep.isCompleted = false;
          targetStep.completedAt = null;
        }
      });
    } catch (e) {
      debugPrint("Error generating substeps: $e");
    } finally {
      _provider.setProviderAISubquestLoading(false);
      _provider.setLoadingTask(null);
    }
  }

  // --- Graph Data Fix ---

  Future<void> fixProjectAnomalies(Project project, List<String> sessionIdsToDelete) async {
    for (var sessionId in sessionIdsToDelete) {
      // Find where this session lives within linked tasks
      for (var step in project.steps) {
        _deleteSessionRecursive(step, sessionId);
      }
    }
  }

  void _deleteSessionRecursive(ProjectStep step, String sessionId) {
    if (step.linkedTaskId != null && step.linkedTaskType == 'subtask') {
       // We need parent MainTask ID to delete.
       if (step.linkedParentTaskId != null) {
         _provider.deleteSessionFromSubtask(step.linkedParentTaskId!, step.linkedTaskId!, sessionId);
       }
    }
    for (var sub in step.substeps) {
      _deleteSessionRecursive(sub, sessionId);
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