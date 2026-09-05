import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/providers/app_provider.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('day plan duplicate handling', () {
    test('removeFromDayPlan consumes one occurrence and keeps checkpoints', () {
      final provider = AppProvider.forTest();
      const date = '2026-07-11';
      provider.taskActions.updateDayPlan(date, [
        'task1|subA',
        'task1|subA|cp1',
        'task1|subA',
        'task2|subB',
      ]);

      provider.taskActions.removeFromDayPlan('task1|subA', date);

      expect(
        provider.taskActions.getDayPlan(date),
        ['task1|subA|cp1', 'task1|subA', 'task2|subB'],
      );
    });

    test('removeFromDayPlan is a no-op when the id is not planned', () {
      final provider = AppProvider.forTest();
      const date = '2026-07-11';
      provider.taskActions.updateDayPlan(date, ['task1|subA']);

      provider.taskActions.removeFromDayPlan('taskX|subY', date);

      expect(provider.taskActions.getDayPlan(date), ['task1|subA']);
    });
  });
}
