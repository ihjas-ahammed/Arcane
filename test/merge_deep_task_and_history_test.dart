import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Deep Task & Completed Data Merge Tests', () {
    test('normalizeImportedData converts map-based mainTasks and nested subtasks to lists', () {
      final input = {
        'mainTasks': {
          't1': {
            'id': 't1',
            'name': 'Workout',
            'description': 'Daily fitness',
            'theme': 'Health',
            'subTasks': {
              'st1': {
                'id': 'st1',
                'name': 'Pushups',
                'completed': true,
                'subSubTasks': {
                  'cp1': {'id': 'cp1', 'name': 'Set 1', 'completed': true},
                },
                'sessions': {
                  's1': {
                    'id': 's1',
                    'startTime': '2026-10-01T08:00:00.000',
                    'endTime': '2026-10-01T08:20:00.000',
                  },
                },
              },
            },
          },
        },
        'completedByDay': {
          '2026-10-01': {
            'subtasksCompleted': {
              '0': {'taskId': 't1', 'subtaskId': 'st1', 'subtaskName': 'Pushups'},
            },
            'checkpointsCompleted': {
              '0': {'taskId': 't1', 'subtaskId': 'st1', 'checkpointTitle': 'Set 1'},
            },
          },
        },
      };

      final normalized = AppProvider.normalizeImportedData(input);
      expect(normalized['mainTasks'], isA<List>());
      final tasks = normalized['mainTasks'] as List;
      expect(tasks.length, equals(1));
      expect(tasks[0]['subTasks'], isA<List>());
      final subtasks = tasks[0]['subTasks'] as List;
      expect(subtasks.length, equals(1));
      expect(subtasks[0]['subSubTasks'], isA<List>());
      expect(subtasks[0]['sessions'], isA<List>());

      final cMap = normalized['completedByDay'] as Map;
      expect(cMap['2026-10-01']['subtasksCompleted'], isA<List>());
      expect(cMap['2026-10-01']['checkpointsCompleted'], isA<List>());
    });

    test('deeply merges subtasks and completed checkpoints into existing tasks', () {
      final provider = AppProvider.forTest();
      provider.endDataLoad();

      // Current state: Task t1 has st1 incomplete, with cp1 incomplete
      final initialTask = MainTask(
        id: 't1',
        name: 'Core Training',
        description: 'Physical',
        theme: 'Fitness',
        subTasks: [
          SubTask(
            id: 'st1',
            name: 'Plank',
            completed: false,
            currentTimeSpent: 100,
            subSubTasks: [
              SubSubTask(id: 'cp1', name: 'Hold 60s', completed: false),
            ],
            sessions: [
              TaskSession(
                id: 'sess1',
                startTime: DateTime(2026, 10, 2, 9, 0),
                endTime: DateTime(2026, 10, 2, 9, 5),
              ),
            ],
          ),
        ],
      );
      provider.setMainTasks([initialTask]);
      provider.setCompletedByDay({
        '2026-10-02': {
          'taskTimes': {'t1': 300},
          'subtasksCompleted': <Map<String, dynamic>>[],
        },
      });

      // Older backup has:
      // - st1 marked completed, with cp1 completed, plus an extra session sess2
      // - an additional subtask st2 that was created in the past
      // - historical completedByDay for 2026-10-01 and additional records for 2026-10-02
      final backupData = {
        'mainTasks': [
          {
            'id': 't1',
            'name': 'Core Training',
            'description': 'Physical',
            'theme': 'Fitness',
            'subTasks': [
              {
                'id': 'st1',
                'name': 'Plank',
                'completed': true,
                'completedDate': '2026-10-01',
                'currentTimeSpent': 250,
                'subSubTasks': [
                  {'id': 'cp1', 'name': 'Hold 60s', 'completed': true},
                ],
                'sessions': [
                  {
                    'id': 'sess2',
                    'startTime': '2026-10-01T10:00:00.000',
                    'endTime': '2026-10-01T10:10:00.000',
                  },
                ],
              },
              {
                'id': 'st2',
                'name': 'Crunches',
                'completed': true,
                'completedDate': '2026-10-01',
                'currentTimeSpent': 180,
                'subSubTasks': [],
                'sessions': [],
              },
            ],
          },
        ],
        'completedByDay': {
          '2026-10-01': {
            'taskTimes': {'t1': 430},
            'subtasksCompleted': [
              {'taskId': 't1', 'subtaskId': 'st1', 'subtaskName': 'Plank'},
            ],
            'checkpointsCompleted': [
              {'taskId': 't1', 'subtaskId': 'st1', 'checkpointTitle': 'Hold 60s'},
            ],
          },
          '2026-10-02': {
            'taskTimes': {'t1': 100},
            'subtasksCompleted': [
              {'taskId': 't1', 'subtaskId': 'st2', 'subtaskName': 'Crunches'},
            ],
          },
        },
      };

      final report = provider.mergeAppStateFromMap(backupData);

      // Verify report
      expect(report.mergedDays >= 1, isTrue);

      // Verify task t1 was enriched:
      final task = provider.mainTasks.firstWhere((t) => t.id == 't1');
      expect(task.subTasks.length, equals(2)); // st1 and restored st2

      final st1 = task.subTasks.firstWhere((s) => s.id == 'st1');
      expect(st1.completed, isTrue); // Incomplete st1 became completed
      expect(st1.currentTimeSpent, equals(250)); // Max time taken
      expect(st1.subSubTasks.first.completed, isTrue); // Checkpoint completed restored
      expect(st1.sessions.length, equals(2)); // Both sess1 and sess2 preserved

      final st2 = task.subTasks.firstWhere((s) => s.id == 'st2');
      expect(st2.completed, isTrue);

      // Verify completedByDay history was merged deeply
      expect(provider.completedByDay.containsKey('2026-10-01'), isTrue);
      expect(provider.completedByDay.containsKey('2026-10-02'), isTrue);

      final day2 = provider.completedByDay['2026-10-02'] as Map<String, dynamic>;
      expect(day2['taskTimes']['t1'], equals(300)); // Max time kept
      final subtasksCompletedDay2 = day2['subtasksCompleted'] as List;
      expect(subtasksCompletedDay2.length, equals(1));
      expect(subtasksCompletedDay2[0]['subtaskName'], equals('Crunches'));
    });
  });
}
