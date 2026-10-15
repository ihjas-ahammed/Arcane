import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/tasks/task_actions.dart';
import 'package:missions/src/tasks/timer_actions.dart';

/// Everything the task logic needs from its host. The task logic is written against this
/// interface only, so the same code can run inside the app (AppProvider) and in a background
/// engine (a headless store on the local data file).
abstract class TaskStore {
  List<MainTask> get mainTasks;
  Map<String, dynamic> get completedByDay;
  Map<String, ActiveTimerInfo> get activeTimers;
  List<RoutineList> get routineLists;
  String? get selectedTaskId;

  /// Single write path for task state. Implementations persist the change (and record ledger
  /// deltas) when [doPersist] is true.
  void setProviderState({
    List<MainTask>? mainTasks,
    Map<String, dynamic>? completedByDay,
    Map<String, dynamic>? activeTimers,
    bool doNotify = true,
    bool doPersist = true,
  });

  void setRoutineLists(List<RoutineList> lists);
  void setSelectedTaskId(String? id);
  void setLoadingTask(String? name);
  void notify();

  /// False in the background engine: there is no notification plugin to call.
  bool get canNotify;

  TaskActions get taskActions;
  TimerActions get timerActions;
  bool addSessionToSubtask(
      String mainTaskId, String subTaskId, DateTime start, DateTime end);
}
