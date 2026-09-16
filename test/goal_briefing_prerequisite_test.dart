import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/goal_briefing_helper.dart';
import 'package:missions/src/widgets/drawers/goals/create_goal_sheet.dart';
import 'package:provider/provider.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('GoalBriefingHelper Prerequisites', () {
    test('hasTomorrowGoals correctly detects tomorrow daily goals', () {
      final provider = AppProvider.forTest();
      final today = DateTime(2026, 9, 16);
      final tomorrow = DateTime(2026, 9, 17);

      expect(GoalBriefingHelper.hasTomorrowGoals(provider, today), isFalse);

      // Add a daily goal for today (should not satisfy tomorrow)
      final todayGoal = GoalModel(
        id: 'goal_today',
        title: 'Today Goal',
        scope: GoalScope.daily,
        startDateTime: today,
        dateKey: DateFormat('yyyy-MM-dd').format(today),
      );
      provider.addGoal(todayGoal);
      expect(GoalBriefingHelper.hasTomorrowGoals(provider, today), isFalse);

      // Add a daily goal for tomorrow
      final tomorrowGoal = GoalModel(
        id: 'goal_tomorrow',
        title: 'Tomorrow Goal',
        scope: GoalScope.daily,
        startDateTime: tomorrow,
        dateKey: DateFormat('yyyy-MM-dd').format(tomorrow),
      );
      provider.addGoal(tomorrowGoal);
      expect(GoalBriefingHelper.hasTomorrowGoals(provider, today), isTrue);
      expect(GoalBriefingHelper.getTomorrowGoals(provider, today).length, equals(1));
    });

    test('hasNextWeekGoals requires at least two weekly goals for next week', () {
      final provider = AppProvider.forTest();
      final today = DateTime(2026, 9, 16); // Wednesday
      final nextWeekMonday = GoalBriefingHelper.getNextWeekMonday(today);
      final nextWeekKey = DateFormat('yyyy-MM-dd').format(nextWeekMonday);

      // Initially 0 next week goals
      expect(GoalBriefingHelper.hasNextWeekGoals(provider, today), isFalse);
      expect(GoalBriefingHelper.getNextWeekGoals(provider, today).length, equals(0));

      // Add 1 weekly goal for next week
      final goal1 = GoalModel(
        id: 'next_week_goal_1',
        title: 'Next Week Goal 1',
        scope: GoalScope.weekly,
        startDateTime: nextWeekMonday,
        dateKey: nextWeekKey,
      );
      provider.addGoal(goal1);
      expect(GoalBriefingHelper.hasNextWeekGoals(provider, today), isFalse);
      expect(GoalBriefingHelper.getNextWeekGoals(provider, today).length, equals(1));

      // Add 2nd weekly goal for next week
      final goal2 = GoalModel(
        id: 'next_week_goal_2',
        title: 'Next Week Goal 2',
        scope: GoalScope.weekly,
        startDateTime: nextWeekMonday,
        dateKey: nextWeekKey,
      );
      provider.addGoal(goal2);
      expect(GoalBriefingHelper.hasNextWeekGoals(provider, today), isTrue);
      expect(GoalBriefingHelper.getNextWeekGoals(provider, today).length, equals(2));
    });

    testWidgets('showWeeklyGoalsCheckDialog proceeds immediately when >= 2 goals exist', (tester) async {
      final provider = AppProvider.forTest();
      final today = DateTime(2026, 9, 16);
      final nextWeekMonday = GoalBriefingHelper.getNextWeekMonday(today);
      final nextWeekKey = DateFormat('yyyy-MM-dd').format(nextWeekMonday);

      provider.addGoal(GoalModel(
        id: 'g1',
        title: 'Weekly 1',
        scope: GoalScope.weekly,
        dateKey: nextWeekKey,
      ));
      provider.addGoal(GoalModel(
        id: 'g2',
        title: 'Weekly 2',
        scope: GoalScope.weekly,
        dateKey: nextWeekKey,
      ));

      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () async {
              result = await GoalBriefingHelper.showWeeklyGoalsCheckDialog(ctx, provider, today);
            },
            child: const Text('CHECK'),
          );
        }),
      ));

      await tester.tap(find.text('CHECK'));
      await tester.pumpAndSettle();

      // No dialog should be shown and result should be true
      expect(find.text('WEEKLY BRIEFING: NEXT WEEK GOALS'), findsNothing);
      expect(result, isTrue);
    });

    testWidgets('showWeeklyGoalsCheckDialog shows alert and allows Proceed Anyway when < 2 goals', (tester) async {
      final provider = AppProvider.forTest();
      final today = DateTime(2026, 9, 16);

      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () async {
              result = await GoalBriefingHelper.showWeeklyGoalsCheckDialog(ctx, provider, today);
            },
            child: const Text('CHECK'),
          );
        }),
      ));

      await tester.tap(find.text('CHECK'));
      await tester.pumpAndSettle();

      // Dialog should be visible with count 0 OF 2 SET
      expect(find.text('WEEKLY BRIEFING: NEXT WEEK GOALS'), findsOneWidget);
      expect(find.text('NEXT WEEK GOALS: 0 OF 2 SET'), findsOneWidget);
      expect(find.text('PROCEED ANYWAY'), findsOneWidget);
      expect(find.text('ADD GOALS FIRST'), findsOneWidget);

      // Tap PROCEED ANYWAY
      await tester.tap(find.text('PROCEED ANYWAY'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('showWeeklyGoalsCheckDialog tapping ADD NEXT WEEK GOAL opens CreateGoalSheet', (tester) async {
      final provider = AppProvider.forTest();
      final today = DateTime(2026, 9, 16);

      bool? result;
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Builder(builder: (ctx) {
              return ElevatedButton(
                onPressed: () async {
                  result = await GoalBriefingHelper.showWeeklyGoalsCheckDialog(ctx, provider, today);
                },
                child: const Text('CHECK'),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text('CHECK'));
      await tester.pumpAndSettle();

      expect(find.text('ADD NEXT WEEK GOAL'), findsOneWidget);
      await tester.tap(find.text('ADD NEXT WEEK GOAL'));
      await tester.pumpAndSettle();

      // CreateGoalSheet should now be displayed
      expect(find.byType(CreateGoalSheet), findsOneWidget);

      // Close the sheet
      Navigator.of(tester.element(find.byType(CreateGoalSheet))).pop();
      await tester.pumpAndSettle();

      // Result should now be false (goals check aborted to add goals)
      expect(result, isFalse);
    });

    test('buildTacticalBriefingGoalsAIContext includes tomorrow planned goals', () {
      final provider = AppProvider.forTest();
      final today = DateTime(2026, 9, 16);
      final tomorrow = DateTime(2026, 9, 17);

      final emptyContext = GoalBriefingHelper.buildTacticalBriefingGoalsAIContext(provider, today);
      expect(emptyContext, contains("TOMORROW'S PLANNED DAILY GOALS:"));
      expect(emptyContext, contains("No daily goals scheduled for tomorrow yet."));

      provider.addGoal(GoalModel(
        id: 'tomorrow_g',
        title: 'Launch Space Mission',
        scope: GoalScope.daily,
        startDateTime: tomorrow,
        targetValue: 5,
      ));

      final populatedContext = GoalBriefingHelper.buildTacticalBriefingGoalsAIContext(provider, today);
      expect(populatedContext, contains("Launch Space Mission (Target: 5.0)"));
    });
  });
}
