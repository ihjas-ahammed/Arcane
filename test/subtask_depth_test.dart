import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/utils/task_calculations.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('SubTask Depth Properties and Calculation Tests', () {
    test('default depth is null, isMaxDepth is true, depthLabel is MAX', () {
      final subTask = SubTask(id: 'sub1', name: 'Test SubTask');
      expect(subTask.depth, isNull);
      expect(subTask.isMaxDepth, isTrue);
      expect(subTask.depthLabel, 'MAX');
    });

    test('maxCheckpointDepth correctly identifies hierarchy depth', () {
      final emptySubTask = SubTask(id: 'sub0', name: 'No Checkpoints');
      expect(emptySubTask.maxCheckpointDepth, 0);

      final flatSubTask = SubTask(
        id: 'sub1',
        name: 'Flat Checkpoints',
        subSubTasks: [
          SubSubTask(id: 'cp1', name: 'Level 1 A'),
          SubSubTask(id: 'cp2', name: 'Level 1 B'),
        ],
      );
      expect(flatSubTask.maxCheckpointDepth, 1);

      final nested2SubTask = SubTask(
        id: 'sub2',
        name: '2 Levels',
        subSubTasks: [
          SubSubTask(
            id: 'cp1',
            name: 'Level 1',
            substeps: [SubSubTask(id: 'ss1', name: 'Level 2')],
          ),
        ],
      );
      expect(nested2SubTask.maxCheckpointDepth, 2);

      final nested3SubTask = SubTask(
        id: 'sub3',
        name: '3 Levels',
        subSubTasks: [
          SubSubTask(
            id: 'cp1',
            name: 'Level 1',
            substeps: [
              SubSubTask(
                id: 'ss1',
                name: 'Level 2',
                substeps: [SubSubTask(id: 'sss1', name: 'Level 3')],
              ),
            ],
          ),
        ],
      );
      expect(nested3SubTask.maxCheckpointDepth, 3);
    });

    test('getCheckpointsAtDepth returns expected level checkpoints', () {
      final subTask = SubTask(
        id: 'sub1',
        name: 'Multi-level Task',
        subSubTasks: [
          SubSubTask(
            id: 'cp1',
            name: 'Root 1',
            substeps: [
              SubSubTask(
                id: 'cp1_1',
                name: 'Child 1.1',
                substeps: [
                  SubSubTask(id: 'cp1_1_1', name: 'Leaf 1.1.1'),
                  SubSubTask(id: 'cp1_1_2', name: 'Leaf 1.1.2'),
                ],
              ),
              SubSubTask(id: 'cp1_2', name: 'Child 1.2'),
            ],
          ),
          SubSubTask(id: 'cp2', name: 'Root 2'),
        ],
      );

      // Depth 1 -> only root checkpoints
      final depth1 = subTask.getCheckpointsAtDepth(targetDepth: 1);
      expect(depth1.map((c) => c.id).toList(), ['cp1', 'cp2']);

      // Depth 2 -> children of cp1 and cp2
      final depth2 = subTask.getCheckpointsAtDepth(targetDepth: 2);
      expect(depth2.map((c) => c.id).toList(), ['cp1_1', 'cp1_2', 'cp2']);

      // Depth null (MAX) -> lowest leaves
      final depthMax = subTask.getCheckpointsAtDepth(targetDepth: null);
      expect(depthMax.map((c) => c.id).toList(), ['cp1_1_1', 'cp1_1_2', 'cp1_2', 'cp2']);
    });

    test('TaskCalculations.nextCheckpoint respects subTask.depth', () {
      final subTask = SubTask(
        id: 'sub1',
        name: 'Hierarchy Task',
        subSubTasks: [
          SubSubTask(
            id: 'cp1',
            name: 'Parent 1',
            substeps: [
              SubSubTask(
                id: 'child1',
                name: 'Child 1',
                substeps: [
                  SubSubTask(id: 'leaf1', name: 'Leaf 1'),
                ],
              ),
            ],
          ),
          SubSubTask(id: 'cp2', name: 'Parent 2'),
        ],
      );

      // Default (max) returns lowest leaf
      expect(TaskCalculations.nextCheckpoint(subTask)?.id, 'leaf1');

      // With depth = 1 -> returns Parent 1
      subTask.depth = 1;
      expect(TaskCalculations.nextCheckpoint(subTask)?.id, 'cp1');

      // With depth = 2 -> returns Child 1
      subTask.depth = 2;
      expect(TaskCalculations.nextCheckpoint(subTask)?.id, 'child1');

      // With depth = 3 -> returns Leaf 1
      subTask.depth = 3;
      expect(TaskCalculations.nextCheckpoint(subTask)?.id, 'leaf1');
    });

    test('completing checkpoint at depth 1 cascades completion to all descendants', () {
      final provider = AppProvider.forTest();

      final leaf = SubSubTask(id: 'leaf1', name: 'Leaf 1', completed: false);
      final child = SubSubTask(id: 'child1', name: 'Child 1', completed: false, substeps: [leaf]);
      final parent = SubSubTask(id: 'p1', name: 'Parent 1', completed: false, substeps: [child]);
      final sub = SubTask(id: 'sub1', name: 'Subtask 1', depth: 1, subSubTasks: [parent]);
      final main = MainTask(id: 'm1', name: 'Main 1', description: '', theme: '', subTasks: [sub]);

      provider.setProviderState(mainTasks: [main]);

      // At depth 1, nextCheckpoint returns Parent 1
      final next = TaskCalculations.nextCheckpoint(sub);
      expect(next?.id, 'p1');

      // Quick checking Parent 1 completes Parent 1 AND its descendants
      provider.taskActions.completeSubSubtask('m1', 'sub1', next!.id);

      final updatedMain = provider.mainTasks.firstWhere((t) => t.id == 'm1');
      final updatedSub = updatedMain.subTasks.firstWhere((s) => s.id == 'sub1');
      expect(updatedSub.subSubTasks.first.completed, isTrue);
      expect(updatedSub.subSubTasks.first.substeps.first.completed, isTrue);
      expect(updatedSub.subSubTasks.first.substeps.first.substeps.first.completed, isTrue);
    });

    test('JSON serialization round-trip preserves depth property', () {
      final subTask = SubTask(
        id: 'sub_json',
        name: 'JSON Depth Test',
        depth: 2,
      );

      final json = subTask.toJson();
      expect(json['depth'], 2);

      final reconstructed = SubTask.fromJson(json);
      expect(reconstructed.depth, 2);
      expect(reconstructed.isMaxDepth, isFalse);
      expect(reconstructed.depthLabel, 'L2');

      final nullDepthSub = SubTask(id: 'sub_null', name: 'Null Depth');
      final nullJson = nullDepthSub.toJson();
      expect(nullJson['depth'], isNull);

      final reconstructedNull = SubTask.fromJson(nullJson);
      expect(reconstructedNull.depth, isNull);
      expect(reconstructedNull.isMaxDepth, isTrue);
      expect(reconstructedNull.depthLabel, 'MAX');
    });

    test('setSubtaskDepth action updates depth and notifies provider state', () {
      final provider = AppProvider.forTest();
      final sub = SubTask(id: 'sub1', name: 'Subtask 1');
      final main = MainTask(id: 'm1', name: 'Main 1', description: '', theme: '', subTasks: [sub]);
      provider.setProviderState(mainTasks: [main]);

      expect(provider.mainTasks.first.subTasks.first.depth, isNull);

      provider.taskActions.setSubtaskDepth('m1', 'sub1', 1);
      expect(provider.mainTasks.first.subTasks.first.depth, 1);

      provider.taskActions.setSubtaskDepth('m1', 'sub1', null);
      expect(provider.mainTasks.first.subTasks.first.depth, isNull);
    });
  });
}
