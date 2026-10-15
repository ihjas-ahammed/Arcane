import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:missions/src/services/local_storage_service.dart';
import 'package:missions/src/tasks/app_liveness.dart';
import 'package:missions/src/tasks/headless_task_store.dart';
import 'package:missions/src/tasks/task_commands.dart';
import 'package:missions/src/utils/task_calculations.dart';

const _runningWidget = 'me.ihjas.missions.widgets.RunningTaskWidget';
const _dayPlanWidget = 'me.ihjas.missions.widgets.DayPlanWidget';

/// Entry point for widget and bubble taps while the app is not running. Android starts a
/// background Flutter engine and calls this with the `arcane://widget?action=...` link.
///
/// It applies the action with the same task code as the app, saves the result to the local data
/// file, and refreshes the widgets. It does nothing while the app is running, because the app
/// handles the tap itself.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  final action = uri?.queryParameters['action'];
  if (action == null || action.isEmpty) return;
  try {
    if (await AppLiveness.isAppRunning()) {
      debugPrint('[Headless] app is running; leaving "$action" to the app');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('active_energy_user');
    if (userId == null || userId.isEmpty) return;
    final state = await LocalStorageService().loadState(userId);
    if (state == null) return;

    final store = HeadlessTaskStore(state);
    final commands = TaskCommands(store);
    _apply(action, commands);
    await store.commit(userId);
    await _refreshWidgets(store, commands);
  } catch (e, stack) {
    debugPrint('[Headless] "$action" failed: $e\n$stack');
  }
}

/// Mirrors the task part of WidgetActionRouter. Plan-position taps (task_check_N) need the plan the
/// widget last drew, which only the running app knows, so they are left to the app.
void _apply(String action, TaskCommands commands) {
  if (action.startsWith('task_check_add:')) {
    commands.checkAndAdd(action.substring('task_check_add:'.length));
    return;
  }
  switch (action) {
    case 'task_toggle':
      commands.toggle();
    case 'task_finish':
      commands.finish();
    case 'task_pause':
      commands.pause();
    case 'task_start':
      commands.start();
    case 'task_check_next':
      commands.checkNext();
    default:
      debugPrint('[Headless] "$action" needs the app; skipped');
  }
}

/// Writes the core running-task keys the widgets and bubble read, then asks Android to redraw.
/// The full publish runs again the next time the app opens.
Future<void> _refreshWidgets(
    HeadlessTaskStore store, TaskCommands commands) async {
  final r = commands.resolveActive();
  final sub = r.subTask;
  final main = r.mainTask;
  final timer = sub == null ? null : store.activeTimers[sub.id];
  final running = r.isRunning && timer != null && timer.isRunning;

  await HomeWidget.saveWidgetData<bool>(
      'arcane.task.hasTask', sub != null && main != null);
  await HomeWidget.saveWidgetData<bool>('arcane.task.isRunning', running);
  await HomeWidget.saveWidgetData<String>('arcane.task.title', sub?.name ?? '');
  await HomeWidget.saveWidgetData<int>(
    'arcane.task.accumulatedSec',
    running
        ? TaskCalculations.getHistoricalTodaySeconds(sub!, store.mainTasks)
            .toInt()
        : 0,
  );
  var sessionStartMs = 0;
  if (running) {
    sessionStartMs = timer.startTime.millisecondsSinceEpoch;
  }
  await HomeWidget.saveWidgetData<int>(
      'arcane.task.sessionStartMs', sessionStartMs);
  await HomeWidget.saveWidgetData<int>(
      'arcane.task.updatedAtMs', DateTime.now().millisecondsSinceEpoch);

  for (final provider in [_runningWidget, _dayPlanWidget]) {
    await HomeWidget.updateWidget(
      name: provider,
      androidName: provider.split('.').last,
      qualifiedAndroidName: provider,
    );
  }
}
