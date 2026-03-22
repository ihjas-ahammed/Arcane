import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/app_state_models.dart';
import 'package:arcane/src/utils/helpers.dart';
import 'package:arcane/src/utils/time_validation_helper.dart';
import 'package:arcane/src/utils/task_calculations.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

class TaskActions {
  final AppProvider _provider;

  TaskActions(this._provider);

  // --- Helper for SubSubTask Recursion ---
  List<SubSubTask> _recursiveNodeOperation(List<SubSubTask> nodes, String targetId, String action, dynamic payload) {
    List<SubSubTask> newNodes = [];
    
    for (var node in nodes) {
      if (node.id == targetId) {
        if (action == 'delete') {
          continue; 
        } else if (action == 'update') {
          final updates = payload as Map<String, dynamic>;
          final updatedNode = node.copyWith(
            name: updates['name'] as String?,
            completed: updates['completed'] as bool?,
            isCountable: updates['isCountable'] as bool?,
            targetCount: updates['targetCount'] as int?,
            currentCount: updates['currentCount'] as int?,
            completionTimestamp: updates['completionTimestamp'] as String?,
            type: updates['type'] as String?,
            why: updates['why'] as String?,
            what: updates['what'] as String?,
          );
          if (updatedNode.isCountable) updatedNode.currentCount = updatedNode.currentCount.clamp(0, updatedNode.targetCount);
          newNodes.add(updatedNode);
        } else if (action == 'duplicate') {
          newNodes.add(node);
          final copy = node.copyWith(
            id: 'ssub_${DateTime.now().millisecondsSinceEpoch}_copy_${node.name.hashCode}',
            name: "${node.name} (Copy)",
            completed: false,
            currentCount: 0,
            completionTimestamp: null,
            substeps: List.from(node.substeps),
          );
          newNodes.add(copy);
        } else if (action == 'add_child') {
          final data = payload as Map<String, dynamic>;
          final newChild = SubSubTask(
            id: 'ssub_${DateTime.now().millisecondsSinceEpoch}_${data['name']?.hashCode ?? 0}',
            name: data['name'] as String,
            isCountable: data['isCountable'] as bool? ?? false,
            targetCount: data['isCountable'] as bool? ?? false ? (data['targetCount'] as int? ?? 1) : 0,
            type: data['type'] as String? ?? 'check',
            why: data['why'] as String? ?? '',
            what: data['what'] as String? ?? '',
          );
          final updatedNode = node.copyWith(substeps: [...node.substeps, newChild]);
          newNodes.add(updatedNode);
        }
      } else {
        final newChildren = _recursiveNodeOperation(node.substeps, targetId, action, payload);
        final updatedNode = node.copyWith(substeps: newChildren);
        newNodes.add(updatedNode);
      }
    }
    return newNodes;
  }

  // --- Day Plan Management ---
  List<String> getDayPlan(String dateStr) {
    final dayData = _provider.completedByDay[dateStr];
    if (dayData == null) return [];
    return List<String>.from(dayData['dailyPlan'] ?? []);
  }

  void updateDayPlan(String dateStr, List<String> plan) {
    final newHistory = Map<String, dynamic>.from(_provider.completedByDay);
    if (!newHistory.containsKey(dateStr)) {
      newHistory[dateStr] = {
        'taskTimes': <String, int>{},
        'subtasksCompleted': <Map<String, dynamic>>[],
        'checkpointsCompleted': <Map<String, dynamic>>[],
      };
    }
    newHistory[dateStr]['dailyPlan'] = plan;
    _provider.setProviderState(completedByDay: newHistory);
  }

  // --- SubSubTask Actions ---

  String addSubSubtask(String mainTaskId, String parentSubtaskId, Map<String, dynamic> subSubtaskData, {String? parentCheckpointId}) {
    if (parentCheckpointId != null) {
      final newMainTasks = _provider.mainTasks.map((task) {
        if (task.id == mainTaskId) {
          return task.copyWith(subTasks: task.subTasks.map((st) {
            if (st.id == parentSubtaskId) {
              return st.copyWith(
                subSubTasks: _recursiveNodeOperation(st.subSubTasks, parentCheckpointId, 'add_child', subSubtaskData),
                updatedAt: DateTime.now(),
              );
            }
            return st;
          }).toList());
        }
        return task;
      }).toList();
      _provider.setProviderState(mainTasks: newMainTasks);
      return "";
    } else {
      final newSubSubtask = SubSubTask(
        id: 'ssub_${DateTime.now().millisecondsSinceEpoch}_${subSubtaskData['name']?.hashCode ?? 0}',
        name: subSubtaskData['name'] as String,
        isCountable: subSubtaskData['isCountable'] as bool? ?? false,
        targetCount: subSubtaskData['isCountable'] as bool? ?? false ? (subSubtaskData['targetCount'] as int? ?? 1) : 0,
        completionTimestamp: null,
        type: subSubtaskData['type'] as String? ?? 'check',
        why: subSubtaskData['why'] as String? ?? '',
        what: subSubtaskData['what'] as String? ?? '',
      );
      final newMainTasks = _provider.mainTasks.map((task) {
        if (task.id == mainTaskId) {
          return task.copyWith(subTasks: task.subTasks.map((st) {
            if (st.id == parentSubtaskId) {
              return st.copyWith(
                subSubTasks: [...st.subSubTasks, newSubSubtask],
                updatedAt: DateTime.now(),
              );
            }
            return st;
          }).toList());
        }
        return task;
      }).toList();
      _provider.setProviderState(mainTasks: newMainTasks);
      return newSubSubtask.id;
    }
  }

  void updateSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, Map<String, dynamic> updates) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(subTasks: task.subTasks.map((st) {
          if (st.id == parentSubtaskId) {
            return st.copyWith(
              subSubTasks: _recursiveNodeOperation(st.subSubTasks, subSubtaskId, 'update', updates),
              updatedAt: DateTime.now(),
            );
          }
          return st;
        }).toList());
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void deleteSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(subTasks: task.subTasks.map((st) {
          if (st.id == parentSubtaskId) {
            return st.copyWith(
              subSubTasks: _recursiveNodeOperation(st.subSubTasks, subSubtaskId, 'delete', null),
              updatedAt: DateTime.now(),
            );
          }
          return st;
        }).toList());
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void duplicateSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(subTasks: task.subTasks.map((st) {
          if (st.id == parentSubtaskId) {
            return st.copyWith(
              subSubTasks: _recursiveNodeOperation(st.subSubTasks, subSubtaskId, 'duplicate', null),
              updatedAt: DateTime.now(),
            );
          }
          return st;
        }).toList());
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void completeSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, {bool fromSync = false}) {
    final updates = {'completed': true, 'completionTimestamp': DateTime.now().toIso8601String()};
    updateSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId, updates);
    if (!fromSync) {
      _provider.projectActions.syncProjectStepFromTaskCompletion(subSubtaskId, true);
    }
    logToDailySummary('subSubtaskCompleted', {'parentTaskId': mainTaskId, 'parentSubTaskId': parentSubtaskId, 'subSubTaskId': subSubtaskId});
  }

  void uncompleteSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, {bool fromSync = false}) {
    final updates = {'completed': false, 'completionTimestamp': null};
    updateSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId, updates);
    if (!fromSync) {
      _provider.projectActions.syncProjectStepFromTaskCompletion(subSubtaskId, false);
    }
  }
  
  void reorderSubSubtasksBySubset(String mainTaskId, String parentSubtaskId, List<String> subsetIds, {String? parentCheckpointId}) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(subTasks: task.subTasks.map((st) {
          if (st.id == parentSubtaskId) {
            if (parentCheckpointId != null) {
              return st.copyWith(subSubTasks: _reorderNodesSubset(st.subSubTasks, parentCheckpointId, subsetIds));
            } else {
              final subsetItems = subsetIds.map((id) => st.subSubTasks.firstWhere((sst) => sst.id == id)).toList();
              final otherItems = st.subSubTasks.where((sst) => !subsetIds.contains(sst.id)).toList();
              int firstIndex = st.subSubTasks.indexWhere((sst) => subsetIds.contains(sst.id));
              if (firstIndex == -1) firstIndex = 0;
              final List<SubSubTask> updated = [];
              updated.addAll(otherItems.sublist(0, firstIndex));
              updated.addAll(subsetItems);
              updated.addAll(otherItems.sublist(firstIndex));
              return st.copyWith(subSubTasks: updated);
            }
          }
          return st;
        }).toList());
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  List<SubSubTask> _reorderNodesSubset(List<SubSubTask> nodes, String targetId, List<String> subsetIds) {
    return nodes.map((node) {
      if (node.id == targetId) {
         final subsetItems = subsetIds.map((id) => node.substeps.firstWhere((sst) => sst.id == id)).toList();
         final otherItems = node.substeps.where((sst) => !subsetIds.contains(sst.id)).toList();
         int firstIndex = node.substeps.indexWhere((sst) => subsetIds.contains(sst.id));
         if (firstIndex == -1) firstIndex = 0;
         final List<SubSubTask> updated = [];
         updated.addAll(otherItems.sublist(0, firstIndex));
         updated.addAll(subsetItems);
         updated.addAll(otherItems.sublist(firstIndex));
         return node.copyWith(substeps: updated);
      } else {
         return node.copyWith(substeps: _reorderNodesSubset(node.substeps, targetId, subsetIds));
      }
    }).toList();
  }

  // --- SubTask Actions ---

  String addSubtask(String mainTaskId, Map<String, dynamic> subtaskData) {
    final newSubtask = SubTask(
      id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
      name: subtaskData['name'] as String,
      description: subtaskData['description'] as String? ?? '',
      isCountable: subtaskData['isCountable'] as bool? ?? false,
      targetCount: subtaskData['targetCount'] as int? ?? 0,
      subSubTasks: [],
      why: subtaskData['why'] as String? ?? '',
      what: subtaskData['what'] as String? ?? '',
      resources: subtaskData['resources'] as String? ?? '', 
      isActive: subtaskData['isActive'] as bool? ?? true,
    );

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(subTasks: [...task.subTasks, newSubtask]);
      }
      return task;
    }).toList();
    
    _provider.setProviderState(mainTasks: newMainTasks);
    return newSubtask.id;
  }

  void updateSubtask(String mainTaskId, String subtaskId, Map<String, dynamic> updates) {
    MainTask? taskToUpdate = _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    if (taskToUpdate == null) return;

    SubTask? subtaskToUpdate = taskToUpdate.subTasks.firstWhereOrNull((s) => s.id == subtaskId);
    if (subtaskToUpdate == null) return;

    final int oldSubtaskTime = subtaskToUpdate.currentTimeSpent;

    if (updates.containsKey('name')) subtaskToUpdate.name = updates['name'] as String;
    if (updates.containsKey('description')) subtaskToUpdate.description = updates['description'] as String;
    if (updates.containsKey('isRecurring')) subtaskToUpdate.isRecurring = updates['isRecurring'] as bool;
    if (updates.containsKey('why')) subtaskToUpdate.why = updates['why'] as String;
    if (updates.containsKey('what')) subtaskToUpdate.what = updates['what'] as String;
    if (updates.containsKey('resources')) subtaskToUpdate.resources = updates['resources'] as String; 
    if (updates.containsKey('isActive')) subtaskToUpdate.isActive = updates['isActive'] as bool;
    
    subtaskToUpdate.updatedAt = DateTime.now();

    if (updates.containsKey('currentTimeSpent')) subtaskToUpdate.currentTimeSpent = updates['currentTimeSpent'] as int;
    if (updates.containsKey('completed')) {
      subtaskToUpdate.completed = updates['completed'] as bool;
      if (!subtaskToUpdate.completed) {
        subtaskToUpdate.completedDate = null;
        subtaskToUpdate.lastCompletedDate = null;
      }
    }

    int timeDifference = 0;
    if (updates.containsKey('currentTimeSpent')) {
      timeDifference = subtaskToUpdate.currentTimeSpent - oldSubtaskTime;
    }

    if (timeDifference != 0) {
      taskToUpdate.dailyTimeSpent = (taskToUpdate.dailyTimeSpent) + timeDifference;
      taskToUpdate.lastWorkedDate = getTodayDateString();
      logToDailySummary('taskTime', {'taskId': mainTaskId, 'time': timeDifference});
    }

    final newMainTasks = _provider.mainTasks.map((t) => t.id == mainTaskId ? taskToUpdate! : t).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  bool completeSubtask(String mainTaskId, String subtaskId, {bool fromSync = false}) {
    MainTask? mainTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    if (mainTask == null) return false;
    SubTask? subTask = mainTask.subTasks.firstWhereOrNull((st) => st.id == subtaskId);
    if (subTask == null || subTask.completed) return false;

    if (subTask.isCountable && subTask.currentCount < subTask.targetCount) return false;

    bool hasTime = subTask.currentTimeSpent > 0;
    if (subTask.isRecurring) {
      hasTime = TaskCalculations.getHistoricalTodaySeconds(subTask) > 0;
      if (_provider.activeTimers[subtaskId]?.isRunning == true) hasTime = true;
    }

    if (!hasTime && !subTask.isCountable) {
      bool allSubSubTasksDone = subTask.subSubTasks.every((sss) => sss.completed);
      if (subTask.subSubTasks.isNotEmpty && !allSubSubTasksDone) return false;
      if (subTask.subSubTasks.isEmpty && !hasTime && !fromSync) return false;
    }

    if (_provider.activeTimers[subtaskId] != null) {
      _provider.timerActions.logTimerAndReset(subtaskId);
    }

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          subTasks: task.subTasks.map((st) {
            if (st.id == subtaskId) {
              return st.copyWith(
                  completed: true, completedDate: getTodayDateString(),
                  lastCompletedDate: DateTime.now(), updatedAt: DateTime.now()
              );
            }
            return st;
          }).toList(),
        );
      }
      return task;
    }).toList();

    _provider.setProviderState(mainTasks: newMainTasks);

    if (!fromSync) {
      _provider.projectActions.syncProjectStepFromTaskCompletion(subtaskId, true);
    }

    logToDailySummary('subtaskCompleted', {
      'parentTaskId': mainTask.id,
      'name': subTask.name,
      'timeLogged': subTask.currentTimeSpent,
    });
    return true;
  }

  void uncompleteSubtask(String mainTaskId, String subtaskId, {bool fromSync = false}) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          subTasks: task.subTasks.map((st) {
            if (st.id == subtaskId) {
              return st.copyWith(
                  completed: false, completedDate: null,
                  lastCompletedDate: null, updatedAt: DateTime.now()
              );
            }
            return st;
          }).toList(),
        );
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);

    if (!fromSync) {
      _provider.projectActions.syncProjectStepFromTaskCompletion(subtaskId, false);
    }
  }

  void deleteSubtask(String mainTaskId, String subtaskId) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          subTasks: task.subTasks.where((st) => st.id != subtaskId).toList(),
        );
      }
      return task;
    }).toList();

    final newActiveTimers = Map<String, dynamic>.from(_provider.activeTimers.map((k, v) => MapEntry(k, v.toJson())));
    newActiveTimers.remove(subtaskId);
    
    _provider.setProviderState(mainTasks: newMainTasks, activeTimers: newActiveTimers);
  }

  void duplicateCompletedSubtask(String mainTaskId, String subtaskId) {
    MainTask? taskToUpdate = _provider.mainTasks.firstWhereOrNull((task) => task.id == mainTaskId);
    if (taskToUpdate == null) return;
    SubTask? subTaskToDuplicate = taskToUpdate.subTasks.firstWhereOrNull((st) => st.id == subtaskId);
    if (subTaskToDuplicate == null || !subTaskToDuplicate.completed) return;

    final newSubtask = subTaskToDuplicate.copyWith(
      id: 'sub_${DateTime.now().millisecondsSinceEpoch}_${(taskToUpdate.subTasks.length + 1)}',
      completed: false, currentTimeSpent: 0, completedDate: null, currentCount: 0,
      subSubTasks: subTaskToDuplicate.subSubTasks.map((sss) => sss.copyWith(
        id: 'ssub_${DateTime.now().millisecondsSinceEpoch}_${(subTaskToDuplicate.subSubTasks.length + 1)}_${sss.name.hashCode}',
        completed: false, currentCount: 0, completionTimestamp: null
      )).toList(), sessions: [], lastCompletedDate: null,
      createdAt: DateTime.now(), updatedAt: DateTime.now(), isActive: true,
    );

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) return task.copyWith(subTasks: [...task.subTasks, newSubtask]);
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void reorderSubtasks(String mainTaskId, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        final List<SubTask> updatedSubtasks = List.from(task.subTasks);
        if (oldIndex >= 0 && oldIndex < updatedSubtasks.length && newIndex >= 0 && newIndex < updatedSubtasks.length) {
          final SubTask item = updatedSubtasks.removeAt(oldIndex);
          updatedSubtasks.insert(newIndex, item);
        }
        return task.copyWith(subTasks: updatedSubtasks);
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void reorderSubtasksBySubset(String mainTaskId, List<String> subsetIds) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        final subsetItems = subsetIds.map((id) => task.subTasks.firstWhere((st) => st.id == id)).toList();
        final otherItems = task.subTasks.where((st) => !subsetIds.contains(st.id)).toList();
        int firstIndex = task.subTasks.indexWhere((st) => subsetIds.contains(st.id));
        if (firstIndex == -1) firstIndex = 0;
        final List<SubTask> updated = [];
        updated.addAll(otherItems.sublist(0, firstIndex));
        updated.addAll(subsetItems);
        updated.addAll(otherItems.sublist(firstIndex));
        return task.copyWith(subTasks: updated);
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  // --- Session Management ---

  bool addSessionToSubtask(String mainTaskId, String subTaskId, DateTime start, DateTime end) {
    if (TimeValidationHelper.hasOverlap(start: start, end: end, allTasks: _provider.mainTasks)) return false;

    final session = TaskSession(id: 'sess_${DateTime.now().millisecondsSinceEpoch}', startTime: start, endTime: end);
    final durationSeconds = session.durationSeconds;
    
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
            dailyTimeSpent: task.dailyTimeSpent + durationSeconds,
            lastWorkedDate: getTodayDateString(),
            subTasks: task.subTasks.map((st) {
              if (st.id == subTaskId) {
                final newSessions = [...st.sessions, session]..sort((a, b) => b.startTime.compareTo(a.startTime));
                final totalTime = newSessions.fold(0, (sum, s) => sum + s.durationSeconds);
                return st.copyWith(
                  currentTimeSpent: totalTime,
                  sessions: newSessions,
                  updatedAt: DateTime.now(),
                );
              }
              return st;
            }).toList());
      }
      return task;
    }).toList();
    
    _provider.setProviderState(mainTasks: newMainTasks);
    recalibrateTimeLogs(silent: true);
    return true; 
  }

  void updateSessionInSubtask(String mainTaskId, String subTaskId, String sessionId, DateTime newStart, DateTime newEnd) {
    if (TimeValidationHelper.hasOverlap(start: newStart, end: newEnd, allTasks: _provider.mainTasks, excludeSessionId: sessionId)) return;

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
            subTasks: task.subTasks.map((st) {
          if (st.id == subTaskId) {
            final updatedSessions = st.sessions.map((s) {
              if (s.id == sessionId) return TaskSession(id: s.id, startTime: newStart, endTime: newEnd);
              return s;
            }).toList();
            final totalTime = updatedSessions.fold(0, (sum, s) => sum + s.durationSeconds);
            return st.copyWith(
              currentTimeSpent: totalTime,
              sessions: updatedSessions..sort((a, b) => b.startTime.compareTo(a.startTime)),
              updatedAt: DateTime.now(),
            );
          }
          return st;
        }).toList());
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
    recalibrateTimeLogs(silent: true);
  }

  void deleteSessionFromSubtask(String mainTaskId, String subTaskId, String sessionId) {
    final oldTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    final oldSub = oldTask?.subTasks.firstWhereOrNull((s) => s.id == subTaskId);
    final oldSession = oldSub?.sessions.firstWhereOrNull((s) => s.id == sessionId);

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        int deduction = oldSession?.durationSeconds ?? 0;
        return task.copyWith(
            dailyTimeSpent: (task.dailyTimeSpent - deduction).clamp(0, 999999),
            subTasks: task.subTasks.map((st) {
          if (st.id == subTaskId) {
            final remainingSessions = st.sessions.where((s) => s.id != sessionId).toList();
            final totalTime = remainingSessions.fold(0, (sum, s) => sum + s.durationSeconds);
            return st.copyWith(
              currentTimeSpent: totalTime,
              sessions: remainingSessions,
              updatedAt: DateTime.now(),
            );
          }
          return st;
        }).toList());
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
    recalibrateTimeLogs(silent: true);
  }

  // --- Task Toggling ---
  void toggleTaskStatus(String taskId, bool isActive) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == taskId) {
        return task.copyWith(isActive: isActive);
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  // --- Utility ---

  Future<void> recalibrateTimeLogs({bool silent = false}) async {
    if (!silent) _provider.setLoadingTask("RECALIBRATING...");

    final Map<String, dynamic> newCompletedByDay = Map.from(_provider.completedByDay);
    final Map<String, Map<String, int>> calculatedHistory = {};

    for (var task in _provider.mainTasks) {
      for (var sub in task.subTasks) {
        for (var session in sub.sessions) {
          DateTime cursor = session.startTime;
          while (cursor.isBefore(session.endTime)) {
            final dateStr = DateFormat('yyyy-MM-dd').format(cursor);
            final endOfDay = DateTime(cursor.year, cursor.month, cursor.day, 23, 59, 59, 999);
            final segmentEnd = session.endTime.isBefore(endOfDay) ? session.endTime : endOfDay;
            final seconds = segmentEnd.difference(cursor).inSeconds;
            
            if (seconds > 0) {
              if (!calculatedHistory.containsKey(dateStr)) {
                calculatedHistory[dateStr] = {};
              }
              calculatedHistory[dateStr]![task.id] = (calculatedHistory[dateStr]![task.id] ?? 0) + seconds;
            }
            cursor = DateTime(cursor.year, cursor.month, cursor.day).add(const Duration(days: 1));
          }
        }
      }
    }

    calculatedHistory.forEach((date, taskMap) {
      if (!newCompletedByDay.containsKey(date)) {
        newCompletedByDay[date] = {
          'taskTimes': <String, int>{},
          'subtasksCompleted': <Map<String, dynamic>>[],
          'checkpointsCompleted': <Map<String, dynamic>>[],
          'dailyPlan': <String>[],
        };
      }
      final dayData = Map<String, dynamic>.from(newCompletedByDay[date]);
      dayData['taskTimes'] = taskMap;
      newCompletedByDay[date] = dayData;
    });

    final todayStr = getTodayDateString();
    final todayTimes = calculatedHistory[todayStr] ?? {};

    final newMainTasks = _provider.mainTasks.map((task) {
      final updatedSubtasks = task.subTasks.map((st) {
        final totalSeconds = st.sessions.fold(0, (sum, s) => sum + s.durationSeconds);
        return st.copyWith(currentTimeSpent: totalSeconds);
      }).toList();

      return task.copyWith(
        subTasks: updatedSubtasks, 
        dailyTimeSpent: todayTimes[task.id] ?? 0 
      );
    }).toList();

    _provider.setProviderState(
      completedByDay: newCompletedByDay,
      mainTasks: newMainTasks
    );
    
    if (!silent) _provider.setLoadingTask(null);
  }

  void addMainTask({required String name, required String description, required String theme, required String colorHex}) {
    final newTask = MainTask(
      id: 'mt_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      theme: theme,
      colorHex: colorHex,
      isActive: true,
    );
    _provider.setProviderState(mainTasks: [..._provider.mainTasks, newTask]);
  }

  void editMainTask(String taskId, {required String name, required String description, required String theme, required String colorHex}) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == taskId) {
        return task.copyWith(name: name, description: description, theme: theme, colorHex: colorHex);
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void logToDailySummary(String type, Map<String, dynamic> data) {
    final today = getTodayDateString();
    final newCompletedByDay = Map<String, dynamic>.from(_provider.completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[today] ?? {'taskTimes': <String, int>{}, 'subtasksCompleted': <Map<String, dynamic>>[], 'checkpointsCompleted': <Map<String, dynamic>>[], 'dailyPlan': <String>[]});

    if (type == 'taskTime') {
      final taskTimes = Map<String, int>.from(dayData['taskTimes'] as Map? ?? {});
      taskTimes[data['taskId'] as String] = (taskTimes[data['taskId'] as String] ?? 0) + (data['time'] as int);
      dayData['taskTimes'] = taskTimes;
    } else if (type == 'subtaskCompleted') {
      final subtasksCompleted = List<Map<String, dynamic>>.from(dayData['subtasksCompleted'] as List? ?? []);
      subtasksCompleted.add(data);
      dayData['subtasksCompleted'] = subtasksCompleted;
    } else if (type == 'subSubtaskCompleted') {
      final checkpointsCompleted = List<Map<String, dynamic>>.from(dayData['checkpointsCompleted'] as List? ?? []);
      if (!data.containsKey('completionTimestamp')) data['completionTimestamp'] = DateTime.now().toIso8601String();
      checkpointsCompleted.add(data);
      dayData['checkpointsCompleted'] = checkpointsCompleted;
    }

    newCompletedByDay[today] = dayData;
    _provider.setProviderState(completedByDay: newCompletedByDay);
  }
}