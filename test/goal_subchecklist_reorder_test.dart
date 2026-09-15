import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/widgets/drawers/goals/tactical_goal_card.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Goal Subchecklist Reordering Logic', () {
    test('reorderGoalSubCheckItem moves items correctly', () {
      final provider = AppProvider.forTest();
      final goal = GoalModel(
        id: 'goal_test_1',
        title: 'Complete Project Milestone',
        scope: GoalScope.daily,
        metricType: GoalMetricType.check,
        subChecklist: [
          GoalSubCheckItem(id: 'sub_1', title: 'Step 1'),
          GoalSubCheckItem(id: 'sub_2', title: 'Step 2'),
          GoalSubCheckItem(id: 'sub_3', title: 'Step 3'),
        ],
      );

      // Add goal to provider
      provider.addGoal(goal);

      expect(provider.goals.first.subChecklist.map((s) => s.title).toList(), [
        'Step 1',
        'Step 2',
        'Step 3',
      ]);

      // Move Step 1 down to index 1
      provider.reorderGoalSubCheckItem('goal_test_1', 0, 1);
      expect(provider.goals.first.subChecklist.map((s) => s.title).toList(), [
        'Step 2',
        'Step 1',
        'Step 3',
      ]);

      // Move Step 3 up to index 0
      provider.reorderGoalSubCheckItem('goal_test_1', 2, 0);
      expect(provider.goals.first.subChecklist.map((s) => s.title).toList(), [
        'Step 3',
        'Step 2',
        'Step 1',
      ]);

      // Out-of-bounds guards
      provider.reorderGoalSubCheckItem('goal_test_1', -1, 1);
      provider.reorderGoalSubCheckItem('goal_test_1', 0, 99);
      expect(provider.goals.first.subChecklist.map((s) => s.title).toList(), [
        'Step 3',
        'Step 2',
        'Step 1',
      ]);
    });
  });

  group('TacticalGoalCard UI Rearrange Mode & Arrow Buttons', () {
    testWidgets('Double-tap enters reorder mode, shows arrow buttons, and rearranges', (tester) async {
      final provider = AppProvider.forTest();
      final goal = GoalModel(
        id: 'goal_ui_test',
        title: 'Deploy Production Build',
        scope: GoalScope.daily,
        metricType: GoalMetricType.check,
        subChecklist: [
          GoalSubCheckItem(id: 'sub_a', title: 'Alpha task'),
          GoalSubCheckItem(id: 'sub_b', title: 'Beta task'),
          GoalSubCheckItem(id: 'sub_c', title: 'Gamma task'),
        ],
      );
      provider.addGoal(goal);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Consumer<AppProvider>(
                  builder: (context, prov, _) {
                    return TacticalGoalCard(
                      goal: prov.goals.first,
                      timeMins: 0,
                      themeColor: Colors.cyan,
                      isLight: false,
                      isSubExpanded: true,
                      appProvider: prov,
                      onEdit: () {},
                      onToggleSubExpanded: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially, arrow buttons should NOT be visible
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
      expect(find.text('ARRANGE'), findsNothing);

      // Double-tap on the 'Alpha task' subchecklist item
      await tester.tap(find.text('Alpha task'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Alpha task'));
      await tester.pumpAndSettle();

      // Now reorder mode is active!
      expect(find.text('ARRANGE'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);

      // Arrow buttons are now visible (3 up arrows and 3 down arrows for the 3 items)
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNWidgets(3));

      // Tap down arrow on the first item (Alpha task)
      final downArrows = find.byIcon(Icons.keyboard_arrow_down_rounded);
      await tester.tap(downArrows.first);
      await tester.pumpAndSettle();

      // Verify provider has rearranged the list
      expect(provider.goals.first.subChecklist.map((s) => s.title).toList(), [
        'Beta task',
        'Alpha task',
        'Gamma task',
      ]);

      // Tap DONE to exit reorder mode
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      // Verify exited reorder mode
      expect(find.text('ARRANGE'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    });
  });
}
