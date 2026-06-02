import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:missions/src/widgets/homescreen_widgets.dart';

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

  static const String _providerRunning = 'me.ihjas.missions.widgets.RunningTaskWidget';
  static const String _providerFinance = 'me.ihjas.missions.widgets.FinanceWidget';
  static const String _providerJournal = 'me.ihjas.missions.widgets.JournalWidget';

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

  // ── Publish ────────────────────────────────────────────────────────────

  Future<void> publishTask({
    required bool hasTask,
    required String title,
    required String subtitle,
    required bool isRunning,
    required bool isCheckpoint,
    required int accumulatedSeconds,
    DateTime? sessionStart,
  }) async {
    if (!_supported) return;
    try {
      await HomeWidget.renderFlutterWidget(
        RunningTaskHomeWidget(
          hasTask: hasTask,
          title: title,
          subtitle: subtitle,
          isRunning: isRunning,
          isCheckpoint: isCheckpoint,
          accumulatedSeconds: accumulatedSeconds,
        ),
        key: 'arcane.task.image',
        logicalSize: const Size(400, 200),
      );
    } catch (e) {
      debugPrint('[HomeWidget] renderTask error: $e');
    }

    await _setAll({
      'arcane.task.hasTask': hasTask,
      'arcane.task.title': title,
      'arcane.task.subtitle': subtitle,
      'arcane.task.isRunning': isRunning,
      'arcane.task.isCheckpoint': isCheckpoint,
      'arcane.task.accumulatedSec': accumulatedSeconds,
      'arcane.task.sessionStartMs': sessionStart?.millisecondsSinceEpoch ?? 0,
      'arcane.task.updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await _refresh(_providerRunning);
  }

  Future<void> publishFinance({
    required double balance,
    required double todaySpend,
    required double monthSpend,
    required int budgetPct,
  }) async {
    if (!_supported) return;
    try {
      await HomeWidget.renderFlutterWidget(
        FinanceHomeWidget(
          balance: balance,
          todaySpend: todaySpend,
          monthSpend: monthSpend,
          budgetPct: budgetPct,
        ),
        key: 'arcane.fin.image',
        logicalSize: const Size(400, 200),
      );
    } catch (e) {
      debugPrint('[HomeWidget] renderFinance error: $e');
    }

    await _setAll({
      // SharedPreferences on Android can't store doubles via the plugin's
      // typed setters — write as strings, parse on the Kotlin side.
      'arcane.fin.balance': balance.toStringAsFixed(2),
      'arcane.fin.today': todaySpend.toStringAsFixed(2),
      'arcane.fin.mtd': monthSpend.toStringAsFixed(2),
      'arcane.fin.budgetPct': budgetPct,
      'arcane.fin.updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await _refresh(_providerFinance);
  }

  Future<void> publishJournal({
    required int count,
    required bool wake,
    required bool morn,
    required bool aft,
    required bool eve,
    required bool night,
  }) async {
    if (!_supported) return;
    try {
      await HomeWidget.renderFlutterWidget(
        JournalHomeWidget(
          count: count,
          wake: wake,
          morn: morn,
          aft: aft,
          eve: eve,
          night: night,
        ),
        key: 'arcane.journal.image',
        logicalSize: const Size(400, 200),
      );
    } catch (e) {
      debugPrint('[HomeWidget] renderJournal error: $e');
    }

    await _setAll({
      'arcane.journal.count': count,
      'arcane.journal.wake': wake,
      'arcane.journal.morn': morn,
      'arcane.journal.aft': aft,
      'arcane.journal.eve': eve,
      'arcane.journal.night': night,
    });
    await _refresh(_providerJournal);
  }

  Future<void> _setAll(Map<String, Object> values) async {
    for (final e in values.entries) {
      try {
        await HomeWidget.saveWidgetData(e.key, e.value);
      } catch (err) {
        debugPrint('[HomeWidget] save ${e.key}: $err');
      }
    }
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
