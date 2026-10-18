import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/bus_schedule_screen.dart';
import 'package:missions/src/screens/nora_ai_screen.dart';
import 'package:missions/src/screens/journaling/quick_therapy_screen.dart';
import 'package:missions/src/screens/reflections_archive_screen.dart';
import 'package:missions/src/screens/settings/widgets_studio/widgets_studio_resolvers.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/services/home_widget_publisher.dart';
import 'package:missions/src/services/stopped_task_memory.dart';
import 'package:missions/src/tasks/task_commands.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/dialogs/add_transaction_dialog.dart';
import 'package:missions/src/widgets/screens/reflection_editor_screen.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:home_widget/home_widget.dart';
import 'package:missions/src/services/tts_service.dart';

/// Tab indexes in HomeScreen — kept in sync with `_viewTitles` over there.
class HomeTab {
  static const missions = 0;
  static const health = 1;
  static const biometrics = 1;
  static const schedule = 2;
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
  final List<({String action, int atMs})> _pending = [];
  AppProvider? _waitingProvider;

  /// Taps older than this are dropped when the queue drains: replaying a halt/engage minutes
  /// later makes the floating button suddenly vanish or appear.
  static const int _pendingMaxAgeMs = 15000;

  static bool _isTimerToggle(String a) => a == 'task_pause' || a == 'task_start' || a == 'task_toggle';

  /// Idempotent actions (opening screens) stay valid however long they waited.
  static bool _isIdempotent(String a) =>
      a.startsWith('task_open') || a.startsWith('open_') || a.endsWith('_open');

  void _queue(String action) =>
      _pending.add((action: action, atMs: DateTime.now().millisecondsSinceEpoch));

  void _listenUntilReady(AppProvider provider) {
    if (identical(_waitingProvider, provider)) return;
    _waitingProvider?.removeListener(_onWaitingProviderChanged);
    _waitingProvider = provider;
    provider.addListener(_onWaitingProviderChanged);
  }

  void _onWaitingProviderChanged() {
    final p = _waitingProvider;
    if (p == null) return;
    if (!p.authLoading && !p.dataLoadInProgress && p.currentUser != null && p.localLoadError == null && !p.cloudAttachRequired) {
      p.removeListener(_onWaitingProviderChanged);
      _waitingProvider = null;
      flushPending();
    }
  }

  /// Channel the native [WidgetActionReceiver] invokes when the app process is
  /// already alive, so quick widget actions apply silently instead of
  /// foregrounding the app. Only fully-killed taps fall back to a launch.
  static const MethodChannel _platform = MethodChannel('arcane/widget');

  /// Wire up the silent in-process path. Call once during app start.
  void attachPlatformChannel() {
    _platform.setMethodCallHandler((call) async {
      if (call.method == 'widgetAction' && call.arguments is String) {
        handle(call.arguments as String, silent: true);
      } else if (call.method == 'energyReply') {
        final args = call.arguments;
        String? reply;
        int? notifId;
        String? pendingLogId;
        if (args is Map) {
          reply = args['reply'] as String?;
          notifId = args['notificationId'] as int?;
          pendingLogId = args['pendingLogId'] as String?;
        } else if (args is String) {
          reply = args;
        }
        if (reply != null) {
          final ctx = navigatorKey.currentContext;
          if (ctx != null) {
            final provider = Provider.of<AppProvider>(ctx, listen: false);
            provider.handleEnergyReply(reply, notificationId: notifId, pendingLogId: pendingLogId);
          }
        }
      } else if (call.method == 'onBackPressed') {
        onBackPressed?.call();
      }
    });
  }

  /// Hook for the Launcher root to handle system back button events safely without killing the activity.
  VoidCallback? onBackPressed;

  void handle(String action, {bool silent = false}) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      // App hasn't built MaterialApp yet — stash for later.
      _queue(action);
      return;
    }
    _dispatch(ctx, action, silent: silent);
  }

  /// Call after MaterialApp builds to drain any cold-start action.
  void flushPending() {
    if (_pending.isEmpty) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final provider = Provider.of<AppProvider>(ctx, listen: false);
    if (provider.authLoading || provider.dataLoadInProgress || provider.currentUser == null || provider.localLoadError != null || provider.cloudAttachRequired) {
      _listenUntilReady(provider);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final queued = List.of(_pending);
    _pending.clear();
    var dropped = false;
    final fresh = <String>[];
    for (final p in queued) {
      if (!_isIdempotent(p.action) && now - p.atMs > _pendingMaxAgeMs) {
        dropped = true;
        continue;
      }
      fresh.add(p.action);
    }
    // Several queued halt/engage taps would replay as start → pause → start. Only the last
    // one reflects what the user wants.
    final lastToggle = fresh.lastIndexWhere(_isTimerToggle);
    final actions = <String>[
      for (var i = 0; i < fresh.length; i++)
        if (!_isTimerToggle(fresh[i]) || i == lastToggle) fresh[i],
    ];
    if (dropped) showGlobalToast('Arcane was loading — tap the button again.');
    for (final action in actions) {
      _dispatch(ctx, action);
    }
  }

  void _dispatch(BuildContext ctx, String action, {bool silent = false}) {
    final provider = Provider.of<AppProvider>(ctx, listen: false);
    if (provider.authLoading || provider.dataLoadInProgress || provider.currentUser == null || provider.localLoadError != null || provider.cloudAttachRequired) {
      _queue(action);
      _listenUntilReady(provider);
      return;
    }
    // Floating task button double-tap: "task_check_add:<new checkpoint name>".
    if (action.startsWith(_checkAddPrefix)) {
      _commands(provider).checkAndAdd(action.substring(_checkAddPrefix.length));
      return;
    }
    switch (action) {
      case 'task_toggle':
        final hadRunning = provider.activeTimers.values.any((t) => t.isRunning && t.type == 'subtask');
        _commands(provider).toggle();
        if (!hadRunning) {
          _resumeLastPausedIfIdle(provider);
        }
        if (!silent) _gotoTab(HomeTab.schedule);
        break;
      case 'task_finish':
        _commands(provider).finish();
        if (!silent) _gotoTab(HomeTab.schedule);
        break;
      case 'task_pause':
        _commands(provider).pause();
        break;
      case 'task_start':
        _commands(provider).start();
        _resumeLastPausedIfIdle(provider);
        break;
      case 'task_check_next':
        _commands(provider).checkNext();
        break;
      case 'task_check_0':
      case 'task_check_1':
      case 'task_check_2':
      case 'task_check_3':
      case 'task_check_4':
        final index = int.parse(action.split('_').last);
        _commands(provider).checkAtPlanIndex(index);
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

      case 'bus_open':
        _push((_) => const BusScheduleScreen());
        break;
      case 'bus_swap':
        _busSwap(provider);
        if (!silent) {
          _push((_) => const BusScheduleScreen());
        }
        break;
      case 'bus_end_trip':
      case 'stop_bus_transit':
        BusLocationService.instance.stopManualCommute();
        showGlobalToast('Bus commute ended');
        break;
      case 'bus_locate':
        if (!silent) {
          _push((_) => const BusScheduleScreen());
        }
        break;

      case 'open_nora':
      case 'open_nora_voice':
      case 'bluetooth_assistant':
        final retrigger = NoraAiScreen.activeVoiceRetrigger;
        if (retrigger != null) {
          retrigger();
          break;
        }
        _push((_) => const NoraAiScreen(isVoiceCommandLaunch: true));
        break;

      case 'goals_open':
        _gotoTab(HomeTab.missions);
        break;
      case 'goal_toggle_0':
      case 'goal_toggle_1':
      case 'goal_toggle_2':
        final slot = int.parse(action.split('_').last);
        _toggleGoalAtSlot(provider, slot);
        break;

      default:
        if (action.startsWith('nora_prompt:')) {
          final prompt = action.substring('nora_prompt:'.length).trim();
          if (prompt.isNotEmpty) {
            _processNoraPrompt(prompt);
          }
          break;
        }
        debugPrint('[WidgetActionRouter] unknown action: $action');
    }
  }

  void _resumeLastPausedIfIdle(AppProvider provider) {
    final anyRunning = provider.activeTimers.values.any((t) => t.isRunning && t.type == 'subtask');
    if (anyRunning) return;
    final paused = HomeWidgetPublisher.lastPausedTaskIds;
    if (paused == null) return;
    final m = provider.mainTasks.firstWhereOrNull((t) => t.id == paused.mainTaskId && !t.isDeleted);
    final s = m?.subTasks.firstWhereOrNull((st) => st.id == paused.subTaskId && !st.isDeleted && !st.completed);
    if (m != null && s != null) {
      StoppedTaskMemory.subTaskId = null;
      provider.startTimer(s.id, 'subtask', m.id);
      HomeWidgetPublisher.republishNow();
    }
  }

  Future<void> _processNoraPrompt(String prompt) async {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) return;
      final appProvider = Provider.of<AppProvider>(context, listen: false);

      await HomeWidget.saveWidgetData<String>('arcane.nora.state', 'thinking');

      await appProvider.sendNoraMessage(prompt);

      String cleanReply = '';
      final messages = appProvider.activeNoraSession?.messages;
      if (messages != null && messages.isNotEmpty) {
        final lastMsg = messages.last;
        if (lastMsg.sender == MessageSender.bot) {
          cleanReply = lastMsg.text;
        }
      }

      await HomeWidget.saveWidgetData<String>('arcane.nora.response', cleanReply);
      await HomeWidget.saveWidgetData<String>('arcane.nora.state', 'ready');

      if (appProvider.settings.noraAutoSpeakTts && cleanReply.isNotEmpty) {
        await TtsService.instance.speak(cleanReply);
      }
    } catch (e) {
      debugPrint('[WidgetActionRouter] Error processing nora prompt: $e');
      await HomeWidget.saveWidgetData<String>('arcane.nora.response', 'Error: $e');
      await HomeWidget.saveWidgetData<String>('arcane.nora.state', 'error');
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

  void _toggleGoalAtSlot(AppProvider provider, int slot) {
    final live = WidgetsStudioResolvers.resolveLiveGoals(provider);
    if (slot >= 0 && slot < live.goals.length) {
      final goal = live.goals[slot];
      provider.toggleGoalCheck(goal.id);
      final wasCompleted = goal.getIsEffectiveCompleted();
      showGlobalToast(!wasCompleted ? '✓ Directive completed: ${goal.title}' : 'Directive reset: ${goal.title}');
    }
  }

  TaskCommands _commands(AppProvider provider) => TaskCommands(
        provider,
        onMessage: showGlobalToast,
        onRepublish: HomeWidgetPublisher.republishNow,
        onSessionEnded: HomeWidgetPublisher.noteSessionEnded,
        shownPlanIds: () {
          final cached = HomeWidgetPublisher.lastPublishedPlanIds;
          if (cached.isNotEmpty) return cached;
          final today = helper.getTodayDateString();
          return TaskCalculations.resolveTopFiveDayPlanTasks(
            mainTasks: provider.mainTasks,
            plan: provider.taskActions.getDayPlan(today),
          ).map((t) => t.compoundId).toList();
        },
      );

  static const _checkAddPrefix = 'task_check_add:';

  void _busSwap(AppProvider provider) {
    try {
      final settings = provider.settings;
      final orig = settings.lastSelectedBusOrigin ?? 'S.S College';
      final dest = settings.lastSelectedBusDestination ?? 'Edavannappara';
      final newSettings = AppSettings.fromJson(settings.toJson());
      newSettings.lastSelectedBusOrigin = dest;
      newSettings.lastSelectedBusDestination = orig;
      provider.setSettings(newSettings);
    } catch (_) {}
  }

  ReflectionLog? _latestReflection(AppProvider provider) {
    final list = provider.reflectionLogs;
    if (list.isEmpty) return null;
    final sorted = List.of(list)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.first;
  }
}
