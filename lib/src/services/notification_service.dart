import 'dart:async';
import 'dart:io' show Platform;
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

  // --- Notification IDs ---
  static const int _timerNotifId = 2001;
  static const int reflectionReminderId = 3001;
  static const int _submissionReminderBase = 4000;

  // Linux: periodic timer for updating the live-elapsed notification every 5 min
  Timer? _linuxTimerUpdater;
  String? _activeTimerSubtaskId;
  DateTime? _activeTimerStartTime;
  String? _activeTimerTaskName;

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
        try {
          await android.requestNotificationsPermission();
        } catch (_) {}
      }
    }
    _initialized = true;
  }

  void setOnTap(void Function(String? payload)? handler) {
    _onTap = handler;
  }

  void _handleResponse(String? actionId, String? payload) {
    if (actionId == 'stop_timer' && payload != null) {
      _onTap?.call('stop_timer:$payload');
    } else {
      _onTap?.call(payload);
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

  Future<void> showTimerNotification({
    required String taskName,
    required DateTime startTime,
    required String subtaskId,
  }) async {
    if (!_initialized) return;
    _activeTimerSubtaskId = subtaskId;
    _activeTimerStartTime = startTime;
    _activeTimerTaskName = taskName;

    if (kIsWeb) return; // No persistent notifications on web

    if (_isAndroid) {
      await _showAndroidTimerNotification(taskName, startTime, subtaskId);
    } else if (_isLinux) {
      await _showLinuxTimerNotification(taskName, startTime);
      _startLinuxTimerUpdater();
    } else {
      // iOS / macOS: basic non-persistent notification
      await _plugin.show(
        _timerNotifId,
        '▶ $taskName',
        'Timer is running',
        const NotificationDetails(
          iOS: DarwinNotificationDetails(presentAlert: false, presentSound: false, presentBadge: false),
          macOS: DarwinNotificationDetails(presentAlert: false),
        ),
        payload: subtaskId,
      );
    }
  }

  Future<void> _showAndroidTimerNotification(
      String taskName, DateTime startTime, String subtaskId) async {
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
      usesChronometer: true,
      chronometerCountDown: false,
      when: startTime.millisecondsSinceEpoch,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFFFB547),
      actions: [
        AndroidNotificationAction(
          'stop_timer',
          'STOP',
          cancelNotification: true,
        ),
      ],
    );
    await _plugin.show(
      _timerNotifId,
      '▶  $taskName',
      'Tap STOP to end session',
      NotificationDetails(android: details),
      payload: subtaskId,
    );
  }

  Future<void> _showLinuxTimerNotification(
      String taskName, DateTime startTime) async {
    final elapsed = DateTime.now().difference(startTime);
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final timeStr = h > 0 ? '$h:$m:$s' : '$m:$s';

    await _plugin.show(
      _timerNotifId,
      '▶  $taskName — $timeStr',
      'Timer running • updates every 5 min',
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
        _showLinuxTimerNotification(_activeTimerTaskName!, _activeTimerStartTime!);
      }
    });
  }

  Future<void> cancelTimerNotification() async {
    _activeTimerSubtaskId = null;
    _activeTimerStartTime = null;
    _activeTimerTaskName = null;
    _linuxTimerUpdater?.cancel();
    _linuxTimerUpdater = null;
    if (!kIsWeb) await _plugin.cancel(_timerNotifId);
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
  }) async {
    if (!_initialized) return;
    await cancelDailyReminder(id);

    if (kIsWeb) return;

    if (_supportsZonedSchedule) {
      await _scheduleAndroidDailyReminder(id, title, body, hour, minute);
    } else {
      _scheduleInAppDailyReminder(id, title, body, hour, minute);
    }
  }

  Future<void> _scheduleAndroidDailyReminder(
      int id, String title, String body, int hour, int minute) async {
    // Build TZDateTime for today at [hour:minute] in local offset expressed as UTC
    final now = DateTime.now();
    var local =
        DateTime(now.year, now.month, now.day, hour, minute, 0);
    if (local.isBefore(now)) {
      local = local.add(const Duration(days: 1));
    }
    final utc = local.toUtc();
    final tzScheduled = tz.TZDateTime(tz.UTC, utc.year, utc.month, utc.day,
        utc.hour, utc.minute, utc.second);

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
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

// Top-level background handler (Android requires this to be a top-level function)
@pragma('vm:entry-point')
void _backgroundResponseHandler(NotificationResponse resp) {
  // Background taps can't easily reach the provider, but the app will handle
  // the payload via onDidReceiveNotificationResponse when it next foregrounds.
}
