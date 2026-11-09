import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/providers/mixins/sync_mixin.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  group('No data loss on update', () {
    test('a manual time entry with no session survives recalibration', () async {
      final provider = AppProvider.forTest();
      final sub = SubTask(id: 'sub1', name: 'Reading', currentTimeSpent: 3600);
      provider.setProviderState(
        mainTasks: [MainTask(id: 'main1', name: 'Study', description: '', theme: '', subTasks: [sub])],
        completedByDay: {
          today: {'taskTimes': {'main1': 600}}
        },
      );

      await provider.recalibrateTimeLogs(silent: true);

      final kept = provider.mainTasks.first.subTasks.first;
      expect(kept.currentTimeSpent, 3600, reason: 'manual subtask total must not be lowered');
      final times = (provider.completedByDay[today]['taskTimes'] as Map);
      expect(times['main1'], 600, reason: 'manual day total must not be lowered');
    });

    test('progress history of a recurring sub-mission survives the daily reset', () async {
      final provider = AppProvider.forTest();
      final points = [
        ProgressDataPoint(timestamp: DateTime(2026, 11, 1), progress: 0.2, spentSeconds: 600),
        ProgressDataPoint(timestamp: DateTime(2026, 11, 2), progress: 0.5, spentSeconds: 1500),
      ];
      final sub = SubTask(id: 'rec1', name: 'Workout', isRecurring: true, progressDataPoints: points);
      provider.setProviderState(
        mainTasks: [MainTask(id: 'main1', name: 'Health', description: '', theme: '', subTasks: [sub])],
        lastLoginDate: '2026-11-01',
      );

      await provider.handleDailyResetForTesting();

      final after = provider.mainTasks.first.subTasks.first;
      expect(after.progressDataPoints.length, 2, reason: 'progress history must not be deleted');
    });

    test('replacing or merging all data is refused without confirmation', () async {
      SyncMixin.debugAllowFullLoads = false;
      addTearDown(() => SyncMixin.debugAllowFullLoads = true);
      final provider = AppProvider.forTest();

      expect(() => provider.mergeAppStateFromMap({'mainTasks': []}), throwsStateError);
      await expectLater(provider.replaceStateSafely({'mainTasks': []}), throwsStateError);
    });
  });
}
