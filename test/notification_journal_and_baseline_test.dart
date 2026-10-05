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

    test('AppProvider.startNewDayForDate establishes baseline and flags day_started', () {
      final provider = AppProvider.forTest();
      provider.addMainTask(name: 'Tactical Recon', description: 'Ops', colorHex: '00E5FF', theme: 'Tactical');
      final mainTask = provider.mainTasks.first;

      provider.addSubtask(mainTask.id, {
        'name': 'Morning Briefing Check',
        'completed': false,
      });

      final todayStr = '2026-10-05';
      provider.startNewDayForDate(
        todayStr,
        startupNote: 'Prepare equipment early. Maintain high focus.',
        directives: ['Direct checklist 1', 'Direct checklist 2'],
      );

      final report = provider.getStartDayReport(todayStr);
      expect(report, isNotNull);
      expect(report!['day_started'], isTrue);
      expect(report['forecast'], 'Prepare equipment early. Maintain high focus.');
      expect(report['directives'], ['Direct checklist 1', 'Direct checklist 2']);
      expect(report['task_snapshot'], isNotNull);
      final snapshot = report['task_snapshot'] as Map;
      expect(snapshot.containsKey(mainTask.id), isTrue);
    });

    test('Daily rollover unflags day_started and resets recurring tasks in startDayReport', () async {
      final provider = AppProvider.forTest();
      provider.setLastLoginDate('2026-10-04');

      final todayStr = DateTime.now().toIso8601String().split('T').first;

      // Add a recurring task that was completed yesterday
      provider.addMainTask(name: 'Health', description: 'Body', colorHex: 'FF9100', theme: 'Health');
      final mainTask = provider.mainTasks.first;
      final subId = provider.addSubtask(mainTask.id, {
        'name': 'Drink water',
        'isRecurring': true,
        'completed': true,
      });

      // Advance startDayReport prepared the night before with completed recurring subtask
      final initialReport = {
        'forecast': 'Advance note from yesterday night',
        'day_started': true,
        'task_snapshot': {
          mainTask.id: {
            'name': 'Health',
            'subtasks': {
              subId: {
                'name': 'Drink water',
                'progress': 1.0,
                'completed': true,
              }
            }
          }
        }
      };
      provider.saveStartDayReport(todayStr, initialReport);

      // Trigger daily rollover
      await provider.handleDailyResetForTesting();

      final report = provider.getStartDayReport(todayStr);
      expect(report, isNotNull);
      expect(report!['day_started'], isFalse); // Must be unflagged for the new day
      final ts = report['task_snapshot'] as Map;
      final subSnap = ts[mainTask.id]['subtasks'][subId] as Map;
      expect(subSnap['completed'], isFalse); // Recurring task reset to 0 in snapshot
      expect(subSnap['progress'], 0.0);
    });
  });
}
