import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/widgets/drawers/goals/goals_copy_action.dart';
import 'package:missions/src/widgets/drawers/goals_bottom_drawer.dart';
import 'package:provider/provider.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('copying from the open goals drawer copies JSON and shows a toast', (tester) async {
    tester.view.physicalSize = const Size(720, 1520);
    tester.view.devicePixelRatio = 271 / 160;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final provider = AppProvider.forTest();
    provider.setGoals([
      GoalModel(id: 'toast_goal', title: 'Toast check', scope: GoalScope.daily),
    ]);

    await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
      value: provider,
      child: MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => GoalsBottomDrawer.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await copyGoalsForPeriod(provider, GoalScope.daily, DateTime.now());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(copied, isNotNull);
    final decoded = jsonDecode(copied!) as Map<String, dynamic>;
    expect(decoded['scope'], 'daily');
    expect(decoded['count'], 1);

    expect(find.textContaining('Copied 1 daily goal'), findsOneWidget,
        reason: 'The toast must be visible while the goals drawer is open');
  });
}
