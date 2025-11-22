// lib/src/providers/actions/task_actions.dart
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/app_state_models.dart';
import 'package:arcane/src/utils/helpers.dart';
import 'package:collection/collection.dart';

class TaskActions {
  final AppProvider _provider;

  TaskActions(this._provider);

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
        return MainTask(
          id: task.id,
          name: name,
          description: description,
          theme: theme,
          colorHex: colorHex,
          streak: task.streak,
          weeklyStreak: task.weeklyStreak,
          dailyTimeSpent: task.dailyTimeSpent,
          lastWorkedDate: task.lastWorkedDate,
          subTasks: task.subTasks,
          weeklyCompletionStatus: task.weeklyCompletionStatus,
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
          'energyLogs': <Map<String, dynamic>>[]
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
      id:
          'sub_${DateTime.now().millisecondsSinceEpoch}_${(_provider.mainTasks.fold<int>(0, (prev, task) => prev + task.subTasks.length) + 1)}',
      name: subtaskData['name'] as String,
      isCountable: subtaskData['isCountable'] as bool? ?? false,
      targetCount: subtaskData['isCountable'] as bool? ?? false
          ? (subtaskData['targetCount'] as int? ?? 1)
          : 0,
      subSubTasks:
          (subtaskData['subSubTasksData'] as List<Map<String, dynamic>>?)
                  ?.map((sssData) => SubSubTask(
                        id:
                            'ssub_${DateTime.now().millisecondsSinceEpoch}_${(_provider.mainTasks.fold<int>(0, (prev, task) => prev + task.subTasks.fold<int>(0, (prevSt, st) => prevSt + st.subSubTasks.length)) + 1)}_${sssData['name']?.hashCode ?? 0}',
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
          subTasks: [...task.subTasks, newSubtask],
          weeklyCompletionStatus: task.weeklyCompletionStatus,
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

    if (updates.containsKey('name'))
      subtaskToUpdate.name = updates['name'] as String;
    if (updates.containsKey('isCountable'))
      subtaskToUpdate.isCountable = updates['isCountable'] as bool;
    if (updates.containsKey('targetCount'))
      subtaskToUpdate.targetCount = updates['targetCount'] as int;
    if (updates.containsKey('currentCount'))
      subtaskToUpdate.currentCount = (updates['currentCount'] as int)
          .clamp(0, subtaskToUpdate.targetCount);
    if (updates.containsKey('currentTimeSpent'))
      subtaskToUpdate.currentTimeSpent = updates['currentTimeSpent'] as int;

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

    final int oldDailyTotalBeforeThisChange =
        taskToUpdate.dailyTimeSpent - timeDifference;
    if (oldDailyTotalBeforeThisChange < dailyTaskGoalMinutes &&
        taskToUpdate.dailyTimeSpent >= dailyTaskGoalMinutes) {
      taskToUpdate.streak = taskToUpdate.streak + 1;
      _provider.markDailyTaskGoalMet(taskToUpdate.id);
    }

    final newMainTasks = _provider.mainTasks
        .map((t) => t.id == mainTaskId ? taskToUpdate : t)
        .toList();

    _provider.setProviderState(mainTasks: newMainTasks);
  }

  bool completeSubtask(String mainTaskId, String subtaskId) {
    MainTask? mainTask =
        _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    if (mainTask == null) return false;
    SubTask? subTask =
        mainTask.subTasks.firstWhereOrNull((st) => st.id == subtaskId);
    if (subTask == null || subTask.completed) return false;

    if (subTask.isCountable && subTask.currentCount < subTask.targetCount)
      return false;

    if (subTask.currentTimeSpent <= 0 && !subTask.isCountable) {
      bool allSubSubTasksDone =
          subTask.subSubTasks.every((sss) => sss.completed);
      if (subTask.subSubTasks.isNotEmpty && !allSubSubTasksDone) return false;
      if (subTask.subSubTasks.isEmpty && subTask.currentTimeSpent <= 0)
        return false;
    }

    ActiveTimerInfo? timerForSubtask = _provider.activeTimers[subtaskId];
    if (timerForSubtask != null) {
      _provider.logTimerAndReset(subtaskId);
    }

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
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
          subTasks: task.subTasks.map((st) {
            if (st.id == subtaskId) {
              return SubTask(
                  id: st.id,
                  name: st.name,
                  completed: true,
                  completedDate: getTodayDateString(),
                  currentTimeSpent: st.currentTimeSpent,
                  isCountable: st.isCountable,
                  targetCount: st.targetCount,
                  currentCount: st.currentCount,
                  subSubTasks: st.subSubTasks);
            }
            return st;
          }).toList(),
          weeklyCompletionStatus: task.weeklyCompletionStatus,
        );
      }
      return task;
    }).toList();

    _provider.setProviderState(mainTasks: newMainTasks);

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

  void deleteSubtask(String mainTaskId, String subtaskId) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
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
          subTasks: task.subTasks.where((st) => st.id != subtaskId).toList(),
          weeklyCompletionStatus: task.weeklyCompletionStatus,
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
    MainTask? taskToUpdate =
        _provider.mainTasks.firstWhereOrNull((task) => task.id == mainTaskId);
    if (taskToUpdate == null) return;

    SubTask? subTaskToDuplicate =
        taskToUpdate.subTasks.firstWhereOrNull((st) => st.id == subtaskId);
    if (subTaskToDuplicate == null || !subTaskToDuplicate.completed) return;

    final newSubtask = SubTask(
      id:
          'sub_${DateTime.now().millisecondsSinceEpoch}_${(taskToUpdate.subTasks.length + 1)}',
      name: subTaskToDuplicate.name,
      completed: false,
      currentTimeSpent: 0,
      completedDate: null,
      isCountable: subTaskToDuplicate.isCountable,
      targetCount: subTaskToDuplicate.targetCount,
      currentCount: 0,
      subSubTasks: subTaskToDuplicate.subSubTasks
          .map((sss) => SubSubTask(
                id:
                    'ssub_${DateTime.now().millisecondsSinceEpoch}_${(subTaskToDuplicate.subSubTasks.length + 1)}_${sss.name.hashCode}',
                name: sss.name,
                completed: false,
                isCountable: sss.isCountable,
                targetCount: sss.targetCount,
                currentCount: 0,
                completionTimestamp: null,
              ))
          .toList(),
    );

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
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
          subTasks: [...task.subTasks, newSubtask],
          weeklyCompletionStatus: task.weeklyCompletionStatus,
        );
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void addSubSubtask(String mainTaskId, String parentSubtaskId,
      Map<String, dynamic> subSubtaskData) {
    final newSubSubtask = SubSubTask(
      id:
          'ssub_${DateTime.now().millisecondsSinceEpoch}_${subSubtaskData['name']?.hashCode ?? 0}',
      name: subSubtaskData['name'] as String,
      isCountable: subSubtaskData['isCountable'] as bool? ?? false,
      targetCount: subSubtaskData['isCountable'] as bool? ?? false
          ? (subSubtaskData['targetCount'] as int? ?? 1)
          : 0,
      completionTimestamp: null,
    );

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
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
          subTasks: task.subTasks.map((st) {
            if (st.id == parentSubtaskId) {
              return SubTask(
                id: st.id,
                name: st.name,
                completed: st.completed,
                currentTimeSpent: st.currentTimeSpent,
                completedDate: st.completedDate,
                isCountable: st.isCountable,
                targetCount: st.targetCount,
                currentCount: st.currentCount,
                subSubTasks: [...st.subSubTasks, newSubSubtask],
              );
            }
            return st;
          }).toList(),
          weeklyCompletionStatus: task.weeklyCompletionStatus,
        );
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void updateSubSubtask(String mainTaskId, String parentSubtaskId,
      String subSubtaskId, Map<String, dynamic> updates) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
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
          subTasks: task.subTasks.map((st) {
            if (st.id == parentSubtaskId) {
              return SubTask(
                id: st.id,
                name: st.name,
                completed: st.completed,
                currentTimeSpent: st.currentTimeSpent,
                completedDate: st.completedDate,
                isCountable: st.isCountable,
                targetCount: st.targetCount,
                currentCount: st.currentCount,
                subSubTasks: st.subSubTasks.map((sss) {
                  if (sss.id == subSubtaskId) {
                    final updatedSss = SubSubTask(
                      id: sss.id,
                      name: updates['name'] as String? ?? sss.name,
                      completed: updates['completed'] as bool? ?? sss.completed,
                      isCountable:
                          updates['isCountable'] as bool? ?? sss.isCountable,
                      targetCount:
                          updates['targetCount'] as int? ?? sss.targetCount,
                      currentCount:
                          updates['currentCount'] as int? ?? sss.currentCount,
                      completionTimestamp: updates['completionTimestamp']
                              as String? ??
                          sss.completionTimestamp,
                    );
                    if (updatedSss.isCountable) {
                      updatedSss.currentCount = updatedSss.currentCount
                          .clamp(0, updatedSss.targetCount);
                    }
                    return updatedSss;
                  }
                  return sss;
                }).toList(),
              );
            }
            return st;
          }).toList(),
          weeklyCompletionStatus: task.weeklyCompletionStatus,
        );
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void completeSubSubtask(
      String mainTaskId, String parentSubtaskId, String subSubtaskId) {
    bool subSubTaskCompletedSuccessfully = false;
    SubSubTask? completedSubSubTaskInstanceForLog;

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
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
          subTasks: task.subTasks.map((st) {
            if (st.id == parentSubtaskId) {
              return SubTask(
                id: st.id,
                name: st.name,
                completed: st.completed,
                currentTimeSpent: st.currentTimeSpent,
                completedDate: st.completedDate,
                isCountable: st.isCountable,
                targetCount: st.targetCount,
                currentCount: st.currentCount,
                subSubTasks: st.subSubTasks.map((sss) {
                  if (sss.id == subSubtaskId && !sss.completed) {
                    if (sss.isCountable && sss.currentCount < sss.targetCount) {
                      subSubTaskCompletedSuccessfully = false;
                      return sss;
                    }

                    SubSubTask updatedSss = SubSubTask(
                      id: sss.id,
                      name: sss.name,
                      completed: true,
                      isCountable: sss.isCountable,
                      targetCount: sss.targetCount,
                      currentCount: sss.currentCount,
                      completionTimestamp: DateTime.now().toIso8601String(),
                    );
                    completedSubSubTaskInstanceForLog = SubSubTask(
                      id: sss.id,
                      name: sss.name,
                      completed: true,
                      isCountable: sss.isCountable,
                      targetCount: sss.targetCount,
                      currentCount: sss.currentCount,
                      completionTimestamp: updatedSss.completionTimestamp,
                    );
                    subSubTaskCompletedSuccessfully = true;
                    return updatedSss;
                  }
                  return sss;
                }).toList(),
              );
            }
            return st;
          }).toList(),
          weeklyCompletionStatus: task.weeklyCompletionStatus,
        );
      }
      return task;
    }).toList();

    if (subSubTaskCompletedSuccessfully &&
        completedSubSubTaskInstanceForLog != null) {
      _provider.setProviderState(mainTasks: newMainTasks);
      logToDailySummary('subSubtaskCompleted', {
        'mainTaskId': mainTaskId,
        'parentSubtaskId': parentSubtaskId,
        'subSubtaskId': subSubtaskId,
        'name': completedSubSubTaskInstanceForLog!.name,
        'isCountable': completedSubSubTaskInstanceForLog!.isCountable,
        'currentCount': completedSubSubTaskInstanceForLog!.currentCount,
        'targetCount': completedSubSubTaskInstanceForLog!.targetCount,
        'completionTimestamp':
            completedSubSubTaskInstanceForLog!.completionTimestamp,
        'parentSubtaskName': _provider.mainTasks
                .firstWhereOrNull((m) => m.id == mainTaskId)
                ?.subTasks
                .firstWhereOrNull((s) => s.id == parentSubtaskId)
                ?.name ??
            'N/A',
        'mainTaskName': _provider.mainTasks
                .firstWhereOrNull((m) => m.id == mainTaskId)
                ?.name ??
            'N/A'
      });
    }
  }

  void deleteSubSubtask(
      String mainTaskId, String parentSubtaskId, String subSubtaskId) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
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
          subTasks: task.subTasks.map((st) {
            if (st.id == parentSubtaskId) {
              return SubTask(
                id: st.id,
                name: st.name,
                completed: st.completed,
                currentTimeSpent: st.currentTimeSpent,
                completedDate: st.completedDate,
                isCountable: st.isCountable,
                targetCount: st.targetCount,
                currentCount: st.currentCount,
                subSubTasks: st.subSubTasks
                    .where((sss) => sss.id != subSubtaskId)
                    .toList(),
              );
            }
            return st;
          }).toList(),
          weeklyCompletionStatus: task.weeklyCompletionStatus,
        );
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }
}