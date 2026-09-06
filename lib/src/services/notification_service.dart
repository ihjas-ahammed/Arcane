import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:universal_html/html.dart' as html;

/// Cross-platform notification facade.
/// Web → HTML5 Notification API.  Native → flutter_local_notifications.
/// Linux → flutter_local_notifications_linux (no persistent / no zonedSchedule).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _webPermissionRequested = false;
  void Function(String? payload)? _onTap;

  // --- Channel IDs ---
  static const String _insightChannelId = 'tactical_insights';
  static const String _insightChannelName = 'Tactical Insights';
  static const String _insightChannelDesc = 'Reflection analyses and AI insights';

  static const String _timerChannelId = 'active_timer';
  static const String _timerChannelName = 'Active Timer';
  static const String _timerChannelDesc = 'Shows the currently running task timer';

  static const String _reminderChannelId = 'reminders';
  static const String _reminderChannelName = 'Reminders';
  static const String _reminderChannelDesc = 'Submission and reflection reminders';

  static const String _transitChannelId = 'bus_transit';
  static const String _transitChannelName = 'Bus Transit';
  static const String _transitChannelDesc = 'Live updates and progress while in the bus';

  // --- Notification IDs ---
  static const int _timerNotifId = 2001;
  static const int _transitNotifId = 2002;
  static const int reflectionReminderId = 3001;
  static const int financeReminderId = 3002;
  static const int healthReminderId = 3003;
  static const int _submissionReminderBase = 4000;

  // Linux: periodic timer for updating the live-elapsed notification every 5 min
  Timer? _linuxTimerUpdater;
  String? _activeTimerSubtaskId;
  DateTime? _activeTimerStartTime;
  String? _activeTimerTaskName;
  String? _activeTimerNextCheckpoint;

  // In-app daily reminder timers (for Linux/macOS where zonedSchedule is unavailable)
  final Map<int, Timer> _inAppReminderTimers = {};

  bool get _isLinux => !kIsWeb && Platform.isLinux;
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _supportsZonedSchedule => _isAndroid || (!kIsWeb && Platform.isIOS);

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  Future<void> init({void Function(String? payload)? onTap}) async {
    if (_initialized) return;
    _onTap = onTap;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    if (!kIsWeb) {
      tz_data.initializeTimeZones();
    }

    AndroidInitializationSettings? androidInit;
    DarwinInitializationSettings? darwinInit;
    LinuxInitializationSettings? linuxInit;

    if (_isAndroid) {
      androidInit = const AndroidInitializationSettings('@mipmap/ic_launcher');
    } else if (Platform.isIOS || Platform.isMacOS) {
      darwinInit = const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
    } else if (_isLinux) {
      linuxInit = LinuxInitializationSettings(
        defaultActionName: 'Open',
        defaultIcon: AssetsLinuxIcon('assets/fonts/icons/icon.png'),
      );
    }

    final settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
      linux: linuxInit,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) {
        _handleResponse(resp.actionId, resp.payload);
      },
      onDidReceiveBackgroundNotificationResponse: _backgroundResponseHandler,
    );

    // Action buttons with showsUserInterface:false are delivered to a separate
    // background isolate that can't reach this singleton. Bridge them back to
    // the main isolate over a named port so CHECK NEXT / UNDO work while the
    // app process is alive (foreground or backgrounded).
    if (!kIsWeb) {
      IsolateNameServer.removePortNameMapping(_notifActionPortName);
      final port = ReceivePort();
      IsolateNameServer.registerPortWithName(port.sendPort, _notifActionPortName);
      port.listen((message) {
        if (message is List && message.length == 2) {
          _handleResponse(message[0] as String?, message[1] as String?);
        }
      });
    }

    if (_isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Insight channel
        await android.createNotificationChannel(const AndroidNotificationChannel(
          _insightChannelId,
          _insightChannelName,
          description: _insightChannelDesc,
          importance: Importance.high,
          enableLights: true,
          ledColor: Color(0xFFFFB547),
        ));
        // Timer channel (low importance so it doesn't make sound on updates)
        await android.createNotificationChannel(const AndroidNotificationChannel(
          _timerChannelId,
          _timerChannelName,
          description: _timerChannelDesc,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ));
        // Reminder channel
        await android.createNotificationChannel(const AndroidNotificationChannel(
          _reminderChannelId,
          _reminderChannelName,
          description: _reminderChannelDesc,
          importance: Importance.high,
        ));
        // Transit channel (low importance for silent ongoing progress updates)
        await android.createNotificationChannel(const AndroidNotificationChannel(
          _transitChannelId,
          _transitChannelName,
          description: _transitChannelDesc,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ));
        try {
          await android.requestNotificationsPermission();
        } catch (_) {}
      }
    }
    _initialized = true;
  }

  // A CHECK / STOP tap can arrive (via the background isolate port) before the
  // AppProvider registers its handler on cold start. Buffer the last one and
  // replay it the moment a handler is set so the action isn't silently dropped.
  String? _pendingActionId;
  String? _pendingPayload;
  bool _hasPending = false;

  void setOnTap(void Function(String? payload)? handler) {
    _onTap = handler;
    if (_onTap != null && _hasPending) {
      final actionId = _pendingActionId;
      final payload = _pendingPayload;
      _pendingActionId = null;
      _pendingPayload = null;
      _hasPending = false;
      _handleResponse(actionId, payload);
    }
  }

  void _handleResponse(String? actionId, String? payload) {
    if (_onTap == null) {
      _pendingActionId = actionId;
      _pendingPayload = payload;
      _hasPending = true;
      return;
    }
    if (payload == null) {
      _onTap?.call(null);
      return;
    }
    switch (actionId) {
      case 'stop_timer':
        _onTap?.call('stop_timer:$payload');
        break;
      case 'check_next':
        _onTap?.call('check_next:$payload');
        break;
      case 'undo_check':
        _onTap?.call('undo_check:$payload');
        break;
      case 'stop_bus_transit':
        _onTap?.call('stop_bus_transit');
        break;
      case 'log_low_energy':
        _onTap?.call('log_low_energy');
        break;
      case 'dismiss_energy':
        break;
      default:
        if (payload.startsWith('log_low_energy')) {
          _onTap?.call('log_low_energy');
        } else {
          _onTap?.call(payload);
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Web helpers
  // ---------------------------------------------------------------------------

  Future<bool> _ensureWebPermission() async {
    if (!kIsWeb) return true;
    final perm = html.Notification.permission;
    if (perm == 'granted') return true;
    if (perm == 'denied') return false;
    if (_webPermissionRequested) return perm == 'granted';
    _webPermissionRequested = true;
    final result = await html.Notification.requestPermission();
    return result == 'granted';
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return _ensureWebPermission();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
    final ok = await android?.requestNotificationsPermission();
    return ok ?? true;
  }

  // ---------------------------------------------------------------------------
  // Insight notification (existing)
  // ---------------------------------------------------------------------------

  Future<void> showInsightReady({
    required String title,
    required String body,
    String? payload,
    int id = 1001,
  }) async {
    if (kIsWeb) {
      final ok = await _ensureWebPermission();
      if (!ok) return;
      final n = html.Notification(
        title,
        body: body,
        icon: 'icons/Icon-192.png',
        tag: 'insight-$id',
      );
      n.onClick.listen((_) {
        n.close();
        _onTap?.call(payload);
      });
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _insightChannelId,
      _insightChannelName,
      channelDescription: _insightChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.status,
      color: const Color(0xFFFFB547),
      colorized: true,
      ledColor: const Color(0xFFFFB547),
      ledOnMs: 800,
      ledOffMs: 400,
      ticker: 'Tactical Insight Acquired',
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: '<b>◢ $title</b>',
        summaryText: '<i>OPERATOR HUD // INSIGHT FEED</i>',
        htmlFormatContent: true,
        htmlFormatContentTitle: true,
        htmlFormatSummaryText: true,
      ),
    );
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwin,
      macOS: darwin,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  // ---------------------------------------------------------------------------
  // Persistent timer notification
  // ---------------------------------------------------------------------------

  /// Show / update the persistent active-timer notification.
  ///
  /// [progress] (0–1) renders a native progress bar mirroring the missions
  /// screen. When [nextCheckpointName] is non-null a "CHECK NEXT" action is
  /// added; [showUndo] swaps it for a transient "UNDO CHECK" button.
  /// [statusBody] overrides the body line (e.g. "✓ Checked X").
  Future<void> showTimerNotification({
    required String taskName,
    required DateTime startTime,
    required String subtaskId,
    String mainTaskId = '',
    String? mainTaskName,
    double progress = 0.0,
    String? nextCheckpointName,
    bool showUndo = false,
    String? statusBody,
  }) async {
    if (!_initialized) return;
    _activeTimerSubtaskId = subtaskId;
    _activeTimerStartTime = startTime;
    _activeTimerTaskName = taskName;
    _activeTimerNextCheckpoint = nextCheckpointName;

    if (kIsWeb) return; // No persistent notifications on web

    if (_isAndroid) {
      await _showAndroidTimerNotification(
        taskName,
        startTime,
        subtaskId,
        mainTaskId,
        progress,
        nextCheckpointName,
        showUndo,
        statusBody,
        mainTaskName,
      );
    } else if (_isLinux) {
      await _showLinuxTimerNotification(taskName, startTime, nextCheckpointName);
      _startLinuxTimerUpdater();
    } else {
      // iOS / macOS: basic non-persistent notification
      await _plugin.show(
        _timerNotifId,
        '▶ $taskName',
        statusBody ?? nextCheckpointName ?? 'Timer is running',
        const NotificationDetails(
          iOS: DarwinNotificationDetails(presentAlert: false, presentSound: false, presentBadge: false),
          macOS: DarwinNotificationDetails(presentAlert: false),
        ),
        payload: '$subtaskId|$mainTaskId',
      );
    }
  }

  Future<void> _showAndroidTimerNotification(
    String taskName,
    DateTime startTime,
    String subtaskId,
    String mainTaskId,
    double progress,
    String? nextCheckpointName,
    bool showUndo,
    String? statusBody,
    String? mainTaskName,
  ) async {
    final pct = (progress.clamp(0.0, 1.0) * 100).round();
    // Actions apply in-place without opening the app (showsUserInterface:false)
    // when the process is alive — the response is routed to setOnTap and the
    // provider mutates state directly.
    final actions = <AndroidNotificationAction>[];
    if (showUndo) {
      actions.add(const AndroidNotificationAction(
        'undo_check',
        'UNDO CHECK',
        showsUserInterface: false,
        cancelNotification: false,
      ));
    } else if (nextCheckpointName != null) {
      actions.add(const AndroidNotificationAction(
        'check_next',
        'CHECK',
        showsUserInterface: false,
        cancelNotification: false,
      ));
    }
    actions.add(const AndroidNotificationAction(
      'stop_timer',
      'STOP',
      cancelNotification: true,
      showsUserInterface: false,
    ));

    // Header = subtask name; secondary line = the latest checkpoint.
    final title = taskName.trim().isNotEmpty ? taskName : 'Session in progress';
    var body = (nextCheckpointName != null && nextCheckpointName.trim().isNotEmpty)
        ? nextCheckpointName
        : 'Session in progress';
    if (statusBody != null) {
      body = statusBody;
    }

    final details = AndroidNotificationDetails(
      _timerChannelId,
      _timerChannelName,
      channelDescription: _timerChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      usesChronometer: true,
      chronometerCountDown: false,
      when: startTime.millisecondsSinceEpoch,
      showWhen: true,
      showProgress: pct > 0,
      maxProgress: 100,
      progress: pct,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFFFB547),
      actions: actions,
    );
    await _plugin.show(
      _timerNotifId,
      '▶  $title',
      body,
      NotificationDetails(android: details),
      payload: '$subtaskId|$mainTaskId',
    );
  }

  Future<void> _showLinuxTimerNotification(
      String taskName, DateTime startTime, String? nextCheckpointName) async {
    final elapsed = DateTime.now().difference(startTime);
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final timeStr = h > 0 ? '$h:$m:$s' : '$m:$s';

    await _plugin.show(
      _timerNotifId,
      '▶  $taskName — $timeStr',
      nextCheckpointName ?? 'Timer running • updates every 5 min',
      const NotificationDetails(
        linux: LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.low,
          resident: true,
        ),
      ),
      payload: _activeTimerSubtaskId,
    );
  }

  void _startLinuxTimerUpdater() {
    _linuxTimerUpdater?.cancel();
    _linuxTimerUpdater = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_activeTimerStartTime != null && _activeTimerTaskName != null) {
        _showLinuxTimerNotification(
          _activeTimerTaskName!,
          _activeTimerStartTime!,
          _activeTimerNextCheckpoint,
        );
      }
    });
  }

  Future<void> cancelTimerNotification() async {
    _activeTimerSubtaskId = null;
    _activeTimerStartTime = null;
    _activeTimerTaskName = null;
    _activeTimerNextCheckpoint = null;
    _linuxTimerUpdater?.cancel();
    _linuxTimerUpdater = null;
    if (!kIsWeb) await _plugin.cancel(_timerNotifId);
  }

  // ---------------------------------------------------------------------------
  // Bus Transit ongoing notification
  // ---------------------------------------------------------------------------

  /// Show / update the persistent ongoing bus transit notification.
  Future<void> showBusTransitNotification({
    required String origin,
    required String destination,
    required double progress,
    required int minutesRemaining,
    double speedKmh = 20.0,
  }) async {
    if (!_initialized || kIsWeb) return;

    final pct = (progress.clamp(0.0, 1.0) * 100).round();
    final title = 'IN THE BUS · $origin → $destination';
    final body = 'ETA ~$minutesRemaining min ($pct%) · ${speedKmh.toStringAsFixed(0)} km/h';

    if (_isAndroid) {
      final details = AndroidNotificationDetails(
        _transitChannelId,
        _transitChannelName,
        channelDescription: _transitChannelDesc,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: 100,
        progress: pct,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFFFFB547), // tactical amber
        actions: const [
          AndroidNotificationAction(
            'stop_bus_transit',
            'END TRIP',
            cancelNotification: true,
            showsUserInterface: true,
          ),
        ],
      );

      await _plugin.show(
        _transitNotifId,
        '🚌 $title',
        body,
        NotificationDetails(android: details),
        payload: 'bus_transit',
      );
    } else if (_isLinux) {
      await _plugin.show(
        _transitNotifId,
        '🚌 $title ($pct%)',
        body,
        const NotificationDetails(
          linux: LinuxNotificationDetails(
            urgency: LinuxNotificationUrgency.low,
            resident: true,
          ),
        ),
        payload: 'bus_transit',
      );
    }
  }

  Future<void> cancelBusTransitNotification() async {
    if (!kIsWeb) {
      await _plugin.cancel(_transitNotifId);
    }
  }

  // ---------------------------------------------------------------------------
  // Daily reminder scheduling
  // ---------------------------------------------------------------------------

  /// Schedule (or reschedule) a daily reminder at [hour]:[minute] local time.
  /// [id] must be unique per reminder type (use [_reflectionReminderId] etc.).
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    List<AndroidNotificationAction>? actions,
    String? payload,
  }) async {
    if (!_initialized) return;
    await cancelDailyReminder(id);

    if (kIsWeb) return;

    if (_supportsZonedSchedule) {
      await _scheduleAndroidDailyReminder(id, title, body, hour, minute, actions: actions, payload: payload);
    } else {
      _scheduleInAppDailyReminder(id, title, body, hour, minute);
    }
  }

  /// Schedule energy check reminders asking "Are you tired?" based on user settings
  Future<void> scheduleEnergyCheckReminders({
    bool enabled = true,
    String title = 'ENERGY CHECK',
    String body = 'Are you feeling tired or low on energy right now?',
    List<String>? customTimes,
  }) async {
    if (!_initialized) return;

    // Cancel existing energy reminders (IDs 5000 to 5099)
    for (int i = 0; i < 100; i++) {
      await cancelDailyReminder(5000 + i);
    }

    if (!enabled) return;

    final defaultTimes = const [
      "09:00",
      "10:30",
      "12:00",
      "13:30",
      "15:00",
      "16:30",
      "18:00",
      "19:30",
      "21:00",
      "22:30"
    ];
    final times = (customTimes != null && customTimes.isNotEmpty) ? customTimes : defaultTimes;

    for (int i = 0; i < times.length; i++) {
      final parts = times[i].split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;

      final id = 5000 + i;
      await scheduleDailyReminder(
        id: id,
        title: title.isNotEmpty ? title : 'ENERGY CHECK',
        body: body.isNotEmpty ? body : 'Are you feeling tired or low on energy right now?',
        hour: h,
        minute: m,
        payload: 'log_low_energy',
        actions: const [
          AndroidNotificationAction('log_low_energy', 'YES (Tired)', showsUserInterface: true),
          AndroidNotificationAction('dismiss_energy', 'NO', showsUserInterface: false),
        ],
      );
    }
  }

  Future<void> _scheduleAndroidDailyReminder(
      int id, String title, String body, int hour, int minute,
      {List<AndroidNotificationAction>? actions, String? payload}) async {
    final location = tz.local;
    final now = tz.TZDateTime.now(location);
    var tzScheduled = tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);
    if (tzScheduled.isBefore(now)) {
      tzScheduled = tzScheduled.add(const Duration(days: 1));
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        actions: actions,
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduled,
      details,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _scheduleInAppDailyReminder(
      int id, String title, String body, int hour, int minute) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    final delay = next.difference(now);
    _inAppReminderTimers[id] = Timer(delay, () async {
      await _showReminderNow(id, title, body);
      // Reschedule for next day
      _scheduleInAppDailyReminder(id, title, body, hour, minute);
    });
  }

  Future<void> _showReminderNow(int id, String title, String body) async {
    if (kIsWeb) return;
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        linux: LinuxNotificationDetails(urgency: LinuxNotificationUrgency.normal),
        macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  Future<void> cancelDailyReminder(int id) async {
    _inAppReminderTimers[id]?.cancel();
    _inAppReminderTimers.remove(id);
    if (!kIsWeb) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // One-time submission reminder
  // ---------------------------------------------------------------------------

  Future<void> scheduleOneTimeReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) return;
    await cancelDailyReminder(id); // reuse cancel (clears both timer + plugin)

    if (kIsWeb) return;
    if (scheduledTime.isBefore(DateTime.now())) return;

    if (_supportsZonedSchedule) {
      final utc = scheduledTime.toUtc();
      final tzScheduled = tz.TZDateTime(
          tz.UTC, utc.year, utc.month, utc.day, utc.hour, utc.minute, utc.second);

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          _reminderChannelName,
          channelDescription: _reminderChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } else {
      // Linux / macOS: in-app timer
      final delay = scheduledTime.difference(DateTime.now());
      _inAppReminderTimers[id] = Timer(delay, () async {
        await _showReminderNow(id, title, body);
        _inAppReminderTimers.remove(id);
      });
    }
  }

  Future<void> cancelOneTimeReminder(int id) async => cancelDailyReminder(id);

  static int subtaskReminderId(String subtaskId) =>
      _submissionReminderBase + subtaskId.hashCode.abs() % 50000;

  // ---------------------------------------------------------------------------
  // Generic cancel
  // ---------------------------------------------------------------------------

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }
}

// Name of the port the main isolate listens on for forwarded notification
// action-button taps.
const String _notifActionPortName = 'arcane_notif_action_port';

// Top-level background handler (Android requires this to be a top-level function).
// Runs in a detached isolate; forward the tap to the main isolate's port so the
// live AppProvider can act on it.
@pragma('vm:entry-point')
void _backgroundResponseHandler(NotificationResponse resp) {
  final send = IsolateNameServer.lookupPortByName(_notifActionPortName);
  send?.send(<String?>[resp.actionId, resp.payload]);
}
