// lib/src/providers/actions/task_actions.dart
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:arcane/src/models/game_models.dart';
import 'package:arcane/src/utils/helpers.dart';
import 'package:collection/collection.dart';

class TaskActions {
  final GameProvider _provider;

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
          dailyTimeSpent: task.dailyTimeSpent,
          lastWorkedDate: task.lastWorkedDate,
          subTasks: task.subTasks,
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
          'checkpointsCompleted': <Map<String, dynamic>>[], // Ensure this exists
          'emotionLogs': <Map<String, dynamic>>[]
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
      // Ensure data includes 'completionTimestamp'
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
      isCountable: subtaskData['isCountable'] as bool? ?? false,
      targetCount: subtaskData['isCountable'] as bool? ?? false
          ? (subtaskData['targetCount'] as int? ?? 1)
          : 0,
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
        return MainTask(
          id: task.id,
          name: task.name,
          description: task.description,
          theme: task.theme,
          colorHex: task.colorHex,
          streak: task.streak,
          dailyTimeSpent: task.dailyTimeSpent,
          lastWorkedDate: task.lastWorkedDate,
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
    if (updates.containsKey('isCountable')) {
      subtaskToUpdate.isCountable = updates['isCountable'] as bool;
    }
    if (updates.containsKey('targetCount')) {
      subtaskToUpdate.targetCount = updates['targetCount'] as int;
    }
    if (updates.containsKey('currentCount')) {
      subtaskToUpdate.currentCount = (updates['currentCount'] as int)
          .clamp(0, subtaskToUpdate.targetCount);
    }
    if (updates.containsKey('currentTimeSpent')) {
      subtaskToUpdate.currentTimeSpent = updates['currentTimeSpent'] as int;
    }

    int timeDifference = 0;
    if (updates.containsKey('currentTimeSpent')) {
      timeDifference = subtaskToUpdate.currentTimeSpent - oldSubtaskTime;
    }

    final Map<String, dynamic> stateUpdatesForSetAndPersist = {};

    if (timeDifference != 0) {
      taskToUpdate.dailyTimeSpent =
          (taskToUpdate.dailyTimeSpent) + timeDifference;
      taskToUpdate.lastWorkedDate = getTodayDateString();
      logToDailySummary(
          'taskTime', {'taskId': mainTaskId, 'time': timeDifference});
      if (timeDifference > 0) {
        stateUpdatesForSetAndPersist['playerEnergy'] = (_provider.playerEnergy +
                timeDifference * energyRegenPerMinuteTasked)
            .clamp(0, _provider.calculatedMaxEnergy);
      }
    }

    final int oldDailyTotalBeforeThisChange =
        taskToUpdate.dailyTimeSpent - timeDifference;
    if (oldDailyTotalBeforeThisChange < dailyTaskGoalMinutes &&
        taskToUpdate.dailyTimeSpent >= dailyTaskGoalMinutes) {
      final double luckBonus =
          1 + (_provider.playerGameStats['luck']!.value / 100);
      final double xpBonusFromArtifact =
          _provider.playerGameStats['bonusXPMod']?.value ?? 0.0;
      final double totalXPMultiplier = luckBonus * (1 + xpBonusFromArtifact);

      stateUpdatesForSetAndPersist['coins'] =
          _provider.coins + (streakBonusCoins * luckBonus).floor();
      stateUpdatesForSetAndPersist['xp'] =
          _provider.xp + (streakBonusXp * totalXPMultiplier).floor();
      taskToUpdate.streak = taskToUpdate.streak + 1;
    }

    final newMainTasks = _provider.mainTasks
        .map((t) => t.id == mainTaskId ? taskToUpdate : t)
        .toList();
    stateUpdatesForSetAndPersist['mainTasks'] = newMainTasks;
    _provider.setProviderState(
      coins: stateUpdatesForSetAndPersist['coins'] as double?,
      xp: stateUpdatesForSetAndPersist['xp'] as double?,
      playerEnergy: stateUpdatesForSetAndPersist['playerEnergy'] as double?,
      mainTasks: newMainTasks,
    );
  }

  bool completeSubtask(String mainTaskId, String subtaskId) {
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
      if (subTask.subSubTasks.isNotEmpty && !allSubSubTasksDone) {
        return false;
      }
      if (subTask.subSubTasks.isEmpty && subTask.currentTimeSpent <= 0) {
        return false;
      }
    }

    ActiveTimerInfo? timerForSubtask = _provider.activeTimers[subtaskId];
    SubTask updatedSubTaskForRewards = SubTask(
        id: subTask.id,
        name: subTask.name,
        currentTimeSpent: subTask.currentTimeSpent,
        isCountable: subTask.isCountable,
        targetCount: subTask.targetCount,
        currentCount: subTask.currentCount,
        subSubTasks: subTask.subSubTasks);

    if (timerForSubtask != null) {
      double totalSecondsToLog = timerForSubtask.accumulatedDisplayTime;
      if (timerForSubtask.isRunning) {
        totalSecondsToLog += (DateTime.now()
                .difference(timerForSubtask.startTime)
                .inMilliseconds) /
            1000;
      }
      final int elapsedMinutes = (totalSecondsToLog / 60).round();

      if (elapsedMinutes > 0) {
        updateSubtask(mainTaskId, subtaskId,
            {'currentTimeSpent': subTask.currentTimeSpent + elapsedMinutes});
        final MainTask? refetchedMainTask =
            _provider.mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
        if (refetchedMainTask != null) {
          updatedSubTaskForRewards = refetchedMainTask.subTasks
                  .firstWhereOrNull((st) => st.id == subtaskId) ??
              subTask;
        }
      }
      final newActiveTimers =
          Map<String, ActiveTimerInfo>.from(_provider.activeTimers);
      newActiveTimers.remove(subtaskId);
      _provider.setProviderState(
          activeTimers: newActiveTimers, doPersist: false);
    }

    final double luckBonus =
        1 + (_provider.playerGameStats['luck']!.value / 100);
    final double xpBonusFromArtifact =
        _provider.playerGameStats['bonusXPMod']?.value ?? 0.0;
    final double totalXPMultiplier = luckBonus * (1 + xpBonusFromArtifact);

    double proportionalXp = 0;
    double proportionalCoins = 0;

    if (updatedSubTaskForRewards.isCountable) {
      proportionalXp =
          updatedSubTaskForRewards.targetCount * xpPerCountUnitSubtask;
      proportionalCoins =
          updatedSubTaskForRewards.targetCount * coinsPerCountUnitSubtask;
    } else {
      proportionalXp =
          updatedSubTaskForRewards.currentTimeSpent * xpPerMinuteSubtask;
      proportionalCoins =
          updatedSubTaskForRewards.currentTimeSpent * coinsPerMinuteSubtask;
    }

    final double baseCompletionXp =
        subtaskCompletionXpBase + _provider.playerLevel + mainTask.streak;
    final double baseCompletionCoins = subtaskCompletionCoinBase +
        (_provider.playerLevel * 0.5) +
        (mainTask.streak * 0.2);

    final int finalXpReward =
        ((baseCompletionXp + proportionalXp) * totalXPMultiplier).floor();
    final int finalCoinReward =
        ((baseCompletionCoins + proportionalCoins) * luckBonus).floor();

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return MainTask(
          id: task.id,
          name: task.name,
          description: task.description,
          theme: task.theme,
          colorHex: task.colorHex,
          streak: task.streak,
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
        );
      }
      return task;
    }).toList();

    _provider.setProviderState(
      mainTasks: newMainTasks,
      xp: _provider.xp + finalXpReward,
      coins: _provider.coins + finalCoinReward,
    );

    logToDailySummary('subtaskCompleted', {
      'parentTaskId': mainTask.id,
      'name': updatedSubTaskForRewards.name,
      'timeLogged': updatedSubTaskForRewards.currentTimeSpent,
      'isCountable': updatedSubTaskForRewards.isCountable,
      'currentCount': updatedSubTaskForRewards.currentCount,
      'targetCount': updatedSubTaskForRewards.targetCount
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
          dailyTimeSpent: task.dailyTimeSpent,
          lastWorkedDate: task.lastWorkedDate,
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
    MainTask? taskToUpdate =
        _provider.mainTasks.firstWhereOrNull((task) => task.id == mainTaskId);
    if (taskToUpdate == null) return;

    SubTask? subTaskToDuplicate =
        taskToUpdate.subTasks.firstWhereOrNull((st) => st.id == subtaskId);
    if (subTaskToDuplicate == null || !subTaskToDuplicate.completed) return;

    final newSubtask = SubTask(
      id: 'sub_${DateTime.now().millisecondsSinceEpoch}_${(taskToUpdate.subTasks.length + 1)}',
      name: subTaskToDuplicate.name,
      completed: false,
      currentTimeSpent: 0,
      completedDate: null,
      isCountable: subTaskToDuplicate.isCountable,
      targetCount: subTaskToDuplicate.targetCount,
      currentCount: 0,
      subSubTasks: subTaskToDuplicate.subSubTasks
          .map((sss) => SubSubTask(
                id: 'ssub_${DateTime.now().millisecondsSinceEpoch}_${(subTaskToDuplicate.subSubTasks.length + 1)}_${sss.name.hashCode}',
                name: sss.name,
                completed: false,
                isCountable: sss.isCountable,
                targetCount: sss.targetCount,
                currentCount: 0,
                completionTimestamp: null, // Reset timestamp
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
          dailyTimeSpent: task.dailyTimeSpent,
          lastWorkedDate: task.lastWorkedDate,
          subTasks: [...task.subTasks, newSubtask],
        );
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void addSubSubtask(String mainTaskId, String parentSubtaskId,
      Map<String, dynamic> subSubtaskData) {
    final newSubSubtask = SubSubTask(
      id: 'ssub_${DateTime.now().millisecondsSinceEpoch}_${subSubtaskData['name']?.hashCode ?? 0}',
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
                      completionTimestamp: updates['completionTimestamp'] as String? ?? sss.completionTimestamp,
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
        );
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void completeSubSubtask(
      String mainTaskId, String parentSubtaskId, String subSubtaskId) {
    double xpReward = 0;
    double coinReward = 0;
    bool subSubTaskCompletedSuccessfully = false;
    SubSubTask? completedSubSubTaskInstanceForLog; // Used specifically for logging

    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return MainTask(
          // ... (copy other MainTask fields) ...
          id: task.id,
          name: task.name,
          description: task.description,
          theme: task.theme,
          colorHex: task.colorHex,
          streak: task.streak,
          dailyTimeSpent: task.dailyTimeSpent,
          lastWorkedDate: task.lastWorkedDate,
          subTasks: task.subTasks.map((st) {
            if (st.id == parentSubtaskId) {
              return SubTask(
                // ... (copy other SubTask fields) ...
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
                    // ... (reward calculation as before) ...
                    final double luckBonus = 1 + (_provider.playerGameStats['luck']!.value / 100);
                    final double xpBonusFromArtifact = _provider.playerGameStats['bonusXPMod']?.value ?? 0.0;
                    final double totalXPMultiplier = luckBonus * (1 + xpBonusFromArtifact);
                    double proportionalXp = 0;
                    double proportionalCoins = 0;
                    if (sss.isCountable) {
                      proportionalXp = sss.targetCount * xpPerCountUnitSubSubtask;
                      proportionalCoins = sss.targetCount * coinsPerCountUnitSubSubtask;
                    }
                    xpReward = ((subSubtaskCompletionXpBase + proportionalXp) * totalXPMultiplier).floorToDouble();
                    coinReward = ((subSubtaskCompletionCoinBase + proportionalCoins) * luckBonus).floorToDouble();

                    // This is the instance that gets saved in the task structure
                    SubSubTask updatedSss = SubSubTask(
                        id: sss.id,
                        name: sss.name,
                        completed: true,
                        isCountable: sss.isCountable,
                        targetCount: sss.targetCount,
                        currentCount: sss.currentCount,
                        completionTimestamp: DateTime.now().toIso8601String(), // SET TIMESTAMP
                    );
                    // This is for logging, capture the state at completion
                    completedSubSubTaskInstanceForLog = SubSubTask(
                        id: sss.id,
                        name: sss.name,
                        completed: true,
                        isCountable: sss.isCountable,
                        targetCount: sss.targetCount,
                        currentCount: sss.currentCount,
                        completionTimestamp: updatedSss.completionTimestamp, // Use the same timestamp
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
        );
      }
      return task;
    }).toList();

    if (subSubTaskCompletedSuccessfully &&
        completedSubSubTaskInstanceForLog != null) {
      _provider.setProviderState(
        mainTasks: newMainTasks,
        xp: _provider.xp + xpReward,
        coins: _provider.coins + coinReward,
      );
      logToDailySummary('subSubtaskCompleted', {
        'mainTaskId': mainTaskId,
        'parentSubtaskId': parentSubtaskId,
        'subSubtaskId': subSubtaskId,
        'name': completedSubSubTaskInstanceForLog!.name,
        'isCountable': completedSubSubTaskInstanceForLog!.isCountable,
        'currentCount': completedSubSubTaskInstanceForLog!.currentCount,
        'targetCount': completedSubSubTaskInstanceForLog!.targetCount,
        'completionTimestamp': completedSubSubTaskInstanceForLog!.completionTimestamp, // Pass to log
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
        );
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }
}