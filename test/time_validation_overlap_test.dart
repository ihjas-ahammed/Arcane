import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/utils/time_validation_helper.dart';

void main() {
  group('TimeValidationHelper overlap tests', () {
    test('allows overlap when both proposed and existing sessions are less than 5 minutes', () {
      final now = DateTime(2026, 7, 25, 10, 0);
      final existingSession = TaskSession(
        id: 'sess_1',
        startTime: now,
        endTime: now.add(const Duration(minutes: 2)),
      );
      final mainTask = MainTask(
        id: 'task_1',
        name: 'Task 1',
        description: 'Test MainTask',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_1',
            name: 'Sub 1',
            sessions: [existingSession],
          )
        ],
      );

      final hasOverlap = TimeValidationHelper.hasOverlap(
        start: now.add(const Duration(minutes: 1)),
        end: now.add(const Duration(minutes: 3)),
        allTasks: [mainTask],
      );

      expect(hasOverlap, isFalse);
    });

    test('disallows overlap when at least one session is 5 minutes or longer', () {
      final now = DateTime(2026, 7, 25, 10, 0);
      final existingSession = TaskSession(
        id: 'sess_1',
        startTime: now,
        endTime: now.add(const Duration(minutes: 10)),
      );
      final mainTask = MainTask(
        id: 'task_1',
        name: 'Task 1',
        description: 'Test MainTask',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_1',
            name: 'Sub 1',
            sessions: [existingSession],
          )
        ],
      );

      final hasOverlap = TimeValidationHelper.hasOverlap(
        start: now.add(const Duration(minutes: 1)),
        end: now.add(const Duration(minutes: 3)),
        allTasks: [mainTask],
      );

      expect(hasOverlap, isTrue);
    });

    test('allows overlap for 1ms instantaneous sessions', () {
      final now = DateTime(2026, 7, 25, 10, 0);
      final existingSession = TaskSession(
        id: 'sess_1',
        startTime: now,
        endTime: now.add(const Duration(milliseconds: 1)),
      );
      final mainTask = MainTask(
        id: 'task_1',
        name: 'Task 1',
        description: 'Test MainTask',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_1',
            name: 'Sub 1',
            sessions: [existingSession],
          )
        ],
      );

      final hasOverlap = TimeValidationHelper.hasOverlap(
        start: now,
        end: now.add(const Duration(milliseconds: 1)),
        allTasks: [mainTask],
      );

      expect(hasOverlap, isFalse);
    });
  });
}
