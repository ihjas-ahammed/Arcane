import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
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

  void dispose() {
    _provider.removeListener(_onProviderChanged);
  }

  /// Force a republish — used immediately after init so the widget reflects
  /// state without waiting for the first user-driven mutation.
  Future<void> publishAll() async {
    await _publishTask(force: true);
    await _publishFinance(force: true);
    await _publishJournal(force: true);
  }

  void _onProviderChanged() {
    // Cheap fire-and-forget — these are async but we don't need to await.
    // ignore: discarded_futures
    _publishTask();
    // ignore: discarded_futures
    _publishFinance();
    // ignore: discarded_futures
    _publishJournal();
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
    bool isPhoenix,
    String? queueId,
  }) _resolveActiveTask() {
    final today = helper.getTodayDateString();
    final plan = List<String>.from(_provider.taskActions.getDayPlan(today));
    final phoenixId = _provider.taskActions.getPhoenixId(today);

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
            cp = s.subSubTasks.firstWhereOrNull((c) => c.id == parts[2]);
          }
        }
        return (
          mainTask: m,
          subTask: s,
          checkpoint: cp,
          isRunning: true,
          isPhoenix: queueId != null && queueId == phoenixId,
          queueId: queueId,
        );
      }
    }

    // The Phoenix outranks the rest of the queue when nothing is running.
    if (phoenixId != null) {
      final parts = phoenixId.split('|');
      if (parts.length >= 2) {
        final m = _provider.mainTasks
            .firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
        final s = m?.subTasks
            .firstWhereOrNull((st) => st.id == parts[1] && !st.isDeleted);
        if (m != null && s != null && !s.completed) {
          if (parts.length == 3) {
            final cp = s.subSubTasks.firstWhereOrNull((c) => c.id == parts[2]);
            if (cp != null && !cp.completed) {
              return (mainTask: m, subTask: s, checkpoint: cp, isRunning: false, isPhoenix: true, queueId: phoenixId);
            }
          } else {
            return (mainTask: m, subTask: s, checkpoint: null, isRunning: false, isPhoenix: true, queueId: phoenixId);
          }
        }
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
        final cp = s.subSubTasks.firstWhereOrNull((c) => c.id == parts[2]);
        if (cp == null || cp.completed) continue;
        return (mainTask: m, subTask: s, checkpoint: cp, isRunning: false, isPhoenix: false, queueId: idPair);
      }
      return (mainTask: m, subTask: s, checkpoint: null, isRunning: false, isPhoenix: false, queueId: idPair);
    }

    return (mainTask: null, subTask: null, checkpoint: null, isRunning: false, isPhoenix: false, queueId: null);
  }

  Future<void> _publishTask({bool force = false}) async {
    final r = _resolveActiveTask();
    final s = r.subTask;
    final m = r.mainTask;
    final cp = r.checkpoint;

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
    if (s != null) {
      final now = DateTime.now();
      final window = resolveDayWindow(_provider, now);
      final planned = _provider.taskActions
          .plannedMinutesForDay(helper.getTodayDateString());
      final realistic = window.realisticMinutes(now);
      if (realistic > 0) {
        capacity = '${formatMinutes(planned)} / ${formatMinutes(realistic)}';
      }
    }

    final key = [
      s != null,
      title,
      subtitle,
      r.isRunning,
      r.isPhoenix,
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
        isPhoenix: r.isPhoenix,
        capacity: capacity,
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
