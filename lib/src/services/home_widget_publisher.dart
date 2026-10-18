import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:intl/intl.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/settings/widgets_studio/widgets_studio_resolvers.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/services/stopped_task_memory.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/services/widget_action_router.dart';
import 'package:missions/src/utils/day_budget_helper.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/schedule/schedule.dart';

/// Subscribes to AppProvider state changes and republishes the slices each
/// home-screen widget cares about. Designed to be cheap on each tick:
/// recomputes hashes and skips redundant publishes.
class HomeWidgetPublisher {
  HomeWidgetPublisher(this._provider) {
    _isLauncherIsolate = _detectLauncherIsolate();
    _provider.addListener(_onProviderChanged);
    if (!_isLauncherIsolate) {
      _active = this;
    }
    _verifyLaunchMode();
    // Self-heal: the floating button and widgets trust the last published state, so re-assert
    // the truth regularly. A single missed or failed publish can no longer leave a stale
    // "running" clock ticking.
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      // The launcher palette can change without any app state changing.
      // ignore: discarded_futures
      _publishTheme();
      if (_isLauncherIsolate || !_isProviderReady) return;
      // Only the unchanged-key check runs on most beats; a forced rewrite wakes the floating
      // button, every widget and the foreground service, so it happens every few minutes only.
      _heartbeatCount++;
      final force = _heartbeatCount % _forceEveryBeats == 0;
      // ignore: discarded_futures
      _publishTask(force: force);
    });
  }

  static bool _detectLauncherIsolate() {
    try {
      final route = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
      return route == '/launcher' ||
          route.startsWith('/launcher/') ||
          route.startsWith('/launcher?');
    } catch (_) {
      return false;
    }
  }

  Future<void> _verifyLaunchMode() async {
    try {
      final mode = await const MethodChannel('arcane/launcher').invokeMethod<String>('getLaunchMode');
      if (mode == 'home') {
        _isLauncherIsolate = true;
        if (identical(_active, this)) _active = null;
      } else if (mode == 'app' && !_isLauncherIsolate) {
        _active = this;
      }
    } catch (_) {}
  }

  static const int _forceEveryBeats = 10; // 10 x 30 s = 5 min
  int _heartbeatCount = 0;

  Timer? _heartbeat;
  bool _isLauncherIsolate = false;
  bool _didInitialPublish = false;
  String? _lastRunningTimerSnapshot;

  static HomeWidgetPublisher? _active;

  /// Last running/paused task IDs so a paused task outside Today's Day Plan can still
  /// be displayed and resumed during the floating button's grace window.
  static ({String mainTaskId, String subTaskId})? lastPausedTaskIds;

  /// Re-asserts the live task state right away (used after a bubble/widget tap, or when a tap
  /// turned out to be stale). Only the task is rewritten: the theme and the other widgets are not
  /// time critical and must not delay it.
  static void republishNow() {
    final active = _active;
    if (active == null || active._isLauncherIsolate) return;
    active._publishDebounce?.cancel();
    // ignore: discarded_futures
    active._publishTask(force: true);
  }

  /// A running session ended for good (finished, not paused): the floating button must not
  /// linger in its paused state for the next planned task.
  static void noteSessionEnded() {
    lastPausedTaskIds = null;
    _active?._skipPausedGrace = true;
  }

  /// Puts the running state and clock back after a Widgets Studio preview push overwrote them,
  /// so the floating button keeps ticking while the user previews widgets.
  static Future<void> restoreLiveTimerState() async {
    final live = _active?._lastLiveTimer;
    if (live == null) return;
    await HomeWidgetService.instance.publishTimerState(
      hasTask: live.hasTask,
      isRunning: live.isRunning,
      accumulatedSeconds: live.accumulatedSeconds,
      sessionStartMs: live.sessionStartMs,
      pausedAtMs: live.pausedAtMs,
    );
  }

  ({bool hasTask, bool isRunning, int accumulatedSeconds, int sessionStartMs, int pausedAtMs})? _lastLiveTimer;
  bool _wasRunning = false;
  bool _skipPausedGrace = false;
  int _pausedAtMs = 0;
  String? _lastRunningMainTaskId;
  String? _lastRunningSubTaskId;

  final AppProvider _provider;

  String? _lastTaskKey;
  String? _lastFinanceKey;
  String? _lastJournalKey;
  String? _lastBusKey;
  String? _lastGoalsKey;
  String? _lastThemeKey;

  Timer? _publishDebounce;

  /// Compound ids of the day-plan items the widget last showed, slot by slot. Widget taps are
  /// checked against this so a stale widget can never tick a different task than the one on it.
  static List<String> lastPublishedPlanIds = const [];

  bool get _isProviderReady =>
      !_provider.authLoading &&
      !_provider.dataLoadInProgress &&
      _provider.currentUser != null &&
      _provider.localLoadError == null &&
      !_provider.cloudAttachRequired;

  String _runningTimersSignature() {
    final entries = _provider.activeTimers.entries
        .where((e) => e.value.isRunning && e.value.type == 'subtask')
        .map((e) => '${e.key}:${e.value.startTime.millisecondsSinceEpoch}')
        .toList()
      ..sort();
    return entries.join(',');
  }

  void dispose() {
    if (identical(_active, this)) _active = null;
    _publishDebounce?.cancel();
    _heartbeat?.cancel();
    _provider.removeListener(_onProviderChanged);
  }

  /// Force a republish — used immediately after init so the widget reflects
  /// state without waiting for the first user-driven mutation.
  Future<void> publishAll() async {
    await _publishTheme(force: true);
    if (_isLauncherIsolate || !_isProviderReady) return;
    _didInitialPublish = true;
    _lastRunningTimerSnapshot = _runningTimersSignature();
    await _publishTask(force: true);
    await _publishFinance(force: true);
    await _publishJournal(force: true);
    await _publishBus(force: true);
    await _publishGoals(force: true);
  }

  void onLifecycleChanged(AppLifecycleState state) {
    if (_isLauncherIsolate) {
      if (state == AppLifecycleState.resumed) {
        // ignore: discarded_futures
        _publishTheme();
      }
      return;
    }
    if (!_isProviderReady) return;
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _publishDebounce?.cancel();
      // ignore: discarded_futures
      _publishTask(force: state == AppLifecycleState.resumed);
    }
  }

  void _onProviderChanged() {
    if (_isLauncherIsolate) {
      _publishDebounce?.cancel();
      _publishDebounce = Timer(const Duration(milliseconds: 400), () {
        // ignore: discarded_futures
        _publishTheme();
      });
      return;
    }

    if (!_isProviderReady) return;

    WidgetActionRouter.instance.flushPending();

    if (!_didInitialPublish) {
      _didInitialPublish = true;
      // ignore: discarded_futures
      publishAll();
      return;
    }

    // If a timer just started or stopped, publish task state immediately without waiting
    // for the debounce so the floating timer and homescreen widget react instantaneously.
    final currentRunningSig = _runningTimersSignature();
    if (currentRunningSig != _lastRunningTimerSnapshot) {
      _lastRunningTimerSnapshot = currentRunningSig;
      // ignore: discarded_futures
      _publishTask(force: true);
    }

    // Coalesce bursts of changes into one publish pass.
    _publishDebounce?.cancel();
    _publishDebounce = Timer(const Duration(milliseconds: 250), () {
      // ignore: discarded_futures
      _publishTheme();
      // ignore: discarded_futures
      _publishTask();
      // ignore: discarded_futures
      _publishFinance();
      // ignore: discarded_futures
      _publishJournal();
      // ignore: discarded_futures
      _publishBus();
      // ignore: discarded_futures
      _publishGoals();
    });
  }

  // ── Theme ──────────────────────────────────────────────────────────────

  Future<void> _publishTheme({bool force = false}) async {
    try {
      // The launcher's own palette, not the protocol colour: widgets should look like the launcher.
      final light = LauncherTheme.isLight;
      final accent = LauncherTheme.accent.toARGB32();
      final surface = LauncherTheme.panel.toARGB32();
      final text = LauncherTheme.text.toARGB32();
      final muted = LauncherTheme.muted.toARGB32();
      final key = '$light|$accent|$surface|$text|$muted';
      if (!force && key == _lastThemeKey) return;
      _lastThemeKey = key;
      await HomeWidgetService.instance.publishTheme(
        light: light,
        accentArgb: accent,
        surfaceArgb: surface,
        textArgb: text,
        mutedArgb: muted,
      );
    } catch (e) {
      debugPrint('[HomeWidget] publish theme: $e');
    }
  }

  // ── Task ───────────────────────────────────────────────────────────────

  Future<void> _publishTask({bool force = false}) async {
    if (_isLauncherIsolate || !_isProviderReady) return;
    try {
      await _publishTaskInner(force: force);
    } catch (e, st) {
      debugPrint('[HomeWidget] publish task failed: $e\n$st');
      await _publishTaskFallback();
    }
  }

  /// Minimal, can't-fail-on-planning-data publish: just the true running state, so the floating
  /// button and widgets never keep showing a timer that has stopped.
  Future<void> _publishTaskFallback() async {
    try {
      final running = _provider.activeTimers.entries
          .firstWhereOrNull((e) => e.value.isRunning && e.value.type == 'subtask');
      MainTask? m;
      SubTask? s;
      if (running != null) {
        m = _provider.mainTasks.firstWhereOrNull((t) => t.id == running.value.mainTaskId && !t.isDeleted);
        s = m?.subTasks.firstWhereOrNull((st) => st.id == running.key && !st.isDeleted);
      }
      final isRunning = s != null && !s.completed;
      final clearPausedGrace = _skipPausedGrace;
      _trackPausedAt(isRunning);
      await HomeWidgetService.instance.publishTask(
        hasTask: isRunning,
        title: isRunning ? s.name : 'NO PLAN SET',
        subtitle: isRunning ? (m?.name ?? '') : 'QUEUE STANDBY',
        isRunning: isRunning,
        isCheckpoint: false,
        accumulatedSeconds: isRunning ? TaskCalculations.getHistoricalTodaySeconds(s, _provider.mainTasks).toInt() : 0,
        sessionStart: isRunning ? _clampStart(running!.value.startTime) : null,
        pausedAtMs: _pausedAtMs,
        clearPausedGrace: clearPausedGrace,
      );
    } catch (e) {
      debugPrint('[HomeWidget] fallback publish failed: $e');
    }
  }

  /// `TimerActions.startTimer` stamps the start one second in the future so back-to-back sessions
  /// never overlap. The published clock must not start in the future, or it freezes at 00:00.
  DateTime _clampStart(DateTime start) {
    final now = DateTime.now();
    return start.isAfter(now) ? now : start;
  }

  /// Remembers when a running session was halted so the floating button can stay for a grace
  /// period. 0 means running, or never seen running in this process.
  void _trackPausedAt(bool isRunning) {
    if (isRunning) {
      _pausedAtMs = 0;
      _skipPausedGrace = false;
    } else if (_wasRunning) {
      _pausedAtMs = _skipPausedGrace ? 0 : DateTime.now().millisecondsSinceEpoch;
      if (_skipPausedGrace) {
        _lastRunningMainTaskId = null;
        _lastRunningSubTaskId = null;
        lastPausedTaskIds = null;
      }
      _skipPausedGrace = false;
    } else if (_skipPausedGrace) {
      _pausedAtMs = 0;
      _lastRunningMainTaskId = null;
      _lastRunningSubTaskId = null;
      lastPausedTaskIds = null;
      _skipPausedGrace = false;
    }
    _wasRunning = isRunning;
  }

  Future<void> _publishTaskInner({bool force = false}) async {
    final now = DateTime.now();

    // Use ScheduleHeroStateResolver so the homescreen widget and the Schedule screen's
    // ScheduleHeroWidget always resolve the exact same mission, checkpoint, and queue state.
    var heroState = ScheduleHeroStateResolver.resolve(
      provider: _provider,
      selectedDate: now,
    );
    if (heroState.nextSubTask == null && StoppedTaskMemory.subTaskId != null) {
      StoppedTaskMemory.subTaskId = null;
      heroState = ScheduleHeroStateResolver.resolve(
        provider: _provider,
        selectedDate: now,
      );
    }

    MainTask? m = heroState.nextMainTask;
    SubTask? s = heroState.nextSubTask;
    SubSubTask? cp = heroState.nextCheckpoint;
    final bool isRunning = heroState.isRunning;

    if (isRunning && m != null && s != null) {
      _lastRunningMainTaskId = m.id;
      _lastRunningSubTaskId = s.id;
      lastPausedTaskIds = (mainTaskId: m.id, subTaskId: s.id);
    }

    final bool clearPausedGrace = _skipPausedGrace;
    _trackPausedAt(isRunning);

    // If a task outside Today's Day Plan was running and just paused, keep it as the active
    // paused task during the grace window so the floating button and widget don't vanish.
    if (!isRunning && s == null && _pausedAtMs > 0 && _lastRunningMainTaskId != null && _lastRunningSubTaskId != null) {
      final lastM = _provider.mainTasks.firstWhereOrNull(
        (t) => t.id == _lastRunningMainTaskId && !t.isDeleted,
      );
      final lastS = lastM?.subTasks.firstWhereOrNull(
        (st) => st.id == _lastRunningSubTaskId && !st.isDeleted && !st.completed,
      );
      if (lastM != null && lastS != null) {
        m = lastM;
        s = lastS;
        cp = TaskCalculations.nextCheckpoint(lastS);
        lastPausedTaskIds = (mainTaskId: lastM.id, subTaskId: lastS.id);
      }
    }

    final dayPlannerWidgetCheckable = _provider.settings.dayPlannerWidgetCheckable;
    final topFiveTasks = heroState.topFiveTasks;
    lastPublishedPlanIds = topFiveTasks.map((t) => t.compoundId).toList();
    final multitaskTasks = heroState.multitaskItems;

    final title = s == null
        ? 'NO PLAN SET'
        : (cp != null ? cp.name : s.name);
    final subtitle = s == null
        ? 'QUEUE STANDBY'
        : (cp != null
            ? '${m?.name ?? ''} · ${s.name}'
            : (m?.name ?? ''));

    final nextCheckpoint = s == null ? '' : (cp?.name ?? TaskCalculations.nextCheckpoint(s)?.name ?? '');
    final accumulated = s == null
        ? 0.0
        : (s.id == heroState.nextSubTask?.id
            ? heroState.accumulatedTodaySeconds
            : TaskCalculations.getHistoricalTodaySeconds(s, _provider.mainTasks));
    final rawStart = isRunning ? heroState.sessionStart : null;
    final sessionStart = rawStart == null ? null : _clampStart(rawStart);
    final progress = s == null ? 0.0 : s.calculateProgress();

    // Buffer-aware day capacity ("planned / realistic"), shown on the widget.
    String capacity = '';
    final planned = heroState.plannedMin;
    final realistic = heroState.realisticMin;
    if (realistic > 0) {
      capacity = '${formatMinutes(planned)} / ${formatMinutes(realistic)}';
    }

    final key = [
      dayPlannerWidgetCheckable,
      topFiveTasks.map((t) => '${t.compoundId}|${t.name}').join(','),
      multitaskTasks.map((t) => '${t.compoundId}|${t.name}|${t.isRunning}').join(','),
      s != null,
      title,
      subtitle,
      isRunning,
      cp != null,
      capacity,
      accumulated.toInt(),
      (progress * 100).round(),
      sessionStart?.millisecondsSinceEpoch ?? 0,
      nextCheckpoint,
    ].join('|');
    if (!force && key == _lastTaskKey) return;
    _lastTaskKey = key;

    _lastLiveTimer = (
      hasTask: s != null,
      isRunning: isRunning,
      accumulatedSeconds: accumulated.toInt(),
      sessionStartMs: sessionStart?.millisecondsSinceEpoch ?? 0,
      pausedAtMs: _pausedAtMs,
    );

    try {
      await HomeWidgetService.instance.publishTask(
        hasTask: s != null,
        title: title,
        subtitle: subtitle,
        isRunning: isRunning,
        isCheckpoint: cp != null,
        accumulatedSeconds: accumulated.toInt(),
        progress: progress,
        sessionStart: sessionStart,
        isPhoenix: false,
        capacity: capacity,
        dayPlannerWidgetCheckable: dayPlannerWidgetCheckable,
        topFiveTasks: topFiveTasks,
        multitaskTasks: multitaskTasks,
        nextCheckpoint: nextCheckpoint,
        pausedAtMs: _pausedAtMs,
        clearPausedGrace: clearPausedGrace,
      );
    } catch (e) {
      debugPrint('[HomeWidget] publish task: $e');
    }
  }

  // ── Finance ────────────────────────────────────────────────────────────

  Future<void> _publishFinance({bool force = false}) async {
    if (_isLauncherIsolate || !_isProviderReady) return;
    final balance = _provider.financeActions.currentBalance;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final thirtyAgo = today.subtract(const Duration(days: 29));

    var todaySpend = 0.0;
    var monthSpend = 0.0;
    var expense30d = 0.0;

    for (final t in _provider.transactions) {
      if (t.isIncome) continue;
      final ts = t.timestamp;
      if (ts.year == today.year && ts.month == today.month && ts.day == today.day) {
        todaySpend += t.amount;
      }
      if (!ts.isBefore(monthStart)) monthSpend += t.amount;
      if (!ts.isBefore(thirtyAgo)) expense30d += t.amount;
    }

    final avg30d = expense30d / 30.0;
    final monthBudget = avg30d * 30;
    final monthPct = monthBudget > 0 ? (monthSpend / monthBudget) * 100 : 0.0;

    final budgetPct = monthPct.clamp(0.0, 999.0).round();

    final key = [
      balance.toStringAsFixed(2),
      todaySpend.toStringAsFixed(2),
      monthSpend.toStringAsFixed(2),
      budgetPct,
    ].join('|');
    if (!force && key == _lastFinanceKey) return;
    _lastFinanceKey = key;

    try {
      await HomeWidgetService.instance.publishFinance(
        balance: balance,
        todaySpend: todaySpend,
        monthSpend: monthSpend,
        budgetPct: budgetPct,
      );
    } catch (e) {
      debugPrint('[HomeWidget] publish finance: $e');
    }
  }

  // ── Journal ────────────────────────────────────────────────────────────

  Future<void> _publishJournal({bool force = false}) async {
    if (_isLauncherIsolate || !_isProviderReady) return;
    final logs = _provider.reflectionLogs;
    final now = DateTime.now();
    final todayLogs = logs.where((log) {
      return log.timestamp.year == now.year &&
          log.timestamp.month == now.month &&
          log.timestamp.day == now.day;
    }).toList();

    bool wake = false;
    bool morn = false;
    bool aft = false;
    bool eve = false;
    bool night = false;

    for (final log in todayLogs) {
      final h = log.timestamp.hour;
      if (h >= 0 && h < 8) {
        wake = true;
      } else if (h >= 8 && h < 12) {
        morn = true;
      } else if (h >= 12 && h < 16) {
        aft = true;
      } else if (h >= 16 && h < 19) {
        eve = true;
      } else if (h >= 19 && h <= 23) {
        night = true;
      }
    }

    // Auto-fill logic matching klogbook / reflection progress widget
    if (night) {
      eve = true;
      aft = true;
      morn = true;
      wake = true;
    } else if (eve) {
      aft = true;
      morn = true;
      wake = true;
    } else if (aft) {
      morn = true;
      wake = true;
    } else if (morn) {
      wake = true;
    }

    final key = [
      logs.length,
      wake,
      morn,
      aft,
      eve,
      night,
    ].join('|');
    if (!force && key == _lastJournalKey) return;
    _lastJournalKey = key;

    try {
      await HomeWidgetService.instance.publishJournal(
        count: logs.length,
        wake: wake,
        morn: morn,
        aft: aft,
        eve: eve,
        night: night,
      );
    } catch (e) {
      debugPrint('[HomeWidget] publish journal: $e');
    }
  }

  // ── Bus ────────────────────────────────────────────────────────────────
  Future<void> _publishBus({bool force = false}) async {
    if (_isLauncherIsolate || !_isProviderReady) return;
    try {
      final live = BusLocationService.instance.currentState;
      final settings = _provider.settings;

      // 1. Resolve Stops & Routes (Custom or default)
      List<BusStop> stops = DefaultBusNetwork.stops;
      if (settings.customBusStopsJson != null && settings.customBusStopsJson!.isNotEmpty) {
        stops = settings.customBusStopsJson!.map((e) => BusStop.fromJson(e)).toList();
      }

      List<BusRoute> routes = DefaultBusNetwork.getRoutes();
      if (settings.customBusRoutesJson != null && settings.customBusRoutesJson!.isNotEmpty) {
        routes = settings.customBusRoutesJson!.map((e) => BusRoute.fromJson(e)).toList();
      }

      // 2. Resolve focused Origin and Destination
      String origin = 'S.S College';
      String destination = 'Edavannappara';

      if (live.activeRoute != null) {
        origin = live.activeRoute!.originId;
        destination = live.activeRoute!.destinationId;
        final origStop = stops.firstWhereOrNull((s) => s.id == origin || s.name.toLowerCase() == origin.toLowerCase());
        final destStop = stops.firstWhereOrNull((s) => s.id == destination || s.name.toLowerCase() == destination.toLowerCase());
        if (origStop != null) origin = origStop.name;
        if (destStop != null) destination = destStop.name;
      } else if (settings.lastSelectedBusOrigin != null && settings.lastSelectedBusDestination != null) {
        origin = settings.lastSelectedBusOrigin!;
        destination = settings.lastSelectedBusDestination!;
      }

      final normOrigin = origin.toLowerCase().trim();
      final normDest = destination.toLowerCase().trim();

      // 3. Find directional departures for this route
      List<String> departures = const [];

      // Check custom schedule map
      if (settings.customBusSchedules != null && settings.customBusSchedules!.isNotEmpty) {
        for (final k in settings.customBusSchedules!.keys) {
          if (k.toLowerCase().trim() == normOrigin) {
            for (final k2 in settings.customBusSchedules![k]!.keys) {
              if (k2.toLowerCase().trim() == normDest && settings.customBusSchedules![k]![k2]!.isNotEmpty) {
                departures = settings.customBusSchedules![k]![k2]!;
                break;
              }
            }
          }
        }
      }

      // Check loaded routes directionally
      if (departures.isEmpty) {
        final activeR = routes.firstWhereOrNull((r) {
          final rOrig = stops.firstWhereOrNull((s) => s.id.toLowerCase() == r.originId.toLowerCase())?.name ?? r.originId;
          final rDest = stops.firstWhereOrNull((s) => s.id.toLowerCase() == r.destinationId.toLowerCase())?.name ?? r.destinationId;
          if (rOrig.toLowerCase().trim() == normOrigin && rDest.toLowerCase().trim() == normDest) return true;
          if (r.name.contains('→')) {
            final parts = r.name.split('→');
            if (parts.length == 2 && parts[0].trim().toLowerCase() == normOrigin && parts[1].trim().toLowerCase() == normDest) return true;
          }
          return false;
        });
        if (activeR != null && activeR.departures.isNotEmpty) {
          departures = activeR.departures;
        }
      }

      if (departures.isEmpty) {
        final defaultMap = DefaultBusNetwork.getDefaultScheduleMap();
        for (final k in defaultMap.keys) {
          if (k.toLowerCase().trim() == normOrigin) {
            for (final k2 in defaultMap[k]!.keys) {
              if (k2.toLowerCase().trim() == normDest && defaultMap[k]![k2]!.isNotEmpty) {
                departures = defaultMap[k]![k2]!;
                break;
              }
            }
          }
        }
      }

      // 4. Calculate next bus
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;
      String nextTime = '08:15 AM';
      int smallestDiff = 99999;

      for (final t in departures) {
        try {
          final parsed = DateFormat("hh:mm a").parse(t);
          final busMin = parsed.hour * 60 + parsed.minute;
          final diff = busMin - currentMinutes;
          if (diff >= 0 && diff < smallestDiff) {
            smallestDiff = diff;
            nextTime = t;
          }
        } catch (_) {}
      }

      if (smallestDiff == 99999 && departures.isNotEmpty) {
        nextTime = departures.first;
        try {
          final parsed = DateFormat("hh:mm a").parse(nextTime);
          final busMin = parsed.hour * 60 + parsed.minute;
          smallestDiff = (busMin + 24 * 60) - currentMinutes;
        } catch (_) {}
      }

      final formOrigin = DefaultBusNetwork.formatPlaceName(origin);
      final formDest = DefaultBusNetwork.formatPlaceName(destination);

      final key = [
        formOrigin,
        formDest,
        nextTime,
        live.isOnBus,
        live.nextSubStop?.name ?? '',
        live.speedKmh.round(),
        smallestDiff,
      ].join('|');

      if (!force && key == _lastBusKey) return;
      _lastBusKey = key;

      await HomeWidgetService.instance.publishBus(
        origin: formOrigin,
        destination: formDest,
        nextTime: nextTime,
        nextSubStop: live.nextSubStop?.name ?? '',
        isOnBus: live.isOnBus,
        speedKmh: live.speedKmh.round(),
        minutesRemaining: smallestDiff < 9999 ? smallestDiff : -1,
      );
    } catch (e) {
      debugPrint('[HomeWidget] publish bus: $e');
    }
  }

  // ── Goals ─────────────────────────────────────────────────────────────

  Future<void> _publishGoals({bool force = false}) async {
    if (_isLauncherIsolate || !_isProviderReady) return;
    final live = WidgetsStudioResolvers.resolveLiveGoals(_provider);
    final topGoals = live.goals.take(3).toList();

    final key = [
      live.scope.name,
      live.totalCount,
      live.completedCount,
      for (final g in topGoals) '${g.id}:${g.getIsEffectiveCompleted()}:${g.title}:${g.currentValue}:${g.targetValue}',
    ].join('|');

    if (!force && key == _lastGoalsKey) return;
    _lastGoalsKey = key;

    final items = <({String id, String title, bool isCompleted, String tag})>[];
    for (final g in topGoals) {
      final isDone = g.getIsEffectiveCompleted();
      final subTotal = g.subChecklist.length;
      final subDone = g.subChecklist.where((s) => s.isCompleted).length;

      String tag = '';
      if (g.metricType == GoalMetricType.timeCounter) {
        tag = '${g.currentValue.toInt()}/${g.targetValue.toInt()}m';
      } else if (subTotal > 0) {
        tag = '$subDone/$subTotal';
      } else if (g.metricType == GoalMetricType.counter) {
        tag = '${g.currentValue.toInt()}/${g.targetValue.toInt()}';
      }

      items.add((
        id: g.id,
        title: g.title,
        isCompleted: isDone,
        tag: tag,
      ));
    }

    try {
      await HomeWidgetService.instance.publishGoals(
        totalCount: live.totalCount,
        completedCount: live.completedCount,
        progressPct: (live.progress * 100).toInt(),
        scope: live.scope == GoalScope.weekly ? 'weekly' : 'daily',
        items: items,
      );
    } catch (e) {
      debugPrint('[HomeWidget] publish goals: $e');
    }
  }
}

/// Convenience: a StatefulWidget that owns a publisher tied to the lifecycle
/// of the widget tree (so it tears down on logout / app-state-reset).
class HomeWidgetHost extends StatefulWidget {
  const HomeWidgetHost({super.key, required this.provider, required this.child});

  final AppProvider provider;
  final Widget child;

  @override
  State<HomeWidgetHost> createState() => _HomeWidgetHostState();
}

class _HomeWidgetHostState extends State<HomeWidgetHost> with WidgetsBindingObserver {
  HomeWidgetPublisher? _publisher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _publisher = HomeWidgetPublisher(widget.provider);
    // Initial publish on first frame so the home screen reflects state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _publisher?.publishAll();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _publisher?.onLifecycleChanged(state);
  }

  @override
  void didUpdateWidget(covariant HomeWidgetHost old) {
    super.didUpdateWidget(old);
    if (old.provider != widget.provider) {
      _publisher?.dispose();
      _publisher = HomeWidgetPublisher(widget.provider);
      _publisher?.publishAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _publisher?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
