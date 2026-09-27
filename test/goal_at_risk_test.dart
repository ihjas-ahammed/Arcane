import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/goal_briefing_helper.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('GoalBriefingHelper at-risk detection', () {
    // Wednesday, Sep 16 2026. Monday of that week is Sep 14 2026.
    final wednesday = DateTime(2026, 9, 16);

    test('daily goals are never flagged at risk', () {
      final goal = GoalModel(
        id: 'daily_1',
        title: 'Daily Goal',
        scope: GoalScope.daily,
        metricType: GoalMetricType.counter,
        currentValue: 0,
        targetValue: 5,
        dateKey: '2026-09-16',
      );
      expect(GoalBriefingHelper.isGoalAtRisk(goal, wednesday), isFalse);
    });

    test('completed weekly goal is never flagged at risk', () {
      final goal = GoalModel(
        id: 'weekly_done',
        title: 'Weekly Goal',
        scope: GoalScope.weekly,
        metricType: GoalMetricType.counter,
        currentValue: 10,
        targetValue: 10,
        isCompleted: true,
        dateKey: '2026-09-14',
      );
      expect(GoalBriefingHelper.isGoalAtRisk(goal, wednesday), isFalse);
    });

    test('weekly goal far behind expected pace is flagged at risk', () {
      final goal = GoalModel(
        id: 'weekly_behind',
        title: 'Weekly Goal Behind',
        scope: GoalScope.weekly,
        metricType: GoalMetricType.counter,
        currentValue: 0,
        targetValue: 10,
        dateKey: '2026-09-14', // Monday of the week containing wednesday
      );
      // By Wednesday (day 3 of 7), expected pace is ~43%; 0% actual is well behind.
      expect(GoalBriefingHelper.isGoalAtRisk(goal, wednesday), isTrue);
    });

    test('weekly goal on/ahead of expected pace is not flagged at risk', () {
      final goal = GoalModel(
        id: 'weekly_on_pace',
        title: 'Weekly Goal On Pace',
        scope: GoalScope.weekly,
        metricType: GoalMetricType.counter,
        currentValue: 5,
        targetValue: 10,
        dateKey: '2026-09-14',
      );
      expect(GoalBriefingHelper.isGoalAtRisk(goal, wednesday), isFalse);
    });

    test('monthly goal far behind expected pace is flagged at risk', () {
      final goal = GoalModel(
        id: 'monthly_behind',
        title: 'Monthly Goal Behind',
        scope: GoalScope.monthly,
        metricType: GoalMetricType.counter,
        currentValue: 0,
        targetValue: 30,
        dateKey: '2026-09',
      );
      // By the 16th of a 30-day month, expected pace is >50%; 0% actual is behind.
      expect(GoalBriefingHelper.isGoalAtRisk(goal, wednesday), isTrue);
    });

    test('getGoalDaysRemaining computes days left in the period', () {
      final weeklyGoal = GoalModel(
        id: 'weekly_days_left',
        title: 'Weekly Goal',
        scope: GoalScope.weekly,
        dateKey: '2026-09-14',
      );
      // Monday(14) + 7 days = next Monday(21); 21 - 16 = 5 days remaining.
      expect(GoalBriefingHelper.getGoalDaysRemaining(weeklyGoal, wednesday), 5);
    });

    test('getGoalsAtRisk returns only at-risk weekly & monthly goals for the date', () {
      final provider = AppProvider.forTest();

      provider.addGoal(GoalModel(
        id: 'w_behind',
        title: 'Behind Weekly',
        scope: GoalScope.weekly,
        metricType: GoalMetricType.counter,
        currentValue: 0,
        targetValue: 10,
        dateKey: '2026-09-14',
      ));
      provider.addGoal(GoalModel(
        id: 'w_on_pace',
        title: 'On Pace Weekly',
        scope: GoalScope.weekly,
        metricType: GoalMetricType.counter,
        currentValue: 6,
        targetValue: 10,
        dateKey: '2026-09-14',
      ));
      provider.addGoal(GoalModel(
        id: 'd_ignored',
        title: 'Daily Goal Ignored',
        scope: GoalScope.daily,
        dateKey: '2026-09-16',
      ));

      final atRisk = GoalBriefingHelper.getGoalsAtRisk(provider, wednesday);
      expect(atRisk.length, 1);
      expect(atRisk.first.id, 'w_behind');
    });
  });
}
