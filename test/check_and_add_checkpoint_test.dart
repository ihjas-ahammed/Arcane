import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/task_models.dart';
import './mock.dart';

/// Floating task button double-tap: tick the current checkpoint, add the next one on its level.
void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  SubTask sub(AppProvider p) => p.mainTasks.single.subTasks.single;

  AppProvider withCheckpoints(List<SubSubTask> checkpoints) {
    final provider = AppProvider.forTest();
    provider.setProviderState(mainTasks: [
      MainTask(
        id: 'm',
        name: 'Reading',
        description: '',
        theme: '',
        subTasks: [SubTask(id: 's', name: 'Book', subSubTasks: checkpoints)],
      ),
    ]);
    return provider;
  }

  test('top level: ticks current, inserts the new one right after it', () {
    final p = withCheckpoints([
      SubSubTask(id: 'c1', name: 'Chapter 1', completed: true),
      SubSubTask(id: 'c2', name: 'Chapter 2'),
      SubSubTask(id: 'c9', name: 'Epilogue'),
    ]);

    final checked = p.taskActions.checkCurrentAndAddNext('m', 's', '  Chapter 3 ');

    expect(checked, 'Chapter 2');
    final cps = sub(p).subSubTasks;
    expect(cps.map((c) => c.name), ['Chapter 1', 'Chapter 2', 'Chapter 3', 'Epilogue']);
    expect(cps[1].completed, true);
    expect(cps[2].completed, false);
    expect(cps[3].completed, false);
  });

  test('nested: adds on the current checkpoint\'s own level', () {
    final p = withCheckpoints([
      SubSubTask(id: 'part1', name: 'Part 1', substeps: [
        SubSubTask(id: 'p1c1', name: 'Page 10', completed: true),
        SubSubTask(id: 'p1c2', name: 'Page 20'),
      ]),
      SubSubTask(id: 'part2', name: 'Part 2'),
    ]);

    final checked = p.taskActions.checkCurrentAndAddNext('m', 's', 'Page 30');

    expect(checked, 'Page 20');
    final top = sub(p).subSubTasks;
    expect(top.map((c) => c.name), ['Part 1', 'Part 2']);
    final pages = top.first.substeps;
    expect(pages.map((c) => c.name), ['Page 10', 'Page 20', 'Page 30']);
    expect(pages[1].completed, true);
    expect(pages[2].completed, false);
    expect(top.first.completed, false);
  });

  test('empty name only ticks', () {
    final p = withCheckpoints([SubSubTask(id: 'c1', name: 'Chapter 1')]);

    expect(p.taskActions.checkCurrentAndAddNext('m', 's', '  '), 'Chapter 1');
    expect(sub(p).subSubTasks.length, 1);
    expect(sub(p).subSubTasks.single.completed, true);
  });

  test('no open checkpoint: adds at the top level', () {
    final p = withCheckpoints([SubSubTask(id: 'c1', name: 'Chapter 1', completed: true)]);

    expect(p.taskActions.checkCurrentAndAddNext('m', 's', 'Chapter 2'), isNull);
    expect(sub(p).subSubTasks.map((c) => c.name), ['Chapter 1', 'Chapter 2']);
    expect(sub(p).subSubTasks.last.completed, false);
  });
}
