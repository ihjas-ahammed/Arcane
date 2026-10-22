import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:missions/src/tasks/headless_entry.dart';
import 'package:missions/src/utils/task_calculations.dart';

/// Bridge between the Flutter app and the Android home-screen widgets.
///
/// Layout:
///  * `publishTask` / `publishFinance` / `publishJournal` write to the shared
///    prefs the AppWidgetProvider reads on its next render.
///  * `init` wires up the URI click handler (arcane://widget?action=…) so
///    a registered callback can react when the user taps a widget button.
///
/// The service is a no-op on non-Android platforms — Android widgets are the
/// only target right now, and the underlying plugin's API surface is identical
/// across platforms anyway.
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  static const String _providerRunning =
      'me.ihjas.missions.widgets.RunningTaskWidget';
  static const String _providerDayPlan =
      'me.ihjas.missions.widgets.DayPlanWidget';
  static const String _providerFinance =
      'me.ihjas.missions.widgets.FinanceWidget';
  static const String _providerJournal =
      'me.ihjas.missions.widgets.JournalWidget';
  static const String _providerBus = 'me.ihjas.missions.widgets.BusWidget';
  static const String _providerGoals = 'me.ihjas.missions.widgets.GoalsWidget';

  bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Caller registers this to receive widget click actions
  /// (e.g. `task_toggle`, `finance_add_expense`, `journal_new`).
  void Function(String action)? onAction;

  StreamSubscription<Uri?>? _clickSub;

  Future<void> init() async {
    if (!_supported) return;
    try {
      await HomeWidget.setAppGroupId('group.me.ihjas.missions');
    } catch (_) {/* Android no-op */}

    // Taps while the app is not running are applied by the background engine (same task code).
    try {
      await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    } catch (e) {
      debugPrint('[HomeWidget] background callback not registered: $e');
    }

    // Cold start: did the app launch from a widget tap?
    try {
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _dispatch(initial);
    } catch (e) {
      debugPrint('[HomeWidget] initiallyLaunched error: $e');
    }

    // Warm: handle taps while the process is alive.
    _clickSub?.cancel();
    _clickSub = HomeWidget.widgetClicked.listen(_dispatch);
  }

  void dispose() {
    _clickSub?.cancel();
    _clickSub = null;
  }

  void _dispatch(Uri? uri) {
    if (uri == null) return;
    final action = uri.queryParameters['action'];
    if (action == null || action.isEmpty) return;
    final cb = onAction;
    if (cb == null) return;
    // Defer so the callback fires after the current frame — important when
    // the dispatch happens during widget-tree construction at cold start.
    Future.microtask(() => cb(action));
  }

  // ── Pin Widget to Home Screen ──────────────────────────────────────────

  Future<bool> requestPinWidget(String providerName) async {
    if (!_supported) return false;
    try {
      await HomeWidget.requestPinWidget(
        androidName: providerName.split('.').last,
        qualifiedAndroidName: providerName,
      );
      return true;
    } catch (e) {
      debugPrint('[HomeWidget] requestPinWidget $providerName error: $e');
      return false;
    }
  }

  Future<bool> requestPinBus() => requestPinWidget(_providerBus);
  Future<bool> requestPinTask() => requestPinWidget(_providerRunning);
  Future<bool> requestPinDayPlan() => requestPinWidget(_providerDayPlan);
  Future<bool> requestPinFinance() => requestPinWidget(_providerFinance);
  Future<bool> requestPinJournal() => requestPinWidget(_providerJournal);
  Future<bool> requestPinGoals() => requestPinWidget(_providerGoals);

  // ── Publish ────────────────────────────────────────────────────────────

  Future<bool> publishTask({
    required bool hasTask,
    required String title,
    required String subtitle,
    required bool isRunning,
    required bool isCheckpoint,
    bool isPhoenix = false,
    String capacity = '',
    required int accumulatedSeconds,
    double progress = 0.0,
    DateTime? sessionStart,
    bool dayPlannerWidgetCheckable = false,
    List<ResolvedDayPlanItem> topFiveTasks = const [],
    List<ResolvedDayPlanItem> multitaskTasks = const [],
    String nextCheckpoint = '',
    int pausedAtMs = 0,
    bool clearPausedGrace = false,
  }) async {
    if (!_supported) return true;

    // The widget renders natively (crisp RemoteViews), so we only push data —
    // no Flutter-to-bitmap rasterization (that was the blurry, non-scaling
    // background). The day-plan checklist reads dp0..dp4 titles.
    final Map<String, Object> data = {
      'arcane.task.hasTask': hasTask,
      'arcane.task.title': title,
      'arcane.task.subtitle': subtitle,
      'arcane.task.isRunning': isRunning,
      'arcane.task.isCheckpoint': isCheckpoint,
      'arcane.task.isPhoenix': isPhoenix,
      'arcane.task.capacity': capacity,
      'arcane.task.accumulatedSec': accumulatedSeconds,
      'arcane.task.progressPct': (progress.clamp(0.0, 1.0) * 100).round(),
      'arcane.task.sessionStartMs': sessionStart?.millisecondsSinceEpoch ?? 0,
      // When the running session was halted (0 while running, -1 when finished). Avoid
      // overwriting an active pause grace timestamp with 0 during cold-start or headless writes.
      if (isRunning)
        'arcane.task.pausedAtMs': 0
      else if (clearPausedGrace)
        'arcane.task.pausedAtMs': -1
      else if (pausedAtMs > 0)
        'arcane.task.pausedAtMs': pausedAtMs,
      'arcane.task.dayPlannerWidgetCheckable': dayPlannerWidgetCheckable,
      'arcane.task.multitaskCount': multitaskTasks.length,
      // Checkpoint "CHECK NEXT" would tick (read by the floating task button's quick-add).
      'arcane.task.nextCheckpoint': nextCheckpoint,
    };
    for (var i = 0; i < 5; i++) {
      data['arcane.task.dp$i.title'] =
          i < topFiveTasks.length ? topFiveTasks[i].name : '';
    }
    for (var i = 0; i < 3; i++) {
      data['arcane.task.mt$i.title'] =
          i < multitaskTasks.length ? multitaskTasks[i].name : '';
      data['arcane.task.mt$i.parent'] =
          i < multitaskTasks.length ? multitaskTasks[i].parentName : '';
      data['arcane.task.mt$i.checkpoints'] = i < multitaskTasks.length
          ? '${multitaskTasks[i].completedCheckpoints}/${multitaskTasks[i].totalCheckpoints}'
          : '';
    }
    return _enqueueTask(data);
  }

  /// Rewrites only the keys the floating button trusts (running state and clock), leaving the
  /// title/preview keys alone. Used to undo a Widgets Studio preview push.
  Future<void> publishTimerState({
    required bool hasTask,
    required bool isRunning,
    required int accumulatedSeconds,
    required int sessionStartMs,
    required int pausedAtMs,
  }) async {
    if (!_supported) return;
    await _enqueueTask({
      'arcane.task.hasTask': hasTask,
      'arcane.task.isRunning': isRunning,
      'arcane.task.accumulatedSec': accumulatedSeconds,
      'arcane.task.sessionStartMs': sessionStartMs,
      if (isRunning)
        'arcane.task.pausedAtMs': 0
      else if (pausedAtMs > 0)
        'arcane.task.pausedAtMs': pausedAtMs,
    });
  }

  static const String _updatedAtKey = 'arcane.task.updatedAtMs';

  /// Snapshots waiting for the writer. Newer values replace older ones key by key, so a slow
  /// publish can never land on top of a newer one.
  Map<String, Object>? _queuedTask;
  Future<void>? _taskWriter;
  bool _lastTaskWriteOk = true;

  /// Serialises task publishes (latest wins, never interleaved). `updatedAtMs` is always written
  /// last: the floating button only re-syncs on that key, so it never reads a half-written state.
  /// Resolves to whether the latest write landed, so the publisher only marks a snapshot as
  /// published once the widget actually has it.
  Future<bool> _enqueueTask(Map<String, Object> data) async {
    _queuedTask = {...?_queuedTask, ...data};
    final writer = _taskWriter ??= () async {
      try {
        while (_queuedTask != null) {
          final next = _queuedTask!;
          _queuedTask = null;
          var ok = await _setAll(next);
          final stamped = await _setAll({_updatedAtKey: DateTime.now().millisecondsSinceEpoch});
          ok = ok && stamped;
          _lastTaskWriteOk = ok;
          await _refresh(_providerRunning);
          await _refresh(_providerDayPlan);
        }
      } finally {
        _taskWriter = null;
      }
    }();
    await writer;
    return _lastTaskWriteOk;
  }

  /// Theme the native widgets follow: the launcher's palette (light/dark, accent, panel, text), as ARGB ints.
  Future<bool> publishTheme({
    required bool light,
    required int accentArgb,
    required int surfaceArgb,
    required int textArgb,
    required int mutedArgb,
  }) async {
    if (!_supported) return true;
    final ok = await _setAll({
      'arcane.theme.light': light,
      'arcane.theme.accent': accentArgb,
      'arcane.theme.surface': surfaceArgb,
      'arcane.theme.text': textArgb,
      'arcane.theme.muted': mutedArgb,
    });
    for (final p in [
      _providerRunning,
      _providerDayPlan,
      _providerFinance,
      _providerJournal,
      _providerBus,
      _providerGoals
    ]) {
      await _refresh(p);
    }
    return ok;
  }

  Future<bool> publishFinance({
    required double balance,
    required double todaySpend,
    required double monthSpend,
    required int budgetPct,
  }) async {
    if (!_supported) return true;

    final ok = await _setAll({
      // SharedPreferences on Android can't store doubles via the plugin's
      // typed setters — write as strings, parse on the Kotlin side.
      'arcane.fin.balance': balance.toStringAsFixed(2),
      'arcane.fin.today': todaySpend.toStringAsFixed(2),
      'arcane.fin.mtd': monthSpend.toStringAsFixed(2),
      'arcane.fin.budgetPct': budgetPct,
      'arcane.fin.updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await _refresh(_providerFinance);
    return ok;
  }

  Future<bool> publishJournal({
    required int count,
    required bool wake,
    required bool morn,
    required bool aft,
    required bool eve,
    required bool night,
  }) async {
    if (!_supported) return true;

    final ok = await _setAll({
      'arcane.journal.count': count,
      'arcane.journal.wake': wake,
      'arcane.journal.morn': morn,
      'arcane.journal.aft': aft,
      'arcane.journal.eve': eve,
      'arcane.journal.night': night,
    });
    await _refresh(_providerJournal);
    return ok;
  }

  Future<bool> publishBus({
    required String origin,
    required String destination,
    required String nextTime,
    String nextSubStop = '',
    bool isOnBus = false,
    int speedKmh = 0,
    int minutesRemaining = -1,
    int progressPct = 0,
  }) async {
    if (!_supported) return true;

    final ok = await _setAll({
      'arcane.bus.origin': origin,
      'arcane.bus.destination': destination,
      'arcane.bus.nextTime': nextTime,
      'arcane.bus.nextSubStop': nextSubStop,
      'arcane.bus.isOnBus': isOnBus,
      'arcane.bus.speedKmh': speedKmh,
      'arcane.bus.minutesRemaining': minutesRemaining,
      'arcane.bus.progressPct': progressPct,
      'arcane.bus.updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await _refresh(_providerBus);
    // When transit state changes or active, also refresh RunningTaskWidget so
    // it can show the travel if placed on user's homescreen
    await _refresh(_providerRunning);
    return ok;
  }

  Future<bool> publishGoals({
    required int totalCount,
    required int completedCount,
    required int progressPct,
    required String scope,
    List<({String id, String title, bool isCompleted, String tag})> items =
        const [],
  }) async {
    if (!_supported) return true;

    final map = <String, Object>{
      'arcane.goals.totalCount': totalCount,
      'arcane.goals.completedCount': completedCount,
      'arcane.goals.progressPct': progressPct,
      'arcane.goals.scope': scope,
      'arcane.goals.updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    };

    for (int i = 0; i < 3; i++) {
      if (i < items.length) {
        final item = items[i];
        map['arcane.goals.g$i.id'] = item.id;
        map['arcane.goals.g$i.title'] = item.title;
        map['arcane.goals.g$i.isCompleted'] = item.isCompleted;
        map['arcane.goals.g$i.tag'] = item.tag;
      } else {
        map['arcane.goals.g$i.id'] = '';
        map['arcane.goals.g$i.title'] = '';
        map['arcane.goals.g$i.isCompleted'] = false;
        map['arcane.goals.g$i.tag'] = '';
      }
    }

    final ok = await _setAll(map);
    await _refresh(_providerGoals);
    return ok;
  }

  /// Writes each key. Returns false if any key failed, so callers retry instead of assuming success.
  Future<bool> _setAll(Map<String, Object> values) async {
    var ok = true;
    for (final e in values.entries) {
      try {
        await HomeWidget.saveWidgetData(e.key, e.value);
      } catch (err) {
        ok = false;
        debugPrint('[HomeWidget] save ${e.key}: $err');
      }
    }
    return ok;
  }

  Future<void> _refresh(String providerName) async {
    try {
      await HomeWidget.updateWidget(
        name: providerName,
        androidName: providerName.split('.').last,
        qualifiedAndroidName: providerName,
      );
    } catch (e) {
      debugPrint('[HomeWidget] update $providerName: $e');
    }
  }
}
