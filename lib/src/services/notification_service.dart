import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:universal_html/html.dart' as html;

/// Cross-platform notification facade.
/// Web -> HTML5 Notification API. Native -> flutter_local_notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _webPermissionRequested = false;
  void Function(String? payload)? _onTap;

  static const String _channelId = 'tactical_insights';
  static const String _channelName = 'Tactical Insights';
  static const String _channelDesc = 'Reflection analyses and AI insights';

  Future<void> init({void Function(String? payload)? onTap}) async {
    if (_initialized) return;
    _onTap = onTap;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) => _onTap?.call(resp.payload),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
        enableLights: true,
        ledColor: Color(0xFFFFB547),
      ));
      try {
        await android.requestNotificationsPermission();
      } catch (_) {}
    }
    _initialized = true;
  }

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
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
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

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }
}
