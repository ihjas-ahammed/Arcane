import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import 'package:intl/intl.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/utils/day_budget_helper.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/utils/task_calculations.dart';

/// Subscribes to AppProvider state changes and republishes the slices each
/// home-screen widget cares about. Designed to be cheap on each tick:
/// recomputes hashes and skips redundant publishes.
class HomeWidgetPublisher {
  HomeWidgetPublisher(this._provider) {
    _provider.addListener(_onProviderChanged);
  }

  final AppProvider _provider;

  String? _lastTaskKey;
  String? _lastFinanceKey;
  String? _lastJournalKey;
  String? _lastBusKey;

  void dispose() {
    _provider.removeListener(_onProviderChanged);
  }

  /// Force a republish — used immediately after init so the widget reflects
  /// state without waiting for the first user-driven mutation.
  Future<void> publishAll() async {
    await _publishTask(force: true);
    await _publishFinance(force: true);
    await _publishJournal(force: true);
    await _publishBus(force: true);
  }

  void _onProviderChanged() {
    // Cheap fire-and-forget — these are async but we don't need to await.
    // ignore: discarded_futures
    _publishTask();
    // ignore: discarded_futures
    _publishFinance();
    // ignore: discarded_futures
    _publishJournal();
    // ignore: discarded_futures
    _publishBus();
  }

  // ── Task ───────────────────────────────────────────────────────────────

  /// Mirror the schedule view's hero resolution: a running session always
  /// claims the hero spot; otherwise fall back to the first uncompleted item
  /// in today's day plan.
  ({
    MainTask? mainTask,
    SubTask? subTask,
    SubSubTask? checkpoint,
    bool isRunning,
    String? queueId,
  }) _resolveActiveTask() {
    final today = helper.getTodayDateString();
    final plan = List<String>.from(_provider.taskActions.getDayPlan(today));

    // Running session always claims the headline.
    final runningEntry = _provider.activeTimers.entries
        .firstWhereOrNull((e) => e.value.isRunning && e.value.type == 'subtask');
    if (runningEntry != null) {
      final m = _provider.mainTasks.firstWhereOrNull(
        (t) => t.id == runningEntry.value.mainTaskId && !t.isDeleted,
      );
      final s = m?.subTasks.firstWhereOrNull(
        (st) => st.id == runningEntry.key && !st.isDeleted,
      );
      if (m != null && s != null && !s.completed) {
        String? queueId;
        SubSubTask? cp;
        final inPlan = plan.firstWhereOrNull((p) {
          final parts = p.split('|');
          return parts.length >= 2 && parts[0] == m.id && parts[1] == s.id;
        });
        if (inPlan != null) {
          queueId = inPlan;
          final parts = inPlan.split('|');
          if (parts.length == 3) {
            cp = s.findCheckpoint(parts[2]);
          }
        }
        return (
          mainTask: m,
          subTask: s,
          checkpoint: cp,
          isRunning: true,
          queueId: queueId,
        );
      }
    }

    for (final idPair in plan) {
      final parts = idPair.split('|');
      if (parts.length < 2) continue;
      final m = _provider.mainTasks.firstWhereOrNull(
        (t) => t.id == parts[0] && !t.isDeleted,
      );
      final s = m?.subTasks.firstWhereOrNull(
        (st) => st.id == parts[1] && !st.isDeleted,
      );
      if (m == null || s == null || s.completed) continue;
      if (parts.length == 3) {
        final cp = s.findCheckpoint(parts[2]);
        if (cp == null || cp.completed) continue;
        return (mainTask: m, subTask: s, checkpoint: cp, isRunning: false, queueId: idPair);
      }
      return (mainTask: m, subTask: s, checkpoint: null, isRunning: false, queueId: idPair);
    }

    return (mainTask: null, subTask: null, checkpoint: null, isRunning: false, queueId: null);
  }

  Future<void> _publishTask({bool force = false}) async {
    final r = _resolveActiveTask();
    final s = r.subTask;
    final m = r.mainTask;
    final cp = r.checkpoint;

    final today = helper.getTodayDateString();
    final dayPlannerWidgetCheckable = _provider.settings.dayPlannerWidgetCheckable;

    final topFiveTasks = TaskCalculations.resolveTopFiveDayPlanTasks(
      mainTasks: _provider.mainTasks,
      plan: _provider.taskActions.getDayPlan(today),
    );

    final planRows = _provider.taskActions.getDayPlanRows(today);
    List<String> activeRowCompoundIds = [];
    if (s != null) {
      final activeSubId = s.id;
      for (final row in planRows) {
        if (row.any((id) {
          final parts = id.split('|');
          return parts.length >= 2 && parts[1] == activeSubId;
        })) {
          activeRowCompoundIds = row;
          break;
        }
      }
    }
    if (activeRowCompoundIds.isEmpty) {
      for (final row in planRows) {
        bool hasUncompleted = false;
        for (final id in row) {
          final parts = id.split('|');
          if (parts.length >= 2) {
            final candM = _provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
            final candS = candM?.subTasks.firstWhereOrNull((st) => st.id == parts[1] && !st.isDeleted);
            if (candS != null && !candS.completed) {
              if (parts.length == 3) {
                final candCp = candS.findCheckpoint(parts[2]);
                if (candCp != null && !candCp.completed) {
                  hasUncompleted = true;
                  break;
                }
              } else {
                hasUncompleted = true;
                break;
              }
            }
          }
        }
        if (hasUncompleted) {
          activeRowCompoundIds = row;
          break;
        }
      }
    }
    final multitaskTasks = TaskCalculations.resolveDayPlanItems(
      mainTasks: _provider.mainTasks,
      compoundIds: activeRowCompoundIds,
      activeTimers: _provider.activeTimers,
    );

    final title = s == null
        ? 'NO PLAN SET'
        : (cp != null ? cp.name : s.name);
    final subtitle = s == null
        ? 'QUEUE STANDBY'
        : (cp != null
            ? '${m?.name ?? ''} · ${s.name}'
            : (m?.name ?? ''));

    final activeTimer = s == null ? null : _provider.activeTimers[s.id];
    final accumulated = s == null ? 0.0 : TaskCalculations.getHistoricalTodaySeconds(s);
    final sessionStart = r.isRunning ? activeTimer?.startTime : null;
    final progress = s == null ? 0.0 : s.calculateProgress();

    // Buffer-aware day capacity ("planned / realistic"), shown on the widget.
    String capacity = '';
    final now = DateTime.now();
    final window = resolveDayWindow(_provider, now);
    final planned = _provider.taskActions.plannedMinutesForDay(today);
    final realistic = window.realisticMinutes(now);
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
      r.isRunning,
      cp != null,
      capacity,
      accumulated.toInt(),
      (progress * 100).round(),
      sessionStart?.millisecondsSinceEpoch ?? 0,
    ].join('|');
    if (!force && key == _lastTaskKey) return;
    _lastTaskKey = key;

    try {
      await HomeWidgetService.instance.publishTask(
        hasTask: s != null,
        title: title,
        subtitle: subtitle,
        isRunning: r.isRunning,
        isCheckpoint: cp != null,
        accumulatedSeconds: accumulated.toInt(),
        progress: progress,
        sessionStart: sessionStart,
        isPhoenix: false,
        capacity: capacity,
        dayPlannerWidgetCheckable: dayPlannerWidgetCheckable,
        topFiveTasks: topFiveTasks,
        multitaskTasks: multitaskTasks,
      );
    } catch (e) {
      debugPrint('[HomeWidget] publish task: $e');
    }
  }

  // ── Finance ────────────────────────────────────────────────────────────

  Future<void> _publishFinance({bool force = false}) async {
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

class _HomeWidgetHostState extends State<HomeWidgetHost> {
  HomeWidgetPublisher? _publisher;

  @override
  void initState() {
    super.initState();
    _publisher = HomeWidgetPublisher(widget.provider);
    // Initial publish on first frame so the home screen reflects state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _publisher?.publishAll();
    });
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
    _publisher?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
