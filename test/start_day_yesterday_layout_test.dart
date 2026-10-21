import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/widgets/cards/start_day/start_day_yesterday_progress.dart';
import './mock.dart';

/// The yesterday-progress rows must lay out at the target screen (720x1520, 271 dpi)
/// with long task, objective and checkpoint names, without any overflow.
void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('yesterday progress rows fit at 720x1520 with long names', (tester) async {
    tester.view.physicalSize = const Size(720, 1520);
    tester.view.devicePixelRatio = 271 / 160;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = AppProvider.forTest();
    provider.setProviderState(
      mainTasks: [
        MainTask(
          id: 'purpose',
          name: 'Purpose',
          description: '',
          theme: '',
          colorHex: 'FFC0392B',
          subTasks: [
            SubTask(
              id: 'linear_sub',
              name: "Linear Algebra and It's Applications",
              subSubTasks: [],
            ),
          ],
        ),
      ],
      completedByDay: {
        '2026-10-20': {
          'subtasksCompleted': [
            {
              'name': 'Introduction to linear transformations and their matrix representations',
              'taskId': 'purpose',
              'subtaskId': 'linear_sub',
            },
          ],
          'checkpointsCompleted': [
            {
              'name': 'Applications of linear systems in population models and networks',
              'parentTaskId': 'purpose',
              'parentSubTaskId': 'linear_sub',
              'parentSubtaskName': "Linear Algebra and It's Applications",
            },
            {
              'name': 'Linear independence',
              'parentTaskId': 'purpose',
              'parentSubTaskId': 'linear_sub',
              'parentSubtaskName': "Linear Algebra and It's Applications",
            },
          ],
        },
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: StartDayYesterdayProgress(provider: provider, yesterdayStr: '2026-10-20'),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'Rows must not overflow at the target size');
    expect(find.textContaining('Applications of linear systems'), findsOneWidget);
  });
}
