import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/widgets/screens/submission_sessions_screen.dart';

/// Regression: the SESSION ARCHIVES screen read keys the edit dialog never returns, so DELETE (and
/// SAVE) threw inside the async handler and did nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AppProvider, MainTask, SubTask)> pumpScreen(WidgetTester tester) async {
    final provider = AppProvider.forTest();
    final start = DateTime(2026, 9, 10, 9, 0);
    final sub = SubTask(
      id: 's1',
      name: 'Read',
      sessions: [
        TaskSession(id: 'a', startTime: start, endTime: start.add(const Duration(minutes: 30))),
        TaskSession(
            id: 'b',
            startTime: start.add(const Duration(hours: 2)),
            endTime: start.add(const Duration(hours: 2, minutes: 45))),
      ],
    );
    final task = MainTask(id: 'm1', name: 'Study', description: '', theme: 'tech', colorHex: '00E5FF', subTasks: [sub]);
    provider.setMainTasks([task]);

    await tester.binding.setSurfaceSize(const Size(900, 1800));
    await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
      value: provider,
      child: MaterialApp(home: SubmissionSessionsScreen(parentTask: task, subTask: sub)),
    ));
    await tester.pump();
    return (provider, task, sub);
  }

  testWidgets('DELETE in the edit dialog removes the session', (tester) async {
    final (provider, _, _) = await pumpScreen(tester);
    expect(provider.mainTasks.first.subTasks.first.sessions.length, 2);

    await tester.tap(find.text('EDIT').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();

    expect(provider.mainTasks.first.subTasks.first.sessions.length, 1);
    await tester.pump(const Duration(seconds: 2)); // let the debounced save timer fire
  });

  testWidgets('CANCEL leaves the sessions untouched', (tester) async {
    final (provider, _, _) = await pumpScreen(tester);
    await tester.tap(find.text('EDIT').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(provider.mainTasks.first.subTasks.first.sessions.length, 2);
    await tester.pump(const Duration(seconds: 2));
  });
}
