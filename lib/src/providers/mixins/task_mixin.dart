import 'package:flutter/foundation.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/utils/constants.dart';
import 'package:missions/src/providers/mixins/sync_mixin.dart';

/// Manages Tasks, Projects, and History Logic
mixin TaskMixin on ChangeNotifier {
  // --- State ---
  List<MainTask> _mainTasks = initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList();
  Map<String, dynamic> _completedByDay = {};
  String? _selectedTaskId;
  Map<String, ActiveTimerInfo> _activeTimers = {}; // Store typed objects internally

  // --- Getters ---
  List<MainTask> get mainTasks => _mainTasks;
  Map<String, dynamic> get completedByDay => _completedByDay;
  String? get selectedTaskId => _selectedTaskId;
  
  // Directly return the typed map
  Map<String, ActiveTimerInfo> get activeTimers => _activeTimers;

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
  }

  Map<String, dynamic> getTaskStateMap() {
    return {
      'mainTasks': _mainTasks.map((t) => t.toJson()).toList(),
      'completedByDay': _completedByDay,
      'selectedTaskId': _selectedTaskId,
      // Serialize objects to JSON maps for storage
      'activeTimers': _activeTimers.map((k, v) => MapEntry(k, v.toJson())),
    };
  }
}