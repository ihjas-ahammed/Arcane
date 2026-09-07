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

  group('day plan row entries and manual checkpoints', () {
    test('saveDayPlanRowEntries and getDayPlanRowEntries preserve manual checkpoints', () {
      final provider = AppProvider.forTest();
      const date = '2026-09-07';

      final rowEntries = [
        [
          {
            'id': 'task1|subA',
            'key': 'entry-1',
            'addedAtRuntime': true,
            'checkpoints': [
              {
                'id': 'cp-1',
                'name': 'Manual Step 1',
                'completed': false,
                'durationMinutes': 15,
              },
            ],
          },
        ],
        [
          {
            'id': 'task2|subB',
            'key': 'entry-2',
            'addedAtRuntime': true,
            'checkpoints': [],
          },
        ],
      ];

      provider.taskActions.saveDayPlanRowEntries(date, rowEntries);

      final loaded = provider.taskActions.getDayPlanRowEntries(date);
      expect(loaded.length, 2);
      expect((loaded[0][0]['checkpoints'] as List).length, 1);
      expect(loaded[0][0]['checkpoints'][0]['name'], 'Manual Step 1');
      expect((loaded[1][0]['checkpoints'] as List).isEmpty, true);

      expect(provider.taskActions.getDayPlanRows(date), [
        ['task1|subA'],
        ['task2|subB'],
      ]);
      expect(provider.taskActions.getDayPlan(date), [
        'task1|subA',
        'task2|subB',
      ]);
    });

    test('row merge simulation moves entry and collapses empty rows', () {
      final provider = AppProvider.forTest();
      const date = '2026-09-07';

      // Start with 2 rows, 1 entry each
      final rows = [
        [
          {'id': 'task1|subA', 'key': 'entry-1', 'checkpoints': []}
        ],
        [
          {'id': 'task2|subB', 'key': 'entry-2', 'checkpoints': []}
        ],
      ];

      // Merge entry-2 (row 1) to top row (row 0)
      final currentRow = rows[1];
      final targetRow = rows[0];
      final movingEntry = currentRow.removeAt(0);
      targetRow.add(movingEntry);
      if (currentRow.isEmpty) {
        rows.removeAt(1);
      }

      provider.taskActions.saveDayPlanRowEntries(date, rows);

      final loaded = provider.taskActions.getDayPlanRowEntries(date);
      expect(loaded.length, 1);
      expect(loaded[0].length, 2);
      expect(loaded[0][0]['id'], 'task1|subA');
      expect(loaded[0][1]['id'], 'task2|subB');
      expect(provider.taskActions.getDayPlanRows(date), [
        ['task1|subA', 'task2|subB'],
      ]);
    });
  });
}
