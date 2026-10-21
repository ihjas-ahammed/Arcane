import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/task_models.dart';
import './mock.dart';

/// Completed checkpoints under inactive subtasks must not be written into daily history,
/// and a checkpoint must be logged once, not again on every new day.
void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Checkpoint history sync', () {
    MainTask buildTask({required bool subActive}) {
      final sub = SubTask(
        id: 'linear_sub',
        name: "Linear Algebra and It's Applications",
        isActive: subActive,
        subSubTasks: [
          SubSubTask(
            id: 'cp_timed',
            name: 'Applications of linear systems',
            completed: true,
            completionTimestamp: '2026-10-10T09:00:00.000',
          ),
          SubSubTask(
            id: 'cp_untimed',
            name: 'Linear independence',
            completed: true,
          ),
        ],
      );
      return MainTask(
        id: 'purpose',
        name: 'Purpose',
        description: '',
        theme: '',
        subTasks: [sub],
      );
    }

    List<Map> checkpointsOn(AppProvider provider, String date) {
      final day = provider.completedByDay[date] as Map? ?? {};
      return (day['checkpointsCompleted'] as List? ?? []).whereType<Map>().toList();
    }

    test('checkpoints under an inactive subtask are not logged to any day', () {
      final provider = AppProvider.forTest();
      provider.setProviderState(mainTasks: [buildTask(subActive: false)]);

      provider.mergeAppStateFromMap({'completedByDay': {}});

      expect(provider.completedByDay.values.any((d) => d is Map && d['checkpointsCompleted'] is List && (d['checkpointsCompleted'] as List).isNotEmpty), false,
          reason: 'Inactive subtask checkpoints must not appear in daily history');
    });

    test('a timestamped checkpoint is logged once and not re-logged on a later merge', () {
      final provider = AppProvider.forTest();
      provider.setProviderState(mainTasks: [buildTask(subActive: true)]);

      provider.mergeAppStateFromMap({'completedByDay': {}});
      provider.mergeAppStateFromMap({'completedByDay': {}});

      final logged = checkpointsOn(provider, '2026-10-10')
          .where((c) => c['subSubTaskId'] == 'cp_timed')
          .toList();
      expect(logged.length, 1, reason: 'Checkpoint must be logged exactly once');
    });

    test('a checkpoint with no timestamp and no subtask date is not stamped onto a day', () {
      final provider = AppProvider.forTest();
      provider.setProviderState(mainTasks: [buildTask(subActive: true)]);

      provider.mergeAppStateFromMap({'completedByDay': {}});

      final untimed = provider.completedByDay.values
          .whereType<Map>()
          .expand((d) => (d['checkpointsCompleted'] as List? ?? []).whereType<Map>())
          .where((c) => c['subSubTaskId'] == 'cp_untimed');
      expect(untimed, isEmpty,
          reason: 'Without a known completion date the checkpoint must not be placed on today');
    });
  });
}
