// lib/src/providers/actions/task_actions.dart
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/app_state_models.dart'; 
import 'package:arcane/src/utils/helpers.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

class TaskActions {
  final AppProvider _provider;

  TaskActions(this._provider);

  // ... [Keep existing basic actions like addMainTask, editMainTask, logToDailySummary] ...
  // ... [Including reorderSubtasks, addSubtask, updateSubtask, addSessionToSubtask, updateSessionInSubtask, deleteSessionFromSubtask] ...
  
  void reorderSubtasks(String mainTaskId, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
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

  void addMainTask(
      {required String name,
      required String description,
      required String theme,
      required String colorHex}) {
    final newTask = MainTask(
      id: 'mt_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      theme: theme,
      colorHex: colorHex,
    );
    _provider.setProviderState(mainTasks: [..._provider.mainTasks, newTask]);
  }

  void editMainTask(String taskId,
      {required String name,
      required String description,
      required String theme,
      required String colorHex}) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == taskId) {
        return task.copyWith(
          name: name,
          description: description,
          theme: theme,
          colorHex: colorHex,
        );
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void logToDailySummary(String type, Map<String, dynamic> data) {
    final today = getTodayDateString();
    final newCompletedByDay =
        Map<String, dynamic>.from(_provider.completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[today] ??
        {
          'taskTimes': <String, int>{},
          'subtasksCompleted': <Map<String, dynamic>>[],
          'checkpointsCompleted': <Map<String, dynamic>>[],
        });

    if (type == 'taskTime') {
      final taskTimes =
          Map<String, int>.from(dayData['taskTimes'] as Map? ?? {});
      taskTimes[data['taskId'] as String] =
          (taskTimes[data['taskId'] as String] ?? 0) + (data['time'] as int);
      dayData['taskTimes'] = taskTimes;
    } else if (type == 'subtaskCompleted') {
      final subtasksCompleted = List<Map<String, dynamic>>.from(
          dayData['subtasksCompleted'] as List? ?? []);
      subtasksCompleted.add(data);
      dayData['subtasksCompleted'] = subtasksCompleted;
    } else if (type == 'subSubtaskCompleted') {
      final checkpointsCompleted = List<Map<String, dynamic>>.from(
          dayData['checkpointsCompleted'] as List? ?? []);
      if (!data.containsKey('completionTimestamp')) {
        data['completionTimestamp'] = DateTime.now().toIso8601String();
      }
      checkpointsCompleted.add(data);
      dayData['checkpointsCompleted'] = checkpointsCompleted;
    }

    newCompletedByDay[today] = dayData;
    _provider.setProviderState(completedByDay: newCompletedByDay);
  }

  String addSubtask(String mainTaskId, Map<String, dynamic> subtaskData) {
    final newSubtask = SubTask(
      id: 'sub_${DateTime.now().millisecondsSinceEpoch}_${(_provider.mainTasks.fold<int>(0, (prev, task) => prev + task.subTasks.length) + 1)}',
      name: subtaskData['name'] as String,
      description: subtaskData['description'] as String? ?? '',
      isCountable: subtaskData['isCountable'] as bool? ?? false,
      targetCount: subtaskData['isCountable'] as bool? ?? false
          ? (subtaskData['targetCount'] as int? ?? 1)
          : 0,
      completed: subtaskData['completed'] as bool? ?? false,
      completedDate: (subtaskData['completed'] as bool? ?? false) ? getTodayDateString() : null,
      isRecurring: subtaskData['isRecurring'] as bool? ?? false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      subSubTasks:
          (subtaskData['subSubTasksData'] as List<Map<String, dynamic>>?)
                  ?.map((sssData) => SubSubTask(
                        id: 'ssub_${DateTime.now().millisecondsSinceEpoch}_${(_provider.mainTasks.fold<int>(0, (prev, task) => prev + task.subTasks.fold<int>(0, (prevSt, st) => prevSt + st.subSubTasks.length)) + 1)}_${sssData['name']?.hashCode ?? 0}',
                        name: sssData['name'] as String,
                        isCountable: sssData['isCountable'] as bool? ?? false,
                        targetCount: sssData['isCountable'] as bool? ?? false
                            ? (sssData['targetCount'] as int? ?? 1)
                            : 0,
                      ))
                  .toList() ??
              [],
    );

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          subTasks: [...task.subTasks, newSubtask],
        );
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
    return newSubtask.id;
  }

  void updateSubtask(
      String mainTaskId, String subtaskId, Map<String, dynamic> updates) {
    MainTask? taskToUpdate =
        _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    if (taskToUpdate == null) return;

    SubTask? subtaskToUpdate =
        taskToUpdate.subTasks.firstWhereOrNull((s) => s.id == subtaskId);
    if (subtaskToUpdate == null) return;

    final int oldSubtaskTime = subtaskToUpdate.currentTimeSpent;

    if (updates.containsKey('name')) {
      subtaskToUpdate.name = updates['name'] as String;
    }
    if (updates.containsKey('description')) {
      subtaskToUpdate.description = updates['description'] as String;
    }
    if (updates.containsKey('isRecurring')) {
      subtaskToUpdate.isRecurring = updates['isRecurring'] as bool;
    }
    
    // Always update timestamp on modification
    subtaskToUpdate.updatedAt = DateTime.now();

    if (updates.containsKey('currentTimeSpent')) {
      subtaskToUpdate.currentTimeSpent = updates['currentTimeSpent'] as int;
    }
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
      taskToUpdate.dailyTimeSpent =
          (taskToUpdate.dailyTimeSpent) + timeDifference;
      taskToUpdate.lastWorkedDate = getTodayDateString();
      logToDailySummary(
          'taskTime', {'taskId': mainTaskId, 'time': timeDifference});
    }

    final newMainTasks = _provider.mainTasks
        .map((t) => t.id == mainTaskId ? taskToUpdate : t)
        .toList();

    _provider.setProviderState(mainTasks: newMainTasks);
  }

  // ... [Session methods unchanged] ...
  void addSessionToSubtask(String mainTaskId, String subTaskId, DateTime start, DateTime end) {
    final session = TaskSession(id: 'sess_${DateTime.now().millisecondsSinceEpoch}', startTime: start, endTime: end);
    final durationSeconds = session.durationSeconds;
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
            dailyTimeSpent: task.dailyTimeSpent + durationSeconds,
            lastWorkedDate: getTodayDateString(),
            subTasks: task.subTasks.map((st) {
              if (st.id == subTaskId) {
                return SubTask(
                  id: st.id, name: st.name, description: st.description, completed: st.completed, currentTimeSpent: st.currentTimeSpent + durationSeconds,
                  completedDate: st.completedDate, isCountable: st.isCountable, targetCount: st.targetCount,
                  currentCount: st.currentCount, subSubTasks: st.subSubTasks,
                  sessions: [...st.sessions, session]..sort((a, b) => b.startTime.compareTo(a.startTime)),
                  isRecurring: st.isRecurring, lastCompletedDate: st.lastCompletedDate, createdAt: st.createdAt, updatedAt: DateTime.now(),
                );
              }
              return st;
            }).toList());
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
    _syncDateWithSessions(start);
  }

  void updateSessionInSubtask(String mainTaskId, String subTaskId, String sessionId, DateTime newStart, DateTime newEnd) {
    DateTime? oldDate;
    final oldTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    final oldSub = oldTask?.subTasks.firstWhereOrNull((s) => s.id == subTaskId);
    final oldSession = oldSub?.sessions.firstWhereOrNull((s) => s.id == sessionId);
    if (oldSession != null) oldDate = oldSession.startTime;

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
            subTasks: task.subTasks.map((st) {
          if (st.id == subTaskId) {
            int totalTime = 0;
            final updatedSessions = st.sessions.map((s) {
              if (s.id == sessionId) return TaskSession(id: s.id, startTime: newStart, endTime: newEnd);
              return s;
            }).toList();
            for (var s in updatedSessions) totalTime += s.durationSeconds;
            return SubTask(
              id: st.id, name: st.name, description: st.description, completed: st.completed, currentTimeSpent: totalTime,
              completedDate: st.completedDate, isCountable: st.isCountable, targetCount: st.targetCount,
              currentCount: st.currentCount, subSubTasks: st.subSubTasks,
              sessions: updatedSessions..sort((a, b) => b.startTime.compareTo(a.startTime)),
              isRecurring: st.isRecurring, lastCompletedDate: st.lastCompletedDate, createdAt: st.createdAt, updatedAt: DateTime.now(),
            );
          }
          return st;
        }).toList());
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
    _syncDateWithSessions(newStart);
    if (oldDate != null && (oldDate.year != newStart.year || oldDate.month != newStart.month || oldDate.day != newStart.day)) {
      _syncDateWithSessions(oldDate);
    }
  }

  void deleteSessionFromSubtask(String mainTaskId, String subTaskId, String sessionId) {
    DateTime? oldDate;
    final oldTask = _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    final oldSub = oldTask?.subTasks.firstWhereOrNull((s) => s.id == subTaskId);
    final oldSession = oldSub?.sessions.firstWhereOrNull((s) => s.id == sessionId);
    if (oldSession != null) oldDate = oldSession.startTime;

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        int deduction = oldSession?.durationSeconds ?? 0;
        return task.copyWith(
            dailyTimeSpent: (task.dailyTimeSpent - deduction).clamp(0, 999999),
            subTasks: task.subTasks.map((st) {
          if (st.id == subTaskId) {
            return SubTask(
              id: st.id, name: st.name, description: st.description, completed: st.completed,
              currentTimeSpent: (st.currentTimeSpent - deduction).clamp(0, 999999),
              completedDate: st.completedDate, isCountable: st.isCountable,
              targetCount: st.targetCount, currentCount: st.currentCount, subSubTasks: st.subSubTasks,
              sessions: st.sessions.where((s) => s.id != sessionId).toList(),
              isRecurring: st.isRecurring, lastCompletedDate: st.lastCompletedDate, createdAt: st.createdAt, updatedAt: DateTime.now(),
            );
          }
          return st;
        }).toList());
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
    _syncDateWithSessions(DateTime.now());
    if (oldDate != null && (oldDate.year != DateTime.now().year || oldDate.month != DateTime.now().month || oldDate.day != DateTime.now().day)) {
      _syncDateWithSessions(oldDate);
    }
  }

  void _syncDateWithSessions(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final Map<String, int> taskTimes = {};
    for (var task in _provider.mainTasks) {
      int taskTotal = 0;
      for (var sub in task.subTasks) {
        for (var session in sub.sessions) {
          if (session.startTime.year == date.year && session.startTime.month == date.month && session.startTime.day == date.day) {
            taskTotal += session.durationSeconds;
          }
        }
      }
      if (taskTotal > 0) taskTimes[task.id] = taskTotal;
    }
    final newCompletedByDay = Map<String, dynamic>.from(_provider.completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[dateStr] ?? {'taskTimes': <String, int>{}, 'subtasksCompleted': <Map<String, dynamic>>[], 'checkpointsCompleted': <Map<String, dynamic>>[]});
    dayData['taskTimes'] = taskTimes;
    newCompletedByDay[dateStr] = dayData;
    _provider.setProviderState(completedByDay: newCompletedByDay);
  }

  bool completeSubtask(String mainTaskId, String subtaskId, {bool fromSync = false}) {
    MainTask? mainTask =
        _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    if (mainTask == null) return false;
    SubTask? subTask =
        mainTask.subTasks.firstWhereOrNull((st) => st.id == subtaskId);
    if (subTask == null || subTask.completed) return false;

    if (subTask.isCountable && subTask.currentCount < subTask.targetCount) {
      return false;
    }

    if (subTask.currentTimeSpent <= 0 && !subTask.isCountable) {
      bool allSubSubTasksDone =
          subTask.subSubTasks.every((sss) => sss.completed);
      if (subTask.subSubTasks.isNotEmpty && !allSubSubTasksDone) return false;
      if (subTask.subSubTasks.isEmpty && subTask.currentTimeSpent <= 0) {
        // Allow completion if forced by sync (e.g. from Project Step)
        if (!fromSync) return false;
      }
    }

    ActiveTimerInfo? timerForSubtask = _provider.activeTimers[subtaskId];
    if (timerForSubtask != null) {
      _provider.logTimerAndReset(subtaskId);
    }

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          subTasks: task.subTasks.map((st) {
            if (st.id == subtaskId) {
              return SubTask(
                  id: st.id,
                  name: st.name,
                  description: st.description,
                  completed: true,
                  completedDate: getTodayDateString(),
                  currentTimeSpent: st.currentTimeSpent,
                  isCountable: st.isCountable,
                  targetCount: st.targetCount,
                  currentCount: st.currentCount,
                  subSubTasks: st.subSubTasks,
                  sessions: st.sessions,
                  isRecurring: st.isRecurring,
                  lastCompletedDate: DateTime.now(), // Store completion time for recurring reset
                  createdAt: st.createdAt,
                  updatedAt: DateTime.now(),
              );
            }
            return st;
          }).toList(),
        );
      }
      return task;
    }).toList();

    _provider.setProviderState(mainTasks: newMainTasks);

    // Sync back to Project Steps if NOT initiated from there
    if (!fromSync) {
      _provider.projectActions.syncProjectStepFromTaskCompletion(subtaskId, true);
    }

    logToDailySummary('subtaskCompleted', {
      'parentTaskId': mainTask.id,
      'name': subTask.name,
      'timeLogged': subTask.currentTimeSpent,
      'isCountable': subTask.isCountable,
      'currentCount': subTask.currentCount,
      'targetCount': subTask.targetCount
    });
    return true;
  }

  void uncompleteSubtask(String mainTaskId, String subtaskId, {bool fromSync = false}) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          subTasks: task.subTasks.map((st) {
            if (st.id == subtaskId) {
              return SubTask(
                  id: st.id,
                  name: st.name,
                  description: st.description,
                  completed: false,
                  completedDate: null,
                  currentTimeSpent: st.currentTimeSpent,
                  isCountable: st.isCountable,
                  targetCount: st.targetCount,
                  currentCount: st.currentCount,
                  subSubTasks: st.subSubTasks,
                  sessions: st.sessions,
                  isRecurring: st.isRecurring,
                  lastCompletedDate: null,
                  createdAt: st.createdAt,
                  updatedAt: DateTime.now(),
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

    final newActiveTimers =
        Map<String, ActiveTimerInfo>.from(_provider.activeTimers);
    newActiveTimers.remove(subtaskId);
    _provider.setProviderState(
        mainTasks: newMainTasks, activeTimers: newActiveTimers);
  }

  void duplicateCompletedSubtask(String mainTaskId, String subtaskId) {
    // ... [Implementation unchanged] ...
    MainTask? taskToUpdate = _provider.mainTasks.firstWhereOrNull((task) => task.id == mainTaskId);
    if (taskToUpdate == null) return;
    SubTask? subTaskToDuplicate = taskToUpdate.subTasks.firstWhereOrNull((st) => st.id == subtaskId);
    if (subTaskToDuplicate == null || !subTaskToDuplicate.completed) return;

    final newSubtask = SubTask(
      id: 'sub_${DateTime.now().millisecondsSinceEpoch}_${(taskToUpdate.subTasks.length + 1)}',
      name: subTaskToDuplicate.name, description: subTaskToDuplicate.description, completed: false, currentTimeSpent: 0, completedDate: null,
      isCountable: subTaskToDuplicate.isCountable, targetCount: subTaskToDuplicate.targetCount, currentCount: 0,
      subSubTasks: subTaskToDuplicate.subSubTasks.map((sss) => SubSubTask(
        id: 'ssub_${DateTime.now().millisecondsSinceEpoch}_${(subTaskToDuplicate.subSubTasks.length + 1)}_${sss.name.hashCode}',
        name: sss.name, completed: false, isCountable: sss.isCountable, targetCount: sss.targetCount, currentCount: 0, completionTimestamp: null,
      )).toList(), sessions: [],
      isRecurring: subTaskToDuplicate.isRecurring,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) return task.copyWith(subTasks: [...task.subTasks, newSubtask]);
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  // ... [Other methods unchanged]
  String addSubSubtask(String mainTaskId, String parentSubtaskId, Map<String, dynamic> subSubtaskData) {
    final newSubSubtask = SubSubTask(
      id: 'ssub_${DateTime.now().millisecondsSinceEpoch}_${subSubtaskData['name']?.hashCode ?? 0}',
      name: subSubtaskData['name'] as String,
      isCountable: subSubtaskData['isCountable'] as bool? ?? false,
      targetCount: subSubtaskData['isCountable'] as bool? ?? false ? (subSubtaskData['targetCount'] as int? ?? 1) : 0,
      completionTimestamp: null,
    );
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(subTasks: task.subTasks.map((st) {
          if (st.id == parentSubtaskId) {
            return SubTask(
              id: st.id, name: st.name, description: st.description, completed: st.completed, currentTimeSpent: st.currentTimeSpent,
              completedDate: st.completedDate, isCountable: st.isCountable, targetCount: st.targetCount,
              currentCount: st.currentCount, subSubTasks: [...st.subSubTasks, newSubSubtask], sessions: st.sessions,
              isRecurring: st.isRecurring, lastCompletedDate: st.lastCompletedDate, createdAt: st.createdAt, updatedAt: DateTime.now(),
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

  void updateSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, Map<String, dynamic> updates) {
    // ... [Implementation unchanged] ...
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(subTasks: task.subTasks.map((st) {
          if (st.id == parentSubtaskId) {
            final updatedSub = SubTask(
              id: st.id, name: st.name, description: st.description, completed: st.completed, currentTimeSpent: st.currentTimeSpent,
              completedDate: st.completedDate, isCountable: st.isCountable, targetCount: st.targetCount,
              currentCount: st.currentCount,
              subSubTasks: st.subSubTasks.map((sss) {
                if (sss.id == subSubtaskId) {
                  final updatedSss = SubSubTask(
                    id: sss.id,
                    name: updates['name'] as String? ?? sss.name,
                    completed: updates['completed'] as bool? ?? sss.completed,
                    isCountable: updates['isCountable'] as bool? ?? sss.isCountable,
                    targetCount: updates['targetCount'] as int? ?? sss.targetCount,
                    currentCount: updates['currentCount'] as int? ?? sss.currentCount,
                    completionTimestamp: updates['completionTimestamp'] as String? ?? sss.completionTimestamp,
                  );
                  if (updatedSss.isCountable) updatedSss.currentCount = updatedSss.currentCount.clamp(0, updatedSss.targetCount);
                  return updatedSss;
                }
                return sss;
              }).toList(), sessions: st.sessions,
              isRecurring: st.isRecurring, lastCompletedDate: st.lastCompletedDate, createdAt: st.createdAt, updatedAt: DateTime.now(),
            );
            return updatedSub;
          }
          return st;
        }).toList());
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void completeSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, {bool fromSync = false}) {
    bool subSubTaskCompletedSuccessfully = false;
    SubSubTask? completedSubSubTaskInstanceForLog;

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          subTasks: task.subTasks.map((st) {
            if (st.id == parentSubtaskId) {
              return SubTask(
                id: st.id, name: st.name, description: st.description, completed: st.completed, currentTimeSpent: st.currentTimeSpent,
                completedDate: st.completedDate, isCountable: st.isCountable, targetCount: st.targetCount,
                currentCount: st.currentCount,
                subSubTasks: st.subSubTasks.map((sss) {
                  if (sss.id == subSubtaskId && !sss.completed) {
                    if (sss.isCountable && sss.currentCount < sss.targetCount && !fromSync) {
                      subSubTaskCompletedSuccessfully = false;
                      return sss;
                    }
                    SubSubTask updatedSss = SubSubTask(
                      id: sss.id, name: sss.name, completed: true, isCountable: sss.isCountable,
                      targetCount: sss.targetCount, currentCount: sss.currentCount,
                      completionTimestamp: DateTime.now().toIso8601String(),
                    );
                    completedSubSubTaskInstanceForLog = SubSubTask(
                      id: sss.id, name: sss.name, completed: true, isCountable: sss.isCountable,
                      targetCount: sss.targetCount, currentCount: sss.currentCount,
                      completionTimestamp: updatedSss.completionTimestamp,
                    );
                    subSubTaskCompletedSuccessfully = true;
                    return updatedSss;
                  }
                  return sss;
                }).toList(), sessions: st.sessions,
                isRecurring: st.isRecurring, lastCompletedDate: st.lastCompletedDate, createdAt: st.createdAt, updatedAt: DateTime.now(),
              );
            }
            return st;
          }).toList(),
        );
      }
      return task;
    }).toList();

    if (subSubTaskCompletedSuccessfully && completedSubSubTaskInstanceForLog != null) {
      _provider.setProviderState(mainTasks: newMainTasks);
      
      if (!fromSync) {
        _provider.projectActions.syncProjectStepFromTaskCompletion(subSubtaskId, true);
      }

      logToDailySummary('subSubtaskCompleted', {
        'mainTaskId': mainTaskId, 'parentSubtaskId': parentSubtaskId, 'subSubtaskId': subSubtaskId,
        'name': completedSubSubTaskInstanceForLog!.name, 'isCountable': completedSubSubTaskInstanceForLog!.isCountable,
        'currentCount': completedSubSubTaskInstanceForLog!.currentCount, 'targetCount': completedSubSubTaskInstanceForLog!.targetCount,
        'completionTimestamp': completedSubSubTaskInstanceForLog!.completionTimestamp,
        'parentSubtaskName': _provider.mainTasks.firstWhereOrNull((m) => m.id == mainTaskId)?.subTasks.firstWhereOrNull((s) => s.id == parentSubtaskId)?.name ?? 'N/A',
        'mainTaskName': _provider.mainTasks.firstWhereOrNull((m) => m.id == mainTaskId)?.name ?? 'N/A'
      });
    }
  }

  void uncompleteSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, {bool fromSync = false}) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(subTasks: task.subTasks.map((st) {
          if (st.id == parentSubtaskId) {
            return SubTask(
              id: st.id, name: st.name, description: st.description, completed: st.completed, currentTimeSpent: st.currentTimeSpent,
              completedDate: st.completedDate, isCountable: st.isCountable, targetCount: st.targetCount,
              currentCount: st.currentCount,
              subSubTasks: st.subSubTasks.map((sss) {
                if (sss.id == subSubtaskId && sss.completed) {
                  return SubSubTask(
                    id: sss.id, name: sss.name, completed: false, isCountable: sss.isCountable,
                    targetCount: sss.targetCount, currentCount: sss.currentCount, completionTimestamp: null,
                  );
                }
                return sss;
              }).toList(), sessions: st.sessions,
              isRecurring: st.isRecurring, lastCompletedDate: st.lastCompletedDate, createdAt: st.createdAt, updatedAt: DateTime.now(),
            );
          }
          return st;
        }).toList());
      }
      return task;
    }).toList();

    _provider.setProviderState(mainTasks: newMainTasks);
    if (!fromSync) {
      _provider.projectActions.syncProjectStepFromTaskCompletion(subSubtaskId, false);
    }
  }

  void deleteSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          subTasks: task.subTasks.map((st) {
            if (st.id == parentSubtaskId) {
              return SubTask(
                id: st.id, name: st.name, description: st.description, completed: st.completed, currentTimeSpent: st.currentTimeSpent,
                completedDate: st.completedDate, isCountable: st.isCountable, targetCount: st.targetCount,
                currentCount: st.currentCount,
                subSubTasks: st.subSubTasks.where((sss) => sss.id != subSubtaskId).toList(),
                sessions: st.sessions,
                isRecurring: st.isRecurring, lastCompletedDate: st.lastCompletedDate, createdAt: st.createdAt, updatedAt: DateTime.now(),
              );
            }
            return st;
          }).toList(),
        );
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }
}