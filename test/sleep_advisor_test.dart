import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/models/health_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/sleep_advisor_helper.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('SleepAdvisorHelper', () {
    test('provides baseline scientific recommendations when no history is present', () {
      final provider = AppProvider.forTest();
      final today = DateTime(2026, 9, 4);

      final advisor = SleepAdvisorHelper.calculate(provider, today);

      expect(advisor.fromHistory, isFalse);
      expect(advisor.napDurationMinutes, 20);
      expect(advisor.napWindowStart.hour, 14); // 7:00 AM + 7h 15m = 14:15
      expect(advisor.napWindowStart.minute, 15);
      expect(advisor.napWindowEnd.hour, 14);
      expect(advisor.napWindowEnd.minute, 45);
      expect(advisor.targetSleepCycles, 5);
      expect(advisor.nextWakeTime.hour, 7);
    });

    test('adapts power nap and bedtime based on 7-day sleep telemetry', () {
      final provider = AppProvider.forTest();
      final today = DateTime(2026, 9, 4);

      // Populate 5 days of sleep logs: Wake 06:30 AM, Bed 22:30 PM
      for (int i = 1; i <= 5; i++) {
        final day = today.subtract(Duration(days: i));
        final dateKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final bed = DateTime(day.year, day.month, day.day - 1, 22, 30);
        final wake = DateTime(day.year, day.month, day.day, 6, 30);

        provider.addSleepLog(
          dateKey,
          SleepLog(id: 'sleep_$i', startTime: bed, endTime: wake),
        );
      }

      final advisor = SleepAdvisorHelper.calculate(provider, today);

      expect(advisor.fromHistory, isTrue);
      // Wake is 6:30 AM. 6:30 + 7h 15m = 13:45 (1:45 PM)
      expect(advisor.napWindowStart.hour, 13);
      expect(advisor.napWindowStart.minute, 45);
      expect(advisor.napWindowEnd.hour, 14);
      expect(advisor.napWindowEnd.minute, 15);
      expect(advisor.habitualWakeMinute, 6 * 60 + 30);
      expect(advisor.habitualBedMinute, 22 * 60 + 30);
      expect(advisor.recordedDaysCount, 5);

      // Bedtime for 6:30 AM wake should be ~10:45 PM tonight (22:45), NEVER afternoon!
      expect(advisor.nextBedtime.hour, isIn([22, 23]));
      expect(advisor.nextBedtime.day, today.day); // Must be tonight
    });

    test('circular midnight calculation handles bedtimes across midnight properly', () {
      final provider = AppProvider.forTest();
      final today = DateTime(2026, 9, 4);

      // User alternates between 23:30 (11:30 PM) and 00:30 (12:30 AM) bedtimes, wakes at 07:00 AM
      final dateKey1 = '2026-09-03';
      provider.addSleepLog(dateKey1, SleepLog(
        id: 's1',
        startTime: DateTime(2026, 9, 2, 23, 30),
        endTime: DateTime(2026, 9, 3, 7, 0),
      ));

      final dateKey2 = '2026-09-02';
      provider.addSleepLog(dateKey2, SleepLog(
        id: 's2',
        startTime: DateTime(2026, 9, 2, 0, 30),
        endTime: DateTime(2026, 9, 2, 7, 0),
      ));

      final advisor = SleepAdvisorHelper.calculate(provider, today);

      // Habitual bedtime should be around midnight (23:30 to 00:30), NEVER midday/afternoon!
      expect(advisor.habitualBedMinute >= 1380 || advisor.habitualBedMinute <= 60, isTrue);
      // Next bedtime for 7:00 AM wake should be around 23:15 (11:15 PM)
      expect(advisor.nextBedtime.hour >= 22 || advisor.nextBedtime.hour <= 1, isTrue);
      expect(advisor.nextBedtime.hour, isNot(16)); // Specifically NOT 4 PM
    });

    test('afternoon naps do not pollute night sleep wake or bedtime medians', () {
      final provider = AppProvider.forTest();
      final today = DateTime(2026, 9, 4);

      // Normal night sleep: 23:00 to 06:30
      provider.addSleepLog('2026-09-03', SleepLog(
        id: 'night_sleep',
        startTime: DateTime(2026, 9, 2, 23, 0),
        endTime: DateTime(2026, 9, 3, 6, 30),
      ));

      // Afternoon nap on weekend: 14:00 to 16:00 (120 mins)
      provider.addSleepLog('2026-09-03', SleepLog(
        id: 'afternoon_nap',
        startTime: DateTime(2026, 9, 3, 14, 0),
        endTime: DateTime(2026, 9, 3, 16, 0),
      ));

      final advisor = SleepAdvisorHelper.calculate(provider, today);

      // Habitual wake must still be 6:30 AM, NOT 4:00 PM!
      expect(advisor.habitualWakeMinute, 6 * 60 + 30);
      expect(advisor.napWindowStart.hour, 13);
      expect(advisor.napWindowStart.minute, 45);
    });

    test('enforces afternoon cutoff cap before 16:00 to protect evening sleep pressure', () {
      final provider = AppProvider.forTest();
      final today = DateTime(2026, 9, 4);

      // Late riser: Wakes at 10:30 AM
      const dateKey = '2026-09-03';
      provider.addSleepLog(
        dateKey,
        SleepLog(
          id: 'late_wake',
          startTime: DateTime(2026, 9, 2, 2, 0),
          endTime: DateTime(2026, 9, 3, 10, 30),
        ),
      );

      final advisor = SleepAdvisorHelper.calculate(provider, today);

      // 10:30 + 7h 15m would be 17:45, but must be capped at 16:00
      expect(advisor.napWindowStart.hour, 16);
      expect(advisor.napWindowStart.minute, 0);
    });
  });
}
