import 'package:flutter/foundation.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/utils/constants.dart';
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

  // --- Getters ---
  List<MainTask> get mainTasks => _mainTasks;
  Map<String, dynamic> get completedByDay => _completedByDay;
  String? get selectedTaskId => _selectedTaskId;
  Map<String, ActiveTimerInfo> get activeTimers => _activeTimers;
  List<Project> get projects => _projects;
  String? get activeProjectId => _activeProjectId;
  List<RoutineList> get routineLists => _routineLists;
  List<GoalModel> get goals => _goals;

  // --- Requirements from AppProvider ---
  SyncMixin get sync => this as SyncMixin;

  // --- Setters / Mutators ---
  
  void setMainTasks(List<MainTask> tasks) {
    if (!listEquals(_mainTasks, tasks)) {
      _mainTasks = List.from(tasks);
      sync.markDirty('tasks');
    }
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
    if (!listEquals(_projects, projects)) {
      _projects = List.from(projects);
      sync.markDirty('tasks');
    }
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

  // --- Goal Actions ---
  void setGoals(List<GoalModel> goals) {
    _goals = List.from(goals);
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
      sync.markDirty('tasks');
      notifyListeners();
      return newSheetGoals;
    }

    return [];
  }

  void addGoal(GoalModel goal) {
    _goals = [..._goals, goal];
    sync.markDirty('tasks');
    notifyListeners();
  }

  void updateGoal(GoalModel goal) {
    _goals = _goals.map((g) => g.id == goal.id ? goal : g).toList();
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
    sync.markDirty('tasks');
    notifyListeners();
  }

  void deleteGoal(String id, {bool silent = false}) {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index == -1) return;
    final savedGoal = _goals[index].copyWith();
    final savedGoals = List<GoalModel>.from(_goals);
    _goals = _goals.where((g) => g.id != id).toList();
    sync.markDirty('tasks');
    notifyListeners();

    if (!silent) {
      showUndoSnackBar(
        message: 'Deleted goal "${savedGoal.title}"',
        onUndo: () {
          _goals = savedGoals;
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
        return g.copyWith(isCompleted: nextState, subChecklist: updatedSubs);
      }
      return g;
    }).toList();
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

  // --- Data Loading Helper ---
  void loadTaskState(Map<String, dynamic> data) {
    if (data['mainTasks'] != null) {
      _mainTasks = (data['mainTasks'] as List).map((e) => MainTask.fromJson(e)).toList();
    } else {
      _mainTasks = initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList();
    }

    _completedByDay = data['completedByDay'] != null 
        ? Map<String, dynamic>.from(data['completedByDay']) 
        : {};
        
    _selectedTaskId = data['selectedTaskId'] as String? ?? (_mainTasks.isNotEmpty ? _mainTasks.first.id : null);
    
    if (data['activeTimers'] != null) {
      final raw = Map<String, dynamic>.from(data['activeTimers']);
      _activeTimers = raw.map((k, v) => MapEntry(k, ActiveTimerInfo.fromJson(Map<String, dynamic>.from(v))));
    } else {
      _activeTimers = {};
    }

    if (data['projects'] != null) {
      _projects = (data['projects'] as List).map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      _projects = [];
    }

    if (data['routineLists'] != null) {
      _routineLists = (data['routineLists'] as List)
          .map((e) => RoutineList.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      _routineLists = [];
    }

    if (data['goals'] != null) {
      _goals = (data['goals'] as List)
          .map((e) => GoalModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      _goals = [];
    }
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
    };
  }
}