import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/journaling/quick_therapy_screen.dart';
import 'package:missions/src/screens/reflections_archive_screen.dart';
import 'package:missions/src/widgets/dialogs/add_transaction_dialog.dart';
import 'package:missions/src/widgets/screens/reflection_editor_screen.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/utils/global_toast.dart';

/// Tab indexes in HomeScreen — kept in sync with `_viewTitles` over there.
class HomeTab {
  static const missions = 0;
  static const schedule = 1;
  static const biometrics = 2;
  static const analytics = 3;
  static const wallet = 4;
}

/// Singleton routing helper. The home-widget click stream resolves to a
/// string action; this class turns that action into provider mutations,
/// navigator pushes, and tab switches.
class WidgetActionRouter {
  WidgetActionRouter._();
  static final WidgetActionRouter instance = WidgetActionRouter._();

  /// Wired into MaterialApp so the router can navigate from anywhere.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// HomeScreen listens to this and switches its IndexedStack on change.
  final ValueNotifier<int?> tabRequest = ValueNotifier<int?>(null);

  /// Buffer for actions that arrive before MaterialApp has a navigator
  /// (cold-start case). Flushed once `flushPending` is called.
  String? _pending;

  void handle(String action) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      // App hasn't built MaterialApp yet — stash for later.
      _pending = action;
      return;
    }
    _dispatch(ctx, action);
  }

  /// Call after MaterialApp builds to drain any cold-start action.
  void flushPending() {
    final p = _pending;
    if (p == null) return;
    _pending = null;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    _dispatch(ctx, p);
  }

  void _dispatch(BuildContext ctx, String action) {
    final provider = Provider.of<AppProvider>(ctx, listen: false);
    switch (action) {
      case 'task_toggle':
        _taskToggle(provider);
        _gotoTab(HomeTab.schedule);
        break;
      case 'task_finish':
        _taskFinish(provider);
        _gotoTab(HomeTab.schedule);
        break;
      case 'task_check_next':
        _taskCheckNext(provider);
        break;
      case 'task_open':
      case 'task_open_plan':
        _gotoTab(HomeTab.schedule);
        break;

      case 'finance_open':
        _gotoTab(HomeTab.wallet);
        break;
      case 'finance_add_income':
        _gotoTab(HomeTab.wallet);
        _showAfterNav((c) => showDialog(
              context: c,
              builder: (_) => const AddTransactionDialog(isIncome: true),
            ));
        break;
      case 'finance_add_expense':
        _gotoTab(HomeTab.wallet);
        _showAfterNav((c) => showDialog(
              context: c,
              builder: (_) => const AddTransactionDialog(isIncome: false),
            ));
        break;

      case 'journal_new':
        _push((_) => ReflectionEditorScreen(
              dateStr: helper.getTodayDateString(),
            ));
        break;
      case 'journal_open_latest':
        final latest = _latestReflection(provider);
        if (latest != null) {
          _push((_) => ReflectionEditorScreen(
                initialLog: latest,
                dateStr: helper.getTodayDateString(),
              ));
        } else {
          _push((_) => const QuickTherapyScreen());
        }
        break;
      case 'journal_archive':
        _push((_) => const ReflectionsArchiveScreen());
        break;

      default:
        debugPrint('[WidgetActionRouter] unknown action: $action');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  void _gotoTab(int index) {
    // Pop back to root so the tab change is visible.
    final nav = navigatorKey.currentState;
    nav?.popUntil((r) => r.isFirst);
    tabRequest.value = index;
  }

  void _push(WidgetBuilder builder) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(builder: builder));
  }

  void _showAfterNav(void Function(BuildContext) cb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = navigatorKey.currentContext;
      if (c != null) cb(c);
    });
  }

  void _taskToggle(AppProvider provider) {
    final r = _resolveActive(provider);
    final m = r.mainTask;
    final s = r.subTask;
    if (m == null || s == null) return;
    if (r.isRunning) {
      provider.pauseTimer(s.id);
      provider.logTimerAndReset(s.id);
    } else {
      provider.startTimer(s.id, 'subtask', m.id);
    }
  }

  void _taskCheckNext(AppProvider provider) {
    final r = _resolveActive(provider);
    final m = r.mainTask;
    final s = r.subTask;
    if (m == null || s == null) return;
    final cp = TaskCalculations.nextCheckpoint(s);
    if (cp == null) {
      showGlobalToast('No checkpoints left to check');
      return;
    }
    provider.taskActions.completeSubSubtask(m.id, s.id, cp.id);
    showGlobalToast('✓ Checked: ${cp.name}');
  }

  void _taskFinish(AppProvider provider) {
    final r = _resolveActive(provider);
    final m = r.mainTask;
    final s = r.subTask;
    final cp = r.checkpoint;
    final queueId = r.queueId;
    if (m == null || s == null) return;

    if (cp != null) {
      provider.taskActions.completeSubSubtask(m.id, s.id, cp.id);
    } else {
      provider.taskActions.completeSubtask(m.id, s.id);
    }

    if (queueId != null) {
      final plan = List<String>.from(
        provider.taskActions.getDayPlan(helper.getTodayDateString()),
      )..remove(queueId);
      provider.taskActions.updateDayPlan(helper.getTodayDateString(), plan);
    }
  }

  ({
    MainTask? mainTask,
    SubTask? subTask,
    SubSubTask? checkpoint,
    bool isRunning,
    String? queueId,
  }) _resolveActive(AppProvider provider) {
    final plan = List<String>.from(
      provider.taskActions.getDayPlan(helper.getTodayDateString()),
    );

    final runningEntry = provider.activeTimers.entries
        .firstWhereOrNull((e) => e.value.isRunning && e.value.type == 'subtask');
    if (runningEntry != null) {
      final m = provider.mainTasks.firstWhereOrNull(
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
        return (mainTask: m, subTask: s, checkpoint: cp, isRunning: true, queueId: queueId);
      }
    }

    for (final idPair in plan) {
      final parts = idPair.split('|');
      if (parts.length < 2) continue;
      final m = provider.mainTasks.firstWhereOrNull(
        (t) => t.id == parts[0] && !t.isDeleted,
      );
      final s = m?.subTasks.firstWhereOrNull(
        (st) => st.id == parts[1] && !st.isDeleted,
      );
      if (m == null || s == null || s.completed) continue;
      if (parts.length == 3) {
        final cp = s.subSubTasks.firstWhereOrNull((c) => c.id == parts[2]);
        if (cp == null || cp.completed) continue;
        return (mainTask: m, subTask: s, checkpoint: cp, isRunning: false, queueId: idPair);
      }
      return (mainTask: m, subTask: s, checkpoint: null, isRunning: false, queueId: idPair);
    }

    return (mainTask: null, subTask: null, checkpoint: null, isRunning: false, queueId: null);
  }

  ReflectionLog? _latestReflection(AppProvider provider) {
    final list = provider.reflectionLogs;
    if (list.isEmpty) return null;
    final sorted = List.of(list)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.first;
  }
}
