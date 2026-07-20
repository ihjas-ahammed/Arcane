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

  group('Unchecking tasks and subtasks', () {
    test('unchecking a SubTask unchecks all its subSubTasks and nested substeps', () {
      final provider = AppProvider.forTest();

      // Create main task with subtask and nested subSubTasks
      final nestedSubstep = SubSubTask(id: 'ss1', name: 'Nested step', completed: true);
      final checkpoint = SubSubTask(id: 'cp1', name: 'Checkpoint 1', completed: true, substeps: [nestedSubstep]);
      final subTask = SubTask(id: 'sub1', name: 'Subtask 1', completed: true, subSubTasks: [checkpoint]);
      final mainTask = MainTask(id: 'main1', name: 'Main 1', description: '', theme: '', subTasks: [subTask]);

      provider.setProviderState(mainTasks: [mainTask]);

      // Uncomplete the subtask
      provider.taskActions.uncompleteSubtask('main1', 'sub1');

      final updatedMain = provider.mainTasks.firstWhere((t) => t.id == 'main1');
      final updatedSub = updatedMain.subTasks.firstWhere((s) => s.id == 'sub1');

      expect(updatedSub.completed, false);
      expect(updatedSub.subSubTasks.first.completed, false);
      expect(updatedSub.subSubTasks.first.substeps.first.completed, false);
    });

    test('unchecking a nested SubSubTask unchecks all its descendant substeps', () {
      final provider = AppProvider.forTest();

      final grandChild = SubSubTask(id: 'gc1', name: 'Grand Child', completed: true);
      final child = SubSubTask(id: 'c1', name: 'Child Step', completed: true, substeps: [grandChild]);
      final parentCp = SubSubTask(id: 'p1', name: 'Parent CP', completed: true, substeps: [child]);
      final subTask = SubTask(id: 'sub1', name: 'Subtask 1', completed: false, subSubTasks: [parentCp]);
      final mainTask = MainTask(id: 'main1', name: 'Main 1', description: '', theme: '', subTasks: [subTask]);

      provider.setProviderState(mainTasks: [mainTask]);

      // Uncomplete the parent checkpoint
      provider.taskActions.uncompleteSubSubtask('main1', 'sub1', 'p1');

      final updatedMain = provider.mainTasks.firstWhere((t) => t.id == 'main1');
      final updatedSub = updatedMain.subTasks.firstWhere((s) => s.id == 'sub1');
      final updatedParentCp = updatedSub.subSubTasks.firstWhere((s) => s.id == 'p1');

      expect(updatedParentCp.completed, false);
      expect(updatedParentCp.substeps.first.completed, false);
      expect(updatedParentCp.substeps.first.substeps.first.completed, false);
    });
  });
}
