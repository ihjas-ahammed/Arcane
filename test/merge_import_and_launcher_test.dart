import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Normalize Imported Data Tests', () {
    test('normalizes raw Firebase RTDB export with nested users/<uid>/data', () {
      final rtdbExport = {
        'users': {
          'user_123': {
            'data': {
              'reflections': {
                'log_old_1': {
                  'timestamp': '2026-08-01T10:00:00.000Z',
                  'trigger': 'Old reflection',
                  'emotion': 'Calm',
                  'reason': 'Reviewing mission',
                  'action': 'Rest',
                  'aiFeedback': 'Good job',
                  'xpGained': {'Positivity': 10},
                },
              },
              'history': {
                'completedByDay': {
                  '2026-08-01': {
                    'briefing': 'Old briefing August',
                    'tasks': [{'id': 'task_aug_1', 'title': 'August Mission'}],
                  },
                },
              },
              'tasks': {
                'mainTasks': [
                  {'id': 'm_aug', 'name': 'Old Task', 'subTasks': []}
                ],
              },
              'launcher': jsonEncode({
                'dock': ['app_a', 'app_b'],
                'home': ['app_c'],
              }),
            }
          }
        }
      };

      final normalized = AppProvider.normalizeImportedData(rtdbExport);

      expect(normalized['reflectionLogs'], isA<List>());
      expect((normalized['reflectionLogs'] as List).length, equals(1));
      expect((normalized['reflectionLogs'] as List).first['id'], equals('log_old_1'));

      expect(normalized['completedByDay'], isA<Map>());
      expect(normalized['completedByDay']['2026-08-01'], isNotNull);

      expect(normalized['mainTasks'], isA<List>());
      expect((normalized['mainTasks'] as List).first['id'], equals('m_aug'));

      expect(normalized['launcher'], isA<Map>());
      expect(normalized['launcher']['dock'], equals(['app_a', 'app_b']));
    });

    test('normalizes history map with direct date keys', () {
      final input = {
        'history': {
          '2026-07-15': {'briefing': 'July brief'},
          '2026-07-16': {'briefing': 'July brief 2'},
        }
      };

      final normalized = AppProvider.normalizeImportedData(input);
      expect(normalized['completedByDay'], isNotNull);
      expect(normalized['completedByDay']['2026-07-15']['briefing'], equals('July brief'));
      expect(normalized['completedByDay']['2026-07-16']['briefing'], equals('July brief 2'));
    });
  });

  group('Merge App State Non-Destructive Tests', () {
    test('merges older reflection logs without overwriting recent logs', () {
      final provider = AppProvider.forTest();
      provider.endDataLoad();

      // Current state: user has reflections from the last 2 days
      final recentLog1 = ReflectionLog(
        id: 'recent_log_today',
        timestamp: DateTime.parse('2026-10-03T08:00:00.000Z'),
        trigger: 'Completed hard coding objective',
        emotion: 'Proud',
        reason: 'Delivered fix',
        action: 'Celebrate',
        aiFeedback: 'Great momentum',
        xpGained: {'Mastery': 25},
      );
      final recentLog2 = ReflectionLog(
        id: 'recent_log_yesterday',
        timestamp: DateTime.parse('2026-10-02T20:00:00.000Z'),
        trigger: 'Evening review',
        emotion: 'Peaceful',
        reason: 'Finished all tasks',
        action: 'Sleep early',
        aiFeedback: 'Rest is restorative',
        xpGained: {'Vitality': 20},
      );
      provider.setReflectionLogs([recentLog2, recentLog1]);

      // Older JSON file contains lost reflection from 2 months ago, AND an outdated version of today's log
      final olderJson = {
        'reflectionLogs': [
          {
            'id': 'lost_reflection_august',
            'timestamp': '2026-08-15T12:00:00.000Z',
            'trigger': 'Lost August memories',
            'emotion': 'Reflective',
            'reason': 'Summer retrospective',
            'action': 'Journal',
            'aiFeedback': 'Deep thoughts',
            'xpGained': {'Growth': 15},
          },
          {
            'id': 'recent_log_today', // Same ID as today's log
            'timestamp': '2026-10-03T07:00:00.000Z',
            'trigger': 'OUTDATED DRAFT THAT MUST NOT OVERWRITE',
            'emotion': 'Tired',
            'reason': 'Early morning',
            'action': 'Coffee',
            'aiFeedback': 'Old feedback',
            'xpGained': {'Positivity': 5},
          }
        ]
      };

      final report = provider.mergeAppStateFromMap(olderJson);

      expect(report.addedReflections, equals(1));
      expect(provider.reflectionLogs.length, equals(3));

      // 1. Verify lost August reflection was restored
      final restored = provider.reflectionLogs.firstWhere((r) => r.id == 'lost_reflection_august');
      expect(restored.trigger, equals('Lost August memories'));

      // 2. CRITICAL: Verify today's recent reflection was NOT overwritten by older draft!
      final today = provider.reflectionLogs.firstWhere((r) => r.id == 'recent_log_today');
      expect(today.trigger, equals('Completed hard coding objective'));
      expect(today.emotion, equals('Proud'));

      // 3. Verify chronological ascending order (oldest to newest)
      expect(provider.reflectionLogs[0].id, equals('lost_reflection_august'));
      expect(provider.reflectionLogs[1].id, equals('recent_log_yesterday'));
      expect(provider.reflectionLogs[2].id, equals('recent_log_today'));
    });

    test('merges completedByDay without replacing recent days', () {
      final provider = AppProvider.forTest();
      provider.endDataLoad();

      // Current state: today and yesterday have active tasks and notes
      provider.setCompletedByDay({
        '2026-10-03': {
          'briefing': 'Morning Briefing Oct 3',
          'tasks': [{'id': 'task_today_1', 'title': 'Fresh Mission Added Today'}],
        },
        '2026-10-02': {
          'briefing': 'Oct 2 wrap up',
        },
      });

      // Older JSON contains days from September, and an older state of Oct 2
      final olderJson = {
        'completedByDay': {
          '2026-09-15': {
            'briefing': 'September Briefing',
          },
          '2026-10-02': {
            'briefing': 'OLD BRIEFING THAT MUST NOT OVERWRITE',
            'notes': 'Old historical note recovered',
          },
        }
      };

      final report = provider.mergeAppStateFromMap(olderJson);

      expect(report.mergedDays, greaterThanOrEqualTo(1));
      expect(provider.completedByDay.containsKey('2026-09-15'), isTrue);
      expect(provider.completedByDay.containsKey('2026-10-03'), isTrue);

      // Verify today's tasks and briefing were preserved
      expect(provider.completedByDay['2026-10-03']['briefing'], equals('Morning Briefing Oct 3'));
      final todayTasks = provider.completedByDay['2026-10-03']['tasks'] as List;
      expect(todayTasks.first['title'], equals('Fresh Mission Added Today'));

      // Verify Oct 2 kept its briefing but adopted the missing note
      expect(provider.completedByDay['2026-10-02']['briefing'], equals('Oct 2 wrap up'));
      expect(provider.completedByDay['2026-10-02']['notes'], equals('Old historical note recovered'));
    });
  });

  group('LauncherService Safety & Merge Tests', () {
    test('loadFromMap with empty arrays does NOT wipe non-empty dock or home', () async {
      SharedPreferences.setMockInitialValues({
        'launcher_v4_dock': ['app.browser', 'app.camera'],
        'launcher_v4_home': ['app.chat', 'app.mail'],
      });

      final service = LauncherService.instance;
      await service.init();

      expect(service.dock.value, contains('app.browser'));
      expect(service.home.value, contains('app.chat'));

      // Empty map incoming from a buggy/blank cloud sync or restore
      await service.loadFromMap({
        'dock': <String>[],
        'home': <String>[],
        'widgets': <dynamic>[],
        'folders': <dynamic>[],
      }, forceReplace: false);

      // CRITICAL: Local dock and home MUST NOT be cleared!
      expect(service.dock.value, contains('app.browser'));
      expect(service.home.value, contains('app.chat'));
    });

    test('mergeFromMap restores missing icons to empty or populated launcher', () async {
      SharedPreferences.setMockInitialValues({
        'launcher_v4_dock': ['me.ihjas.missions/app'],
        'launcher_v4_home': <String>[],
      });

      final service = LauncherService.instance;
      await service.init();

      // Older JSON has the user's previously configured dock and home
      final olderLauncher = {
        'dock': ['app.phone', 'app.messages', 'app.camera'],
        'home': ['app.calculator', 'app.clock'],
        'quickNotes': 'Tactical mission reminders',
      };

      await service.mergeFromMap(olderLauncher);

      // Home restored from backup
      expect(service.home.value, contains('app.calculator'));
      expect(service.home.value, contains('app.clock'));

      // Dock restored from backup
      expect(service.dock.value, contains('app.phone'));
      expect(service.dock.value, contains('app.messages'));

      // Notes restored
      expect(service.quickNotes, equals('Tactical mission reminders'));
    });
  });
}
