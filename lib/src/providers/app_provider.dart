import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:missions/src/theme/wellbeing_theme.dart';
import 'package:missions/src/services/ai_service.dart';
import 'package:missions/src/services/firebase_service.dart' as fb_service;
import 'package:missions/src/services/local_storage_service.dart';
import 'package:missions/src/services/storage_service.dart';
import 'package:missions/src/services/data_export_service.dart';
import 'package:missions/src/services/notification_service.dart';
import 'package:missions/src/utils/briefing_context_helper.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/utils/history_helper.dart';
import 'package:missions/src/utils/constants.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/utils/goal_briefing_helper.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/models/health_models.dart';
import 'package:missions/src/models/update_model.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/services/update_service.dart';
import 'package:missions/src/services/nora_agent_engine.dart';
import 'package:missions/src/services/widget_action_router.dart';
import 'package:missions/src/widgets/dialogs/whats_new_update_dialog.dart';
import 'package:missions/src/services/app_action_ledger_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:missions/src/services/app_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import Mixins
import 'package:missions/src/providers/mixins/sync_mixin.dart';
import 'package:missions/src/providers/mixins/task_mixin.dart';
import 'package:missions/src/providers/mixins/finance_mixin.dart';
import 'package:missions/src/providers/mixins/user_mixin.dart';
import 'package:missions/src/providers/mixins/health_mixin.dart';
import 'package:missions/src/providers/paper_trading_provider.dart';

// Import Actions
import 'package:missions/src/providers/actions/task_actions.dart';
import 'package:missions/src/providers/actions/ai_generation_actions.dart';
import 'package:missions/src/providers/actions/timer_actions.dart';
import 'package:missions/src/providers/actions/report_actions.dart';
import 'package:missions/src/providers/actions/schedule_actions.dart';
import 'package:missions/src/providers/actions/finance_actions.dart';
import 'package:missions/src/providers/actions/journaling_actions.dart';
import 'package:missions/src/screens/launcher/launcher_icon.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';

class AppProvider with ChangeNotifier, SyncMixin, TaskMixin, FinanceMixin, UserMixin, HealthMixin, WidgetsBindingObserver {
  
  final AIService _aiService = AIService();
  final DataExportService _exportService = DataExportService();
  final StorageService _cloudStorage = StorageService();
  final LocalStorageService _localStorage = LocalStorageService();

  AIService get aiService => _aiService;

  void notify() => notifyListeners();

  /// Fires whenever a reflection's AI analysis completes successfully.
  /// Carries the payload needed to render the "INSIGHT ACQUIRED" dialog.
  final ValueNotifier<InsightReadyEvent?> insightReady =
      ValueNotifier<InsightReadyEvent?>(null);

  /// Set of reflection log ids currently being analyzed in the background.
  final Set<String> _processingReflections = {};
  Set<String> get processingReflections => Set.unmodifiable(_processingReflections);
  bool isReflectionProcessing(String logId) => _processingReflections.contains(logId);

  // UI State
  String? _loadingTaskName;
  String? get loadingTaskName => _loadingTaskName;
  bool _isGeneratingSubquestsForTask = false;
  bool get isGeneratingSubquests => _isGeneratingSubquestsForTask;
  
  bool get isDataLoadingAfterLogin => false; 

  // Actions
  late final TaskActions _taskActions;
  late final AIGenerationActions _aiGenerationActions;
  late final TimerActions _timerActions;
  late final ReportActions _reportActions;
  late final ScheduleActions _scheduleActions;
  late final FinanceActions _financeActions;
  late final JournalingActions _journalingActions;
  late final PaperTradingProvider _paperTrading;
  final UpdateService _updateService = UpdateService();

  TaskActions get taskActions => _taskActions;
  AIGenerationActions get aiGenerationActions => _aiGenerationActions;
  TimerActions get timerActions => _timerActions;
  ReportActions get reportActions => _reportActions;
  ScheduleActions get scheduleActions => _scheduleActions;
  FinanceActions get financeActions => _financeActions;
  JournalingActions get journalingActions => _journalingActions;
  PaperTradingProvider get paperTrading => _paperTrading;
  UpdateService get updateService => _updateService;

  UpdateModel? _availableUpdate;
  UpdateModel? get availableUpdate => _availableUpdate;
  bool _isCheckingUpdate = false;
  bool get isCheckingUpdate => _isCheckingUpdate;

  List<Map<String, dynamic>> _cachedWeeklyReports = [];
  List<Map<String, dynamic>> _cachedMonthlyReports = [];
  List<Map<String, dynamic>> get cachedWeeklyReports => List.unmodifiable(_cachedWeeklyReports);
  List<Map<String, dynamic>> get cachedMonthlyReports => List.unmodifiable(_cachedMonthlyReports);

  int? _promptedVersionCode;

  void promptUpdateIfAvailable(UpdateModel update) {
    if (_promptedVersionCode == update.versionCode) return;
    _promptedVersionCode = update.versionCode;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navContext = WidgetActionRouter.instance.navigatorKey.currentContext;
      if (navContext != null && navContext.mounted) {
        final packageInfo = await _updateService.getLocalPackageInfo();
        if (navContext.mounted) {
          WhatsNewUpdateDialog.show(
            navContext,
            update: update,
            currentVersion: packageInfo.version,
            currentBuildNumber: packageInfo.buildNumber,
            updateService: _updateService,
          );
        }
      }
    });
  }

  Future<UpdateModel?> checkForAppUpdate({bool forceCheck = false}) async {
    _isCheckingUpdate = true;
    notifyListeners();
    try {
      final update = await _updateService.checkForUpdate(forceCheck: forceCheck);
      _availableUpdate = update;
      if (update != null) {
        promptUpdateIfAvailable(update);
      }
      return update;
    } catch (e) {
      debugPrint("[AppProvider.checkForAppUpdate] Error: $e");
      return null;
    } finally {
      _isCheckingUpdate = false;
      notifyListeners();
    }
  }

  AppProvider() {
    _taskActions = TaskActions(this);
    _aiGenerationActions = AIGenerationActions(this);
    _timerActions = TimerActions(this);
    _reportActions = ReportActions(this);
    _scheduleActions = ScheduleActions(this);
    _financeActions = FinanceActions(this);
    _journalingActions = JournalingActions(this);
    _paperTrading = PaperTradingProvider.instance;
    _paperTrading.onStateChanged = () => markDirty('trading');
    LauncherService.instance.onLauncherChanged = () {
      markDirty('launcher');
      markDirty('settings');
    };

    // Real-time instant app update stream from Firebase Realtime Database
    _updateService.watchAppUpdates().listen((update) {
      if (update != null && update.versionCode != _availableUpdate?.versionCode) {
        debugPrint('[AppProvider] Real-time update detected from Firebase: #${update.versionCode}');
        _availableUpdate = update;
        notifyListeners();
        promptUpdateIfAvailable(update);
      }
    });

    // Background periodic update check (every 15 minutes)
    Timer.periodic(const Duration(minutes: 15), (_) {
      checkForAppUpdate();
    });

    // Auto-check updates as soon as internet connectivity recovers
    Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        checkForAppUpdate();
      }
    });

    // Route notification taps / action buttons.
    // Payload for the timer notification is encoded as "<subtaskId>|<mainTaskId>".
    NotificationService.instance.setOnTap((payload) {
      if (payload == null) return;
      if (payload == 'retry_cloud_sync') {
        syncEndOfDay();
      } else if (payload.startsWith('stop_timer:')) {
        final subtaskId =
            payload.substring('stop_timer:'.length).split('|').first;
        _timerActions.pauseTimer(subtaskId);
      } else if (payload.startsWith('check_next:')) {
        _handleNotificationCheck(payload.substring('check_next:'.length),
            undo: false);
      } else if (payload.startsWith('undo_check:')) {
        _handleNotificationCheck(payload.substring('undo_check:'.length),
            undo: true);
      } else if (payload.startsWith('stop_bus_transit') || payload == 'stop_bus_transit') {
        BusLocationService.instance.stopManualCommute();
        showGlobalToast('Bus commute ended');
      } else if (payload.startsWith('energy_reply:')) {
        final rest = payload.substring('energy_reply:'.length);
        final parts = rest.split(':');
        final replyText = parts.isNotEmpty ? parts[0] : 'yes';
        final notifId = parts.length > 1 ? int.tryParse(parts[1]) : null;
        handleEnergyReply(replyText, notificationId: notifId);
      } else if (payload.startsWith('log_low_energy') || payload == 'log_low_energy') {
        handleEnergyReply('yes');
      }
    });

    NotificationService.instance.setOnEnergyReply((replyText, notifId) {
      handleEnergyReply(replyText, notificationId: notifId);
    });

    _initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  AppProvider.forTest() {
    _taskActions = TaskActions(this);
    _aiGenerationActions = AIGenerationActions(this);
    _timerActions = TimerActions(this);
    _reportActions = ReportActions(this);
    _scheduleActions = ScheduleActions(this);
    _financeActions = FinanceActions(this);
    _journalingActions = JournalingActions(this);
    _paperTrading = PaperTradingProvider.instance;
    _paperTrading.onStateChanged = () => markDirty('trading');
  }

  @override
  void dispose() {
    _midnightRolloverTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final todayStr = helper.getTodayDateString();
      if (lastLoginDate != todayStr) {
        debugPrint("[AppProvider] App resumed on new day ($todayStr vs $lastLoginDate). Running daily rollover.");
        _handleDailyReset();
        _scheduleMidnightTimer();
      }
      drainPendingEnergyLogs();
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.hidden) {
      if (hasPendingLocalSave) {
        forceLocalBackup();
      }
    }
  }

  @override
  void didHaveMemoryPressure() {
    debugPrint("[AppProvider] Memory pressure reported by OS. Purging memory caches.");
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _cachedWeeklyReports.clear();
    _cachedMonthlyReports.clear();
    TaskCalculations.invalidateCache();
    LauncherIconCache.instance.clearMemory();
  }

  @override
  Future<bool> manuallyLoadFromCloud() async {
    final success = await super.manuallyLoadFromCloud();
    await fetchDailyReportsFromCloud();
    return success;
  }

  // --- Notification Reminders ---

  /// (Re)arms every reminder we know about: the daily reflection reminder
  /// (driven by settings flags) plus all persisted [ScheduledReminder]s.
  /// Safe to call repeatedly — each reminder cancels its own slot first.
  void rescheduleReminders() {
    final s = settings;
    if (s.reflectionReminderEnabled) {
      NotificationService.instance.scheduleDailyReminder(
        id: NotificationService.reflectionReminderId,
        title: '◈ REFLECT',
        body: 'Time for your daily reflection. How did today go?',
        hour: s.reflectionReminderHour,
        minute: s.reflectionReminderMinute,
      );
    } else {
      NotificationService.instance.cancelDailyReminder(
          NotificationService.reflectionReminderId);
    }

    if (s.financeReminderEnabled) {
      NotificationService.instance.scheduleDailyReminder(
        id: NotificationService.financeReminderId,
        title: '◈ FINANCE DATA SYNC',
        body: 'Time to update your finance data and records.',
        hour: s.financeReminderHour,
        minute: s.financeReminderMinute,
      );
    } else {
      NotificationService.instance.cancelDailyReminder(
          NotificationService.financeReminderId);
    }

    if (s.healthReminderEnabled) {
      NotificationService.instance.scheduleDailyReminder(
        id: NotificationService.healthReminderId,
        title: '◈ HEALTH METRICS UPDATE',
        body: 'Time to update your food, water, sleep, and activity logs.',
        hour: s.healthReminderHour,
        minute: s.healthReminderMinute,
      );
    } else {
      NotificationService.instance.cancelDailyReminder(
          NotificationService.healthReminderId);
    }

    for (final r in s.scheduledReminders) {
      _armReminder(r);
    }

    NotificationService.instance.scheduleEnergyCheckReminders(
      enabled: s.energyNotificationsEnabled,
      title: s.energyNotificationTitle,
      body: s.energyNotificationBody,
      customTimes: s.energyNotificationTimes,
    );

    NotificationService.instance.scheduleAllGoalContemplationReminders(goals);
  }

  /// Schedule or cancel one reminder with the OS, based on its current state.
  void _armReminder(ScheduledReminder r) {
    if (!r.enabled) {
      NotificationService.instance.cancelOneTimeReminder(r.notificationId);
      return;
    }
    if (r.repeat == 'daily') {
      NotificationService.instance.scheduleDailyReminder(
        id: r.notificationId,
        title: r.title,
        body: r.body,
        hour: r.hour,
        minute: r.minute,
      );
    } else if (r.time != null) {
      NotificationService.instance.scheduleOneTimeReminder(
        id: r.notificationId,
        title: r.title,
        body: r.body,
        scheduledTime: r.time!,
      );
    }
  }

  /// Handle an inline reply from an energy check notification or wearable auto-reply.
  /// Android 14 compliant: acknowledges inline reply immediately, parses sentiment/level,
  /// commits to health logs, consults AI, and sends response notification.
  Future<void> handleEnergyReply(String replyText, {int? notificationId}) async {
    final trimmed = replyText.trim();
    if (trimmed.isEmpty) return;

    final notifId = notificationId ?? 5000;

    // 1. Android 14 instant visual feedback: immediately update notification inline
    await NotificationService.instance.showEnergySyncedNotification(
      notificationId: notifId,
      replyText: trimmed,
    );

    // 2. Parse energy level from input text
    final lower = trimmed.toLowerCase();
    int level = 5;
    if (lower == 'yes' ||
        lower.contains('tired') ||
        lower.contains('exhausted') ||
        lower.contains('low') ||
        lower.contains('sleepy') ||
        lower.contains('drained') ||
        lower.contains('fatigued') ||
        lower.contains('burnt')) {
      level = 2;
    } else if (lower == 'no' ||
        lower.contains('energetic') ||
        lower.contains('good') ||
        lower.contains('great') ||
        lower.contains('fine') ||
        lower.contains('pumped') ||
        lower.contains('fresh') ||
        lower.contains('active')) {
      level = 8;
    } else {
      final match = RegExp(r'\b([1-9]|10)\b').firstMatch(lower);
      if (match != null) {
        level = int.tryParse(match.group(1)!) ?? 5;
      }
    }

    // 3. Log to health state
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    addEnergyLog(
      todayStr,
      EnergyLog(
        id: const Uuid().v4(),
        level: level,
        timestamp: DateTime.now(),
        note: 'Wearable/Notification reply: "$trimmed"',
      ),
    );

    showGlobalToast('Energy check: "$trimmed" logged');

    // 4. Process with AI to generate tactical operator guidance
    String aiResponse = '';
    try {
      final prompt = '''
You are the tactical AI operator in Arcane.
The user just answered a scheduled Energy Check: "Are you feeling tired or low on energy right now?"
User's response: "$trimmed" (Estimated energy level: $level/10).
Provide a concise, tactical 1-2 sentence response (under 140 characters so it fits cleanly in a notification) directly addressing their energy state with an actionable tip or operator motivation. Do not use markdown headers or bullet points.
''';

      aiResponse = await _aiService.makeRawTextAICall(
        prompt: prompt,
        modelCandidates: settings.liteModels,
        customApiKeys: settings.customApiKeys,
        currentApiKeyIndex: apiKeyIndex,
        onNewApiKeyIndex: setProviderApiKeyIndex,
        onLog: (msg) {
          if (kDebugMode) debugPrint('[EnergyCheckAI] $msg');
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[EnergyCheckAI] Error: $e');
    }

    // Fallback if AI call failed or returned empty
    if (aiResponse.trim().isEmpty) {
      if (level <= 3) {
        aiResponse =
            'Tactical Alert: Low energy registered ($trimmed). Hydrate with 250ml water and take a 3-minute visual reset before continuing.';
      } else if (level >= 7) {
        aiResponse =
            'Tactical Status: High energy confirmed ($trimmed). Channel peak cognitive momentum into your primary mission.';
      } else {
        aiResponse =
            'Energy status "$trimmed" logged. Maintain steady pacing and monitor fatigue thresholds.';
      }
    }

    // 5. Post response notification (visible on wearable and notification tray)
    await NotificationService.instance.showEnergyResponseNotification(
      title: 'ARCANE // ENERGY ADVISOR',
      body: aiResponse.trim(),
      replyText: trimmed,
    );
  }

  /// Drains any pending energy logs saved to SharedPreferences while the app was suspended or killed.
  Future<void> drainPendingEnergyLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList('pending_energy_logs_v2') ?? [];
      if (logs.isNotEmpty) {
        await prefs.remove('pending_energy_logs_v2');
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        for (final raw in logs) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            final level = (map['level'] as num?)?.toInt() ?? 5;
            final reply = map['reply'] as String? ?? 'yes';
            final ts = map['timestamp'] != null
                ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
                : DateTime.now();
            addEnergyLog(
              todayStr,
              EnergyLog(
                id: const Uuid().v4(),
                level: level,
                timestamp: ts,
                note: 'Wearable/Notification reply: "$reply"',
              ),
            );
          } catch (_) {}
        }
      }

      // Also drain native Android pending logs if any
      final nativeLogsJson = prefs.getString('pending_energy_logs');
      if (nativeLogsJson != null && nativeLogsJson.isNotEmpty) {
        await prefs.remove('pending_energy_logs');
        final array = jsonDecode(nativeLogsJson);
        if (array is List) {
          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          for (final item in array) {
            if (item is Map) {
              final reply = item['reply'] as String? ?? 'yes';
              final lower = reply.toLowerCase();
              int lvl = 5;
              if (lower == 'yes' || lower.contains('tired')) {
                lvl = 2;
              } else if (lower == 'no' || lower.contains('good') || lower.contains('energetic')) {
                lvl = 8;
              }
              addEnergyLog(
                todayStr,
                EnergyLog(
                  id: const Uuid().v4(),
                  level: lvl,
                  timestamp: DateTime.now(),
                  note: 'Wearable/Notification reply: "$reply"',
                ),
              );
            }
          }
        }
      }
    } catch (_) {}
  }

  List<ScheduledReminder> get scheduledReminders =>
      List.unmodifiable(settings.scheduledReminders);

  /// Insert or replace a reminder (matched by [ScheduledReminder.id]),
  /// persist it, and (re)arm the OS notification.
  void upsertReminder(ScheduledReminder reminder) {
    final list = List<ScheduledReminder>.from(settings.scheduledReminders);
    final idx = list.indexWhere((e) => e.id == reminder.id);
    if (idx >= 0) {
      list[idx] = reminder;
    } else {
      list.add(reminder);
    }
    setSettings(settings..scheduledReminders = list);
    _armReminder(reminder);
    notifyListeners();
  }

  void deleteReminder(String id, {bool silent = false}) {
    final list = List<ScheduledReminder>.from(settings.scheduledReminders);
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final removed = list.removeAt(idx);
    final previousSettings = AppSettings.fromJson(settings.toJson());

    setSettings(settings..scheduledReminders = list);
    NotificationService.instance.cancelOneTimeReminder(removed.notificationId);
    notifyListeners();

    if (!silent) {
      showUndoSnackBar(
        message: 'Deleted reminder "${removed.title}"',
        onUndo: () {
          setSettings(previousSettings);
          rescheduleReminders();
          notifyListeners();
        },
      );
    }
  }

  void setReminderEnabled(String id, bool enabled) {
    final r = settings.scheduledReminders.firstWhereOrNull((e) => e.id == id);
    if (r == null) return;
    upsertReminder(r.copyWith(enabled: enabled));
  }

  List<ScheduledReminder> getSubtaskReminders(String subtaskId) {
    return settings.scheduledReminders
        .where((e) => e.id.startsWith('task_${subtaskId}_') || e.id == 'task_$subtaskId')
        .toList();
  }

  List<ScheduledReminder> getCheckpointReminders(String checkpointId) {
    return settings.scheduledReminders
        .where((e) => e.id.startsWith('checkpoint_${checkpointId}_') || e.id == 'checkpoint_$checkpointId')
        .toList();
  }

  Future<void> addSubtaskReminder(
      String mainTaskId, String subtaskId, DateTime reminderTime, String repeat) async {
    final task = mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == subtaskId);
    if (task == null || sub == null) return;

    final id = 'task_${subtaskId}_${DateTime.now().millisecondsSinceEpoch}';
    upsertReminder(ScheduledReminder(
      id: id,
      title: '⏰ ${sub.name}',
      body: 'Reminder for: ${task.name} › ${sub.name}',
      type: 'task',
      repeat: repeat,
      time: repeat == 'once' ? reminderTime : null,
      hour: reminderTime.hour,
      minute: reminderTime.minute,
      mainTaskId: mainTaskId,
      subtaskId: subtaskId,
    ));
  }

  Future<void> addCheckpointReminder(
      String mainTaskId, String subtaskId, String checkpointId, DateTime reminderTime, String repeat) async {
    final task = mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == subtaskId);
    final cp = sub?.findCheckpoint(checkpointId);
    if (task == null || sub == null || cp == null) return;

    final id = 'checkpoint_${checkpointId}_${DateTime.now().millisecondsSinceEpoch}';
    upsertReminder(ScheduledReminder(
      id: id,
      title: '⏰ ${cp.name}',
      body: 'Reminder for: ${task.name} › ${sub.name} › ${cp.name}',
      type: 'task',
      repeat: repeat,
      time: repeat == 'once' ? reminderTime : null,
      hour: reminderTime.hour,
      minute: reminderTime.minute,
      mainTaskId: mainTaskId,
      subtaskId: subtaskId,
      compoundId: '$mainTaskId|$subtaskId|$checkpointId',
    ));
  }

  Future<void> setSubtaskReminder(
      String mainTaskId, String subtaskId, DateTime? reminderTime) async {
    if (reminderTime == null) {
      final rems = getSubtaskReminders(subtaskId);
      for (final r in rems) {
        deleteReminder(r.id);
      }
      return;
    }
    await addSubtaskReminder(mainTaskId, subtaskId, reminderTime, 'once');
  }

  Future<void> setCheckpointReminder(
      String mainTaskId, String subtaskId, String checkpointId, DateTime? reminderTime) async {
    if (reminderTime == null) {
      final rems = getCheckpointReminders(checkpointId);
      for (final r in rems) {
        deleteReminder(r.id);
      }
      return;
    }
    await addCheckpointReminder(mainTaskId, subtaskId, checkpointId, reminderTime, 'once');
  }

  DateTime? subtaskReminderTime(String subtaskId) {
    final active = getSubtaskReminders(subtaskId).where((e) => e.isActive).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) {
      final fa = a.nextFire;
      final fb = b.nextFire;
      if (fa == null) return 1;
      if (fb == null) return -1;
      return fa.compareTo(fb);
    });
    return active.first.nextFire;
  }

  DateTime? checkpointReminderTime(String checkpointId) {
    final active = getCheckpointReminders(checkpointId).where((e) => e.isActive).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) {
      final fa = a.nextFire;
      final fb = b.nextFire;
      if (fa == null) return 1;
      if (fb == null) return -1;
      return fa.compareTo(fb);
    });
    return active.first.nextFire;
  }

  /// The reminder time currently set for a planned day-plan item, or null.
  DateTime? plannerReminderTime(String compoundId) {
    final r = settings.scheduledReminders
        .firstWhereOrNull((e) => e.id == 'plan_$compoundId');
    return r?.time;
  }

  /// Set (or clear, when [reminderTime] is null) the reminder for a planner item.
  Future<void> setPlannerReminder(
      String compoundId, DateTime? reminderTime) async {
    final id = 'plan_$compoundId';
    if (reminderTime == null) {
      deleteReminder(id);
      return;
    }
    final parts = compoundId.split('|');
    final task = mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = parts.length > 1
        ? task?.subTasks.firstWhereOrNull((s) => s.id == parts[1])
        : null;
    String label = sub?.name ?? 'Planned task';
    if (parts.length == 3 && sub != null) {
      final cp = sub.findCheckpoint(parts[2]);
      if (cp != null) label = cp.name;
    }

    upsertReminder(ScheduledReminder(
      id: id,
      title: '🎯 $label',
      body: task != null ? 'Planned: ${task.name} › $label' : 'Planned: $label',
      type: 'planner',
      repeat: 'once',
      time: reminderTime,
      mainTaskId: task?.id,
      subtaskId: sub?.id,
      compoundId: compoundId,
    ));
  }

  // --- Ongoing-notification checkpoint actions ---

  Timer? _notifUndoTimer;
  Timer? _midnightRolloverTimer;

  /// Handles the CHECK NEXT / UNDO CHECK action buttons on the active-timer
  /// notification. [raw] is encoded as `subtaskId|mainTaskId`.
  void _handleNotificationCheck(String raw, {required bool undo}) {
    final parts = raw.split('|');
    if (parts.length < 2) return;
    final subtaskId = parts[0];
    final mainTaskId = parts[1];
    final task = mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == subtaskId);
    if (task == null || sub == null) return;

    _notifUndoTimer?.cancel();

    if (undo) {
      final lastId = _lastCheckedCheckpointId[subtaskId];
      if (lastId != null) {
        _taskActions.uncompleteSubSubtask(mainTaskId, subtaskId, lastId);
        _lastCheckedCheckpointId.remove(subtaskId);
        showGlobalToast('↩ Unchecked');
      }
      refreshTimerNotification(mainTaskId, subtaskId);
      return;
    }

    final cp = TaskCalculations.nextCheckpoint(sub);
    if (cp == null) {
      showGlobalToast('No checkpoints left to check');
      refreshTimerNotification(mainTaskId, subtaskId);
      return;
    }
    _taskActions.completeSubSubtask(mainTaskId, subtaskId, cp.id);
    _lastCheckedCheckpointId[subtaskId] = cp.id;
    showGlobalToast('✓ Checked: ${cp.name}');

    // Show the just-checked state with an UNDO CHECK button for 2 seconds,
    // then revert to CHECK NEXT pointing at the new lowest checkpoint.
    refreshTimerNotification(mainTaskId, subtaskId,
        justCheckedName: cp.name, showUndo: true);
    _notifUndoTimer = Timer(const Duration(seconds: 2), () {
      _lastCheckedCheckpointId.remove(subtaskId);
      refreshTimerNotification(mainTaskId, subtaskId);
    });
  }

  final Map<String, String> _lastCheckedCheckpointId = {};

  void refreshTimerNotification(String mainTaskId, String subtaskId,
      {String? justCheckedName, bool showUndo = false}) {
    final task = mainTasks.firstWhereOrNull((t) => t.id == mainTaskId);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == subtaskId);
    if (task == null || sub == null) return;
    final timer = activeTimers[subtaskId];
    if (timer == null || !timer.isRunning) return;

    final next = TaskCalculations.nextCheckpoint(sub);
    NotificationService.instance.showTimerNotification(
      taskName: sub.name,
      startTime: timer.startTime,
      subtaskId: subtaskId,
      mainTaskId: mainTaskId,
      mainTaskName: task.name,
      progress: sub.calculateProgress(),
      nextCheckpointName: next?.name,
      showUndo: showUndo,
      statusBody: justCheckedName != null ? '✓ $justCheckedName' : null,
    );
  }

  void saveReflectionDraft({
    required String trigger,
    required String emotion,
    required String reason,
    required String action,
    double energyLevel = 5,
  }) {
    final draft = ReflectionDraft(
      trigger: trigger,
      emotion: emotion,
      reason: reason,
      action: action,
      energyLevel: energyLevel,
      savedAt: DateTime.now(),
    );
    if (draft.isEmpty) return;
    setSettings(settings..reflectionDraft = draft);
  }

  void clearReflectionDraft() {
    if (settings.reflectionDraft == null) return;
    setSettings(settings..reflectionDraft = null);
  }

  // --- Initialization ---

  Future<void> _initialize() async {
    initializeSkills();
    initializeDefaultFinanceCategories();
    _scheduleMidnightTimer();
    try {
      await NotificationService.instance.init();
      rescheduleReminders();
      drainPendingEnergyLogs();
    } catch (e) {
      debugPrint("Notification init error: $e");
    }

    fb_service.authStateChanges.listen(_onAuthStateChanged);

    // Seed initial auth state to avoid infinite loading if the auth stream does not emit on startup (common on Linux)
    try {
      final initialUser = fb_service.currentUser;
      unawaited(_onAuthStateChanged(initialUser));
    } catch (e) {
      debugPrint("Error getting initial auth state: $e");
      // Fallback: transition out of loading screen anyway
      setAuthLoading(false);
    }

    // Zero-lag startup watchdog: ensure authLoading is never stuck on true under any circumstances
    Timer(const Duration(milliseconds: 800), () {
      if (authLoading) {
        debugPrint("[AppProvider] Startup watchdog triggered: forcing authLoading to false");
        setAuthLoading(false);
      }
    });
  }

  Future<void> _onAuthStateChanged(AppUser? user) async {
    try {
      if (user != null) {
        final isDifferentUser = currentUser == null || currentUser!.uid != user.uid;
        if (isDifferentUser) {
          // No saves or dirty-marking until the user's real data is in memory (see beginDataLoad).
          beginDataLoad();
          Map<String, dynamic>? localData;
          var loadedFromCloud = false;
          try {
            setCurrentUser(user);
            unawaited(AppActionLedgerService.instance.init(user.uid));
            localData = await _localStorage.loadState(user.uid);
            if (localData != null) {
              loadStateFromMap(localData);
            } else {
              // Auto load from cloud if local state is missing, with timeout to prevent startup lag
              await _resetToInitialState();
              try {
                loadedFromCloud = await manuallyLoadFromCloud().timeout(
                  const Duration(seconds: 3),
                  onTimeout: () => false,
                );
              } catch (e) {
                debugPrint("Failed to load initial state from cloud: $e");
              }
            }
          } catch (e, stack) {
            debugPrint("Error loading user data on auth change: $e\n$stack");
          } finally {
            endDataLoad();
          }

          if (loadedFromCloud) unawaited(forceLocalBackup());
          initSync();
        }

        // Release loading screen immediately so there is zero UI startup lag
        setAuthLoading(false);

        // Run background validation and maintenance asynchronously without blocking UI
        unawaited(_runPostAuthMaintenance());
      } else {
        if (currentUser != null || authLoading) {
          setCurrentUser(null);
          beginDataLoad();
          try {
            await _resetToInitialState();
          } catch (e) {
            debugPrint("Error resetting state on sign out: $e");
          } finally {
            endDataLoad();
          }
        }
        setAuthLoading(false);
      }
    } catch (e, stack) {
      debugPrint("Fatal error in _onAuthStateChanged: $e\n$stack");
    } finally {
      // Ironclad guarantee: authLoading MUST be false once auth change resolution completes
      setAuthLoading(false);
    }
  }

  Future<void> _runPostAuthMaintenance() async {
    try {
      _cleanOverlappingSessions();
      _fixTimerAnomalies();
      await _taskActions.recalibrateTimeLogs(silent: true);
      await _handleDailyReset();
      _scheduleMidnightTimer();
      try {
        await fetchDailyReportsFromCloud();
      } catch (_) {}
      rescheduleReminders();
    } catch (e) {
      debugPrint("Error in post-auth background maintenance: $e");
    }
  }

  Future<void> fetchDailyReportsFromCloud() async {
    if (currentUser == null) return;
    final recentDaily = await _cloudStorage.fetchRecentDailyData(currentUser!.uid, 60); 
    if (recentDaily.isNotEmpty) {
      final newHistory = Map<String, dynamic>.from(completedByDay);
      recentDaily.forEach((date, data) {
        final dayData = Map<String, dynamic>.from(newHistory[date] ?? {});
        bool changed = false;
        if (data.containsKey('briefing')) {
          dayData['aiBriefing'] = data['briefing'];
          changed = true;
        }
        if (data.containsKey('report')) {
          dayData['startDayReport'] = data['report'];
          changed = true;
        }
        if (changed) {
          newHistory[date] = dayData;
        }
      });
      setCompletedByDay(newHistory);
    }
  }

  Future<void> _resetToInitialState() async {
    setLastLoginDate(null);
    // Timestamp 0: defaults must never look newer than real data (local cache or cloud).
    setSettings(AppSettings(lastModified: 0));
    setMainTasks(initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList());
    setCompletedByDay({});
    _cachedWeeklyReports = [];
    _cachedMonthlyReports = [];
    setActiveTimers({});
    setReflectionLogs([]);
    setTransactions([]);
    setCategories([]);
    setSavingsGoals([]);
    setAccounts([]);
    setProjects([]);
    setChatbotMemory(ChatbotMemory());
    initializeSkills();
    initializeDefaultFinanceCategories();
    try {
      _paperTrading.resetPortfolio();
    } catch (_) {}
  }

  // --- Mixin Implementations & Legacy Compat ---

  @override
  Map<String, dynamic> getTradingStateMap() => _paperTrading.getStateMap();

  @override
  Map<String, dynamic> getLauncherStateMap() => LauncherService.instance.getStateMap();

  @override
  Map<String, dynamic> getFullAppState() {
    final map = <String, dynamic>{};
    map.addAll(getTaskStateMap());
    map.addAll(getFinanceStateMap());
    map.addAll(getUserStateMap());
    map.addAll(getHealthStateMap());
    map['trading'] = getTradingStateMap();
    map['launcher'] = getLauncherStateMap();
    return map;
  }

  Map<String, dynamic> getAppStateAsMap() => getFullAppState();
  
  void loadAppStateFromMap(Map<String, dynamic> data) => loadStateFromMap(normalizeImportedData(data));

  @override
  void loadStateFromMap(Map<String, dynamic> data) {
    try {
      loadTaskState(data);
    } catch (e) {
      debugPrint("Error loading task state in loadStateFromMap: $e");
    }
    try {
      loadFinanceState(data);
    } catch (e) {
      debugPrint("Error loading finance state in loadStateFromMap: $e");
    }
    try {
      loadUserState(data);
    } catch (e) {
      debugPrint("Error loading user state in loadStateFromMap: $e");
    }
    try {
      loadHealthState(data);
    } catch (e) {
      debugPrint("Error loading health state in loadStateFromMap: $e");
    }
    if (data['trading'] != null) {
      try {
        final t = data['trading'];
        if (t is Map) {
          _paperTrading.loadState(Map<String, dynamic>.from(t));
        } else if (t is String) {
          final decoded = jsonDecode(t);
          if (decoded is Map) {
            _paperTrading.loadState(Map<String, dynamic>.from(decoded));
          }
        }
      } catch (e) {
        debugPrint("Error loading trading state in loadStateFromMap: $e");
      }
    }
    if (data['launcher'] != null) {
      try {
        final l = data['launcher'];
        if (l is Map) {
          unawaited(LauncherService.instance.loadFromMap(Map<String, dynamic>.from(l)));
        } else if (l is String) {
          final decoded = jsonDecode(l);
          if (decoded is Map) {
            unawaited(LauncherService.instance.loadFromMap(Map<String, dynamic>.from(decoded)));
          }
        }
      } catch (e) {
        debugPrint("Error loading launcher state in loadStateFromMap: $e");
      }
    }
    
    if (settings.dataVersion < 1) {
      settings.dataVersion = 1;
      markDirty('settings');
    }
  }

  @override
  MergeReport mergeAppStateFromMap(Map<String, dynamic> rawData) {
    final data = normalizeImportedData(rawData);

    final taskResult = mergeTaskState(data);
    final addedReflections = mergeUserState(data);
    final addedTransactions = mergeFinanceState(data);

    if (data['foodItems'] != null || data['healthLogs'] != null) {
      loadHealthState(data);
    }

    bool launcherMerged = false;
    if (data['launcher'] != null) {
      final l = data['launcher'];
      Map<String, dynamic>? lMap;
      if (l is Map) {
        lMap = Map<String, dynamic>.from(l);
      } else if (l is String) {
        try {
          final decoded = jsonDecode(l);
          if (decoded is Map) lMap = Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      if (lMap != null && lMap.isNotEmpty) {
        unawaited(LauncherService.instance.mergeFromMap(lMap));
        launcherMerged = true;
      }
    }

    if (data['trading'] != null) {
      final t = data['trading'];
      if (t is Map) {
        _paperTrading.loadState(Map<String, dynamic>.from(t));
      } else if (t is String) {
        try {
          final decoded = jsonDecode(t);
          if (decoded is Map) _paperTrading.loadState(Map<String, dynamic>.from(decoded));
        } catch (_) {}
      }
    }

    markAllDirty();
    notifyListeners();

    return MergeReport(
      addedReflections: addedReflections,
      totalReflections: reflectionLogs.length,
      mergedDays: taskResult.mergedDays,
      totalHistoryDays: completedByDay.length,
      addedTasks: taskResult.addedTasks,
      addedProjects: taskResult.addedProjects,
      addedGoals: taskResult.addedGoals,
      addedTransactions: addedTransactions,
      launcherMerged: launcherMerged,
    );
  }

  /// Async foreground merge with granular progress reporting across each subsystem.
  Future<MergeReport> mergeAppStateFromMapWithProgress(
    Map<String, dynamic> rawData, {
    Future<void> Function(int stepIndex, String message)? onProgress,
  }) async {
    await onProgress?.call(0, "Analyzing & normalizing snapshot payload...");
    final data = normalizeImportedData(rawData);
    final rawTasksCount = (data['mainTasks'] as List?)?.length ?? 0;
    await Future.delayed(const Duration(milliseconds: 120));

    await onProgress?.call(1, "Restoring & merging tasks, subtasks & checkpoints ($rawTasksCount found)...");
    final taskResult = mergeTaskState(data);
    await Future.delayed(const Duration(milliseconds: 140));

    final totalDaysCount = completedByDay.length;
    await onProgress?.call(2, "Restoring daily history (merged ${taskResult.mergedDays} days across $totalDaysCount days)...");
    await Future.delayed(const Duration(milliseconds: 140));

    final reflectionsCount = (data['reflectionLogs'] as List?)?.length ?? 0;
    await onProgress?.call(3, "Weaving reflection journals & memories ($reflectionsCount found)...");
    final addedReflections = mergeUserState(data);
    await Future.delayed(const Duration(milliseconds: 140));

    final txCount = (data['transactions'] as List?)?.length ?? 0;
    await onProgress?.call(4, "Restoring projects, goals & financial records ($txCount transactions)...");
    final addedTransactions = mergeFinanceState(data);
    await Future.delayed(const Duration(milliseconds: 140));

    await onProgress?.call(5, "Synchronizing health data & home launcher configuration...");
    if (data['foodItems'] != null || data['healthLogs'] != null) {
      loadHealthState(data);
    }

    bool launcherMerged = false;
    if (data['launcher'] != null) {
      final l = data['launcher'];
      Map<String, dynamic>? lMap;
      if (l is Map) {
        lMap = Map<String, dynamic>.from(l);
      } else if (l is String) {
        try {
          final decoded = jsonDecode(l);
          if (decoded is Map) lMap = Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      if (lMap != null && lMap.isNotEmpty) {
        unawaited(LauncherService.instance.mergeFromMap(lMap));
        launcherMerged = true;
      }
    }

    if (data['trading'] != null) {
      final t = data['trading'];
      if (t is Map) {
        _paperTrading.loadState(Map<String, dynamic>.from(t));
      } else if (t is String) {
        try {
          final decoded = jsonDecode(t);
          if (decoded is Map) _paperTrading.loadState(Map<String, dynamic>.from(decoded));
        } catch (_) {}
      }
    }
    await Future.delayed(const Duration(milliseconds: 140));

    await onProgress?.call(6, "Finalizing local storage & refreshing system state...");
    markAllDirty();
    notifyListeners();
    await forceLocalBackup();
    await Future.delayed(const Duration(milliseconds: 120));

    return MergeReport(
      addedReflections: addedReflections,
      totalReflections: reflectionLogs.length,
      mergedDays: taskResult.mergedDays,
      totalHistoryDays: completedByDay.length,
      addedTasks: taskResult.addedTasks,
      addedProjects: taskResult.addedProjects,
      addedGoals: taskResult.addedGoals,
      addedTransactions: addedTransactions,
      launcherMerged: launcherMerged,
    );
  }

  /// Normalizes imported JSON across multiple schema versions, full backups,
  /// and raw Firebase Realtime Database exports.
  static Map<String, dynamic> normalizeImportedData(Map<String, dynamic> input) {
    var raw = Map<String, dynamic>.from(input);

    dynamic decodeIfString(dynamic val) {
      if (val is String) {
        final trimmed = val.trim();
        if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
            (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
          try {
            return jsonDecode(trimmed);
          } catch (_) {
            return val;
          }
        }
      }
      return val;
    }

    // Helper to safely normalize dynamic map/list into List<Map<String, dynamic>>
    List<Map<String, dynamic>> toListOfMaps(dynamic value) {
      value = decodeIfString(value);
      if (value is List) {
        return value.map((e) {
          final decoded = decodeIfString(e);
          return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
        }).whereType<Map<String, dynamic>>().toList();
      } else if (value is Map) {
        return value.entries.map((e) {
          final decoded = decodeIfString(e.value);
          if (decoded is Map) {
            final m = Map<String, dynamic>.from(decoded);
            m.putIfAbsent('id', () => e.key.toString());
            return m;
          }
          return <String, dynamic>{'id': e.key.toString()};
        }).toList();
      }
      return [];
    }

    // 1. Unwrap Firebase RTDB root: { "users": { "<uid>": { "data": { ... } } } } or { "data": { ... } }
    if (raw['users'] is Map) {
      final usersMap = raw['users'] as Map;
      if (usersMap.isNotEmpty) {
        final firstVal = decodeIfString(usersMap.values.first);
        if (firstVal is Map) {
          if (firstVal['data'] != null) {
            final d = decodeIfString(firstVal['data']);
            if (d is Map) raw = Map<String, dynamic>.from(d);
          } else {
            raw = Map<String, dynamic>.from(firstVal);
          }
        }
      }
    } else if (raw['data'] != null) {
      final d = decodeIfString(raw['data']);
      if (d is Map) raw = Map<String, dynamic>.from(d);
    }

    // Decode top-level string chunks if present
    for (final key in [
      'tasks', 'finance', 'health', 'history', 'reflections', 'reflectionLogs',
      'completedByDay', 'mainTasks', 'projects', 'goals', 'routineLists',
      'goalPlaces', 'transactions', 'categories', 'savingsGoals', 'accounts',
      'foodItems', 'healthLogs', 'launcher', 'trading', 'completedTasks', 'completed_tasks'
    ]) {
      if (raw[key] != null) {
        raw[key] = decodeIfString(raw[key]);
      }
    }

    // 2. Normalize reflections: can be under 'reflections' (Map or List) or 'reflectionLogs' (List)
    if (raw['reflectionLogs'] == null && raw['reflections'] != null) {
      raw['reflectionLogs'] = toListOfMaps(raw['reflections']);
    } else if (raw['reflectionLogs'] != null) {
      raw['reflectionLogs'] = toListOfMaps(raw['reflectionLogs']);
    }

    // 3. Normalize history: can be under 'history' (Map with 'completedByDay' or date keys)
    if (raw['completedByDay'] == null && raw['history'] != null) {
      final h = decodeIfString(raw['history']);
      if (h is Map) {
        if (h['completedByDay'] != null) {
          raw['completedByDay'] = decodeIfString(h['completedByDay']);
        } else {
          final normHistory = <String, dynamic>{};
          for (final entry in h.entries) {
            final k = entry.key.toString().replaceAll('_', '-');
            normHistory[k] = decodeIfString(entry.value);
          }
          final isDateMap = normHistory.keys.any((k) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(k));
          if (isDateMap) {
            raw['completedByDay'] = normHistory;
          }
        }
      }
    }

    // Deeply normalize completedByDay map
    if (raw['completedByDay'] is Map) {
      final cMap = Map<String, dynamic>.from(raw['completedByDay'] as Map);
      final normalizedCMap = <String, dynamic>{};
      for (final dateKey in cMap.keys) {
        final normDateKey = dateKey.toString().replaceAll('_', '-');
        var day = decodeIfString(cMap[dateKey]);
        if (day is Map) {
          final dayMap = Map<String, dynamic>.from(day);
          if (dayMap['tasks'] != null) dayMap['tasks'] = toListOfMaps(dayMap['tasks']);
          if (dayMap['subtasksCompleted'] != null) dayMap['subtasksCompleted'] = toListOfMaps(dayMap['subtasksCompleted']);
          if (dayMap['checkpointsCompleted'] != null) dayMap['checkpointsCompleted'] = toListOfMaps(dayMap['checkpointsCompleted']);
          if (dayMap['notifications'] != null) dayMap['notifications'] = toListOfMaps(dayMap['notifications']);
          if (dayMap['taskTimes'] != null) {
            final tt = decodeIfString(dayMap['taskTimes']);
            if (tt is Map) dayMap['taskTimes'] = Map<String, dynamic>.from(tt);
          }
          if (dayMap['dailyPlan'] != null) {
            final dp = decodeIfString(dayMap['dailyPlan']);
            if (dp is Map) {
              dayMap['dailyPlan'] = dp.values.map((e) => e.toString()).toList();
            } else if (dp is List) {
              dayMap['dailyPlan'] = dp.map((e) => e.toString()).toList();
            }
          }
          normalizedCMap[normDateKey] = dayMap;
        }
      }
      raw['completedByDay'] = normalizedCMap;
    }

    // 4. Normalize tasks chunk: if { "tasks": { "mainTasks": [...], "goals": [...] } }
    if (raw['tasks'] is Map) {
      final t = Map<String, dynamic>.from(raw['tasks'] as Map);
      if (t['mainTasks'] != null) raw['mainTasks'] ??= decodeIfString(t['mainTasks']);
      if (t['projects'] != null) raw['projects'] ??= decodeIfString(t['projects']);
      if (t['goals'] != null) raw['goals'] ??= decodeIfString(t['goals']);
      if (t['routineLists'] != null) raw['routineLists'] ??= decodeIfString(t['routineLists']);
      if (t['goalPlaces'] != null) raw['goalPlaces'] ??= decodeIfString(t['goalPlaces']);
      if (t['completedByDay'] != null) raw['completedByDay'] ??= decodeIfString(t['completedByDay']);
    }

    // Deeply normalize mainTasks and its nested subtasks / subSubTasks / sessions
    if (raw['mainTasks'] != null) {
      final tasksList = toListOfMaps(raw['mainTasks']);
      for (final t in tasksList) {
        if (t['subTasks'] != null) {
          final stList = toListOfMaps(t['subTasks']);
          for (final st in stList) {
            if (st['subSubTasks'] != null) st['subSubTasks'] = toListOfMaps(st['subSubTasks']);
            if (st['sessions'] != null) st['sessions'] = toListOfMaps(st['sessions']);
            if (st['progressDataPoints'] != null) st['progressDataPoints'] = toListOfMaps(st['progressDataPoints']);
            if (st['templateSets'] != null) st['templateSets'] = toListOfMaps(st['templateSets']);
          }
          t['subTasks'] = stList;
        }
      }
      raw['mainTasks'] = tasksList;
    }

    if (raw['projects'] != null) raw['projects'] = toListOfMaps(raw['projects']);
    if (raw['goals'] != null) {
      final gList = toListOfMaps(raw['goals']);
      for (final g in gList) {
        if (g['subChecklist'] != null) g['subChecklist'] = toListOfMaps(g['subChecklist']);
      }
      raw['goals'] = gList;
    }
    if (raw['routineLists'] != null) raw['routineLists'] = toListOfMaps(raw['routineLists']);
    if (raw['goalPlaces'] != null) raw['goalPlaces'] = toListOfMaps(raw['goalPlaces']);

    // 5. Normalize finance chunk: if { "finance": { "transactions": [...], ... } }
    if (raw['finance'] is Map) {
      final f = Map<String, dynamic>.from(raw['finance'] as Map);
      if (f['transactions'] != null) raw['transactions'] ??= decodeIfString(f['transactions']);
      if (f['categories'] != null) raw['categories'] ??= decodeIfString(f['categories']);
      if (f['savingsGoals'] != null) raw['savingsGoals'] ??= decodeIfString(f['savingsGoals']);
      if (f['accounts'] != null) raw['accounts'] ??= decodeIfString(f['accounts']);
    }
    if (raw['transactions'] != null) raw['transactions'] = toListOfMaps(raw['transactions']);
    if (raw['categories'] != null) raw['categories'] = toListOfMaps(raw['categories']);
    if (raw['savingsGoals'] != null) raw['savingsGoals'] = toListOfMaps(raw['savingsGoals']);
    if (raw['accounts'] != null) raw['accounts'] = toListOfMaps(raw['accounts']);

    // 6. Normalize health chunk
    if (raw['health'] is Map) {
      final h = Map<String, dynamic>.from(raw['health'] as Map);
      if (h['foodItems'] != null) raw['foodItems'] ??= decodeIfString(h['foodItems']);
      if (h['healthLogs'] != null) raw['healthLogs'] ??= decodeIfString(h['healthLogs']);
    }
    if (raw['foodItems'] != null) raw['foodItems'] = toListOfMaps(raw['foodItems']);
    if (raw['healthLogs'] != null) {
      final hl = decodeIfString(raw['healthLogs']);
      if (hl is Map) {
        raw['healthLogs'] = hl;
      } else if (hl is List) {
        raw['healthLogs'] = toListOfMaps(hl);
      }
    }

    // 7. Normalize launcher chunk: string or map
    if (raw['launcher'] != null) {
      raw['launcher'] = decodeIfString(raw['launcher']);
    }

    // 8. Standalone completedTasks / completed_tasks
    if (raw['completedTasks'] != null) {
      raw['completedTasks'] = decodeIfString(raw['completedTasks']);
    }
    if (raw['completed_tasks'] != null) {
      raw['completed_tasks'] = decodeIfString(raw['completed_tasks']);
    }

    return raw;
  }

  // --- UI Helpers ---

  void setLoadingTask(String? name) {
    _loadingTaskName = name;
    notifyListeners();
  }

  void setProviderAISubquestLoading(bool loading) {
    _isGeneratingSubquestsForTask = loading;
    notifyListeners();
  }

  void setProviderApiKeyIndex(int index) => setApiKeyIndex(index);

  // --- State Bridge ---
  
  void setProviderState({
      String? lastLoginDate,
      List<MainTask>? mainTasks,
      Map<String, dynamic>? completedByDay,
      Map<String, dynamic>? activeTimers,
      DateTime? lastSuccessfulSaveTimestamp,
      bool? isUsernameMissing,
      ChatbotMemory? chatbotMemory,
      List<FinanceTransaction>? transactions,
      List<FinanceCategory>? categories,
      List<SavingsGoal>? savingsGoals,
      List<FinanceAccount>? accounts,
      List<Project>? projects,
      bool doNotify = true,
      bool doPersist = true
  }) {
    if (lastLoginDate != null) setLastLoginDate(lastLoginDate);
    if (mainTasks != null) {
      if (!authLoading && doPersist) {
        _recordTaskLedgerDelta(this.mainTasks, mainTasks);
      }
      setMainTasks(mainTasks);
    }
    if (completedByDay != null) setCompletedByDay(completedByDay);
    if (activeTimers != null) setActiveTimers(activeTimers);
    if (chatbotMemory != null) setChatbotMemory(chatbotMemory);
    if (transactions != null) {
      if (!authLoading && doPersist) {
        _recordTransactionLedgerDelta(this.transactions, transactions);
      }
      setTransactions(transactions);
    }
    if (categories != null) setCategories(categories);
    if (savingsGoals != null) setSavingsGoals(savingsGoals);
    if (accounts != null) setAccounts(accounts);
    if (projects != null) {
      if (!authLoading && doPersist) {
        _recordProjectLedgerDelta(this.projects, projects);
      }
      setProjects(projects);
    }

    if (doNotify) notifyListeners();
  }

  void _recordTaskLedgerDelta(List<MainTask> oldList, List<MainTask> newList) {
    try {
      final oldMap = {for (final t in oldList) t.id: t};
      final newMap = {for (final t in newList) t.id: t};

      for (final t in newList) {
        if (!oldMap.containsKey(t.id)) {
          unawaited(AppActionLedgerService.instance.recordAction(
            actionType: 'CREATE',
            collection: 'task',
            entityId: t.id,
            title: t.name,
            summary: 'Created mission "${t.name}"',
            before: null,
            after: t.toJson(),
          ));
        }
      }

      for (final t in oldList) {
        if (!newMap.containsKey(t.id)) {
          unawaited(AppActionLedgerService.instance.recordAction(
            actionType: 'DELETE',
            collection: 'task',
            entityId: t.id,
            title: t.name,
            summary: 'Deleted mission "${t.name}"',
            before: t.toJson(),
            after: null,
          ));
        }
      }

      for (final t in newList) {
        if (oldMap.containsKey(t.id)) {
          final oldTask = oldMap[t.id]!;
          // Untouched tasks/subtasks keep their identity across copyWith, so skip the (expensive)
          // serialize-and-compare for everything except what an action actually replaced.
          if (!identical(oldTask, t) && jsonEncode(oldTask.toJson()) != jsonEncode(t.toJson())) {
            final oldSubMap = {for (final s in oldTask.subTasks) s.id: s};
            final newSubMap = {for (final s in t.subTasks) s.id: s};

            for (final s in t.subTasks) {
              if (!oldSubMap.containsKey(s.id)) {
                unawaited(AppActionLedgerService.instance.recordAction(
                  actionType: 'CREATE',
                  collection: 'subtask',
                  entityId: '${t.id}:${s.id}',
                  title: s.name,
                  summary: 'Added subtask "${s.name}" to "${t.name}"',
                  before: null,
                  after: s.toJson(),
                ));
              } else {
                final oldS = oldSubMap[s.id]!;
                if (!identical(oldS, s) && jsonEncode(oldS.toJson()) != jsonEncode(s.toJson())) {
                  final action = (oldS.completed != s.completed) ? (s.completed ? 'COMPLETE' : 'INCOMPLETE') : 'UPDATE';
                  unawaited(AppActionLedgerService.instance.recordAction(
                    actionType: action,
                    collection: 'subtask',
                    entityId: '${t.id}:${s.id}',
                    title: s.name,
                    summary: '${action == 'COMPLETE' ? 'Completed' : 'Updated'} subtask "${s.name}" in "${t.name}"',
                    before: oldS.toJson(),
                    after: s.toJson(),
                  ));
                }
              }
            }

            for (final s in oldTask.subTasks) {
              if (!newSubMap.containsKey(s.id)) {
                unawaited(AppActionLedgerService.instance.recordAction(
                  actionType: 'DELETE',
                  collection: 'subtask',
                  entityId: '${t.id}:${s.id}',
                  title: s.name,
                  summary: 'Deleted subtask "${s.name}" from "${t.name}"',
                  before: s.toJson(),
                  after: null,
                ));
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  void _recordTransactionLedgerDelta(List<FinanceTransaction> oldList, List<FinanceTransaction> newList) {
    try {
      final oldMap = {for (final t in oldList) t.id: t};
      final newMap = {for (final t in newList) t.id: t};

      for (final t in newList) {
        final txTitle = t.note.isNotEmpty ? t.note : 'Transaction (\$${t.amount.toStringAsFixed(2)})';
        if (!oldMap.containsKey(t.id)) {
          unawaited(AppActionLedgerService.instance.recordAction(
            actionType: 'CREATE',
            collection: 'transaction',
            entityId: t.id,
            title: txTitle,
            summary: 'Added transaction "$txTitle" (\$${t.amount.toStringAsFixed(2)})',
            before: null,
            after: t.toJson(),
          ));
        } else {
          final oldT = oldMap[t.id]!;
          if (jsonEncode(oldT.toJson()) != jsonEncode(t.toJson())) {
            unawaited(AppActionLedgerService.instance.recordAction(
              actionType: 'UPDATE',
              collection: 'transaction',
              entityId: t.id,
              title: txTitle,
              summary: 'Updated transaction "$txTitle"',
              before: oldT.toJson(),
              after: t.toJson(),
            ));
          }
        }
      }

      for (final t in oldList) {
        final txTitle = t.note.isNotEmpty ? t.note : 'Transaction (\$${t.amount.toStringAsFixed(2)})';
        if (!newMap.containsKey(t.id)) {
          unawaited(AppActionLedgerService.instance.recordAction(
            actionType: 'DELETE',
            collection: 'transaction',
            entityId: t.id,
            title: txTitle,
            summary: 'Deleted transaction "$txTitle"',
            before: t.toJson(),
            after: null,
          ));
        }
      }
    } catch (_) {}
  }

  void _recordProjectLedgerDelta(List<Project> oldList, List<Project> newList) {
    try {
      final oldMap = {for (final p in oldList) p.id: p};
      final newMap = {for (final p in newList) p.id: p};

      for (final p in newList) {
        if (!oldMap.containsKey(p.id)) {
          unawaited(AppActionLedgerService.instance.recordAction(
            actionType: 'CREATE',
            collection: 'project',
            entityId: p.id,
            title: p.name,
            summary: 'Created project "${p.name}"',
            before: null,
            after: p.toJson(),
          ));
        } else {
          final oldP = oldMap[p.id]!;
          if (jsonEncode(oldP.toJson()) != jsonEncode(p.toJson())) {
            unawaited(AppActionLedgerService.instance.recordAction(
              actionType: 'UPDATE',
              collection: 'project',
              entityId: p.id,
              title: p.name,
              summary: 'Updated project "${p.name}"',
              before: oldP.toJson(),
              after: p.toJson(),
            ));
          }
        }
      }

      for (final p in oldList) {
        if (!newMap.containsKey(p.id)) {
          unawaited(AppActionLedgerService.instance.recordAction(
            actionType: 'DELETE',
            collection: 'project',
            entityId: p.id,
            title: p.name,
            summary: 'Deleted project "${p.name}"',
            before: p.toJson(),
            after: null,
          ));
        }
      }
    } catch (_) {}
  }

  // --- Project Helpers ---
  void addProject(Project project) {
    final list = List<Project>.from(projects)..add(project);
    setProjects(list);
    notifyListeners();
  }

  void updateProject(Project project) {
    final list = projects.map((p) => p.id == project.id ? project : p).toList();
    setProjects(list);
    notifyListeners();
  }

  void deleteProject(String projectId, {bool silent = false}) {
    final project = projects.firstWhereOrNull((p) => p.id == projectId);
    if (project == null) return;
    final savedProjects = projects;
    final list = projects.where((p) => p.id != projectId).toList();
    setProjects(list);
    notifyListeners();

    if (!silent) {
      showUndoSnackBar(
        message: 'Deleted project "${project.name}"',
        onUndo: () {
          setProjects(savedProjects);
          notifyListeners();
        },
      );
    }
  }

  void reorderProjects(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final list = List<Project>.from(projects);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    setProjects(list);
    notifyListeners();
  }

  @override
  void setMainTasks(List<MainTask> tasks) {
    super.setMainTasks(tasks);
    final running = activeTimers.entries.firstWhereOrNull((e) => e.value.isRunning);
    if (running != null) {
      refreshTimerNotification(running.value.mainTaskId, running.key);
    }
  }

  // --- Delegated Actions ---

  void addMainTask({required String name, required String description, required String theme, required String colorHex}) => _taskActions.addMainTask(name: name, description: description, theme: theme, colorHex: colorHex);
  void editMainTask(String taskId, {required String name, required String description, required String theme, required String colorHex}) => _taskActions.editMainTask(taskId, name: name, description: description, theme: theme, colorHex: colorHex);
  void logToDailySummary(String type, Map<String, dynamic> data) => _taskActions.logToDailySummary(type, data);
  String addSubtask(String mainTaskId, Map<String, dynamic> subtaskData) => _taskActions.addSubtask(mainTaskId, subtaskData);
  void updateSubtask(String mainTaskId, String subtaskId, Map<String, dynamic> updates) => _taskActions.updateSubtask(mainTaskId, subtaskId, updates);
  bool addSessionToSubtask(String mainTaskId, String subTaskId, DateTime start, DateTime end) => _taskActions.addSessionToSubtask(mainTaskId, subTaskId, start, end);
  void updateSessionInSubtask(String mainTaskId, String subTaskId, String sessionId, DateTime newStart, DateTime newEnd) => _taskActions.updateSessionInSubtask(mainTaskId, subTaskId, sessionId, newStart, newEnd);
  void deleteSessionFromSubtask(String mainTaskId, String subTaskId, String sessionId, {bool silent = false}) => _taskActions.deleteSessionFromSubtask(mainTaskId, subTaskId, sessionId, silent: silent);
  bool completeSubtask(String mainTaskId, String subtaskId, {bool fromSync = false}) => _taskActions.completeSubtask(mainTaskId, subtaskId, fromSync: fromSync);
  void uncompleteSubtask(String mainTaskId, String subtaskId, {bool fromSync = false}) => _taskActions.uncompleteSubtask(mainTaskId, subtaskId, fromSync: fromSync);
  void deleteSubtask(String mainTaskId, String subtaskId) => _taskActions.deleteSubtask(mainTaskId, subtaskId);
  void duplicateCompletedSubtask(String mainTaskId, String subtaskId) => _taskActions.duplicateCompletedSubtask(mainTaskId, subtaskId);
  String addSubSubtask(String mainTaskId, String parentSubtaskId, Map<String, dynamic> subSubtaskData, {String? parentCheckpointId}) => _taskActions.addSubSubtask(mainTaskId, parentSubtaskId, subSubtaskData, parentCheckpointId: parentCheckpointId);
  void updateSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, Map<String, dynamic> updates) => _taskActions.updateSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId, updates);
  void completeSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, {bool fromSync = false}) => _taskActions.completeSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId, fromSync: fromSync);
  void uncompleteSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId, {bool fromSync = false}) => _taskActions.uncompleteSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId, fromSync: fromSync);
  void deleteSubSubtask(String mainTaskId, String parentSubtaskId, String subSubtaskId) => _taskActions.deleteSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId);
  void reorderSubtasks(String mainTaskId, int oldIndex, int newIndex) => _taskActions.reorderSubtasks(mainTaskId, oldIndex, newIndex);
  Future<void> recalibrateTimeLogs({bool silent = false}) => _taskActions.recalibrateTimeLogs(silent: silent);
  void saveProgressDataPoint(String mainTaskId, String subTaskId, double progress, int spentSeconds) => _taskActions.saveProgressDataPoint(mainTaskId, subTaskId, progress, spentSeconds);
  void deleteProgressDataPoint(String mainTaskId, String subTaskId, int index) => _taskActions.deleteProgressDataPoint(mainTaskId, subTaskId, index);
  void startTimer(String id, String type, String mainTaskId) => _timerActions.startTimer(id, type, mainTaskId);
  void pauseTimer(String id) => _timerActions.pauseTimer(id);
  void logTimerAndReset(String id) => _timerActions.logTimerAndReset(id);
  Future<void> triggerAISubquestGeneration(MainTask mainTask, String generationMode, String userInput, int numSubquests) => _aiGenerationActions.triggerAISubquestGeneration(mainTask, generationMode, userInput, numSubquests);

  // --- Auth & Wrappers ---

  Future<void> loginUser(String email, String password) async => await fb_service.signInWithEmail(email, password);
  Future<void> logoutUser() async => await fb_service.signOut();
  
  Future<void> signupUser(String email, String password) async {
    final user = await fb_service.signUpWithEmail(email, password);
    if (user != null) {
      await fb_service.updateDisplayName("OPERATIVE");
      setCurrentUser(fb_service.currentUser);
    }
  }

  Future<void> changePasswordHandler(String pwd) async => await fb_service.changePassword(pwd);
  Future<void> updateUserDisplayName(String name) async {
    if (currentUser != null) {
      await fb_service.updateDisplayName(name);
      setCurrentUser(fb_service.currentUser);
    }
  }

  void markAllDirty() {
    markDirty('settings');
    markDirty('tasks');
    markDirty('history');
    markDirty('reflections');
    markDirty('finance');
    markDirty('health');
    markDirty('trading');
    markDirty('launcher');
  }

  Future<void> clearAllData() async {
    if (currentUser == null) return;
    await _cloudStorage.deleteUserData(currentUser!.uid);
    await _localStorage.clearState(currentUser!.uid);
    await _resetToInitialState();
    markAllDirty();
  }

  Future<MergeReport?> restoreFromLocalSnapshot(File backupFile, {bool merge = true}) async {
    try {
      final contents = await backupFile.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;
      MergeReport? report;
      if (merge) {
        report = mergeAppStateFromMap(data);
      } else {
        loadStateFromMap(data);
      }
      markAllDirty();
      await forceLocalBackup();
      return report;
    } catch (e) {
      rethrow;
    }
  }

  /// Foreground cloud recovery with granular progress updates.
  Future<MergeReport?> restoreFromCloudWithProgress({
    bool merge = true,
    Future<void> Function(int stepIndex, String message)? onProgress,
  }) async {
    if (currentUser == null) return null;
    setManuallyLoading(true);
    try {
      await onProgress?.call(0, "Connecting to cloud & fetching remote snapshot");
      final cloudData = await storageService.getUserData(currentUser!.uid);
      if (cloudData == null || cloudData.isEmpty) {
        throw Exception("No cloud backup found for this account.");
      }

      MergeReport? report;
      if (merge) {
        report = await mergeAppStateFromMapWithProgress(cloudData, onProgress: onProgress);
      } else {
        await onProgress?.call(1, "Normalizing cloud snapshot payload");
        final norm = normalizeImportedData(cloudData);
        await onProgress?.call(2, "Replacing full database state");
        beginDataLoad();
        try {
          loadStateFromMap(norm);
        } finally {
          endDataLoad();
        }
        await onProgress?.call(3, "Synchronizing local timestamps");
        try {
          final remoteTs = await storageService.getLastModified(currentUser!.uid);
          if (remoteTs > settings.lastModified) {
            settings.lastModified = remoteTs;
          }
        } catch (_) {}
        await onProgress?.call(4, "Writing atomic local cache");
        markAllDirty();
        await forceLocalBackup();
      }
      return report;
    } finally {
      setManuallyLoading(false);
    }
  }

  /// Foreground snapshot recovery with granular progress updates.
  Future<MergeReport?> restoreFromLocalSnapshotWithProgress(
    File backupFile, {
    bool merge = true,
    Future<void> Function(int stepIndex, String message)? onProgress,
  }) async {
    try {
      await onProgress?.call(0, "Reading backup snapshot file from disk");
      final contents = await backupFile.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;
      MergeReport? report;
      if (merge) {
        report = await mergeAppStateFromMapWithProgress(data, onProgress: onProgress);
      } else {
        await onProgress?.call(1, "Normalizing snapshot payload");
        final norm = normalizeImportedData(data);
        await onProgress?.call(2, "Replacing full database state");
        loadStateFromMap(norm);
        await onProgress?.call(4, "Writing atomic local cache");
        markAllDirty();
        await forceLocalBackup();
      }
      return report;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveNoraBackupSnapshot() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${backupDir.path}/nora_backup_$timestamp.json');
      final data = getAppStateAsMap();
      await file.writeAsString(jsonEncode(data));
      debugPrint("Nora backup created at: ${file.path}");
    } catch (e) {
      debugPrint("Error creating Nora backup: $e");
    }
  }

  void initializeChatbotMemory() {
    notifyListeners(); 
  }

  Future<void> exportReflections() async {
    final data = {'reflectionLogs': reflectionLogs.map((l) => l.toJson()).toList()};
    await _exportService.exportJson(data, 'arcane_reflections');
  }

  Future<void> importReflections() async {
    final data = await _exportService.importJson();
    if (data != null && data['reflectionLogs'] != null) {
      final List<dynamic> logsJson = data['reflectionLogs'];
      final importedLogs = logsJson.map((l) => ReflectionLog.fromJson(l as Map<String, dynamic>)).toList();
      final currentIds = reflectionLogs.map((l) => l.id).toSet();
      final newLogs = importedLogs.where((l) => !currentIds.contains(l.id)).toList();
      if (newLogs.isNotEmpty) {
        setReflectionLogs([...reflectionLogs, ...newLogs]..sort((a,b) => a.timestamp.compareTo(b.timestamp)));
      }
    }
  }

  // --- Gratitude / Assets Actions ---
  void updateGratitudeList(List<GratitudeItem> newList) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.gratitudeList = newList;
    setChatbotMemory(newMemory);
  }

  void updateGratitudeItem(GratitudeItem updatedItem) {
    final currentList = List<GratitudeItem>.from(chatbotMemory.gratitudeList);
    final index = currentList.indexWhere((i) => i.id == updatedItem.id);
    if (index != -1) {
      currentList[index] = updatedItem;
    } else {
      currentList.insert(0, updatedItem);
    }
    updateGratitudeList(currentList);
  }

  // --- People Actions ---
  void updatePeopleList(List<PersonInfo> newList) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.people = newList;
    setChatbotMemory(newMemory);
  }

  void updatePersonInfo(PersonInfo updatedPerson) {
    final currentList = List<PersonInfo>.from(chatbotMemory.people);
    final index = currentList.indexWhere((p) => p.id == updatedPerson.id);
    if (index != -1) {
      currentList[index] = updatedPerson;
    } else {
      currentList.insert(0, updatedPerson);
    }
    updatePeopleList(currentList);
  }

  /// Automatically updates person profile across main info, Tab 1 (The Manual - Last Contact Intel & Next Meet Plan), and Tab 2 (AI Dossier/Biodata)
  void logInteractionForPerson({
    required String name,
    String? relation,
    String? interactionSummary,
    String? nextActionPlan,
    DateTime? date,
    String? occupation,
    String? location,
  }) {
    final targetName = name.trim();
    if (targetName.isEmpty) return;

    final today = date ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(today);

    final currentPeople = List<PersonInfo>.from(chatbotMemory.people);
    final existingIndex = currentPeople.indexWhere((p) => p.name.toLowerCase() == targetName.toLowerCase());

    PersonInfo person;
    if (existingIndex != -1) {
      person = currentPeople[existingIndex];
      if (relation != null && relation.trim().isNotEmpty && (person.relation.isEmpty || person.relation == 'Acquaintance')) {
        person.relation = relation.trim();
      }
    } else {
      person = PersonInfo(
        id: const Uuid().v4(),
        name: targetName,
        relation: (relation != null && relation.trim().isNotEmpty) ? relation.trim() : 'Acquaintance',
      );
      currentPeople.add(person);
    }

    person.lastUpdated = DateTime.now();

    // 1. Tab 1: THE MANUAL -> Last Contact Intel Chronicle (manualLastContactIntel)
    if (interactionSummary != null && interactionSummary.trim().isNotEmpty) {
      final summaryClean = interactionSummary.trim();
      final intelEntry = "[$dateStr] $summaryClean";
      final intelList = List<String>.from(person.manualLastContactIntel ?? []);

      final alreadyLogged = intelList.any((e) => e.contains(dateStr) && e.contains(summaryClean));
      if (!alreadyLogged) {
        intelList.insert(0, intelEntry);
        person.manualLastContactIntel = intelList;
      }
    }

    // 2. Tab 1: THE MANUAL -> Next Meet/Collaboration Plan (manualNextMeetPlan)
    if (nextActionPlan != null && nextActionPlan.trim().isNotEmpty) {
      final actionClean = nextActionPlan.trim();
      final planEntry = "[$dateStr] $actionClean";
      if (person.manualNextMeetPlan == null || person.manualNextMeetPlan!.trim().isEmpty) {
        person.manualNextMeetPlan = planEntry;
      } else if (!person.manualNextMeetPlan!.contains(actionClean)) {
        person.manualNextMeetPlan = "$planEntry\n${person.manualNextMeetPlan}";
      }
    }

    // 3. Tab 2 & Dossier: Update Biodata & AI Dossier interaction history
    if (occupation != null && occupation.trim().isNotEmpty && (person.manualOccupation == null || person.manualOccupation!.isEmpty)) {
      person.manualOccupation = occupation.trim();
    }
    if (location != null && location.trim().isNotEmpty && (person.manualLocation == null || person.manualLocation!.isEmpty)) {
      person.manualLocation = location.trim();
    }

    // Update AI Dossier details structure if available
    if (interactionSummary != null && interactionSummary.trim().isNotEmpty) {
      Map<String, dynamic> parsedDetails = {};
      if (person.details != null && person.details!.isNotEmpty) {
        try {
          parsedDetails = jsonDecode(person.details!);
        } catch (_) {}
      }
      final history = (parsedDetails['interaction_history'] as List?)?.map((e) => e is Map ? Map<String, dynamic>.from(e) : {'text': e.toString()}).toList() ?? [];
      final existsInHistory = history.any((h) => (h['text']?.toString() ?? '').contains(interactionSummary.trim()));
      if (!existsInHistory) {
        history.insert(0, {
          'highlight': DateFormat('MMM dd').format(today),
          'text': interactionSummary.trim(),
        });
        parsedDetails['interaction_history'] = history;
        person.details = jsonEncode(parsedDetails);
      }
    }

    updatePersonInfo(person);
  }
  
  // --- Someday List Actions ---
  void addSomedayItem(String title) {
    final newItem = SomedayItem(id: const Uuid().v4(), title: title, createdAt: DateTime.now());
    final newSettings = AppSettings.fromJson(settings.toJson());
    newSettings.somedayList.insert(0, newItem);
    setSettings(newSettings);
  }

  void removeSomedayItem(String id, {bool silent = false}) {
    final item = settings.somedayList.firstWhereOrNull((i) => i.id == id);
    if (item == null) return;
    final previousSettings = AppSettings.fromJson(settings.toJson());
    final newSettings = AppSettings.fromJson(settings.toJson());
    newSettings.somedayList.removeWhere((i) => i.id == id);
    setSettings(newSettings);

    if (!silent) {
      showUndoSnackBar(
        message: 'Removed "${item.title}"',
        onUndo: () {
          setSettings(previousSettings);
        },
      );
    }
  }

  // --- Reports Logic ---
  Map<String, dynamic> getLast7DaysData([DateTime? targetDate]) { 
    final now = targetDate != null
        ? DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999)
        : DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7));
    final historyStr = HistoryHelper.getSessionHistoryString(mainTasks, 7, now); 
    final recentReflections = reflectionLogs
        .where((l) => l.timestamp.isAfter(cutoff) && l.timestamp.isBefore(now))
        .map((l) => "[${DateFormat('MM-dd').format(l.timestamp)}] ${l.trigger} -> ${l.emotion}")
        .join("\n");
    return {'logs': recentReflections, 'times': historyStr, 'sessions': historyStr};
  }
  
  String getWeeklyWellbeingComparison([DateTime? targetDate]) {
    final now = targetDate != null
        ? DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999)
        : DateTime.now();
    final last7 = now.subtract(const Duration(days: 7));
    final prev7 = now.subtract(const Duration(days: 14));
    
    Map<String, int> currentNeeds = {};
    Map<String, int> prevNeeds = {};
    
    for (var log in reflectionLogs) {
      if (log.timestamp.isAfter(last7) && log.timestamp.isBefore(now)) {
        log.needs.forEach((k, v) {
          final normalized = WellbeingTheme.normalizeSkillName(k);
          if (normalized != null) {
            currentNeeds[normalized] = (currentNeeds[normalized] ?? 0) + v;
          }
        });
      } else if (log.timestamp.isAfter(prev7) && log.timestamp.isBefore(last7)) {
        log.needs.forEach((k, v) {
          final normalized = WellbeingTheme.normalizeSkillName(k);
          if (normalized != null) {
            prevNeeds[normalized] = (prevNeeds[normalized] ?? 0) + v;
          }
        });
      }
    }

    final currTotal = currentNeeds.values.fold<int>(0, (a, b) => a + b);
    final prevTotal = prevNeeds.values.fold<int>(0, (a, b) => a + b);
    int pct(int v, int total) => total <= 0 ? 0 : (v * 100 / total).round();

    final buffer = StringBuffer();
    for (var skill in getBaseWellbeingSkills()) {
      final curr = currentNeeds[skill.name] ?? 0;
      final prev = prevNeeds[skill.name] ?? 0;
      if (curr > 0 || prev > 0) {
        buffer.writeln("${skill.name}: ${pct(curr, currTotal)}% of reflection focus (Prev week: ${pct(prev, prevTotal)}%)");
      }
    }
    return buffer.toString();
  }

  /// Collects daily gratitude notes from saved tactical briefings & reflections across the 7 days ending at [targetDate].
  List<Map<String, dynamic>> getWeeklyGratitudeBreakdown([DateTime? targetDate]) {
    final now = targetDate != null
        ? DateTime(targetDate.year, targetDate.month, targetDate.day)
        : DateTime.now();
    final List<Map<String, dynamic>> days = [];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dStr = DateFormat('yyyy-MM-dd').format(day);
      final dayName = DateFormat('EEEE').format(day);
      final displayLabel = DateFormat('EEE, MMM d').format(day);

      final briefing = getTacticalBriefing(dStr);
      final List<Map<String, dynamic>> items = [];

      if (briefing != null) {
        final rawGrat = (briefing['grateful_today'] as List<dynamic>?)
            ?? (briefing['grateful_assets'] as List<dynamic>?)
            ?? [];
        for (final item in rawGrat) {
          if (item is Map) {
            final text = item['text']?.toString() ?? '';
            final iconType = item['icon_type']?.toString() ?? 'general';
            if (text.isNotEmpty) {
              items.add({'text': text, 'icon_type': iconType});
            }
          } else if (item is String && item.isNotEmpty) {
            items.add({'text': item, 'icon_type': 'general'});
          }
        }
      }

      days.add({
        'date': dStr,
        'day_name': dayName,
        'label': displayLabel,
        'items': items,
      });
    }
    return days;
  }

  Future<List<Map<String, dynamic>>> getArchivedWeeklyReports({bool forceRefresh = false}) async {
    if (currentUser == null) return _cachedWeeklyReports;
    if (_cachedWeeklyReports.isNotEmpty && !forceRefresh) {
      return _cachedWeeklyReports;
    }
    final reports = await _cloudStorage.fetchWeeklyReports(currentUser!.uid);
    _cachedWeeklyReports = reports;
    return reports;
  }

  Future<void> saveWeeklyReport(String date, Map<String, dynamic> data) async {
    final existingIdx = _cachedWeeklyReports.indexWhere((r) => r['id'] == date);
    final entry = {'id': date, 'report': data, 'updatedAt': DateTime.now().toIso8601String()};
    if (existingIdx >= 0) {
      _cachedWeeklyReports[existingIdx] = entry;
    } else {
      _cachedWeeklyReports.insert(0, entry);
    }
    final newCompletedByDay = Map<String, dynamic>.from(completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[date] ?? {});
    dayData['weeklyReport'] = data;
    newCompletedByDay[date] = dayData;
    setCompletedByDay(newCompletedByDay);

    if (currentUser != null) {
      await _cloudStorage.saveWeeklyReport(currentUser!.uid, date, data);
    }
  }

  Future<List<Map<String, dynamic>>> getArchivedMonthlyReports({bool forceRefresh = false}) async {
    if (currentUser == null) return _cachedMonthlyReports;
    if (_cachedMonthlyReports.isNotEmpty && !forceRefresh) {
      return _cachedMonthlyReports;
    }
    final reports = await _cloudStorage.fetchMonthlyReports(currentUser!.uid);
    _cachedMonthlyReports = reports;
    return reports;
  }

  Future<void> saveMonthlyReport(String date, Map<String, dynamic> data) async {
    final existingIdx = _cachedMonthlyReports.indexWhere((r) => r['id'] == date);
    final entry = {'id': date, 'report': data, 'updatedAt': DateTime.now().toIso8601String()};
    if (existingIdx >= 0) {
      _cachedMonthlyReports[existingIdx] = entry;
    } else {
      _cachedMonthlyReports.insert(0, entry);
    }
    final newCompletedByDay = Map<String, dynamic>.from(completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[date] ?? {});
    dayData['monthlyReport'] = data;
    newCompletedByDay[date] = dayData;
    setCompletedByDay(newCompletedByDay);

    if (currentUser != null) {
      await _cloudStorage.saveMonthlyReport(currentUser!.uid, date, data);
    }
  }

  void saveTacticalBriefing(String date, Map<String, dynamic> data) { 
    final newCompletedByDay = Map<String, dynamic>.from(completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[date] ?? {});
    dayData['aiBriefing'] = data;
    newCompletedByDay[date] = dayData;
    setCompletedByDay(newCompletedByDay);

    if (currentUser != null) {
      _cloudStorage.saveDailyData(currentUser!.uid, date, 'briefing', data);
      unawaited(syncEndOfDay());
    }
  }

  void deleteTacticalBriefing(String date) {
    final newCompletedByDay = Map<String, dynamic>.from(completedByDay);
    if (newCompletedByDay.containsKey(date)) {
      final dayData = Map<String, dynamic>.from(newCompletedByDay[date]);
      dayData.remove('aiBriefing');
      newCompletedByDay[date] = dayData;
      setCompletedByDay(newCompletedByDay);
    }
    if (currentUser != null) {
      _cloudStorage.saveDailyData(currentUser!.uid, date, 'briefing', {});
    }
  }

  Map<String, dynamic> buildTaskSnapshot() {
    final taskSnapshot = <String, dynamic>{};
    for (var task in mainTasks) {
      if (task.isDeleted || !task.isActive) continue;
      final subtaskData = <String, dynamic>{};
      for (var sub in task.subTasks) {
        if (sub.isDeleted || !sub.isActive) continue;
        if (sub.completed && !sub.isRecurring) continue;
        subtaskData[sub.id] = {
          'name': sub.name,
          'progress': sub.calculateProgress(),
          'time_spent': sub.currentTimeSpent,
          'completed': sub.completed,
        };
      }
      taskSnapshot[task.id] = {
        'name': task.name,
        'color_hex': task.colorHex,
        'subtasks': subtaskData,
      };
    }
    return taskSnapshot;
  }

  void saveStartDayReport(String date, Map<String, dynamic> data) { 
    final reportData = Map<String, dynamic>.from(data);
    if (reportData['task_snapshot'] == null) {
      reportData['task_snapshot'] = buildTaskSnapshot();
    }
    if (reportData['weekly_monthly_goals_snapshot'] == null) {
      reportData['weekly_monthly_goals_snapshot'] = GoalBriefingHelper.buildWeeklyMonthlyGoalsSnapshot(this, DateTime.now());
    }
    final newCompletedByDay = Map<String, dynamic>.from(completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[date] ?? {});
    dayData['startDayReport'] = reportData;
    newCompletedByDay[date] = dayData;
    setCompletedByDay(newCompletedByDay);

    if (currentUser != null) {
      _cloudStorage.saveDailyData(currentUser!.uid, date, 'report', reportData);
    }
  }

  /// Calibrates today's startup baseline for tasks, allowing progress calculation
  /// to accurately track tasks worked on or checked today.
  void createTimeLogStartForToday({required Set<String> checkedSubtaskIds}) {
    final today = helper.getTodayDateString();
    final taskSnapshot = <String, dynamic>{};
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var task in mainTasks) {
      if (task.isDeleted || !task.isActive) continue;
      final subtaskData = <String, dynamic>{};
      for (var sub in task.subTasks) {
        if (sub.isDeleted || !sub.isActive) continue;
        
        final isCheckedToday = checkedSubtaskIds.contains(sub.id);
        
        double baselineProgress;
        int baselineTime;

        if (isCheckedToday) {
          int todaySessionsSec = 0;
          for (var s in sub.sessions) {
            if (s.startTime.isAfter(startOfToday)) {
              todaySessionsSec += s.durationSeconds;
            }
          }
          baselineProgress = 0.0;
          baselineTime = (sub.currentTimeSpent - todaySessionsSec).clamp(0, sub.currentTimeSpent);
        } else {
          baselineProgress = sub.calculateProgress();
          baselineTime = sub.currentTimeSpent;
        }

        subtaskData[sub.id] = {
          'name': sub.name,
          'progress': baselineProgress,
          'time_spent': baselineTime,
          'completed': !isCheckedToday && sub.completed,
        };
      }
      taskSnapshot[task.id] = {
        'name': task.name,
        'color_hex': task.colorHex,
        'subtasks': subtaskData,
      };
    }

    final newCompletedByDay = Map<String, dynamic>.from(completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[today] ?? {});
    final startDayReport = Map<String, dynamic>.from(dayData['startDayReport'] as Map? ?? {});
    startDayReport['task_snapshot'] = taskSnapshot;
    startDayReport['snapshot_time'] = now.toIso8601String();
    startDayReport['weekly_monthly_goals_snapshot'] ??= GoalBriefingHelper.buildWeeklyMonthlyGoalsSnapshot(this, now);
    dayData['startDayReport'] = startDayReport;
    newCompletedByDay[today] = dayData;
    setCompletedByDay(newCompletedByDay);

    if (currentUser != null) {
      _cloudStorage.saveDailyData(currentUser!.uid, today, 'report', startDayReport);
    }
    notifyListeners();
  }

  /// Starts a new day for the given [date], establishing a fresh task baseline snapshot
  /// at the current time so that live progress is accurately measured from this moment forward.
  void startNewDayForDate(
    String date, {
    String? startupNote,
    List<String>? directives,
    Map<String, dynamic>? initialReportData,
  }) {
    final now = DateTime.now();
    final taskSnapshot = buildTaskSnapshot();

    final newCompletedByDay = Map<String, dynamic>.from(completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[date] ?? {});
    final startDayReport = Map<String, dynamic>.from(
      dayData['startDayReport'] as Map? ?? initialReportData ?? {},
    );

    startDayReport['task_snapshot'] = taskSnapshot;
    startDayReport['snapshot_time'] = now.toIso8601String();
    startDayReport['day_started'] = true;
    startDayReport['started_at'] = now.toIso8601String();

    if (startupNote != null && startupNote.trim().isNotEmpty) {
      startDayReport['forecast'] = startupNote.trim();
    } else if (startDayReport['forecast'] == null ||
        startDayReport['forecast'].toString().trim().isEmpty) {
      startDayReport['forecast'] =
          "Day initiated at ${DateFormat('HH:mm').format(now)}. Systems online and tracking active.";
    }

    if (directives != null && directives.isNotEmpty) {
      startDayReport['directives'] = directives;
    }

    startDayReport['weekly_monthly_goals_snapshot'] ??=
        GoalBriefingHelper.buildWeeklyMonthlyGoalsSnapshot(this, now);

    dayData['startDayReport'] = startDayReport;
    newCompletedByDay[date] = dayData;
    setCompletedByDay(newCompletedByDay);

    if (currentUser != null) {
      _cloudStorage.saveDailyData(currentUser!.uid, date, 'report', startDayReport);
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> getNotificationsForDate(String dateStr) {
    if (completedByDay[dateStr] != null) {
      final notifsRaw = completedByDay[dateStr]['notifications'];
      if (notifsRaw is List) {
        return notifsRaw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (notifsRaw is Map && notifsRaw['items'] is List) {
        return (notifsRaw['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }
    return [];
  }

  void saveNotificationsForDate(String dateStr, List<Map<String, dynamic>> notifs) {
    final newCompletedByDay = Map<String, dynamic>.from(completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[dateStr] ?? {});
    dayData['notifications'] = notifs;
    newCompletedByDay[dateStr] = dayData;
    setCompletedByDay(newCompletedByDay);

    if (currentUser != null) {
      _cloudStorage.saveDailyData(currentUser!.uid, dateStr, 'notifications', {'items': notifs});
    }
    notifyListeners();
  }

  Map<String, dynamic>? getTacticalBriefing(String date) {
    if (completedByDay[date] != null && completedByDay[date]['aiBriefing'] != null) {
      return completedByDay[date]['aiBriefing'] as Map<String, dynamic>;
    }
    return null;
  }

  Map<String, dynamic>? getStartDayReport(String date) {
    if (completedByDay[date] != null && completedByDay[date]['startDayReport'] != null) {
      return completedByDay[date]['startDayReport'] as Map<String, dynamic>;
    }
    return null;
  }

  /// Collects all unique author/thinker/philosopher names featured in startup motivational quotes.
  List<String> getPreviouslyUsedQuoteAuthors() {
    final authors = <String>[];
    final seenNormalized = <String>{};

    void addAuthor(String? raw) {
      if (raw == null) return;
      var clean = raw.trim();
      clean = clean.replaceAll(RegExp(r'''^[\s\-_—–"“”']+|[\s\-_—–"“”']+$'''), '').trim();
      if (clean.isEmpty) return;
      final norm = clean.toLowerCase();
      if (!seenNormalized.contains(norm)) {
        seenNormalized.add(norm);
        authors.add(clean);
      }
    }

    for (final dayData in completedByDay.values) {
      if (dayData is Map) {
        final startDay = dayData['startDayReport'];
        if (startDay is Map && startDay['motivational_quote'] != null) {
          final q = startDay['motivational_quote'];
          if (q is Map) {
            addAuthor(q['author']?.toString());
          } else if (q is String) {
            if (q.contains(' — ')) {
              addAuthor(q.split(' — ').last);
            } else if (q.contains(' - ')) {
              addAuthor(q.split(' - ').last);
            }
          }
        }
      }
    }
    return authors;
  }

  /// Collects all previously used motivational quotes, authors, and reflection quotes
  /// across daily data, startup reports, briefings, and reviews to prevent repeats.
  List<String> getPreviouslyUsedQuotes() {
    final quotes = <String>{};
    for (final dayData in completedByDay.values) {
      if (dayData is Map) {
        final startDay = dayData['startDayReport'];
        if (startDay is Map) {
          if (startDay['motivational_quote'] != null) {
            final q = startDay['motivational_quote'];
            if (q is Map) {
              final text = q['quote']?.toString().trim() ?? '';
              final author = q['author']?.toString().trim() ?? '';
              if (author.isNotEmpty && text.isNotEmpty) {
                quotes.add('"$text" — $author');
              } else if (text.isNotEmpty) {
                quotes.add('"$text"');
              }
            } else if (q is String && q.trim().isNotEmpty) {
              quotes.add(q.trim());
            }
          }
          if (startDay['yesterday_quote'] != null) {
            final yq = startDay['yesterday_quote'].toString().trim();
            if (yq.isNotEmpty) quotes.add('"$yq"');
          }
        }
        final briefing = dayData['aiBriefing'] ?? dayData['briefing'] ?? dayData['tactical_briefing'] ?? dayData['tacticalBriefing'];
        if (briefing is Map && briefing['quote_reflections'] is List) {
          for (final qr in briefing['quote_reflections']) {
            if (qr is Map && qr['user_quote'] != null) {
              final uq = qr['user_quote'].toString().trim();
              if (uq.isNotEmpty) quotes.add('"$uq"');
            }
          }
        }
      }
    }
    // Also check cached weekly & monthly reports
    for (final item in cachedWeeklyReports) {
      final rep = item['report'] ?? item;
      if (rep is Map) {
        if (rep['health_intel'] is Map && rep['health_intel']['vitality_quote'] != null) {
          final vq = rep['health_intel']['vitality_quote'].toString().trim();
          if (vq.isNotEmpty) quotes.add(vq);
        }
      }
    }
    for (final item in cachedMonthlyReports) {
      final rep = item['report'] ?? item;
      if (rep is Map && rep['quote_reflections'] is List) {
        for (final qr in rep['quote_reflections']) {
          if (qr is Map && qr['user_quote'] != null) {
            final uq = qr['user_quote'].toString().trim();
            if (uq.isNotEmpty) quotes.add('"$uq"');
          }
        }
      }
    }
    return quotes.where((q) => q.isNotEmpty).toList();
  }

  /// Collects all previously used creative stories and historical figures across reports to prevent repeats.
  List<String> getPreviouslyUsedStories() {
    final stories = <String>{};
    final seen = <String>{};

    void addStory(dynamic s) {
      if (s == null) return;
      if (s is Map) {
        final title = s['title']?.toString().trim() ?? '';
        final takeaway = s['takeaway']?.toString().trim() ?? '';
        if (title.isNotEmpty) {
          final formatted = takeaway.isNotEmpty ? '$title (Lesson: $takeaway)' : title;
          final norm = title.toLowerCase();
          if (!seen.contains(norm)) {
            seen.add(norm);
            stories.add(formatted);
          }
        }
      } else if (s is String && s.trim().isNotEmpty) {
        final norm = s.trim().toLowerCase();
        if (!seen.contains(norm)) {
          seen.add(norm);
          stories.add(s.trim());
        }
      }
    }

    // Check cached weekly reports
    for (final doc in _cachedWeeklyReports) {
      final rep = doc['report'] ?? doc;
      if (rep is Map) addStory(rep['creative_story']);
    }

    // Check cached monthly reports
    for (final doc in _cachedMonthlyReports) {
      final rep = doc['report'] ?? doc;
      if (rep is Map) addStory(rep['creative_story']);
    }

    // Check completedByDay
    for (final dayData in completedByDay.values) {
      if (dayData is Map) {
        final weekly = dayData['weeklyReport'];
        if (weekly is Map) addStory(weekly['creative_story']);
        final monthly = dayData['monthlyReport'];
        if (monthly is Map) addStory(monthly['creative_story']);
      }
    }

    return stories.where((s) => s.isNotEmpty).toList();
  }

  /// Async version that ensures archived weekly and monthly reports are fetched from cloud before collecting.
  Future<List<String>> fetchPreviouslyUsedStories() async {
    try {
      if (currentUser != null && (_cachedWeeklyReports.isEmpty || _cachedMonthlyReports.isEmpty)) {
        await Future.wait([
          getArchivedWeeklyReports(),
          getArchivedMonthlyReports(),
        ]);
      }
    } catch (e) {
      debugPrint('[AppProvider.fetchPreviouslyUsedStories] Failed fetching archived reports: $e');
    }
    return getPreviouslyUsedStories();
  }

  Future<Map<String, dynamic>> generateTacticalBriefing(
    String date,
    List<ReflectionLog> logs, {
    Function(String status)? onStatusUpdate,
  }) async { 
    final logsFormatted = logs.map((l) => {'trigger': l.trigger, 'emotion': l.emotion, 'reason': l.reason, 'action': l.action}).toList();
    final recentBriefings = <String>[];
    for (int i=1; i<=3; i++) {
       final d = DateTime.parse(date).subtract(Duration(days: i));
       final dStr = DateFormat('yyyy-MM-dd').format(d);
       final b = getTacticalBriefing(dStr);
       if (b != null && b['summary'] != null) recentBriefings.add(b['summary']);
    }
    
    final targetDate = DateTime.tryParse(date) ?? DateTime.now();
    final targetEndOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999);
    final pastLogs = reflectionLogs.where((l) => l.timestamp.isBefore(targetEndOfDay)).toList();
    final allLogsContext = pastLogs.reversed.take(50).map((l) => "[${DateFormat('MM-dd').format(l.timestamp)}] ${l.trigger} -> ${l.emotion}").join("\n");
    final pastQuotes = getPreviouslyUsedQuotes().take(15).toList();
    final pastQuotesStr = pastQuotes.isNotEmpty ? pastQuotes.join("\n") : null;
    
    // Finance context for target date
    double dayIncome = 0, dayExpense = 0;
    for (final t in transactions) {
      if (t.timestamp.year == targetDate.year &&
          t.timestamp.month == targetDate.month &&
          t.timestamp.day == targetDate.day) {
        if (t.isIncome) {
          dayIncome += t.amount;
        } else {
          dayExpense += t.amount;
        }
      }
    }
    final financeStr = 'Today Income: ₹${dayIncome.toStringAsFixed(0)}, Expense: ₹${dayExpense.toStringAsFixed(0)}, Net: ₹${(dayIncome - dayExpense).toStringAsFixed(0)}, Current Balance: ₹${financeActions.currentBalance.toStringAsFixed(0)}';

    final goalsStr = GoalBriefingHelper.buildTacticalBriefingGoalsAIContext(this, targetDate);

    final notifsText = BriefingContextHelper.buildNotificationsText(this, date);
    final dayContextText = BriefingContextHelper.buildDayContextText(this, targetDate);

    final result = await _aiService.generateDailySummary(
      reflections: logsFormatted, 
      previousBriefings: recentBriefings, 
      fullContext: allLogsContext,
      previousQuotesContext: pastQuotesStr,
      financeText: financeStr,
      goalsText: goalsStr,
      notificationsText: notifsText.isNotEmpty ? notifsText : null,
      dayContextText: dayContextText.isNotEmpty ? dayContextText : null,
      modelCandidates: settings.heavyModels, 
      liteModelCandidates: settings.liteModels,
      proTimeout: const Duration(seconds: 60),
      currentApiKeyIndex: apiKeyIndex, 
      customApiKeys: settings.customApiKeys,
      onNewApiKeyIndex: (idx) => setApiKeyIndex(idx), 
      onLog: (m) => debugPrint(m),
      onStatusUpdate: onStatusUpdate,
      customInstruction: settings.customBriefingPrompt,
      writingStyleMap: settings.adaptWritingStyle ? settings.writingStyleMap : null,
    );

    if (result['grateful_assets'] != null) {
      final extracted = result['grateful_assets'] as List<dynamic>;
      final currentAssets = List<GratitudeItem>.from(chatbotMemory.gratitudeList);
      bool changed = false;
      for (var e in extracted) {
        final map = e as Map<String, dynamic>;
        final name = map['name'] as String? ?? '';
        final type = map['type'] as String? ?? 'resource';
        final why = map['why'] as String? ?? '';
        final what = map['what'] as String? ?? '';
        if (name.isEmpty) continue;

        final existingIdx = currentAssets.indexWhere((a) => a.name.toLowerCase() == name.toLowerCase());
        if (existingIdx != -1) {
          if (why.isNotEmpty && !currentAssets[existingIdx].why.contains(why)) {
            currentAssets[existingIdx].why += (currentAssets[existingIdx].why.isEmpty ? "" : " ") + why;
            changed = true;
          }
          if (what.isNotEmpty && !currentAssets[existingIdx].what.contains(what)) {
             currentAssets[existingIdx].what += (currentAssets[existingIdx].what.isEmpty ? "" : " ") + what;
             changed = true;
          }
        } else {
          currentAssets.insert(0, GratitudeItem(id: const Uuid().v4(), type: type, name: name, why: why, what: what));
          changed = true;
        }
      }
      if (changed) updateGratitudeList(currentAssets);
    }

    if (result['grateful_people'] != null) {
      final extracted = result['grateful_people'] as List<dynamic>;
      for (var e in extracted) {
        if (e is Map) {
          final name = e['name'] as String? ?? '';
          final relation = e['relation'] as String? ?? 'Acquaintance';
          final reason = e['reason'] as String? ?? '';
          final express = e['express'] as String? ?? '';
          if (name.isNotEmpty) {
            logInteractionForPerson(
              name: name,
              relation: relation,
              interactionSummary: reason,
              nextActionPlan: express,
              date: targetDate,
            );
          }
        }
      }
    }

    if (result['tomorrow_startup_report'] != null && result['tomorrow_startup_report'] is Map) {
      final startupData = Map<String, dynamic>.from(result['tomorrow_startup_report'] as Map);
      final tomorrow = targetDate.add(const Duration(days: 1));
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);
      startupData['snapshot_time'] = DateTime.now().toIso8601String();
      saveStartDayReport(tomorrowStr, startupData);

      if (startupData['suggested_contacts'] is List) {
        for (final c in startupData['suggested_contacts'] as List) {
          if (c is Map) {
            final name = c['name']?.toString() ?? '';
            final relation = c['relation']?.toString() ?? 'Acquaintance';
            final reason = c['reason']?.toString() ?? '';
            final type = c['type']?.toString() ?? 'CONTACT';
            if (name.isNotEmpty) {
              logInteractionForPerson(
                name: name,
                relation: relation,
                interactionSummary: "Startup Recommendation [$type]: $reason",
                nextActionPlan: "[$type] $reason",
                date: tomorrow,
              );
            }
          }
        }
      }
    }

    // End of day: this is the one moment the whole app state is pushed to the cloud.
    unawaited(syncEndOfDay());

    return result;
  }

  void _cleanOverlappingSessions() {
    bool changed = false;
    final newMainTasks = mainTasks.map((task) {
      return task.copyWith(
        subTasks: task.subTasks.map((sub) {
          if (sub.sessions.length <= 1) return sub;
          final sorted = List<TaskSession>.from(sub.sessions)..sort((a, b) => a.startTime.compareTo(b.startTime));
          final List<TaskSession> cleaned =[sorted.first];
          for (int i = 1; i < sorted.length; i++) {
            final current = sorted[i];
            final previous = cleaned.last;
            if (current.startTime.isBefore(previous.endTime)) {
              changed = true;
              if (current.endTime.isAfter(previous.endTime)) {
                cleaned.removeLast();
                cleaned.add(TaskSession(id: previous.id, startTime: previous.startTime, endTime: current.endTime));
              }
            } else {
              cleaned.add(current);
            }
          }
          if (cleaned.length != sub.sessions.length) {
            final totalSeconds = cleaned.fold(0, (sum, s) => sum + s.durationSeconds);
            return sub.copyWith(currentTimeSpent: totalSeconds, sessions: cleaned);
          }
          return sub;
        }).toList()
      );
    }).toList();

    if (changed) setMainTasks(newMainTasks);
  }

  void _fixTimerAnomalies() {
    // Handled in mixins
  }

  Future<void> _handleDailyReset() async {
    final todayStr = helper.getTodayDateString();
    if (lastLoginDate != todayStr) {
      debugPrint("[AppProvider] Daily reset triggered: $lastLoginDate -> $todayStr");
      bool changed = false;
      final newMainTasks = mainTasks.map((task) {
        final updatedSubtasks = task.subTasks.map((st) {
          if (st.isRecurring) {
            bool shouldReset = true;
            if (st.completed && st.lastCompletedDate != null) {
              if (DateFormat('yyyy-MM-dd').format(st.lastCompletedDate!) == todayStr) {
                shouldReset = false;
              }
            }
            if (shouldReset) {
              changed = true;
              // Stable reset: only flip completion + counters. Preserve every
              // other field (subSubTasks, substeps, sessions, why/what/etc.)
              // via copyWith. Recurring resets must NEVER drop checkpoints.
              // Progress-vs-time data points are scoped to the current cycle,
              // so they get cleared along with the reset.
              return st.copyWith(
                completed: false,
                currentCount: 0,
                subSubTasks: st.subSubTasks.map(_resetCheckpoint).toList(),
                templateSets: st.templateSets.map((ts) => ts.copyWith(
                  subSubTasks: ts.subSubTasks.map(_resetCheckpoint).toList(),
                )).toList(),
                progressDataPoints: [],
                updatedAt: DateTime.now(),
              );
            }
          }
          return st;
        }).toList();

        if (task.dailyTimeSpent > 0) {
          changed = true;
          return task.copyWith(subTasks: updatedSubtasks, dailyTimeSpent: 0);
        }
        return task.copyWith(subTasks: updatedSubtasks);
      }).toList();

      setLastLoginDate(todayStr);
      if (changed) setMainTasks(newMainTasks);

      // If an advance startDayReport exists for today (e.g. synthesized the night before),
      // ensure day_started is unflagged and recurring tasks in task_snapshot start fresh.
      if (completedByDay[todayStr] != null && completedByDay[todayStr]['startDayReport'] != null) {
        final sdr = Map<String, dynamic>.from(completedByDay[todayStr]['startDayReport'] as Map);
        sdr['day_started'] = false;
        if (sdr['task_snapshot'] is Map) {
          final ts = Map<String, dynamic>.from(sdr['task_snapshot'] as Map);
          for (final tKey in ts.keys) {
            if (ts[tKey] is Map) {
              final tVal = Map<String, dynamic>.from(ts[tKey] as Map);
              if (tVal['subtasks'] is Map) {
                final subMap = Map<String, dynamic>.from(tVal['subtasks'] as Map);
                for (final sKey in subMap.keys) {
                  if (subMap[sKey] is Map) {
                    final sData = Map<String, dynamic>.from(subMap[sKey] as Map);
                    final matchingSub = mainTasks.expand((t) => t.subTasks).where((s) => s.id == sKey).firstOrNull;
                    if (matchingSub?.isRecurring == true) {
                      sData['progress'] = 0.0;
                      sData['completed'] = false;
                      subMap[sKey] = sData;
                    }
                  }
                }
                tVal['subtasks'] = subMap;
              }
              ts[tKey] = tVal;
            }
          }
          sdr['task_snapshot'] = ts;
        }
        final newCompleted = Map<String, dynamic>.from(completedByDay);
        final dayMap = Map<String, dynamic>.from(newCompleted[todayStr] ?? {});
        dayMap['startDayReport'] = sdr;
        newCompleted[todayStr] = dayMap;
        setCompletedByDay(newCompleted);
      }

      notifyListeners();
      try {
        forceLocalBackup();
      } catch (e) {
        debugPrint("[AppProvider] Error backing up post daily reset: $e");
      }
    }
  }

  void _scheduleMidnightTimer() {
    _midnightRolloverTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    final delay = nextMidnight.difference(now);
    debugPrint("[AppProvider] Scheduled midnight rollover in ${delay.inMinutes}m (${delay.inSeconds}s) at $nextMidnight");

    _midnightRolloverTimer = Timer(delay, () async {
      debugPrint("[AppProvider] Midnight reached ($nextMidnight). Running automatic daily rollover.");
      try {
        await _handleDailyReset();
      } catch (e) {
        debugPrint("[AppProvider] Error during midnight rollover: $e");
      }
      _scheduleMidnightTimer();
    });
  }

  @visibleForTesting
  Future<void> handleDailyResetForTesting() => _handleDailyReset();

  /// Recursively flip a checkpoint (and any nested substeps) back to
  /// incomplete while preserving structure, names, and configuration.
  SubSubTask _resetCheckpoint(SubSubTask cp) {
    return SubSubTask(
      id: cp.id,
      name: cp.name,
      completed: false,
      isCountable: cp.isCountable,
      targetCount: cp.targetCount,
      currentCount: 0,
      completionTimestamp: null,
      type: cp.type,
      substeps: cp.substeps.map(_resetCheckpoint).toList(),
      why: cp.why,
      what: cp.what,
    );
  }

  List<bool> getCompletionStatusForCurrentWeek(MainTask task) {
    List<bool> weeklyStatus = List.filled(7, false);
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final startOffset = settings.startOfWeek;
    int diff = currentWeekday - startOffset;
    if (diff < 0) diff += 7;
    final startOfWeekDate = now.subtract(Duration(days: diff));

    for (int i = 0; i < 7; i++) {
      final targetDate = startOfWeekDate.add(Duration(days: i));
      if (targetDate.isAfter(now)) break;
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final dayData = completedByDay[dateStr];
      if (dayData != null && dayData['taskTimes'] != null) {
         final times = dayData['taskTimes'] as Map<String, dynamic>;
         if (times.containsKey(task.id) && (times[task.id] as int) > 0) weeklyStatus[i] = true;
      }
    }
    return weeklyStatus;
  }

  int getYesterdaysTimeForTask(String taskId) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = DateFormat('yyyy-MM-dd').format(yesterday);
    final dayData = completedByDay[dateStr];
    if (dayData != null && dayData['taskTimes'] != null) {
      return (dayData['taskTimes'] as Map<String, dynamic>)[taskId] as int? ?? 0;
    }
    return 0;
  }

  Future<void> syncWeeklyWellbeing() async {
    setLoadingTask("Analyzing Weekly Wellbeing...");
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentLogs = reflectionLogs.where((l) => l.timestamp.isAfter(sevenDaysAgo)).toList();
      if (recentLogs.isEmpty) {
        throw Exception("No reflection logs in the past 7 days to analyze.");
      }
      
      final logsPayload = recentLogs.map((l) => {
        "log_id": l.id,
        "trigger": l.trigger,
        "emotion": l.emotion,
        "action": l.action,
      }).toList();
      
      final updates = await aiService.evaluateBatchReflections(
        logsPayload: logsPayload,
        modelCandidates: settings.heavyModels, 
        currentApiKeyIndex: apiKeyIndex,
        customApiKeys: settings.customApiKeys,
        onNewApiKeyIndex: (i) => setApiKeyIndex(i),
        onLog: (msg) => debugPrint(msg),
      );
      
      final newLogs = List<ReflectionLog>.from(reflectionLogs);
      bool logsChanged = false;
      for (var update in updates) {
        final logId = update['log_id'];
        final rawScores = <String, double>{};
        (update['need_allocation'] as Map? ?? update['xp_allocation'] as Map? ?? {}).forEach(
            (k, v) => rawScores[k.toString()] = (v as num).toDouble());
        final needsMap = _scoresToNeeds(rawScores);
        final idx = newLogs.indexWhere((l) => l.id == logId);
        if (idx != -1) {
          newLogs[idx] = ReflectionLog(
            id: newLogs[idx].id,
            timestamp: newLogs[idx].timestamp,
            trigger: newLogs[idx].trigger,
            emotion: newLogs[idx].emotion,
            reason: newLogs[idx].reason,
            action: newLogs[idx].action,
            aiFeedback: newLogs[idx].aiFeedback,
            needs: needsMap,
          );
          logsChanged = true;
        }
      }
      
      if (logsChanged) {
        setReflectionLogs(newLogs);
      }
      
    } finally {
      setLoadingTask(null);
    }
  }

  /// Turns the AI's 0.0-1.0 relevance per well-being area into whole 0-100 weights for one
  /// reflection. These only ever feed a single day's pie chart; nothing accumulates.
  Map<String, int> _scoresToNeeds(Map<String, double> scores) {
    final result = <String, int>{};
    for (final entry in scores.entries) {
      final normalized = WellbeingTheme.normalizeSkillName(entry.key);
      if (normalized == null) continue;
      final weight = (entry.value.clamp(0.0, 1.0) * 100).round();
      if (weight > 0) result[normalized] = (result[normalized] ?? 0) + weight;
    }
    return result;
  }

  /// Synchronously persists a stub reflection log, then runs AI analysis in
  /// the background. When the analysis completes, [insightReady] is fired and
  /// a system notification is posted via [NotificationService].
  ///
  /// Returns the new log's id so callers can correlate completion if needed.
  String startReflectionAnalysis({
    required String trigger,
    required String emotion,
    required String reason,
    required String action,
    DateTime? timestamp,
  }) {
    final logId = const Uuid().v4();
    final log = ReflectionLog(
      id: logId,
      timestamp: timestamp ?? DateTime.now(),
      trigger: trigger,
      emotion: emotion,
      reason: reason,
      action: action,
      aiFeedback: 'Pending AI analysis...',
      needs: {},
    );
    setReflectionLogs([...reflectionLogs, log]);
    unawaited(AppActionLedgerService.instance.recordAction(
      actionType: 'CREATE',
      collection: 'reflection',
      entityId: logId,
      title: trigger,
      summary: 'Logged reflection: $trigger -> $emotion',
      before: null,
      after: log.toJson(),
    ));
    _processingReflections.add(logId);
    notifyListeners();

    // Fire-and-forget; the future is intentionally not awaited.
    // ignore: discarded_futures
    _runReflectionAnalysis(logId, trigger, emotion, reason, action);

    if (settings.adaptWritingStyle) {
      updateWritingStyleMap();
    }
    return logId;
  }

  Future<void> _runReflectionAnalysis(
    String logId,
    String trigger,
    String emotion,
    String reason,
    String action,
  ) async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentContext = reflectionLogs
          .where((l) => l.timestamp.isAfter(sevenDaysAgo) && l.id != logId)
          .map((l) => "[${DateFormat('MM-dd').format(l.timestamp)}] ${l.trigger} -> ${l.emotion}")
          .join("\n");

      final eval = await _aiService.evaluateReflection(
        trigger: trigger, emotion: emotion, reason: reason, action: action,
        modelCandidates: settings.liteModels,
        customApiKeys: settings.customApiKeys,
        recentContext: recentContext,
        systemInstruction: settings.customReflectionPrompt,
        writingStyleMap: settings.adaptWritingStyle ? settings.writingStyleMap : null,
      );
      final rawScores = <String, double>{};
      (eval['need_allocation'] as Map? ?? eval['xp_allocation'] as Map? ?? {}).forEach(
          (k, v) => rawScores[k.toString()] = (v as num).toDouble());
      final needs = _scoresToNeeds(rawScores);
      final feedback = (eval['feedback'] as String?) ?? '';
      updateReflectionLog(logId, aiFeedback: feedback, needs: needs);

      insightReady.value = InsightReadyEvent(
        logId: logId,
        feedback: feedback,
        needs: needs,
        timestamp: DateTime.now(),
      );

      final preview = feedback.length > 120 ? '${feedback.substring(0, 117)}…' : feedback;
      // ignore: discarded_futures
      NotificationService.instance.showInsightReady(
        title: 'TACTICAL INSIGHT ACQUIRED',
        body: preview.isEmpty ? 'Reflection analysis complete.' : preview,
        payload: logId,
      );
    } catch (e) {
      updateReflectionLog(logId, aiFeedback: 'AI Analysis failed or offline.', needs: {});
    } finally {
      _processingReflections.remove(logId);
      notifyListeners();
    }
  }

  /// Legacy synchronous path retained for any caller that still needs to
  /// await the AI result inline (returns log + needs once analysis completes).
  Future<Map<String, dynamic>> processReflection({
    required String trigger,
    required String emotion,
    required String reason,
    required String action,
    DateTime? timestamp,
  }) async {
    final logId = startReflectionAnalysis(
      trigger: trigger, emotion: emotion, reason: reason, action: action, timestamp: timestamp,
    );
    final completer = Completer<Map<String, dynamic>>();
    void listener() {
      if (_processingReflections.contains(logId)) return;
      removeListener(listener);
      final log = reflectionLogs.firstWhereOrNull((l) => l.id == logId);
      if (log == null) {
        if (!completer.isCompleted) completer.completeError(StateError('Log $logId vanished'));
        return;
      }
      if (!completer.isCompleted) {
        completer.complete({'log': log, 'needs': log.needs});
      }
    }
    addListener(listener);
    return completer.future;
  }

  void updateReflectionLog(String id, {String? trigger, String? emotion, String? reason, String? action, String? aiFeedback, Map<String, int>? needs}) {
    final index = reflectionLogs.indexWhere((l) => l.id == id);
    if (index != -1) {
      final old = reflectionLogs[index];
      final updated = ReflectionLog(
        id: old.id,
        timestamp: old.timestamp,
        trigger: trigger ?? old.trigger,
        emotion: emotion ?? old.emotion,
        reason: reason ?? old.reason,
        action: action ?? old.action,
        aiFeedback: aiFeedback ?? old.aiFeedback,
        needs: needs ?? old.needs,
      );
      final newLogs = List<ReflectionLog>.from(reflectionLogs);
      newLogs[index] = updated;
      setReflectionLogs(newLogs);
    }
  }

  void deleteReflectionLog(String id) {
    final index = reflectionLogs.indexWhere((l) => l.id == id);
    if (index != -1) {
      final old = reflectionLogs[index];
      final newLogs = List<ReflectionLog>.from(reflectionLogs)..removeAt(index);
      setReflectionLogs(newLogs);
      unawaited(AppActionLedgerService.instance.recordAction(
        actionType: 'DELETE',
        collection: 'reflection',
        entityId: id,
        title: old.trigger,
        summary: 'Deleted reflection "${old.trigger}"',
        before: old.toJson(),
        after: null,
      ));
      if (currentUser != null) {
        unawaited(_cloudStorage.deleteReflection(currentUser!.uid, id));
      }
    }
  }

  NoraSession? get activeNoraSession {
    if (chatbotMemory.noraSessions.isEmpty) return null;
    if (chatbotMemory.activeNoraSessionId != null) {
      final found = chatbotMemory.noraSessions.firstWhereOrNull((s) => s.id == chatbotMemory.activeNoraSessionId);
      if (found != null) return found;
    }
    return chatbotMemory.noraSessions.last;
  }

  List<NoraPersona> get noraPersonas => chatbotMemory.allPersonas;

  NoraPersona getActiveNoraPersona([NoraSession? session]) {
    final s = session ?? activeNoraSession;
    if (s?.personaId != null) {
      return chatbotMemory.getPersona(s!.personaId);
    }
    return chatbotMemory.getPersona(s?.tone);
  }

  void saveCustomPersona(NoraPersona persona) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.saveCustomPersona(persona);
    setChatbotMemory(newMemory);
    markDirty('settings');
    notifyListeners();
  }

  void deleteCustomPersona(String id) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.deleteCustomPersona(id);
    setChatbotMemory(newMemory);
    markDirty('settings');
    notifyListeners();
  }

  void addPersonaMemoryItem(String personaId, NoraMemoryItem item) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.addPersonaMemoryItem(personaId, item);
    setChatbotMemory(newMemory);
    markDirty('settings');
    notifyListeners();
  }

  void deletePersonaMemoryItem(String personaId, String memoryIdOrKey) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.deletePersonaMemoryItem(personaId, memoryIdOrKey);
    setChatbotMemory(newMemory);
    markDirty('settings');
    notifyListeners();
  }

  List<NoraMemoryItem> getPersonaMemories(String personaId) {
    return chatbotMemory.getPersonaMemories(personaId);
  }

  Future<NoraPersona> generateCharacterFromInput({
    required String inputSource,
    required String sourceType,
  }) async {
    final result = await _aiService.generateCharacterSheet(
      inputSource: inputSource,
      sourceType: sourceType,
      modelCandidates: settings.heavyModels,
      currentApiKeyIndex: apiKeyIndex,
      customApiKeys: settings.customApiKeys,
      onNewApiKeyIndex: (i) => setApiKeyIndex(i),
      onLog: (m) => debugPrint("[CharacterGen] $m"),
    );

    final name = result['name']?.toString() ?? 'Custom Character';
    final tagline = result['tagline']?.toString() ?? '';
    final avatarIcon = result['avatarIcon']?.toString() ?? 'creation';
    final systemPrompt = result['systemPrompt']?.toString() ?? 'You are a custom AI character.';
    final greetingMessage = result['greetingMessage']?.toString() ?? 'Hello.';
    final initialMemories = <NoraMemoryItem>[];

    if (result['initialMemories'] is List) {
      for (final im in result['initialMemories']) {
        if (im is Map) {
          initialMemories.add(NoraMemoryItem(
            id: const Uuid().v4(),
            key: im['key']?.toString() ?? 'initial',
            content: im['content']?.toString() ?? '',
            tags: (im['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
          ));
        }
      }
    }

    final persona = NoraPersona(
      id: "persona_${const Uuid().v4().substring(0, 8)}",
      name: name,
      tagline: tagline,
      avatarIcon: avatarIcon,
      systemPrompt: systemPrompt,
      greetingMessage: greetingMessage,
      isBuiltIn: false,
      sourceType: sourceType,
      memorySpace: initialMemories,
    );

    saveCustomPersona(persona);
    return persona;
  }

  void createNoraSession({
    required String title, 
    required String tone, 
    required DateTime startDate, 
    required DateTime endDate, 
    String? customContext,
    String? personaId,
    int? messageLimit,
    String? modelOverride,
    int? contextDays,
    String? systemPromptOverride,
  }) {
    final persona = chatbotMemory.getPersona(personaId ?? tone);
    final initialGreeting = persona.greetingMessage;

    final newSession = NoraSession(
      id: const Uuid().v4(), 
      title: title, 
      tone: tone, 
      startDate: startDate, 
      endDate: endDate, 
      customContext: customContext,
      personaId: persona.id,
      messageLimit: messageLimit ?? 0,
      modelOverride: modelOverride,
      contextDays: contextDays ?? 7,
      systemPromptOverride: systemPromptOverride,
      messages: [
        ChatbotMessage(
          id: const Uuid().v4(),
          text: initialGreeting,
          sender: MessageSender.bot,
          timestamp: DateTime.now(),
        ),
      ],
    );
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.noraSessions.add(newSession);
    newMemory.activeNoraSessionId = newSession.id;
    setChatbotMemory(newMemory);
    markDirty('settings');
    notifyListeners();
  }
  
  void updateNoraSessionConfig({
    required String sessionId,
    int? messageLimit,
    String? modelOverride,
    int? contextDays,
    String? systemPromptOverride,
  }) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    final index = newMemory.noraSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      if (messageLimit != null) newMemory.noraSessions[index].messageLimit = messageLimit;
      newMemory.noraSessions[index].modelOverride = modelOverride; // allow nulling
      if (contextDays != null) newMemory.noraSessions[index].contextDays = contextDays;
      newMemory.noraSessions[index].systemPromptOverride = systemPromptOverride; // allow nulling
      setChatbotMemory(newMemory);
      markDirty('settings');
      notifyListeners();
    }
  }

  void switchNoraSession(String sessionId) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.activeNoraSessionId = sessionId;
    setChatbotMemory(newMemory);
    markDirty('settings');
    notifyListeners();
  }

  void deleteNoraSession(String sessionId) {
    final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson());
    newMemory.noraSessions.removeWhere((s) => s.id == sessionId);
    if (newMemory.activeNoraSessionId == sessionId) {
      newMemory.activeNoraSessionId = newMemory.noraSessions.isNotEmpty ? newMemory.noraSessions.last.id : null;
    }
    setChatbotMemory(newMemory);
    markDirty('settings');
    notifyListeners();
  }

  Future<void> sendNoraMessage(String text, {bool isLiveVoice = false}) async {
    var session = activeNoraSession;
    if (session == null) {
      final p = chatbotMemory.getPersona(null);
      createNoraSession(
        title: "Session ${DateFormat('MM-dd').format(DateTime.now())}",
        tone: p.name,
        personaId: p.id,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      );
      session = activeNoraSession;
      if (session == null) return;
    }

    final userMsg = ChatbotMessage(
      id: const Uuid().v4(),
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );
    session.messages.add(userMsg);
    markDirty('settings');
    notifyListeners();

    final modelCandidates = session.modelOverride != null
        ? [session.modelOverride!]
        : [...settings.liveModels, ...settings.liteModels];

    try {
      final engine = NoraAgentEngine(provider: this, aiService: _aiService);
      final responseMap = await engine.executeAgentLoop(
        session: session,
        userQuery: text,
        modelCandidates: modelCandidates,
        currentApiKeyIndex: apiKeyIndex,
        customApiKeys: settings.customApiKeys,
        onNewApiKeyIndex: (i) => setApiKeyIndex(i),
        onLog: (m) => debugPrint(m),
      );

      final List<dynamic> messages = responseMap['messages'] as List<dynamic>? ?? [];
      final List<dynamic> actions = responseMap['actions'] as List<dynamic>? ?? [];

      if (actions.isNotEmpty) {
        await executeNoraAgentActions(actions);
      }

      for (var resp in messages) {
        final respStr = resp.toString();
        // Dynamic typing delay only when not in live voice mode
        if (!isLiveVoice) {
          await Future.delayed(Duration(milliseconds: 100 + (respStr.length * 4).clamp(0, 400)));
        }
        final botMsg = ChatbotMessage(
          id: const Uuid().v4(),
          text: respStr,
          sender: MessageSender.bot,
          timestamp: DateTime.now(),
        );
        session.messages.add(botMsg);
        markDirty('settings');
        notifyListeners();
      }
    } catch (e) {
      final errorMsg = ChatbotMessage(
        id: const Uuid().v4(),
        text: "Error: $e",
        sender: MessageSender.bot,
        timestamp: DateTime.now(),
      );
      session.messages.add(errorMsg);
      markDirty('settings');
      notifyListeners();
    }
  }

  String getLast30DaysReflectionLogsContext() {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final logs = reflectionLogs.where((l) => l.timestamp.isAfter(thirtyDaysAgo)).toList();
    if (logs.isEmpty) return "No reflection logs recorded in the last 30 days.";
    return logs.map((l) =>
      "- [Date: ${DateFormat('yyyy-MM-dd').format(l.timestamp)}] trigger: '${l.trigger}', emotion: '${l.emotion}', reason: '${l.reason}', action: '${l.action}'"
    ).join("\n");
  }

  String getTodayUncompletedPlanContext() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final plan = taskActions.getDayPlan(todayStr);
    if (plan.isEmpty) return "No plan items scheduled for today.";

    final List<String> uncompletedItems = [];
    for (String idPair in plan) {
      final parts = idPair.split('|');
      if (parts.length >= 2) {
        final mTask = mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
        final sTask = mTask?.subTasks.firstWhereOrNull((s) => s.id == parts[1] && !s.isDeleted);
        if (mTask != null && sTask != null && !sTask.completed) {
          if (parts.length == 3) {
            final cp = sTask.findCheckpoint(parts[2]);
            if (cp != null && !cp.completed) {
              uncompletedItems.add("- Checkpoint: ${mTask.name} > ${sTask.name} > ${cp.name}");
            }
          } else {
            uncompletedItems.add("- Subtask: ${mTask.name} > ${sTask.name}");
          }
        }
      }
    }

    if (uncompletedItems.isEmpty) return "All scheduled plan items for today are completed!";
    return uncompletedItems.join("\n");
  }

  void addAiLog({
    required String action,
    required String model,
    required String promptSnippet,
    required String status,
  }) {
    debugPrint("[AI LOG][$status] Action: $action | Model: $model | Snippet: $promptSnippet");
  }

  Future<void> executeNoraAgentActions(List<dynamic> actions) async {
    if (actions.isEmpty) return;

    // 1. Take a database snapshot first
    await saveNoraBackupSnapshot();

    // 2. Loop and execute actions with context linking
    String? lastCreatedCompoundId;
    String? lastCreatedTaskName;

    for (var act in actions) {
      if (act is! Map<String, dynamic>) continue;
      final type = (act['type'] as String?)?.toLowerCase();
      if (type == null) continue;

      try {
        switch (type) {
          case 'check_task':
          case 'checktask':
            String? taskId = act['taskId'] as String? ?? act['mainTaskId'] as String?;
            String? subtaskId = act['subtaskId'] as String?;
            String? subSubtaskId = act['subSubtaskId'] as String? ?? act['checkpointId'] as String?;
            final completed = act['completed'] as bool? ?? true;
            final compoundId = act['compoundId'] as String? ?? act['compound_id'] as String?;
            final name = (act['name'] as String? ?? act['taskName'] as String? ?? act['task_name'] as String?)?.trim();

            if (compoundId != null && compoundId.contains('|')) {
              final parts = compoundId.split('|');
              taskId = parts[0];
              if (parts.length > 1) subtaskId = parts[1];
              if (parts.length > 2) subSubtaskId = parts[2];
            } else if ((taskId == null || subtaskId == null) && name != null && name.isNotEmpty) {
              final lowerName = name.toLowerCase();
              for (final m in mainTasks.where((t) => !t.isDeleted)) {
                for (final s in m.subTasks.where((st) => !st.isDeleted)) {
                  if (s.name.toLowerCase() == lowerName) {
                    taskId = m.id;
                    subtaskId = s.id;
                    break;
                  }
                  for (final cp in s.subSubTasks.where((c) => c.isActive)) {
                    if (cp.name.toLowerCase() == lowerName) {
                      taskId = m.id;
                      subtaskId = s.id;
                      subSubtaskId = cp.id;
                      break;
                    }
                  }
                  if (taskId != null) break;
                }
                if (taskId != null) break;
              }
            }

            if (taskId != null && subtaskId != null) {
              if (subSubtaskId != null) {
                if (completed) {
                  completeSubSubtask(taskId, subtaskId, subSubtaskId);
                } else {
                  uncompleteSubSubtask(taskId, subtaskId, subSubtaskId);
                }
              } else {
                if (completed) {
                  completeSubtask(taskId, subtaskId, fromSync: true);
                } else {
                  uncompleteSubtask(taskId, subtaskId, fromSync: true);
                }
              }
              markDirty('tasks');
              notifyListeners();
            }
            break;

          case 'add_task':
          case 'addtask':
            final taskType = (act['taskType'] as String? ?? act['task_type'] as String?)?.toLowerCase();
            final name = (act['name'] as String? ?? act['task_name'] as String? ?? act['title'] as String?)?.trim();
            final description = (act['description'] as String?) ?? '';
            String? mainTaskId = act['mainTaskId'] as String? ?? act['main_task_id'] as String?;
            final mainTaskName = (act['mainTaskName'] as String? ?? act['main_task_name'] as String?)?.trim();
            final subtaskId = act['subtaskId'] as String? ?? act['subtask_id'] as String?;
            final why = (act['why'] as String?) ?? '';
            final what = (act['what'] as String?) ?? '';
            final theme = (act['theme'] as String?) ?? 'General';
            final colorHex = (act['colorHex'] as String? ?? act['color_hex'] as String?) ?? 'FF00F8F8';

            if (name != null && name.isNotEmpty) {
              if (taskType == 'main') {
                addMainTask(name: name, description: description, theme: theme, colorHex: colorHex);
                final created = mainTasks.firstWhereOrNull((t) => t.name == name);
                if (created != null) {
                  lastCreatedCompoundId = created.id;
                  lastCreatedTaskName = name;
                }
              } else {
                // For subtask or default
                if (mainTaskId == null && mainTaskName != null && mainTaskName.isNotEmpty) {
                  final matchedMain = mainTasks.firstWhereOrNull(
                    (t) => !t.isDeleted && t.name.toLowerCase() == mainTaskName.toLowerCase(),
                  );
                  mainTaskId = matchedMain?.id;
                }
                if (mainTaskId == null) {
                  final activeMains = mainTasks.where((t) => !t.isDeleted).toList();
                  if (activeMains.isNotEmpty) {
                    mainTaskId = activeMains.first.id;
                  } else {
                    addMainTask(name: 'General', description: 'Default category', theme: 'General', colorHex: colorHex);
                    mainTaskId = mainTasks.firstWhereOrNull((t) => !t.isDeleted)?.id;
                  }
                }

                if (mainTaskId != null) {
                  if (taskType == 'subsub' && subtaskId != null) {
                    final assignedCpId = addSubSubtask(mainTaskId, subtaskId, {
                      'name': name,
                      'completed': false,
                    });
                    lastCreatedCompoundId = "$mainTaskId|$subtaskId|$assignedCpId";
                    lastCreatedTaskName = name;
                  } else {
                    final assignedSubId = addSubtask(mainTaskId, {
                      'name': name,
                      'description': description,
                      'why': why,
                      'what': what,
                      'completed': false,
                    });
                    lastCreatedCompoundId = "$mainTaskId|$assignedSubId";
                    lastCreatedTaskName = name;
                  }
                  markDirty('tasks');
                  notifyListeners();
                }
              }
            }
            break;

          case 'add_to_plan':
          case 'addtoplan':
          case 'plan_add':
            String? compoundId = act['compoundId'] as String? ?? act['compound_id'] as String?;
            final name = (act['name'] as String? ?? act['taskName'] as String? ?? act['task_name'] as String?)?.trim();
            final dateStr = (act['date'] as String? ?? act['dateStr'] as String? ?? act['targetDate'] as String?)?.trim() ??
                DateFormat('yyyy-MM-dd').format(DateTime.now());
            final estVal = act['estimateMinutes'] ?? act['estimate_minutes'] ?? act['estimate'] ?? act['minutes'];
            int? estimateMinutes;
            if (estVal is num) {
              estimateMinutes = estVal.toInt();
            } else if (estVal is String) {
              estimateMinutes = int.tryParse(estVal);
            }

            if (compoundId == null && name != null && name.isNotEmpty) {
              if (lastCreatedTaskName != null &&
                  lastCreatedTaskName.toLowerCase() == name.toLowerCase() &&
                  lastCreatedCompoundId != null) {
                compoundId = lastCreatedCompoundId;
              } else {
                final lowerName = name.toLowerCase();
                for (final m in mainTasks.where((t) => !t.isDeleted)) {
                  for (final s in m.subTasks.where((st) => !st.isDeleted)) {
                    if (s.name.toLowerCase() == lowerName) {
                      compoundId = "${m.id}|${s.id}";
                      break;
                    }
                    for (final cp in s.subSubTasks.where((c) => c.isActive)) {
                      if (cp.name.toLowerCase() == lowerName) {
                        compoundId = "${m.id}|${s.id}|${cp.id}";
                        break;
                      }
                    }
                    if (compoundId != null) break;
                  }
                  if (compoundId != null) break;
                }
              }
            }

            // Fallback: If no compoundId but last created exists, use it
            compoundId ??= lastCreatedCompoundId;

            // If still null and name was provided, create the subtask on the fly then add to plan!
            if (compoundId == null && name != null && name.isNotEmpty) {
              var main = mainTasks.firstWhereOrNull((t) => !t.isDeleted);
              if (main == null) {
                addMainTask(name: 'General', description: 'Default category', theme: 'General', colorHex: 'FF00F8F8');
                main = mainTasks.firstWhereOrNull((t) => !t.isDeleted);
              }
              if (main != null) {
                final assignedSubId = addSubtask(main.id, {
                  'name': name,
                  'description': '',
                  'why': '',
                  'what': '',
                  'completed': false,
                });
                compoundId = "${main.id}|$assignedSubId";
              }
            }

            if (compoundId != null) {
              taskActions.addToDayPlan(compoundId, dateStr, estimateMinutes);
              markDirty('tasks');
              notifyListeners();
            }
            break;

          case 'remove_from_plan':
          case 'removefromplan':
          case 'plan_remove':
            String? compoundId = act['compoundId'] as String? ?? act['compound_id'] as String?;
            final name = (act['name'] as String? ?? act['taskName'] as String? ?? act['task_name'] as String?)?.trim();
            final dateStr = (act['date'] as String? ?? act['dateStr'] as String?)?.trim() ??
                DateFormat('yyyy-MM-dd').format(DateTime.now());

            if (compoundId == null && name != null && name.isNotEmpty) {
              final lowerName = name.toLowerCase();
              for (final m in mainTasks.where((t) => !t.isDeleted)) {
                for (final s in m.subTasks.where((st) => !st.isDeleted)) {
                  if (s.name.toLowerCase() == lowerName) {
                    compoundId = "${m.id}|${s.id}";
                    break;
                  }
                  for (final cp in s.subSubTasks.where((c) => c.isActive)) {
                    if (cp.name.toLowerCase() == lowerName) {
                      compoundId = "${m.id}|${s.id}|${cp.id}";
                      break;
                    }
                  }
                  if (compoundId != null) break;
                }
                if (compoundId != null) break;
              }
            }

            if (compoundId != null) {
              taskActions.removeFromDayPlan(compoundId, dateStr);
              markDirty('tasks');
              notifyListeners();
            }
            break;

          case 'add_progress_point':
            final mainTaskId = act['mainTaskId'] as String?;
            final subTaskId = act['subTaskId'] as String?;
            final progressVal = act['progress'];
            final spentSecsVal = act['spentSeconds'];

            if (mainTaskId != null && subTaskId != null && progressVal != null) {
              double progress = 0.0;
              if (progressVal is num) {
                progress = progressVal.toDouble();
              }
              int spentSeconds = 0;
              if (spentSecsVal is num) {
                spentSeconds = spentSecsVal.toInt();
              }
              saveProgressDataPoint(mainTaskId, subTaskId, progress, spentSeconds);
            }
            break;

          case 'edit_person':
            final name = act['name'] as String?;
            final relation = act['relation'] as String?;
            final details = act['details'] as String?;
            final age = act['age'] as int?;
            final gender = act['gender'] as String?;
            final notes = act['notes'] as String?;

            if (name != null) {
              final list = List<PersonInfo>.from(chatbotMemory.people);
              final idx = list.indexWhere((p) => p.name.toLowerCase() == name.toLowerCase());
              if (idx != -1) {
                list[idx] = PersonInfo(
                  id: list[idx].id,
                  name: name,
                  relation: relation ?? list[idx].relation,
                  details: details ?? list[idx].details,
                  manualAge: age ?? list[idx].manualAge,
                  manualGender: gender ?? list[idx].manualGender,
                  manualNotes: notes ?? list[idx].manualNotes,
                  lastUpdated: DateTime.now(),
                );
              } else {
                list.add(PersonInfo(
                  id: const Uuid().v4(),
                  name: name,
                  relation: relation ?? "Acquaintance",
                  details: details,
                  manualAge: age,
                  manualGender: gender,
                  manualNotes: notes,
                  lastUpdated: DateTime.now(),
                ));
              }
              final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson())..people = list;
              setChatbotMemory(newMemory);
            }
            break;

          case 'edit_reflection':
            final id = act['id'] as String?;
            final trigger = act['trigger'] as String?;
            final emotion = act['emotion'] as String?;
            final reason = act['reason'] as String?;
            final actionVal = act['action'] as String?;

            if (id != null) {
              final list = List<ReflectionLog>.from(reflectionLogs);
              final idx = list.indexWhere((r) => r.id == id);
              if (idx != -1) {
                if (trigger != null) list[idx].trigger = trigger;
                if (emotion != null) list[idx].emotion = emotion;
                if (reason != null) list[idx].reason = reason;
                if (actionVal != null) list[idx].action = actionVal;
                setReflectionLogs(list);
              }
            }
            break;

          case 'add_nora_skill':
            final name = act['name'] as String?;
            final description = act['description'] as String?;
            final instructions = act['instructions'] as String?;

            if (name != null && description != null && instructions != null) {
              final list = List<NoraAgentSkill>.from(chatbotMemory.noraAgentSkills);
              list.removeWhere((s) => s.name.toLowerCase() == name.toLowerCase());
              list.add(NoraAgentSkill(
                id: const Uuid().v4(),
                name: name,
                description: description,
                instructions: instructions,
              ));
              final newMemory = ChatbotMemory.fromJson(chatbotMemory.toJson())..noraAgentSkills = list;
              setChatbotMemory(newMemory);
            }
            break;

          case 'custom_db_edit':
            final path = act['path'] as String?;
            final value = act['value'];

            if (path != null) {
              final stateMap = getAppStateAsMap();
              _updateJsonPathHelper(stateMap, path, value);
              loadStateFromMap(stateMap);
              markDirty('tasks');
              markDirty('settings');
              markDirty('reflections');
              markDirty('finance');
              markDirty('health');
              notifyListeners();
            }
            break;
        }
      } catch (e) {
        debugPrint("Error executing Nora action $type: $e");
      }
    }
  }

  void _updateJsonPathHelper(Map<String, dynamic> map, String path, dynamic value) {
    final parts = path.split('.');
    dynamic current = map;
    for (int i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      final intIndex = int.tryParse(part);
      if (intIndex != null && current is List) {
        if (intIndex >= 0 && intIndex < current.length) {
          current = current[intIndex];
        } else {
          return;
        }
      } else if (current is Map) {
        if (current.containsKey(part)) {
          current = current[part];
        } else {
          current[part] = <String, dynamic>{};
          current = current[part];
        }
      } else {
        return;
      }
    }

    final lastPart = parts.last;
    final intIndex = int.tryParse(lastPart);
    if (intIndex != null && current is List) {
      if (intIndex >= 0 && intIndex < current.length) {
        current[intIndex] = value;
      }
    } else if (current is Map) {
      current[lastPart] = value;
    }
  }
  
  Future<void> sendMessageToChatbot(String text) async => await sendNoraMessage(text);
  
  void addCustomApiKey(String key) {
    final newKeys = List<String>.from(settings.customApiKeys)..add(key);
    setSettings(settings..customApiKeys = newKeys);
  }
  
  void removeCustomApiKey(String key) {
    final newKeys = List<String>.from(settings.customApiKeys)..remove(key);
    setSettings(settings..customApiKeys = newKeys);
  }
  
  void setJournalPin(String pin) {
    setSettings(settings..journalPin = pin);
  }

  Future<void> updateWritingStyleMap() async {
    if (!settings.adaptWritingStyle) {
      return;
    }
    
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentLogs = reflectionLogs
        .where((l) => l.timestamp.isAfter(sevenDaysAgo))
        .toList();
    
    if (recentLogs.isEmpty) {
      setSettings(settings..writingStyleMap = null);
      notifyListeners();
      return;
    }
    
    final logsText = recentLogs
        .map((l) => "Situation/Trigger: ${l.trigger}\nFeeling/Emotion: ${l.emotion}\nReason: ${l.reason}\nAction Planned: ${l.action}")
        .join("\n\n");
        
    final prompt = """
    You are an expert linguist and writing style analyzer. 
    Analyze the following journal/reflection entries written by the user over the last 7 days:
    
    $logsText
    
    Extract and create a detailed profile/map of their writing style. 
    Focus on:
    - Tone (e.g., formal, casual, reflective, self-critical, optimistic, stoic, emotional, analytical)
    - Vocabulary and word choice (common words, slang, specific terminology used)
    - Sentence structure and length (e.g., short fragments, long compound sentences)
    - Format and styling (e.g., use of bullet points, emoji usage)
    
    CRITICAL CONSTRAINT: Do NOT copy or include any grammatical errors, spelling mistakes, typos, lack of capitalization, run-on sentences, lazy texting shortcuts, or chat abbreviations in the style map. Instead, formulate and describe the absolute BEST version of their writing style—one that is fully polished and grammatically perfect (using correct casing, punctuation, spelling, and standard sentence flow), while retaining their core voice, tone, vocabulary, personality, and perspective.

    Output a JSON object with a single key "style_map" containing a concise summary (1-3 paragraphs) describing this elevated, grammatically correct writing style so another LLM can replicate it perfectly.
    
    JSON Schema:
    {
      "style_map": "string description"
    }
    ENSURE VALID JSON. NO TRAILING COMMAS.
    """;
    
    try {
      final result = await _aiService.makeAICall(
        prompt: prompt,
        modelCandidates: settings.liteModels,
        customApiKeys: settings.customApiKeys,
        currentApiKeyIndex: apiKeyIndex,
        onNewApiKeyIndex: (idx) => setApiKeyIndex(idx),
        onLog: (m) => debugPrint("[StyleMap] $m"),
      );
      
      final styleDescription = result['style_map'] as String?;
      if (styleDescription != null && styleDescription.isNotEmpty) {
        setSettings(settings..writingStyleMap = styleDescription);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error generating writing style map: $e");
    }
  }

}

class InsightReadyEvent {
  final String logId;
  final String feedback;
  final Map<String, int> needs;
  final DateTime timestamp;

  const InsightReadyEvent({
    required this.logId,
    required this.feedback,
    required this.needs,
    required this.timestamp,
  });
}

class MergeReport {
  final int addedReflections;
  final int totalReflections;
  final int mergedDays;
  final int totalHistoryDays;
  final int addedTasks;
  final int addedProjects;
  final int addedGoals;
  final int addedTransactions;
  final bool launcherMerged;

  const MergeReport({
    this.addedReflections = 0,
    this.totalReflections = 0,
    this.mergedDays = 0,
    this.totalHistoryDays = 0,
    this.addedTasks = 0,
    this.addedProjects = 0,
    this.addedGoals = 0,
    this.addedTransactions = 0,
    this.launcherMerged = false,
  });

  String get summary {
    final lines = <String>[];
    if (addedReflections > 0) {
      lines.add('+$addedReflections past reflection log${addedReflections == 1 ? '' : 's'} restored (Total: $totalReflections)');
    } else {
      lines.add('All reflection logs retained intact ($totalReflections total)');
    }
    if (mergedDays > 0) {
      lines.add('+$mergedDays historical day${mergedDays == 1 ? '' : 's'} merged into timeline (Total: $totalHistoryDays days)');
    } else {
      lines.add('All recent timeline history preserved ($totalHistoryDays days total)');
    }
    if (addedTasks > 0) lines.add('+$addedTasks missing task${addedTasks == 1 ? '' : 's'} restored');
    if (addedProjects > 0) lines.add('+$addedProjects project${addedProjects == 1 ? '' : 's'} restored');
    if (addedGoals > 0) lines.add('+$addedGoals goal${addedGoals == 1 ? '' : 's'} restored');
    if (addedTransactions > 0) lines.add('+$addedTransactions transaction${addedTransactions == 1 ? '' : 's'} merged');
    if (launcherMerged) lines.add('Launcher layout, dock, and widgets merged non-destructively');
    lines.add('Recent entries from the last few days were strictly preserved.');
    return lines.join('\n• ');
  }
}