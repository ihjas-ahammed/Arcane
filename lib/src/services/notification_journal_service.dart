import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationJournalEntry {
  final String id;
  final String packageName;
  final String appName;
  final String title;
  final String text;
  final String subText;
  final int timestamp;
  final String timeStr;
  final String dateStr;

  const NotificationJournalEntry({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    this.subText = '',
    required this.timestamp,
    required this.timeStr,
    required this.dateStr,
  });

  factory NotificationJournalEntry.fromMap(Map<dynamic, dynamic> map) {
    return NotificationJournalEntry(
      id: map['id']?.toString() ?? '',
      packageName: map['packageName']?.toString() ?? '',
      appName: map['appName']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      subText: map['subText']?.toString() ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      timeStr: map['timeStr']?.toString() ?? '',
      dateStr: map['dateStr']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'appName': appName,
      'title': title,
      'text': text,
      'subText': subText,
      'timestamp': timestamp,
      'timeStr': timeStr,
      'dateStr': dateStr,
    };
  }
}

class NotificationJournalService {
  static const MethodChannel _channel = MethodChannel('arcane/notifications');

  static final NotificationJournalService instance = NotificationJournalService._internal();

  NotificationJournalService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final _notificationController = StreamController<NotificationJournalEntry>.broadcast();
  Stream<NotificationJournalEntry> get onNotification => _notificationController.stream;

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onNotificationReceived') {
      try {
        final map = call.arguments as Map<dynamic, dynamic>;
        final entry = NotificationJournalEntry.fromMap(map);
        _notificationController.add(entry);
      } catch (e) {
        debugPrint('[NotificationJournalService] Failed to parse received notification: $e');
      }
    }
  }

  Future<bool> isPermissionGranted() async {
    try {
      final res = await _channel.invokeMethod<bool>('isPermissionGranted');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openPermissionSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openPermissionSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getSelectedApps() async {
    try {
      final res = await _channel.invokeListMethod<String>('getSelectedApps');
      return res ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> setSelectedApps(List<String> packages) async {
    try {
      final res = await _channel.invokeMethod<bool>('setSelectedApps', {'packages': packages});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<List<NotificationJournalEntry>> getNotifications(String dateStr) async {
    try {
      final res = await _channel.invokeListMethod<dynamic>('getNotifications', {'date': dateStr});
      if (res == null) return [];
      return res.map((item) => NotificationJournalEntry.fromMap(item as Map<dynamic, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> deleteNotification(String dateStr, String id) async {
    try {
      final res = await _channel.invokeMethod<bool>('deleteNotification', {'date': dateStr, 'id': id});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearNotifications(String dateStr) async {
    try {
      final res = await _channel.invokeMethod<bool>('clearNotifications', {'date': dateStr});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
