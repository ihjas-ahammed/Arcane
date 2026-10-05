import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/task_models.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Daily rollover and permanent task retention tests', () {
    test('non-recurring task checkpoints and status are retained across daily rollover', () async {
      final provider = AppProvider.forTest();

      final permanentSub = SubTask(
        id: 'perm_sub',
        name: 'Permanent Objective',
        isRecurring: false,
        completed: true,
        completedDate: '2026-10-04',
        subSubTasks: [
          SubSubTask(id: 'cp1', name: 'Step 1', completed: true),
          SubSubTask(id: 'cp2', name: 'Step 2', completed: false),
        ],
      );

      final recurringSub = SubTask(
        id: 'rec_sub',
        name: 'Daily Workout',
        isRecurring: true,
        completed: true,
        completedDate: '2026-10-04',
        subSubTasks: [
          SubSubTask(id: 'rcp1', name: 'Warmup', completed: true),
        ],
      );

      final mainTask = MainTask(
        id: 'main1',
        name: 'Project Alpha',
        description: '',
        theme: '',
        dailyTimeSpent: 120,
        subTasks: [permanentSub, recurringSub],
      );

      provider.setProviderState(mainTasks: [mainTask], lastLoginDate: '2026-10-04');

      // Trigger daily reset
      await provider.handleDailyResetForTesting();

      final updatedMain = provider.mainTasks.firstWhere((t) => t.id == 'main1');
      expect(updatedMain.dailyTimeSpent, 0, reason: 'Daily time spent should reset on new day');

      final updatedPerm = updatedMain.subTasks.firstWhere((s) => s.id == 'perm_sub');
      expect(updatedPerm.completed, true, reason: 'Permanent subtask must remain completed');
      expect(updatedPerm.subSubTasks[0].completed, true, reason: 'Permanent checkpoint 1 must remain completed');
      expect(updatedPerm.subSubTasks[1].completed, false);

      final updatedRec = updatedMain.subTasks.firstWhere((s) => s.id == 'rec_sub');
      expect(updatedRec.completed, false, reason: 'Recurring subtask must reset completed status on new day');
      expect(updatedRec.subSubTasks[0].completed, false, reason: 'Recurring checkpoint must reset on new day');
    });

    test('cross-sync restores completed checkpoints from completedByDay history', () {
      final provider = AppProvider.forTest();

      final permanentSub = SubTask(
        id: 'perm_sub',
        name: 'Long Term Task',
        isRecurring: false,
        completed: false, // temporarily unchecked in task list
        subSubTasks: [
          SubSubTask(id: 'cp1', name: 'Read chapter 1', completed: false),
          SubSubTask(id: 'cp2', name: 'Read chapter 2', completed: false),
        ],
      );

      final mainTask = MainTask(
        id: 'main1',
        name: 'Study',
        description: '',
        theme: '',
        subTasks: [permanentSub],
      );

      provider.setProviderState(mainTasks: [mainTask]);

      // Feed completed history for yesterday
      final historyData = {
        '2026-10-04': {
          'checkpointsCompleted': [
            {
              'name': 'Read chapter 1',
              'parentTaskId': 'main1',
              'subtaskId': 'perm_sub',
            }
          ]
        }
      };

      provider.mergeAppStateFromMap({'completedByDay': historyData});

      final updatedSub = provider.mainTasks.first.subTasks.first;
      expect(updatedSub.subSubTasks[0].completed, true,
          reason: 'Checkpoint found in history must be restored as completed');
      expect(updatedSub.subSubTasks[1].completed, false);
    });

    test('updateSubtask properly updates task without reference mutation and persists changes', () {
      final provider = AppProvider.forTest();

      final sub = SubTask(
        id: 'sub1',
        name: 'Original Name',
        description: 'Original Desc',
        subSubTasks: [
          SubSubTask(id: 'cp1', name: 'Checkpoint 1', completed: false),
        ],
      );

      final mainTask = MainTask(
        id: 'm1',
        name: 'Main Task',
        description: '',
        theme: '',
        subTasks: [sub],
      );

      provider.setProviderState(mainTasks: [mainTask]);

      provider.taskActions.updateSubtask('m1', 'sub1', {
        'name': 'Updated Name',
        'description': 'Updated Desc',
        'subSubTasks': [
          SubSubTask(id: 'cp1', name: 'Checkpoint 1', completed: true),
          SubSubTask(id: 'cp2', name: 'Checkpoint 2', completed: false),
        ],
      });

      final updatedSub = provider.mainTasks.first.subTasks.first;
      expect(updatedSub.name, 'Updated Name');
      expect(updatedSub.description, 'Updated Desc');
      expect(updatedSub.subSubTasks.length, 2);
      expect(updatedSub.subSubTasks[0].completed, true);
      expect(updatedSub.subSubTasks[1].name, 'Checkpoint 2');
    });
  });
}
