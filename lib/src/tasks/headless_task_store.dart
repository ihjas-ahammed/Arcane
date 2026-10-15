import 'package:shared_preferences/shared_preferences.dart';

import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/services/local_storage_service.dart';
import 'package:missions/src/tasks/task_actions.dart';
import 'package:missions/src/tasks/task_ledger.dart';
import 'package:missions/src/tasks/task_store.dart';
import 'package:missions/src/tasks/timer_actions.dart';

/// A [TaskStore] for the background engine, used when the app is not running.
///
/// It holds a copy of the saved task state, applies the change through the same [TaskActions] and
/// [TimerActions] code as the app, and then writes the changed keys back to the local data file in
/// the same format the app uses. It never shows notifications.
class HeadlessTaskStore implements TaskStore {
  HeadlessTaskStore(Map<String, dynamic> state)
      : _state = Map<String, dynamic>.from(state),
        _mainTasks = _parseTasks(state['mainTasks']),
        _completedByDay = Map<String, dynamic>.from(
            (state['completedByDay'] as Map?) ?? const {}),
        _activeTimers = _parseTimers(state['activeTimers']),
        _routineLists = _parseRoutines(state['routineLists']),
        _selectedTaskId = state['selectedTaskId'] as String?;

  /// The full state as loaded. Only the keys this store writes are replaced on save.
  final Map<String, dynamic> _state;

  List<MainTask> _mainTasks;
  Map<String, dynamic> _completedByDay;
  Map<String, ActiveTimerInfo> _activeTimers;
  List<RoutineList> _routineLists;
  String? _selectedTaskId;

  /// Collections changed since the last [commit]: 'tasks', 'history', 'settings'.
  final Set<String> _dirty = {};

  TaskActions? _taskActions;
  TimerActions? _timerActions;

  bool get hasChanges => _dirty.isNotEmpty;

  static List<MainTask> _parseTasks(Object? raw) {
    if (raw is! List) return <MainTask>[];
    return raw
        .whereType<Map>()
        .map((m) => MainTask.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static List<RoutineList> _parseRoutines(Object? raw) {
    if (raw is! List) return <RoutineList>[];
    return raw
        .whereType<Map>()
        .map((m) => RoutineList.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Same rules as the app's setActiveTimers: accepts ready objects and JSON maps.
  static Map<String, ActiveTimerInfo> _parseTimers(Object? raw) {
    final out = <String, ActiveTimerInfo>{};
    if (raw is! Map) return out;
    raw.forEach((key, value) {
      if (value is ActiveTimerInfo) {
        out[key.toString()] = value;
      } else if (value is Map) {
        out[key.toString()] =
            ActiveTimerInfo.fromJson(Map<String, dynamic>.from(value));
      }
    });
    return out;
  }

  @override
  List<MainTask> get mainTasks => _mainTasks;

  @override
  Map<String, dynamic> get completedByDay => _completedByDay;

  @override
  Map<String, ActiveTimerInfo> get activeTimers => _activeTimers;

  @override
  List<RoutineList> get routineLists => _routineLists;

  @override
  String? get selectedTaskId => _selectedTaskId;

  @override
  bool get canNotify => false;

  @override
  void notify() {}

  @override
  void setLoadingTask(String? name) {}

  @override
  void setRoutineLists(List<RoutineList> lists) {
    _routineLists = List.of(lists);
    _dirty.add('tasks');
  }

  @override
  void setSelectedTaskId(String? id) {
    if (_selectedTaskId != id) {
      _selectedTaskId = id;
      _dirty.add('settings');
    }
  }

  @override
  void setProviderState({
    List<MainTask>? mainTasks,
    Map<String, dynamic>? completedByDay,
    Map<String, dynamic>? activeTimers,
    bool doNotify = true,
    bool doPersist = true,
  }) {
    if (mainTasks != null) {
      // Same history recording as the app; skipped only when the caller asks for no persistence.
      if (doPersist) recordTaskLedgerDelta(_mainTasks, mainTasks);
      _mainTasks = List.of(mainTasks);
      _dirty.add('tasks');
    }
    if (completedByDay != null) {
      _completedByDay = Map<String, dynamic>.from(completedByDay);
      _dirty.add('history');
    }
    if (activeTimers != null) {
      _activeTimers = _parseTimers(activeTimers);
      _dirty.add('settings');
    }
  }

  @override
  TaskActions get taskActions => _taskActions ??= TaskActions(this);

  @override
  TimerActions get timerActions => _timerActions ??= TimerActions(this);

  @override
  bool addSessionToSubtask(
          String mainTaskId, String subTaskId, DateTime start, DateTime end) =>
      taskActions.addSessionToSubtask(mainTaskId, subTaskId, start, end);

  /// Writes the changed keys to the local file, using the same key names as the app's local
  /// snapshot, then marks cloud sync as pending for this user. Does nothing when nothing changed.
  Future<void> commit(String userId, {DateTime? now}) async {
    if (_dirty.isEmpty) return;
    final stamp = (now ?? DateTime.now()).millisecondsSinceEpoch;

    final out = <String, dynamic>{
      // Any change marks the settings collection dirty, exactly as the app does.
      'selectedTaskId': _selectedTaskId,
      'activeTimers': _activeTimers.map((k, v) => MapEntry(k, v.toJson())),
    };
    if (_dirty.contains('tasks')) {
      out['mainTasks'] = _mainTasks.map((t) => t.toJson()).toList();
      out['routineLists'] = _routineLists.map((r) => r.toJson()).toList();
    }
    if (_dirty.contains('history')) {
      out['completedByDay'] = _completedByDay;
    }
    final settings =
        Map<String, dynamic>.from((_state['settings'] as Map?) ?? const {});
    settings['lastModified'] = stamp;
    out['settings'] = settings;

    await LocalStorageService().saveState(userId, out, partial: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cloud_dirty_$userId', true);

    _state['settings'] = settings;
    _dirty.clear();
  }
}
