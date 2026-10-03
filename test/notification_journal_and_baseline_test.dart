import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/notification_journal_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NotificationJournalEntry & AppProvider Notification History Tests', () {
    test('NotificationJournalEntry converts to/from Map correctly', () {
      final entry = NotificationJournalEntry(
        id: 'msg-123',
        packageName: 'com.whatsapp',
        appName: 'WhatsApp',
        title: 'Alice',
        text: 'Mission protocol review scheduled at 14:00.',
        subText: 'Tactical Team',
        timestamp: 1727932800000,
        timeStr: '14:00',
        dateStr: '2026-10-03',
      );

      final map = entry.toMap();
      expect(map['id'], 'msg-123');
      expect(map['packageName'], 'com.whatsapp');
      expect(map['appName'], 'WhatsApp');
      expect(map['title'], 'Alice');
      expect(map['text'], 'Mission protocol review scheduled at 14:00.');

      final parsed = NotificationJournalEntry.fromMap(map);
      expect(parsed.id, entry.id);
      expect(parsed.packageName, entry.packageName);
      expect(parsed.appName, entry.appName);
      expect(parsed.title, entry.title);
      expect(parsed.text, entry.text);
      expect(parsed.subText, entry.subText);
      expect(parsed.timestamp, entry.timestamp);
      expect(parsed.timeStr, entry.timeStr);
      expect(parsed.dateStr, entry.dateStr);
    });

    test('AppProvider saves and retrieves notifications for date seamlessly', () {
      final provider = AppProvider.forTest();
      final dateStr = '2026-10-03';

      expect(provider.getNotificationsForDate(dateStr), isEmpty);

      final notifs = [
        {
          'id': 'notif-1',
          'packageName': 'org.telegram.messenger',
          'appName': 'Telegram',
          'title': 'HQ Dispatch',
          'text': 'Operation Revive is active',
          'timestamp': 1727933000000,
          'timeStr': '14:15',
          'dateStr': dateStr,
        },
        {
          'id': 'notif-2',
          'packageName': 'com.discord',
          'appName': 'Discord',
          'title': 'Agent Team',
          'text': 'Briefing ready for review',
          'timestamp': 1727933500000,
          'timeStr': '14:25',
          'dateStr': dateStr,
        },
      ];

      provider.saveNotificationsForDate(dateStr, notifs);

      final retrieved = provider.getNotificationsForDate(dateStr);
      expect(retrieved.length, 2);
      expect(retrieved[0]['title'], 'HQ Dispatch');
      expect(retrieved[1]['appName'], 'Discord');
    });

    test('AppProvider.createTimeLogStartForToday initializes task snapshot baseline', () {
      final provider = AppProvider.forTest();
      provider.addMainTask(name: 'Strategic Ops', description: 'Main Ops', colorHex: '#FF0000', theme: 'Ops');
      final mainTask = provider.mainTasks.first;

      final subId = provider.addSubtask(mainTask.id, {
        'name': 'Deploy notifications journal',
        'completed': true,
      });

      // Calibrate today's baseline with this subtask
      provider.createTimeLogStartForToday(checkedSubtaskIds: {subId});

      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final startDayReport = provider.getStartDayReport(todayStr);

      expect(startDayReport, isNotNull);
      expect(startDayReport!['task_snapshot'], isNotNull);
      final snapshot = startDayReport['task_snapshot'] as Map;
      expect(snapshot.containsKey(mainTask.id), isTrue);
    });
  });
}
