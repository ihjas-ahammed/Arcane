import 'package:flutter/foundation.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/utils/constants.dart';
import 'package:missions/src/providers/mixins/sync_mixin.dart';

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

  void deleteGoal(String id) {
    _goals = _goals.where((g) => g.id != id).toList();
    sync.markDirty('tasks');
    notifyListeners();
  }

  void toggleGoalCheck(String id) {
    _goals = _goals.map((g) {
      if (g.id == id) {
        return g.copyWith(isCompleted: !g.isCompleted);
      }
      return g;
    }).toList();
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