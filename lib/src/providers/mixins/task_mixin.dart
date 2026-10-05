import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/services/notification_service.dart';
import 'package:missions/src/utils/constants.dart';
import 'package:missions/src/utils/helpers.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/providers/mixins/sync_mixin.dart';
import 'package:collection/collection.dart';
import 'package:missions/src/utils/global_toast.dart';

/// Manages Tasks, Projects, History Logic, and Goals
mixin TaskMixin on ChangeNotifier {
  // --- State ---
  List<MainTask> _mainTasks = initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList();
  Map<String, dynamic> _completedByDay = {};
  String? _selectedTaskId;
  Map<String, ActiveTimerInfo> _activeTimers = {}; // Store typed objects internally
  List<Project> _projects = [];
  String? _activeProjectId;
  List<RoutineList> _routineLists = [];
  List<GoalModel> _goals = [];
  List<GoalPlace> _goalPlaces = List.from(GoalPlace.defaultPlaces);

  // --- Getters ---
  List<MainTask> get mainTasks => _mainTasks;
  Map<String, dynamic> get completedByDay => _completedByDay;
  String? get selectedTaskId => _selectedTaskId;
  Map<String, ActiveTimerInfo> get activeTimers => _activeTimers;
  List<Project> get projects => _projects;
  String? get activeProjectId => _activeProjectId;
  List<RoutineList> get routineLists => _routineLists;
  List<GoalModel> get goals => _goals;
  List<GoalPlace> get goalPlaces => _goalPlaces;

  // --- Requirements from AppProvider ---
  SyncMixin get sync => this as SyncMixin;

  // --- Setters / Mutators ---
  
  void setMainTasks(List<MainTask> tasks) {
    _mainTasks = List.from(tasks);
    sync.markDirty('tasks');
  }

  void setCompletedByDay(Map<String, dynamic> data) {
    _completedByDay = Map.from(data);
    sync.markDirty('history');
  }

  void setSelectedTaskId(String? id) {
    if (_selectedTaskId != id) {
      _selectedTaskId = id;
      sync.markDirty('settings');
    }
  }

  void setActiveTimers(Map<String, dynamic> timers) {
    // Handle both Map (from JSON) and ActiveTimerInfo (from Runtime) values
    final Map<String, ActiveTimerInfo> newTimers = {};
    
    timers.forEach((key, value) {
      if (value is ActiveTimerInfo) {
        newTimers[key] = value;
      } else if (value is Map) {
        newTimers[key] = ActiveTimerInfo.fromJson(Map<String, dynamic>.from(value));
      }
    });

    _activeTimers = newTimers;
    sync.markDirty('settings');
  }

  void setProjects(List<Project> projects) {
    _projects = List.from(projects);
    sync.markDirty('tasks');
  }

  void setRoutineLists(List<RoutineList> lists) {
    _routineLists = List.from(lists);
    sync.markDirty('tasks');
  }

  void setActiveProjectId(String? id) {
    if (_activeProjectId != id) {
      _activeProjectId = id;
      notifyListeners();
    }
  }

  // --- Goal Place Actions ---
  GoalPlace? getGoalPlace(String? id) {
    if (id == null) return null;
    return _goalPlaces.firstWhereOrNull((p) => p.id == id) ??
        GoalPlace.defaultPlaces.firstWhereOrNull((p) => p.id == id);
  }

  void addGoalPlace(GoalPlace place) {
    _goalPlaces = [..._goalPlaces.where((p) => p.id != place.id), place];
    sync.markDirty('tasks');
    notifyListeners();
  }

  void updateGoalPlace(GoalPlace place) {
    final index = _goalPlaces.indexWhere((p) => p.id == place.id);
    if (index != -1) {
      _goalPlaces[index] = place;
    } else {
      _goalPlaces.add(place);
    }
    sync.markDirty('tasks');
    notifyListeners();
  }

  void deleteGoalPlace(String id) {
    _goalPlaces = _goalPlaces.where((p) => p.id != id).toList();
    _goals = _goals.map((g) => g.placeId == id ? g.copyWith(clearPlaceId: true) : g).toList();
    sync.markDirty('tasks');
    notifyListeners();
  }

  // --- Goal Actions ---
  void setGoals(List<GoalModel> goals) {
    _goals = List.from(goals);
    NotificationService.instance.scheduleAllGoalContemplationReminders(_goals);
    sync.markDirty('tasks');
    notifyListeners();
  }

  List<GoalModel> getGoalsForDate(DateTime date, GoalScope scope) {
    final periodKey = GoalModel.getPeriodKey(scope, date);
    final periodGoals = _goals.where((g) => g.scope == scope && g.dateKey == periodKey).toList();

    if (periodGoals.isNotEmpty) {
      return periodGoals;
    }

    // Auto-instantiate clean sheet copies of recurring goals for this period
    final recurringTemplates = _goals
        .where((g) => g.scope == scope && g.isRecurring)
        .fold<Map<String, GoalModel>>({}, (map, g) {
          map.putIfAbsent(g.title, () => g);
          return map;
        }).values.toList();

    if (recurringTemplates.isNotEmpty) {
      final newSheetGoals = <GoalModel>[];
      for (final template in recurringTemplates) {
        final newId = 'goal_${DateTime.now().millisecondsSinceEpoch}_${template.title.hashCode}';
        final cleanSubChecklist = template.subChecklist
            .map((item) => item.copyWith(isCompleted: false))
            .toList();

        final cleanGoal = template.copyWith(
          id: newId,
          dateKey: periodKey,
          currentValue: 0.0,
          isCompleted: false,
          startDateTime: date,
          subChecklist: cleanSubChecklist,
        );
        newSheetGoals.add(cleanGoal);
      }

      _goals = [..._goals, ...newSheetGoals];
      NotificationService.instance.scheduleAllGoalContemplationReminders(_goals);
      sync.markDirty('tasks');
      notifyListeners();
      return newSheetGoals;
    }

    return [];
  }

  void addGoal(GoalModel goal) {
    _goals = [..._goals, goal];
    NotificationService.instance.scheduleAllGoalContemplationReminders(_goals);
    sync.markDirty('tasks');
    notifyListeners();
  }

  void updateGoal(GoalModel goal) {
    _goals = _goals.map((g) => g.id == goal.id ? goal : g).toList();
    NotificationService.instance.scheduleAllGoalContemplationReminders(_goals);
    sync.markDirty('tasks');
    notifyListeners();
  }

  void restoreGoal(GoalModel goal) {
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      _goals[index] = goal;
    } else {
      _goals.add(goal);
    }
    NotificationService.instance.scheduleAllGoalContemplationReminders(_goals);
    sync.markDirty('tasks');
    notifyListeners();
  }

  void deleteGoal(String id, {bool silent = false}) {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index == -1) return;
    final savedGoal = _goals[index].copyWith();
    final savedGoals = List<GoalModel>.from(_goals);
    _goals = _goals.where((g) => g.id != id).toList();
    NotificationService.instance.scheduleAllGoalContemplationReminders(_goals);
    sync.markDirty('tasks');
    notifyListeners();

    if (!silent) {
      showUndoSnackBar(
        message: 'Deleted goal "${savedGoal.title}"',
        onUndo: () {
          _goals = savedGoals;
          NotificationService.instance.scheduleAllGoalContemplationReminders(_goals);
          sync.markDirty('tasks');
          notifyListeners();
        },
      );
    }
  }

  void toggleGoalCheck(String id, {bool silent = false}) {
    GoalModel? previousState;
    _goals = _goals.map((g) {
      if (g.id == id) {
        previousState = g.copyWith();
        final nextState = !g.isCompleted;
        final updatedSubs = nextState && g.subChecklist.isNotEmpty
            ? g.subChecklist.map((s) => s.copyWith(isCompleted: true)).toList()
            : (!nextState && g.subChecklist.isNotEmpty
                ? g.subChecklist.map((s) => s.copyWith(isCompleted: false)).toList()
                : g.subChecklist);
        final nextGoal = g.copyWith(isCompleted: nextState, subChecklist: updatedSubs);
        return nextGoal;
      }
      return g;
    }).toList();
    NotificationService.instance.scheduleAllGoalContemplationReminders(_goals);
    sync.markDirty('tasks');
    notifyListeners();

    if (!silent && previousState != null) {
      final isNowCompleted = !previousState!.isCompleted;
      showUndoSnackBar(
        message: isNowCompleted ? 'Completed "${previousState!.title}"' : 'Marked "${previousState!.title}" incomplete',
        onUndo: () => restoreGoal(previousState!),
      );
    }
  }

  void reorderGoalsForPeriod(GoalScope scope, DateTime date, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final periodKey = GoalModel.getPeriodKey(scope, date);
    final periodGoals = _goals.where((g) => g.scope == scope && g.dateKey == periodKey).toList();
    if (oldIndex < 0 || oldIndex >= periodGoals.length || newIndex < 0 || newIndex >= periodGoals.length) return;

    final item = periodGoals.removeAt(oldIndex);
    periodGoals.insert(newIndex, item);

    final otherGoals = _goals.where((g) => !(g.scope == scope && g.dateKey == periodKey)).toList();
    _goals = [...otherGoals, ...periodGoals];
    sync.markDirty('tasks');
    notifyListeners();
  }

  void updateGoalCounter(String id, double delta) {
    _goals = _goals.map((g) {
      if (g.id == id) {
        final newVal = (g.currentValue + delta).clamp(0.0, 999999.0);
        final isDone = g.targetValue > 0 && newVal >= g.targetValue;
        return g.copyWith(currentValue: newVal, isCompleted: isDone);
      }
      return g;
    }).toList();
    sync.markDirty('tasks');
    notifyListeners();
  }

  void setGoalCounterValue(String id, double newValue) {
    _goals = _goals.map((g) {
      if (g.id == id) {
        final val = newValue.clamp(0.0, 999999.0);
        final isDone = g.targetValue > 0 && val >= g.targetValue;
        return g.copyWith(currentValue: val, isCompleted: isDone);
      }
      return g;
    }).toList();
    sync.markDirty('tasks');
    notifyListeners();
  }

  void toggleGoalSubCheckItem(String goalId, String itemId) {
    _goals = _goals.map((g) {
      if (g.id == goalId) {
        final updatedList = g.subChecklist.map((item) {
          if (item.id == itemId) {
            return item.copyWith(isCompleted: !item.isCompleted);
          }
          return item;
        }).toList();

        final allCompleted = updatedList.isNotEmpty && updatedList.every((i) => i.isCompleted);
        return g.copyWith(subChecklist: updatedList, isCompleted: allCompleted);
      }
      return g;
    }).toList();
    sync.markDirty('tasks');
    notifyListeners();
  }

  void reorderGoalSubCheckItem(String goalId, int oldIndex, int newIndex) {
    _goals = _goals.map((g) {
      if (g.id == goalId) {
        final list = List<GoalSubCheckItem>.from(g.subChecklist);
        if (oldIndex < 0 || oldIndex >= list.length) return g;
        if (newIndex < 0 || newIndex >= list.length) return g;
        if (oldIndex == newIndex) return g;
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        return g.copyWith(subChecklist: list);
      }
      return g;
    }).toList();
    sync.markDirty('tasks');
    notifyListeners();
  }

  void addGoalSubCheckItem(String goalId, String title) {
    if (title.trim().isEmpty) return;
    _goals = _goals.map((g) {
      if (g.id == goalId) {
        final newItem = GoalSubCheckItem(
          id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
          title: title.trim(),
          isCompleted: false,
        );
        return g.copyWith(
          subChecklist: [...g.subChecklist, newItem],
          isCompleted: false,
        );
      }
      return g;
    }).toList();
    sync.markDirty('tasks');
    notifyListeners();
  }

  void deleteGoalSubCheckItem(String goalId, String itemId, {bool silent = false}) {
    final targetGoal = _goals.firstWhereOrNull((g) => g.id == goalId);
    if (targetGoal == null) return;
    final deletedItem = targetGoal.subChecklist.firstWhereOrNull((item) => item.id == itemId);
    final savedGoals = _goals.map((g) => g.copyWith()).toList();

    _goals = _goals.map((g) {
      if (g.id == goalId) {
        final updatedList = g.subChecklist.where((item) => item.id != itemId).toList();
        return g.copyWith(subChecklist: updatedList);
      }
      return g;
    }).toList();
    sync.markDirty('tasks');
    notifyListeners();

    if (!silent && deletedItem != null) {
      showUndoSnackBar(
        message: 'Deleted "${deletedItem.title}"',
        onUndo: () {
          _goals = savedGoals;
          sync.markDirty('tasks');
          notifyListeners();
        },
      );
    }
  }

  MainTask? getSelectedTask() {
    try {
      return _mainTasks.firstWhere((t) => t.id == _selectedTaskId);
    } catch (_) {
      return null;
    }
  }

  // --- Checkpoint Hierarchy & Synchronization Helpers ---

  ({SubSubTask node, bool modified}) _mergeCheckpointNodes(SubSubTask localCp, SubSubTask incCp, bool isRecurring) {
    bool nodeModified = false;
    final bool cpCompleted = isRecurring ? localCp.completed : (localCp.completed || incCp.completed);
    if (cpCompleted != localCp.completed) nodeModified = true;

    final String? cpTime = localCp.completionTimestamp ?? incCp.completionTimestamp;
    if (cpTime != localCp.completionTimestamp) nodeModified = true;

    final bool cpActive = localCp.isActive || incCp.isActive;
    if (cpActive != localCp.isActive) nodeModified = true;

    final int cpCount = math.max(localCp.currentCount, incCp.currentCount);
    if (cpCount != localCp.currentCount) nodeModified = true;

    final substepsRes = _mergeCheckpointLists(localCp.substeps, incCp.substeps, isRecurring);
    if (substepsRes.modified) nodeModified = true;

    final mergedNode = localCp.copyWith(
      name: localCp.name.isNotEmpty ? localCp.name : incCp.name,
      completed: cpCompleted,
      completionTimestamp: cpTime,
      isActive: cpActive,
      currentCount: cpCount,
      substeps: substepsRes.checkpoints,
    );
    return (node: mergedNode, modified: nodeModified);
  }

  ({List<SubSubTask> checkpoints, bool modified}) _mergeCheckpointLists(List<SubSubTask> localList, List<SubSubTask> incList, bool isRecurring) {
    bool anyModified = false;
    final cpMap = <String, SubSubTask>{for (final cp in localList) cp.id: cp};
    final cpTitleMap = <String, SubSubTask>{
      for (final cp in localList)
        if (cp.name.trim().isNotEmpty) cp.name.trim().toLowerCase(): cp
    };
    final merged = List<SubSubTask>.from(localList);

    for (final incCp in incList) {
      SubSubTask? match = cpMap[incCp.id];
      if (match == null && incCp.name.trim().isNotEmpty) {
        match = cpTitleMap[incCp.name.trim().toLowerCase()];
      }

      if (match == null) {
        merged.add(incCp);
        cpMap[incCp.id] = incCp;
        if (incCp.name.trim().isNotEmpty) {
          cpTitleMap[incCp.name.trim().toLowerCase()] = incCp;
        }
        anyModified = true;
      } else {
        final nodeRes = _mergeCheckpointNodes(match, incCp, isRecurring);
        if (nodeRes.modified) {
          anyModified = true;
          final idx = merged.indexWhere((c) => c.id == match!.id);
          if (idx >= 0) {
            merged[idx] = nodeRes.node;
          }
        }
      }
    }
    return (checkpoints: merged, modified: anyModified);
  }

  bool _crossSyncTasksAndHistory(Map<String, dynamic> historyMap) {
    bool tasksModified = false;
    final todayStr = getTodayDateString();

    // 1. Collect completed history from historyMap for non-recurring restoration
    final completedCheckpointMap = <String, String>{}; // id -> completionTimestamp
    final completedCheckpointByName = <String, String>{}; // name or subtaskId_name -> completionTimestamp
    final completedSubtaskIds = <String>{};
    final completedSubtaskNames = <String>{};

    for (final dayEntry in historyMap.entries) {
      final dayData = dayEntry.value;
      if (dayData is Map) {
        final cpList = dayData['checkpointsCompleted'];
        if (cpList is List) {
          for (final c in cpList.whereType<Map>()) {
            final id = (c['subSubTaskId'] ?? c['id'] ?? c['checkpointId'])?.toString();
            final name = (c['name'] ?? c['checkpointTitle'] ?? c['title'])?.toString().trim().toLowerCase();
            final ts = c['completionTimestamp']?.toString() ?? dayEntry.key;
            if (id != null && id.isNotEmpty) completedCheckpointMap[id] = ts;
            if (name != null && name.isNotEmpty) {
              completedCheckpointByName[name] = ts;
              final subtaskId = (c['parentSubTaskId'] ?? c['parentSubtaskId'] ?? c['subtaskId'])?.toString();
              if (subtaskId != null && subtaskId.isNotEmpty) {
                completedCheckpointByName['${subtaskId}_$name'] = ts;
              }
            }
          }
        }
        final stList = dayData['subtasksCompleted'];
        if (stList is List) {
          for (final s in stList.whereType<Map>()) {
            final id = (s['subtaskId'] ?? s['id'])?.toString();
            final name = (s['name'] ?? s['subtaskName'])?.toString().trim().toLowerCase();
            if (id != null && id.isNotEmpty) completedSubtaskIds.add(id);
            if (name != null && name.isNotEmpty) completedSubtaskNames.add(name);
          }
        }
      }
    }

    void restoreCheckpointsRecursively(String subtaskId, List<SubSubTask> cps) {
      for (final cp in cps) {
        final normName = cp.name.trim().toLowerCase();
        final matchedTs = completedCheckpointMap[cp.id] ??
            completedCheckpointByName['${subtaskId}_$normName'] ??
            completedCheckpointByName[normName];
        if (!cp.completed && matchedTs != null) {
          cp.completed = true;
          cp.completionTimestamp ??= matchedTs;
          tasksModified = true;
        }
        if (cp.substeps.isNotEmpty) {
          restoreCheckpointsRecursively(subtaskId, cp.substeps);
        }
      }
    }

    for (final task in _mainTasks) {
      for (final st in task.subTasks) {
        if (!st.isRecurring) {
          final normStName = st.name.trim().toLowerCase();
          if (!st.completed && (completedSubtaskIds.contains(st.id) || completedSubtaskNames.contains(normStName))) {
            st.completed = true;
            tasksModified = true;
          }
          restoreCheckpointsRecursively(st.id, st.subSubTasks);
        }
      }
    }

    // 2. Cross-sync completed items on _mainTasks into historyMap
    for (final task in _mainTasks) {
      for (final st in task.subTasks) {
        if (st.completed && st.completedDate != null && st.completedDate!.isNotEmpty) {
          final dateKey = st.completedDate!;
          final dayData = Map<String, dynamic>.from(historyMap[dateKey] as Map? ?? {});
          final curSts = (dayData['subtasksCompleted'] as List? ?? []).whereType<Map>().toList();
          final exists = curSts.any((s) => s['subtaskId'] == st.id || (s['taskId'] == task.id && s['subtaskName'] == st.name));
          if (!exists) {
            curSts.add({
              'taskId': task.id,
              'subtaskId': st.id,
              'subtaskName': st.name,
              'name': st.name,
              'completionTimestamp': st.lastCompletedDate?.toIso8601String() ?? st.completedDate,
            });
            dayData['subtasksCompleted'] = curSts;
            historyMap[dateKey] = dayData;
          }
        }

        void syncCheckpointsRecursively(List<SubSubTask> cps) {
          for (final cp in cps) {
            if (cp.completed) {
              final cpDate = (cp.completionTimestamp != null && cp.completionTimestamp!.length >= 10)
                  ? cp.completionTimestamp!.substring(0, 10)
                  : (st.completedDate ?? todayStr);
              final dayData = Map<String, dynamic>.from(historyMap[cpDate] as Map? ?? {});
              final curCps = (dayData['checkpointsCompleted'] as List? ?? []).whereType<Map>().toList();
              final exists = curCps.any((c) => c['subSubTaskId'] == cp.id);
              if (!exists) {
                curCps.add({
                  'parentTaskId': task.id,
                  'parentSubTaskId': st.id,
                  'parentSubtaskName': st.name,
                  'subSubTaskId': cp.id,
                  'name': cp.name,
                  'completionTimestamp': cp.completionTimestamp ?? DateTime.now().toIso8601String(),
                });
                dayData['checkpointsCompleted'] = curCps;
                historyMap[cpDate] = dayData;
              }
            }
            if (cp.substeps.isNotEmpty) {
              syncCheckpointsRecursively(cp.substeps);
            }
          }
        }

        syncCheckpointsRecursively(st.subSubTasks);
      }
    }

    if (tasksModified) {
      sync.markDirty('tasks');
    }
    return tasksModified;
  }

  // --- Data Loading Helper ---
  void loadTaskState(Map<String, dynamic> data) {
    if (data['mainTasks'] != null) {
      final incoming = (data['mainTasks'] as List)
          .whereType<Map>()
          .map((e) => MainTask.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _mainTasks = incoming;
    } else if (_mainTasks.isEmpty) {
      _mainTasks = initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList();
    }

    if (data['completedByDay'] != null) {
      final incoming = Map<String, dynamic>.from(data['completedByDay']);
      _completedByDay = incoming;
    }

    if (data['completedTasks'] != null || data['completed_tasks'] != null) {
      final rawCt = data['completedTasks'] ?? data['completed_tasks'];
      final ids = <String>{};
      if (rawCt is List) {
        for (final item in rawCt) {
          if (item is String) {
            ids.add(item);
          } else if (item is Map && item['id'] != null) {
            ids.add(item['id'].toString());
          }
        }
      }
      if (ids.isNotEmpty) {
        for (final t in _mainTasks) {
          for (final st in t.subTasks) {
            if (ids.contains(st.id)) {
              st.completed = true;
            }
          }
        }
      }
    }

    // Cross-synchronize: ensure full two-way parity between _mainTasks and _completedByDay
    final currentCompleted = Map<String, dynamic>.from(_completedByDay);
    _crossSyncTasksAndHistory(currentCompleted);
    _completedByDay = currentCompleted;
        
    _selectedTaskId = data['selectedTaskId'] as String? ?? (_mainTasks.isNotEmpty ? _mainTasks.first.id : null);
    
    if (data['activeTimers'] != null) {
      final raw = Map<String, dynamic>.from(data['activeTimers']);
      _activeTimers = raw.map((k, v) => MapEntry(k, ActiveTimerInfo.fromJson(Map<String, dynamic>.from(v))));
    } else {
      _activeTimers = {};
    }

    if (data['projects'] != null) {
      _projects = (data['projects'] as List)
          .whereType<Map>()
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (data['routineLists'] != null) {
      _routineLists = (data['routineLists'] as List)
          .whereType<Map>()
          .map((e) => RoutineList.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (data['goals'] != null) {
      _goals = (data['goals'] as List)
          .whereType<Map>()
          .map((e) => GoalModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      NotificationService.instance.scheduleAllGoalContemplationReminders(_goals);
    }

    if (data['goalPlaces'] != null) {
      _goalPlaces = (data['goalPlaces'] as List)
          .whereType<Map>()
          .map((e) => GoalPlace.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      _goalPlaces = List.from(GoalPlace.defaultPlaces);
    }
  }

  /// Non-destructively merges tasks, completed items, historical days, projects, routines, and goals.
  /// Returns a record with counts of restored items.
  ({int mergedDays, int addedTasks, int addedProjects, int addedGoals}) mergeTaskState(Map<String, dynamic> data) {
    int mergedDays = 0;
    int addedTasks = 0;
    int addedProjects = 0;
    int addedGoals = 0;

    if (data['mainTasks'] != null) {
      final incoming = (data['mainTasks'] as List)
          .whereType<Map>()
          .map((e) => MainTask.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final tMap = <String, MainTask>{for (final t in _mainTasks) t.id: t};
      for (final incTask in incoming) {
        if (!tMap.containsKey(incTask.id)) {
          tMap[incTask.id] = incTask;
          addedTasks++;
        } else {
          final curTask = tMap[incTask.id]!;
          bool taskModified = false;

          bool curIsDeleted = curTask.isDeleted;
          if (curIsDeleted && !incTask.isDeleted) {
            curIsDeleted = false;
            taskModified = true;
          }

          // 1. Deep merge subtasks
          final stMap = <String, SubTask>{for (final st in curTask.subTasks) st.id: st};
          final stNameMap = <String, SubTask>{
            for (final st in curTask.subTasks)
              if (st.name.trim().isNotEmpty) st.name.trim().toLowerCase(): st
          };

          final mergedSubtasks = List<SubTask>.from(curTask.subTasks);

          for (final incSt in incTask.subTasks) {
            SubTask? match = stMap[incSt.id];
            if (match == null && incSt.name.trim().isNotEmpty) {
              match = stNameMap[incSt.name.trim().toLowerCase()];
            }

            if (match == null) {
              mergedSubtasks.add(incSt);
              stMap[incSt.id] = incSt;
              if (incSt.name.trim().isNotEmpty) {
                stNameMap[incSt.name.trim().toLowerCase()] = incSt;
              }
              taskModified = true;
            } else {
              bool stModified = false;
              bool newCompleted = match.completed || incSt.completed;
              if (newCompleted != match.completed) stModified = true;

              String? newCompletedDate = match.completedDate ?? incSt.completedDate;
              if (newCompletedDate != match.completedDate) stModified = true;

              DateTime? newLastCompletedDate = match.lastCompletedDate;
              if (incSt.lastCompletedDate != null) {
                if (newLastCompletedDate == null || incSt.lastCompletedDate!.isAfter(newLastCompletedDate)) {
                  newLastCompletedDate = incSt.lastCompletedDate;
                  stModified = true;
                }
              }

              bool newIsDeleted = match.isDeleted;
              if (newIsDeleted && !incSt.isDeleted) {
                newIsDeleted = false;
                stModified = true;
              }

              bool newIsActive = match.isActive || incSt.isActive;
              if (newIsActive != match.isActive) stModified = true;

              final newManualProgress = (incSt.manualProgress > match.manualProgress)
                  ? incSt.manualProgress
                  : match.manualProgress;
              if (newManualProgress != match.manualProgress) stModified = true;

              final newCurrentCount = (incSt.currentCount > match.currentCount)
                  ? incSt.currentCount
                  : match.currentCount;
              if (newCurrentCount != match.currentCount) stModified = true;

              final newTargetCount = (incSt.targetCount > match.targetCount)
                  ? incSt.targetCount
                  : match.targetCount;
              if (newTargetCount != match.targetCount) stModified = true;

              // Merge checkpoints (subSubTasks) recursively
              final cpRes = _mergeCheckpointLists(match.subSubTasks, incSt.subSubTasks, match.isRecurring);
              final mergedCheckpoints = cpRes.checkpoints;
              if (cpRes.modified) stModified = true;

              // Merge sessions
              final sMap = <String, TaskSession>{for (final s in match.sessions) s.id: s};
              final sKeySet = match.sessions.map((s) => '${s.startTime.millisecondsSinceEpoch}_${s.endTime.millisecondsSinceEpoch}').toSet();
              final mergedSessions = List<TaskSession>.from(match.sessions);
              for (final incS in incSt.sessions) {
                final sKey = '${incS.startTime.millisecondsSinceEpoch}_${incS.endTime.millisecondsSinceEpoch}';
                if (!sMap.containsKey(incS.id) && !sKeySet.contains(sKey)) {
                  mergedSessions.add(incS);
                  sMap[incS.id] = incS;
                  sKeySet.add(sKey);
                  stModified = true;
                }
              }

              // Merge progressDataPoints
              final dpSet = match.progressDataPoints.map((p) => p.timestamp.millisecondsSinceEpoch).toSet();
              final mergedDataPoints = List<ProgressDataPoint>.from(match.progressDataPoints);
              for (final incP in incSt.progressDataPoints) {
                if (!dpSet.contains(incP.timestamp.millisecondsSinceEpoch)) {
                  mergedDataPoints.add(incP);
                  dpSet.add(incP.timestamp.millisecondsSinceEpoch);
                  stModified = true;
                }
              }

              final newTimeSpent = match.currentTimeSpent > incSt.currentTimeSpent
                  ? match.currentTimeSpent
                  : incSt.currentTimeSpent;
              if (newTimeSpent != match.currentTimeSpent) stModified = true;

              if (stModified) {
                final stIdx = mergedSubtasks.indexWhere((s) => s.id == match!.id);
                if (stIdx >= 0) {
                  mergedSubtasks[stIdx] = match.copyWith(
                    completed: newCompleted,
                    completedDate: newCompletedDate,
                    lastCompletedDate: newLastCompletedDate,
                    isDeleted: newIsDeleted,
                    isActive: newIsActive,
                    manualProgress: newManualProgress,
                    currentCount: newCurrentCount,
                    targetCount: newTargetCount,
                    subSubTasks: mergedCheckpoints,
                    sessions: mergedSessions,
                    progressDataPoints: mergedDataPoints,
                    currentTimeSpent: newTimeSpent,
                  );
                  taskModified = true;
                }
              }
            }
          }

          // 2. Merge weeklyCompletionStatus
          final mergedWeekly = Map<String, List<bool>>.from(curTask.weeklyCompletionStatus);
          for (final wEntry in incTask.weeklyCompletionStatus.entries) {
            if (!mergedWeekly.containsKey(wEntry.key)) {
              mergedWeekly[wEntry.key] = wEntry.value;
              taskModified = true;
            } else {
              final curList = List<bool>.from(mergedWeekly[wEntry.key]!);
              final incList = wEntry.value;
              bool listChanged = false;
              for (int d = 0; d < curList.length && d < incList.length; d++) {
                if (!curList[d] && incList[d]) {
                  curList[d] = true;
                  listChanged = true;
                }
              }
              if (listChanged) {
                mergedWeekly[wEntry.key] = curList;
                taskModified = true;
              }
            }
          }

          final newDailyTimeSpent = curTask.dailyTimeSpent > incTask.dailyTimeSpent
              ? curTask.dailyTimeSpent
              : incTask.dailyTimeSpent;
          if (newDailyTimeSpent != curTask.dailyTimeSpent) taskModified = true;

          if (taskModified) {
            tMap[incTask.id] = curTask.copyWith(
              isDeleted: curIsDeleted,
              subTasks: mergedSubtasks,
              weeklyCompletionStatus: mergedWeekly,
              dailyTimeSpent: newDailyTimeSpent,
            );
          }
        }
      }
      _mainTasks = tMap.values.toList();
      sync.markDirty('tasks');
    }

    // Merge standalone completedTasks or completed_tasks list if present
    final rawComp = (data['completedTasks'] ?? data['completed_tasks']);
    if (rawComp is List) {
      for (final item in rawComp.whereType<Map>()) {
        final taskId = item['taskId']?.toString();
        final subtaskId = (item['subtaskId'] ?? item['id'])?.toString();
        final subtaskName = (item['subtaskName'] ?? item['name'] ?? item['title'])?.toString().trim().toLowerCase();
        final compDate = item['completedDate']?.toString() ?? item['date']?.toString();

        for (int i = 0; i < _mainTasks.length; i++) {
          final task = _mainTasks[i];
          if (taskId != null && task.id != taskId) continue;

          bool taskChanged = false;
          final updatedSubtasks = task.subTasks.map((st) {
            bool match = false;
            if (subtaskId != null && st.id == subtaskId) match = true;
            if (!match && subtaskName != null && st.name.trim().toLowerCase() == subtaskName) match = true;

            if (match && !st.completed) {
              taskChanged = true;
              return st.copyWith(
                completed: true,
                completedDate: compDate ?? st.completedDate,
                lastCompletedDate: DateTime.tryParse(compDate ?? '') ?? st.lastCompletedDate,
              );
            }
            return st;
          }).toList();

          if (taskChanged) {
            _mainTasks[i] = task.copyWith(subTasks: updatedSubtasks);
            sync.markDirty('tasks');
          }
        }
      }
    }

    if (data['completedByDay'] != null) {
      final incoming = Map<String, dynamic>.from(data['completedByDay']);
      final merged = Map<String, dynamic>.from(_completedByDay);
      for (final entry in incoming.entries) {
        var dateKey = entry.key.toString();
        if (RegExp(r'^\d{4}_\d{2}_\d{2}$').hasMatch(dateKey)) {
          dateKey = dateKey.replaceAll('_', '-');
        }

        dynamic dayRaw = entry.value;
        if (dayRaw is String) {
          try {
            dayRaw = jsonDecode(dayRaw);
          } catch (_) {}
        }
        if (dayRaw is! Map) continue;
        final oldDay = Map<String, dynamic>.from(dayRaw);

        if (!merged.containsKey(dateKey)) {
          merged[dateKey] = oldDay;
          mergedDays++;
        } else {
          dynamic curRaw = merged[dateKey];
          if (curRaw is String) {
            try {
              curRaw = jsonDecode(curRaw);
            } catch (_) {}
          }
          final currentDay = Map<String, dynamic>.from(curRaw is Map ? curRaw : {});
          bool dayEnriched = false;

          // 1. Metadata & text fields
          for (final field in [
            'briefing',
            'aiBriefing',
            'startDayReport',
            'morningDirectives',
            'notes',
            'rating',
            'mood',
            'reflection',
            'wakeTime',
            'sleepTime',
          ]) {
            if ((currentDay[field] == null || currentDay[field].toString().isEmpty) &&
                oldDay[field] != null &&
                oldDay[field].toString().isNotEmpty) {
              currentDay[field] = oldDay[field];
              dayEnriched = true;
            }
          }

          // 2. tasks completed list
          if (oldDay['tasks'] is List) {
            final curTasks = (currentDay['tasks'] as List? ?? []).whereType<Map>().toList();
            final curTitles = curTasks.map((t) => t['title']?.toString().toLowerCase()).toSet();
            final curIds = curTasks.map((t) => t['id']?.toString()).toSet();
            for (final ot in (oldDay['tasks'] as List).whereType<Map>()) {
              final otTitle = ot['title']?.toString().toLowerCase();
              final otId = ot['id']?.toString();
              if ((otId != null && !curIds.contains(otId)) ||
                  (otTitle != null && !curTitles.contains(otTitle))) {
                curTasks.add(Map<String, dynamic>.from(ot));
                dayEnriched = true;
              }
            }
            currentDay['tasks'] = curTasks;
          }

          // 3. subtasksCompleted list
          if (oldDay['subtasksCompleted'] is List) {
            final curSts = (currentDay['subtasksCompleted'] as List? ?? []).whereType<Map>().toList();
            final curStKeys = curSts.map((s) => '${s['taskId']}_${s['subtaskId']}_${s['subtaskName']}').toSet();
            for (final ost in (oldDay['subtasksCompleted'] as List).whereType<Map>()) {
              final ostKey = '${ost['taskId']}_${ost['subtaskId']}_${ost['subtaskName']}';
              if (!curStKeys.contains(ostKey)) {
                curSts.add(Map<String, dynamic>.from(ost));
                curStKeys.add(ostKey);
                dayEnriched = true;
              }
            }
            currentDay['subtasksCompleted'] = curSts;
          }

          // 4. checkpointsCompleted list
          if (oldDay['checkpointsCompleted'] is List) {
            final curCps = (currentDay['checkpointsCompleted'] as List? ?? []).whereType<Map>().toList();
            final curCpKeys = curCps.map((c) => '${c['taskId']}_${c['subtaskId']}_${c['checkpointTitle'] ?? c['title']}').toSet();
            for (final ocp in (oldDay['checkpointsCompleted'] as List).whereType<Map>()) {
              final ocpKey = '${ocp['taskId']}_${ocp['subtaskId']}_${ocp['checkpointTitle'] ?? ocp['title']}';
              if (!curCpKeys.contains(ocpKey)) {
                curCps.add(Map<String, dynamic>.from(ocp));
                curCpKeys.add(ocpKey);
                dayEnriched = true;
              }
            }
            currentDay['checkpointsCompleted'] = curCps;
          }

          // 5. taskTimes map
          if (oldDay['taskTimes'] is Map) {
            final curTimes = Map<String, dynamic>.from(currentDay['taskTimes'] as Map? ?? {});
            final oldTimes = Map<String, dynamic>.from(oldDay['taskTimes'] as Map);
            for (final tEntry in oldTimes.entries) {
              final curVal = (curTimes[tEntry.key] as num?)?.toInt() ?? 0;
              final oldVal = (tEntry.value as num?)?.toInt() ?? 0;
              if (oldVal > curVal) {
                curTimes[tEntry.key] = oldVal;
                dayEnriched = true;
              }
            }
            currentDay['taskTimes'] = curTimes;
          }

          // 6. dailyPlan list
          if (oldDay['dailyPlan'] is List) {
            // If currentDay does not yet have a dailyPlan initialized, take the remote/incoming one.
            // If currentDay already has a dailyPlan (even if empty, meaning the user removed all tasks),
            // preserve the local dailyPlan so deleted items are not resurrected.
            if (currentDay['dailyPlan'] == null) {
              currentDay['dailyPlan'] = (oldDay['dailyPlan'] as List).map((e) => e.toString()).toList();
              dayEnriched = true;
            }
          }

          // dailyPlanRows
          if (oldDay['dailyPlanRows'] is List && currentDay['dailyPlanRows'] == null) {
            currentDay['dailyPlanRows'] = oldDay['dailyPlanRows'];
            dayEnriched = true;
          }

          // planRowEntries
          if (oldDay['planRowEntries'] is List && currentDay['planRowEntries'] == null) {
            currentDay['planRowEntries'] = oldDay['planRowEntries'];
            dayEnriched = true;
          }

          // 7. task_snapshot
          if (currentDay['task_snapshot'] == null && oldDay['task_snapshot'] != null) {
            currentDay['task_snapshot'] = oldDay['task_snapshot'];
            dayEnriched = true;
          }

          // 8. notifications list
          if (oldDay['notifications'] is List) {
            final curN = (currentDay['notifications'] as List? ?? []).whereType<Map>().toList();
            final curNKeys = curN.map((n) => '${n['id']}_${n['timestamp']}').toSet();
            for (final on in (oldDay['notifications'] as List).whereType<Map>()) {
              final onKey = '${on['id']}_${on['timestamp']}';
              if (!curNKeys.contains(onKey)) {
                curN.add(Map<String, dynamic>.from(on));
                curNKeys.add(onKey);
                dayEnriched = true;
              }
            }
            currentDay['notifications'] = curN;
          }

          if (dayEnriched) {
            merged[dateKey] = currentDay;
            mergedDays++;
          }
        }
      }

      // Cross-synchronize: ensure full two-way parity between _mainTasks and _completedByDay
      final tasksUpdated = _crossSyncTasksAndHistory(merged);
      if (tasksUpdated) mergedDays++;

      _completedByDay = merged;
      sync.markDirty('history');
      if (tasksUpdated) sync.markDirty('tasks');
    }

    if (data['projects'] != null) {
      final incoming = (data['projects'] as List)
          .whereType<Map>()
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final pMap = <String, Project>{for (final p in _projects) p.id: p};
      for (final p in incoming) {
        if (!pMap.containsKey(p.id)) {
          pMap[p.id] = p;
          addedProjects++;
        }
      }
      _projects = pMap.values.toList();
      sync.markDirty('tasks');
    }

    if (data['routineLists'] != null) {
      final incoming = (data['routineLists'] as List)
          .whereType<Map>()
          .map((e) => RoutineList.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final rMap = <String, RoutineList>{for (final r in _routineLists) r.id: r};
      for (final r in incoming) {
        rMap.putIfAbsent(r.id, () => r);
      }
      _routineLists = rMap.values.toList();
      sync.markDirty('tasks');
    }

    if (data['goals'] != null) {
      final incoming = (data['goals'] as List)
          .whereType<Map>()
          .map((e) => GoalModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final gMap = <String, GoalModel>{for (final g in _goals) g.id: g};
      for (final g in incoming) {
        if (!gMap.containsKey(g.id)) {
          gMap[g.id] = g;
          addedGoals++;
        }
      }
      _goals = gMap.values.toList();
      NotificationService.instance.scheduleAllGoalContemplationReminders(_goals);
      sync.markDirty('tasks');
    }

    if (data['goalPlaces'] != null) {
      final incoming = (data['goalPlaces'] as List)
          .whereType<Map>()
          .map((e) => GoalPlace.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final gpMap = <String, GoalPlace>{for (final gp in _goalPlaces) gp.id: gp};
      for (final gp in incoming) {
        gpMap.putIfAbsent(gp.id, () => gp);
      }
      _goalPlaces = gpMap.values.toList();
      sync.markDirty('tasks');
    }

    // Recalibrate time logs across tasks and history for consistency
    try {
      final recalibrated = TaskCalculations.recalculateAllTimeLogs(_mainTasks);
      final newCompleted = Map<String, dynamic>.from(_completedByDay);
      recalibrated.dailyTaskTimes.forEach((date, taskMap) {
        final dayData = Map<String, dynamic>.from(newCompleted[date] as Map? ?? {});
        final curTimes = Map<String, dynamic>.from(dayData['taskTimes'] as Map? ?? {});
        taskMap.forEach((tid, secs) {
          final curSecs = (curTimes[tid] as num?)?.toInt() ?? 0;
          if (secs > curSecs) curTimes[tid] = secs;
        });
        dayData['taskTimes'] = curTimes;
        newCompleted[date] = dayData;
      });
      _completedByDay = newCompleted;
    } catch (_) {}

    return (
      mergedDays: mergedDays,
      addedTasks: addedTasks,
      addedProjects: addedProjects,
      addedGoals: addedGoals,
    );
  }

  Map<String, dynamic> getTaskStateMap() {
    return {
      'mainTasks': _mainTasks.map((t) => t.toJson()).toList(),
      'completedByDay': _completedByDay,
      'selectedTaskId': _selectedTaskId,
      'activeTimers': _activeTimers.map((k, v) => MapEntry(k, v.toJson())),
      'projects': _projects.map((p) => p.toJson()).toList(),
      'routineLists': _routineLists.map((r) => r.toJson()).toList(),
      'goals': _goals.map((g) => g.toJson()).toList(),
      'goalPlaces': _goalPlaces.map((p) => p.toJson()).toList(),
    };
  }
}