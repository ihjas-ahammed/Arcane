import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/utils/helpers.dart';
import 'package:missions/src/utils/time_validation_helper.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/utils/id_generator.dart';
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
          newNodes.add(_deepCloneCheckpoint(node, suffix: "(Copy)"));
        } else if (action == 'add_child') {
          final data = payload as Map<String, dynamic>;
          final newChild = SubSubTask(
            id: IdGenerator.generateCheckpointId(),
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

  SubSubTask _deepCloneCheckpoint(SubSubTask original, {String? suffix}) {
    return SubSubTask(
      id: IdGenerator.generateCheckpointId(),
      name: suffix != null ? "${original.name} $suffix" : original.name,
      completed: false,
      isCountable: original.isCountable,
      targetCount: original.targetCount,
      currentCount: 0,
      type: original.type,
      why: original.why,
      what: original.what,
      substeps: original.substeps.map((s) => _deepCloneCheckpoint(s)).toList(),
    );
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
    // A Phoenix that's no longer in the plan can't remain anointed.
    final phx = newHistory[dateStr]['phoenixId'];
    if (phx is String && !plan.contains(phx)) {
      newHistory[dateStr].remove('phoenixId');
    }
    _provider.setProviderState(completedByDay: newHistory);
  }

  // --- Phoenix (daily most-important task) ---
  String? getPhoenixId(String dateStr) {
    final id = _provider.completedByDay[dateStr]?['phoenixId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  void setPhoenix(String dateStr, String? compoundId) {
    final newHistory = Map<String, dynamic>.from(_provider.completedByDay);
    if (!newHistory.containsKey(dateStr)) {
      newHistory[dateStr] = {
        'taskTimes': <String, int>{},
        'subtasksCompleted': <Map<String, dynamic>>[],
        'checkpointsCompleted': <Map<String, dynamic>>[],
      };
    }
    if (compoundId == null || compoundId.isEmpty) {
      newHistory[dateStr].remove('phoenixId');
    } else {
      newHistory[dateStr]['phoenixId'] = compoundId;
    }
    _provider.setProviderState(completedByDay: newHistory);
  }

  void setAgentPhoenix(String mainTaskId, String? subTaskId) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          phoenixSubTaskId: subTaskId,
        );
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  /// Clears today's Phoenix if its id is [prefix] or a child of it (completing a
  /// subtask retires the subtask itself and any of its checkpoints).
  void _clearPhoenixIfPrefix(String prefix) {
    final today = getTodayDateString();
    final current = getPhoenixId(today);
    if (current != null &&
        (current == prefix || current.startsWith('$prefix|'))) {
      setPhoenix(today, null);
    }
  }

  void removeFromDayPlan(String compoundId) {
    final today = getTodayDateString();
    final currentPlan = getDayPlan(today);
    if (currentPlan.contains(compoundId)) {
      final newPlan = List<String>.from(currentPlan)..remove(compoundId);
      updateDayPlan(today, newPlan);
    }
  }

  Map<String, int> getDayPlanEstimates(String dateStr) {
    final dayData = _provider.completedByDay[dateStr];
    if (dayData == null) return {};
    final raw = dayData['dailyPlanEstimates'];
    if (raw is! Map) return {};
    final out = <String, int>{};
    raw.forEach((k, v) {
      if (k is String && v is num) out[k] = v.toInt();
    });
    return out;
  }

  void setDayPlanEstimate(String dateStr, String compoundId, int minutes) {
    final newHistory = Map<String, dynamic>.from(_provider.completedByDay);
    if (!newHistory.containsKey(dateStr)) {
      newHistory[dateStr] = {
        'taskTimes': <String, int>{},
        'subtasksCompleted': <Map<String, dynamic>>[],
        'checkpointsCompleted': <Map<String, dynamic>>[],
      };
    }
    final current = Map<String, dynamic>.from(
      (newHistory[dateStr]['dailyPlanEstimates'] as Map?) ?? {},
    );
    if (minutes <= 0) {
      current.remove(compoundId);
    } else {
      current[compoundId] = minutes;
    }
    newHistory[dateStr]['dailyPlanEstimates'] = current;
    _provider.setProviderState(completedByDay: newHistory);
  }

  /// Estimated minutes for a single plan item: an explicit estimate if set,
  /// otherwise the subtask's median session time, otherwise a sane default.
  /// Mirrors the Today Planner's per-row logic so the hero/widget agree.
  int estimateForPlanItem(String dateStr, String compoundId) {
    final stored = getDayPlanEstimates(dateStr)[compoundId];
    if (stored != null) return stored;
    final parts = compoundId.split('|');
    if (parts.length < 2) return TaskCalculations.defaultSubtaskMinutes;
    final task = _provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    if (sub == null) return TaskCalculations.defaultSubtaskMinutes;
    final median = TaskCalculations.medianSessionMinutes(sub);
    if (median != null) return median;
    return parts.length == 3
        ? TaskCalculations.defaultCheckpointMinutes
        : TaskCalculations.defaultSubtaskMinutes;
  }

  /// Total planned minutes for a day across every queued item.
  int plannedMinutesForDay(String dateStr) {
    return getDayPlan(dateStr)
        .fold<int>(0, (sum, id) => sum + estimateForPlanItem(dateStr, id));
  }

  /// True if there are remaining (uncompleted, still-valid) items in [fromDate]'s plan.
  bool hasUnfinishedPlan(String fromDate) {
    final plan = getDayPlan(fromDate);
    if (plan.isEmpty) return false;
    for (final id in plan) {
      if (_isPlanItemActionable(id)) return true;
    }
    return false;
  }

  bool _isPlanItemActionable(String compoundId) {
    final parts = compoundId.split('|');
    if (parts.length < 2) return false;
    final task = _provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
    if (task == null) return false;
    final sub = task.subTasks.firstWhereOrNull((s) => s.id == parts[1] && !s.isDeleted);
    if (sub == null) return false;
    if (parts.length == 3) {
      final cp = sub.subSubTasks.firstWhereOrNull((c) => c.id == parts[2]);
      return cp != null && !cp.completed;
    }
    return !sub.completed;
  }

  /// Moves all actionable unfinished items from [fromDate] into [toDate]'s plan
  /// (appended, de-duplicated, preserving order). Estimates ride along.
  /// Marks [toDate] as carryover-handled so the banner doesn't reappear.
  void carryOverUnfinished(String fromDate, String toDate) {
    final src = getDayPlan(fromDate);
    final actionable = src.where(_isPlanItemActionable).toList();
    final dst = getDayPlan(toDate);
    final merged = [...dst];
    for (final id in actionable) {
      if (!merged.contains(id)) merged.add(id);
    }

    final srcEstimates = getDayPlanEstimates(fromDate);
    final newHistory = Map<String, dynamic>.from(_provider.completedByDay);
    if (!newHistory.containsKey(toDate)) {
      newHistory[toDate] = {
        'taskTimes': <String, int>{},
        'subtasksCompleted': <Map<String, dynamic>>[],
        'checkpointsCompleted': <Map<String, dynamic>>[],
      };
    }
    newHistory[toDate]['dailyPlan'] = merged;
    final mergedEstimates = Map<String, dynamic>.from(
      (newHistory[toDate]['dailyPlanEstimates'] as Map?) ?? {},
    );
    for (final id in actionable) {
      if (srcEstimates.containsKey(id) && !mergedEstimates.containsKey(id)) {
        mergedEstimates[id] = srcEstimates[id];
      }
    }
    newHistory[toDate]['dailyPlanEstimates'] = mergedEstimates;

    // Carry the Phoenix forward if it survived and the new day has none.
    final srcPhoenix = getPhoenixId(fromDate);
    final dstHasPhoenix = newHistory[toDate]['phoenixId'] is String;
    if (srcPhoenix != null &&
        !dstHasPhoenix &&
        _isPlanItemActionable(srcPhoenix) &&
        merged.contains(srcPhoenix)) {
      newHistory[toDate]['phoenixId'] = srcPhoenix;
    }

    newHistory[toDate]['carryoverHandled'] = true;
    _provider.setProviderState(completedByDay: newHistory);
  }

  /// Marks [dateStr] as carryover-handled without moving anything.
  void dismissCarryover(String dateStr) {
    final newHistory = Map<String, dynamic>.from(_provider.completedByDay);
    if (!newHistory.containsKey(dateStr)) {
      newHistory[dateStr] = {
        'taskTimes': <String, int>{},
        'subtasksCompleted': <Map<String, dynamic>>[],
        'checkpointsCompleted': <Map<String, dynamic>>[],
      };
    }
    newHistory[dateStr]['carryoverHandled'] = true;
    _provider.setProviderState(completedByDay: newHistory);
  }

  bool wasCarryoverHandled(String dateStr) {
    final dayData = _provider.completedByDay[dateStr];
    if (dayData == null) return false;
    return dayData['carryoverHandled'] == true;
  }

  // --- SubSubTask Actions ---

  // --- Helper to sync template sets with active checkpoints ---
  SubTask _syncTemplateSetsWithActiveCheckpoints(SubTask st) {
    if (!st.isRecurring) return st;
    final currentSets = List<SubTaskTemplateSet>.from(st.templateSets);
    if (currentSets.isEmpty) {
      currentSets.add(SubTaskTemplateSet(
        id: 'default',
        name: 'Default',
        subSubTasks: List.from(st.subSubTasks),
      ));
    }
    final activeId = st.activeTemplateSetId ?? 'default';
    final activeIndex = currentSets.indexWhere((ts) => ts.id == activeId);
    if (activeIndex != -1) {
      currentSets[activeIndex] = currentSets[activeIndex].copyWith(
        subSubTasks: List.from(st.subSubTasks),
      );
    } else if (activeId == 'default' && currentSets.isNotEmpty) {
      currentSets[0] = currentSets[0].copyWith(
        subSubTasks: List.from(st.subSubTasks),
      );
    }
    return st.copyWith(templateSets: currentSets);
  }

  // --- SubSubTask Actions ---

  String addSubSubtask(String mainTaskId, String parentSubtaskId, Map<String, dynamic> subSubtaskData, {String? parentCheckpointId}) {
    if (parentCheckpointId != null) {
      final newMainTasks = _provider.mainTasks.map((task) {
        if (task.id == mainTaskId) {
          return task.copyWith(subTasks: task.subTasks.map((st) {
            if (st.id == parentSubtaskId) {
              return _syncTemplateSetsWithActiveCheckpoints(st.copyWith(
                subSubTasks: _recursiveNodeOperation(st.subSubTasks, parentCheckpointId, 'add_child', subSubtaskData),
                updatedAt: DateTime.now(),
              ));
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
        id: IdGenerator.generateCheckpointId(),
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
              return _syncTemplateSetsWithActiveCheckpoints(st.copyWith(
                subSubTasks: [...st.subSubTasks, newSubSubtask],
                updatedAt: DateTime.now(),
              ));
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
            return _syncTemplateSetsWithActiveCheckpoints(st.copyWith(
              subSubTasks: _recursiveNodeOperation(st.subSubTasks, subSubtaskId, 'update', updates),
              updatedAt: DateTime.now(),
            ));
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
            return _syncTemplateSetsWithActiveCheckpoints(st.copyWith(
              subSubTasks: _recursiveNodeOperation(st.subSubTasks, subSubtaskId, 'delete', null),
              updatedAt: DateTime.now(),
            ));
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
            return _syncTemplateSetsWithActiveCheckpoints(st.copyWith(
              subSubTasks: _recursiveNodeOperation(st.subSubTasks, subSubtaskId, 'duplicate', null),
              updatedAt: DateTime.now(),
            ));
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
    _clearPhoenixIfPrefix('$mainTaskId|$parentSubtaskId|$subSubtaskId');
    logToDailySummary('subSubtaskCompleted', {'parentTaskId': mainTaskId, 'parentSubTaskId': parentSubtaskId, 'subSubTaskId': subSubtaskId});
  }

  void uncompleteSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, {bool fromSync = false}) {
    final updates = {'completed': false, 'completionTimestamp': null};
    updateSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId, updates);
  }

  void moveCheckpointRelative(String mainTaskId, String subTaskId, String draggedId, String targetId, String position) {
    if (draggedId == targetId) return;

    final taskIndex = _provider.mainTasks.indexWhere((t) => t.id == mainTaskId);
    if (taskIndex == -1) return;
    final task = _provider.mainTasks[taskIndex];
    
    final subIndex = task.subTasks.indexWhere((s) => s.id == subTaskId);
    if (subIndex == -1) return;
    final sub = task.subTasks[subIndex];

    List<SubSubTask> clonedCheckpoints = sub.subSubTasks.map((e) => SubSubTask.fromJson(e.toJson())).toList();

    bool isDescendant(List<SubSubTask> list) {
      for (var node in list) {
         if (node.id == targetId) return true;
         if (isDescendant(node.substeps)) return true;
      }
      return false;
    }
    
    SubSubTask? draggedNodeRaw;
    void findDragged(List<SubSubTask> list) {
      for (var node in list) {
        if (node.id == draggedId) draggedNodeRaw = node;
        findDragged(node.substeps);
      }
    }
    findDragged(clonedCheckpoints);
    
    if (draggedNodeRaw != null && (position == 'inside' || position == 'before' || position == 'after') && isDescendant(draggedNodeRaw!.substeps)) {
      return; // Cannot drop a parent into or adjacent to its own child
    }

    SubSubTask? detachedNode;
    bool extractNode(List<SubSubTask> list) {
       for (int i = 0; i < list.length; i++) {
          if (list[i].id == draggedId) {
             detachedNode = list.removeAt(i);
             return true;
          }
          if (extractNode(list[i].substeps)) return true;
       }
       return false;
    }
    extractNode(clonedCheckpoints);

    if (detachedNode == null) return;

    bool insertNode(List<SubSubTask> list) {
       for (int i = 0; i < list.length; i++) {
          if (list[i].id == targetId) {
             if (position == 'inside') {
                list[i].substeps.add(detachedNode!);
             } else if (position == 'before') {
                list.insert(i, detachedNode!);
             } else if (position == 'after') {
                list.insert(i + 1, detachedNode!);
             }
             return true;
          }
          if (insertNode(list[i].substeps)) return true;
       }
       return false;
    }
    insertNode(clonedCheckpoints);

    final updatedSubTask = _syncTemplateSetsWithActiveCheckpoints(sub.copyWith(subSubTasks: clonedCheckpoints));
    final updatedTask = task.copyWith(subTasks: task.subTasks.map((s) => s.id == subTaskId ? updatedSubTask : s).toList());
    final newMainTasks = List<MainTask>.from(_provider.mainTasks);
    newMainTasks[taskIndex] = updatedTask;
    _provider.setProviderState(mainTasks: newMainTasks);
  }
  
  void reorderSubSubtasksBySubset(String mainTaskId, String parentSubtaskId, List<String> subsetIds, {String? parentCheckpointId}) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(subTasks: task.subTasks.map((st) {
          if (st.id == parentSubtaskId) {
            if (parentCheckpointId != null) {
              return _syncTemplateSetsWithActiveCheckpoints(st.copyWith(subSubTasks: _reorderNodesSubset(st.subSubTasks, parentCheckpointId, subsetIds)));
            } else {
              final subsetItems = subsetIds.map((id) => st.subSubTasks.firstWhere((sst) => sst.id == id)).toList();
              final otherItems = st.subSubTasks.where((sst) => !subsetIds.contains(sst.id)).toList();
              int firstIndex = st.subSubTasks.indexWhere((sst) => subsetIds.contains(sst.id));
              if (firstIndex == -1) firstIndex = 0;
              final List<SubSubTask> updated = [];
              updated.addAll(otherItems.sublist(0, firstIndex));
              updated.addAll(subsetItems);
              updated.addAll(otherItems.sublist(firstIndex));
              return _syncTemplateSetsWithActiveCheckpoints(st.copyWith(subSubTasks: updated));
            }
          }
          return st;
        }).toList());
      }
      return task;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  // --- SubTask Template Set Actions ---

  void addTemplateSet(String mainTaskId, String subTaskId, String name) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          subTasks: task.subTasks.map((st) {
            if (st.id == subTaskId) {
              final currentSets = List<SubTaskTemplateSet>.from(st.templateSets);
              if (currentSets.isEmpty) {
                currentSets.add(SubTaskTemplateSet(
                  id: 'default',
                  name: 'Default',
                  subSubTasks: List.from(st.subSubTasks),
                ));
              }
              final newSetId = IdGenerator.generateCheckpointId();
              final newSet = SubTaskTemplateSet(
                id: newSetId,
                name: name,
                subSubTasks: [],
              );
              currentSets.add(newSet);
              return st.copyWith(
                templateSets: currentSets,
                activeTemplateSetId: newSetId,
                subSubTasks: [],
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
  }

  void selectTemplateSet(String mainTaskId, String subTaskId, String setId) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          subTasks: task.subTasks.map((st) {
            if (st.id == subTaskId) {
              final currentSets = List<SubTaskTemplateSet>.from(st.templateSets);
              if (currentSets.isEmpty) {
                currentSets.add(SubTaskTemplateSet(
                  id: 'default',
                  name: 'Default',
                  subSubTasks: List.from(st.subSubTasks),
                ));
              }
              final prevActiveId = st.activeTemplateSetId ?? 'default';
              final prevIndex = currentSets.indexWhere((ts) => ts.id == prevActiveId);
              if (prevIndex != -1) {
                currentSets[prevIndex] = currentSets[prevIndex].copyWith(
                  subSubTasks: List.from(st.subSubTasks),
                );
              } else if (prevActiveId == 'default' && currentSets.isNotEmpty) {
                currentSets[0] = currentSets[0].copyWith(
                  subSubTasks: List.from(st.subSubTasks),
                );
              }

              final targetSet = currentSets.firstWhereOrNull((ts) => ts.id == setId);
              if (targetSet == null) return st;

              return st.copyWith(
                templateSets: currentSets,
                activeTemplateSetId: setId,
                subSubTasks: List.from(targetSet.subSubTasks),
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
  }

  void deleteTemplateSet(String mainTaskId, String subTaskId, String setId) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          subTasks: task.subTasks.map((st) {
            if (st.id == subTaskId) {
              final currentSets = List<SubTaskTemplateSet>.from(st.templateSets);
              if (currentSets.isEmpty) {
                currentSets.add(SubTaskTemplateSet(
                  id: 'default',
                  name: 'Default',
                  subSubTasks: List.from(st.subSubTasks),
                ));
              }
              if (currentSets.length <= 1) return st;
              currentSets.removeWhere((ts) => ts.id == setId);
              String newActiveId = st.activeTemplateSetId ?? 'default';
              List<SubSubTask> newActiveSubsteps = st.subSubTasks;
              if (newActiveId == setId) {
                final fallbackSet = currentSets.first;
                newActiveId = fallbackSet.id;
                newActiveSubsteps = List.from(fallbackSet.subSubTasks);
              }
              return st.copyWith(
                templateSets: currentSets,
                activeTemplateSetId: newActiveId,
                subSubTasks: newActiveSubsteps,
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
  }

  void renameTemplateSet(String mainTaskId, String subTaskId, String setId, String newName) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        return task.copyWith(
          subTasks: task.subTasks.map((st) {
            if (st.id == subTaskId) {
              final currentSets = st.templateSets.map((ts) {
                if (ts.id == setId) {
                  return ts.copyWith(name: newName);
                }
                return ts;
              }).toList();
              return st.copyWith(
                templateSets: currentSets,
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
      id: IdGenerator.generateSubTaskId(),
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
    if (updates.containsKey('progressMode')) subtaskToUpdate.progressMode = updates['progressMode'] as String;
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
        final nextPhx = task.phoenixSubTaskId == subtaskId ? null : task.phoenixSubTaskId;
        return task.copyWith(
          phoenixSubTaskId: nextPhx,
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

    _clearPhoenixIfPrefix('$mainTaskId|$subtaskId');

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
  }

  // FIX: Perform soft deletion to preserve session logs for schedule history
  void deleteSubtask(String mainTaskId, String subtaskId) {
    final newMainTasks = _provider.mainTasks.map((task) {
      if (task.id == mainTaskId) {
        final nextPhx = task.phoenixSubTaskId == subtaskId ? null : task.phoenixSubTaskId;
        return task.copyWith(
          phoenixSubTaskId: nextPhx,
          subTasks: task.subTasks.map((st) => st.id == subtaskId ? st.copyWith(isDeleted: true) : st).toList(),
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

    final newSubtask = SubTask(
      id: IdGenerator.generateSubTaskId(),
      name: "${subTaskToDuplicate.name} (Copy)",
      description: subTaskToDuplicate.description,
      completed: false,
      currentTimeSpent: 0,
      isCountable: subTaskToDuplicate.isCountable,
      targetCount: subTaskToDuplicate.targetCount,
      currentCount: 0,
      why: subTaskToDuplicate.why,
      what: subTaskToDuplicate.what,
      resources: subTaskToDuplicate.resources,
      isRecurring: subTaskToDuplicate.isRecurring,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
      subSubTasks: subTaskToDuplicate.subSubTasks.map((sss) => _deepCloneCheckpoint(sss)).toList(),
      sessions: [],
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

    final session = TaskSession(id: IdGenerator.generateSessionId(), startTime: start, endTime: end);
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
    // Defer recalibration — currentTimeSpent is already correct above;
    // history rebuild runs after UI paints to avoid blocking the frame
    Future.microtask(() => recalibrateTimeLogs(silent: true));
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

  // FIX: Soft delete protocol/MainTask
  void deleteMainTask(String id) {
    final newTasks = _provider.mainTasks.map((t) => t.id == id ? t.copyWith(isDeleted: true) : t).toList();
    _provider.setProviderState(mainTasks: newTasks);
    if (_provider.selectedTaskId == id) {
      final firstValid = newTasks.firstWhereOrNull((t) => !t.isDeleted);
      _provider.setSelectedTaskId(firstValid?.id);
    }
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

  void saveProgressDataPoint(String mainTaskId, String subTaskId, double progress, int spentSeconds) {
    final point = ProgressDataPoint(
      timestamp: DateTime.now(),
      progress: progress.clamp(0.0, 1.0),
      spentSeconds: spentSeconds,
    );

    final newMainTasks = _provider.mainTasks.map((t) {
      if (t.id == mainTaskId) {
        return t.copyWith(subTasks: t.subTasks.map((s) {
          if (s.id == subTaskId) {
            final updated = [...s.progressDataPoints, point]
              ..sort((a, b) => a.spentSeconds.compareTo(b.spentSeconds));
            return s.copyWith(progressDataPoints: updated);
          }
          return s;
        }).toList());
      }
      return t;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void deleteProgressDataPoint(String mainTaskId, String subTaskId, int index) {
    final newMainTasks = _provider.mainTasks.map((t) {
      if (t.id == mainTaskId) {
        return t.copyWith(subTasks: t.subTasks.map((s) {
          if (s.id == subTaskId) {
            final updated = List<ProgressDataPoint>.from(s.progressDataPoints);
            if (index >= 0 && index < updated.length) updated.removeAt(index);
            return s.copyWith(progressDataPoints: updated);
          }
          return s;
        }).toList());
      }
      return t;
    }).toList();
    _provider.setProviderState(mainTasks: newMainTasks);
  }

  void addMainTask({required String name, required String description, required String theme, required String colorHex}) {
    final newTask = MainTask(
      id: IdGenerator.generateMainTaskId(),
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