import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/utils/time_validation_helper.dart';
import 'package:missions/src/widgets/schedule/schedule_timeline.dart';

void main() {
  group('TaskCalculations.recalculateAllTimeLogs time averaging tests', () {
    test('Non-overlapping sessions retain full time', () {
      final t1 = DateTime(2026, 9, 12, 10, 0);
      final t2 = DateTime(2026, 9, 12, 11, 0); // 1 hr = 3600s
      final t3 = DateTime(2026, 9, 12, 14, 0);
      final t4 = DateTime(2026, 9, 12, 15, 0); // 1 hr = 3600s

      final task1 = MainTask(
        id: 'task_1',
        name: 'Task 1',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_1',
            name: 'Sub 1',
            sessions: [TaskSession(id: 's1', startTime: t1, endTime: t2)],
          )
        ],
      );

      final task2 = MainTask(
        id: 'task_2',
        name: 'Task 2',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_2',
            name: 'Sub 2',
            sessions: [TaskSession(id: 's2', startTime: t3, endTime: t4)],
          )
        ],
      );

      final result = TaskCalculations.recalculateAllTimeLogs([task1, task2]);
      final todayTimes = result.dailyTaskTimes['2026-09-12']!;

      expect(todayTimes['task_1'], equals(3600));
      expect(todayTimes['task_2'], equals(3600));
      expect(result.subtaskLifetimeSeconds['sub_1'], equals(3600));
      expect(result.subtaskLifetimeSeconds['sub_2'], equals(3600));
    });

    test('Two sessions in same line (100% overlap) split time evenly (avg)', () {
      final start = DateTime(2026, 9, 12, 10, 0);
      final end = DateTime(2026, 9, 12, 11, 0); // 1 hour = 3600s total wall-clock

      final task1 = MainTask(
        id: 'task_1',
        name: 'Task 1',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_1',
            name: 'Sub 1',
            sessions: [TaskSession(id: 's1', startTime: start, endTime: end)],
          )
        ],
      );

      final task2 = MainTask(
        id: 'task_2',
        name: 'Task 2',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_2',
            name: 'Sub 2',
            sessions: [TaskSession(id: 's2', startTime: start, endTime: end)],
          )
        ],
      );

      final result = TaskCalculations.recalculateAllTimeLogs([task1, task2]);
      final todayTimes = result.dailyTaskTimes['2026-09-12']!;

      // Each gets half (1800s = 30 min), total sum = 3600s (exactly 1 hr)
      expect(todayTimes['task_1'], equals(1800));
      expect(todayTimes['task_2'], equals(1800));
      expect(todayTimes['task_1']! + todayTimes['task_2']!, equals(3600));

      expect(result.subtaskLifetimeSeconds['sub_1'], equals(1800));
      expect(result.subtaskLifetimeSeconds['sub_2'], equals(1800));
    });

    test('Partial overlap splits only the overlapping window, total never exceeds real time', () {
      // Task 1: 10:00 - 11:00 (60 min)
      // Task 2: 10:30 - 11:30 (60 min)
      // Wall-clock total: 10:00 - 11:30 = 90 min (5400s)
      // 10:00-10:30 (30m): Task 1 only -> 30m (1800s)
      // 10:30-11:00 (30m): Task 1 & 2 -> 15m each (900s)
      // 11:00-11:30 (30m): Task 2 only -> 30m (1800s)
      // Task 1 total: 30 + 15 = 45m (2700s)
      // Task 2 total: 15 + 30 = 45m (2700s)
      // Sum = 2700 + 2700 = 5400s (90m)
      final t1 = DateTime(2026, 9, 12, 10, 0);
      final t2 = DateTime(2026, 9, 12, 11, 0);
      final t3 = DateTime(2026, 9, 12, 10, 30);
      final t4 = DateTime(2026, 9, 12, 11, 30);

      final task1 = MainTask(
        id: 'task_1',
        name: 'Task 1',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_1',
            name: 'Sub 1',
            sessions: [TaskSession(id: 's1', startTime: t1, endTime: t2)],
          )
        ],
      );

      final task2 = MainTask(
        id: 'task_2',
        name: 'Task 2',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_2',
            name: 'Sub 2',
            sessions: [TaskSession(id: 's2', startTime: t3, endTime: t4)],
          )
        ],
      );

      final result = TaskCalculations.recalculateAllTimeLogs([task1, task2]);
      final todayTimes = result.dailyTaskTimes['2026-09-12']!;

      expect(todayTimes['task_1'], equals(2700));
      expect(todayTimes['task_2'], equals(2700));
      expect(todayTimes['task_1']! + todayTimes['task_2']!, equals(5400));
    });

    test('Three overlapping sessions divide by 3 during mutual overlap', () {
      final start = DateTime(2026, 9, 12, 12, 0);
      final end = DateTime(2026, 9, 12, 13, 0); // 3600s

      final tasks = List.generate(3, (i) {
        return MainTask(
          id: 'task_$i',
          name: 'Task $i',
          description: '',
          theme: 'general',
          subTasks: [
            SubTask(
              id: 'sub_$i',
              name: 'Sub $i',
              sessions: [TaskSession(id: 's_$i', startTime: start, endTime: end)],
            )
          ],
        );
      });

      final result = TaskCalculations.recalculateAllTimeLogs(tasks);
      final todayTimes = result.dailyTaskTimes['2026-09-12']!;

      expect(todayTimes['task_0'], equals(1200));
      expect(todayTimes['task_1'], equals(1200));
      expect(todayTimes['task_2'], equals(1200));
      expect(todayTimes.values.reduce((a, b) => a + b), equals(3600));
    });

    test('Sessions spanning across midnight are properly attributed to respective dates', () {
      // 23:00 on Day 1 to 01:00 on Day 2 (2 hours total = 7200s)
      final tStart = DateTime(2026, 9, 12, 23, 0);
      final tEnd = DateTime(2026, 9, 13, 1, 0);

      final task = MainTask(
        id: 'task_1',
        name: 'Task 1',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_1',
            name: 'Sub 1',
            sessions: [TaskSession(id: 's1', startTime: tStart, endTime: tEnd)],
          )
        ],
      );

      final result = TaskCalculations.recalculateAllTimeLogs([task]);

      expect(result.dailyTaskTimes['2026-09-12']!['task_1'], equals(3600));
      expect(result.dailyTaskTimes['2026-09-13']!['task_1'], equals(3600));
      expect(result.subtaskLifetimeSeconds['sub_1'], equals(7200));
    });

    test('Cluster fraction: Task from 9 to 5 pm with interior tasks allocates exact realtime difference', () {
      // Task A: 09:00 - 17:00 (8h = 28,800s)
      // Task B: 10:00 - 12:00 (2h = 7,200s)
      // Task C: 13:00 - 15:00 (2h = 7,200s)
      // Task D: 15:00 - 17:00 (2h = 7,200s)
      // Raw sum = 28,800 + 7,200 + 7,200 + 7,200 = 50,400s (14 hours!)
      // Realtime span = 17:00 - 09:00 = 8h (28,800s)
      // Total sum must be strictly 28,800s (NEVER overcounted to 14h or 16h)
      final t9 = DateTime(2026, 9, 12, 9, 0);
      final t17 = DateTime(2026, 9, 12, 17, 0);
      final t10 = DateTime(2026, 9, 12, 10, 0);
      final t12 = DateTime(2026, 9, 12, 12, 0);
      final t13 = DateTime(2026, 9, 12, 13, 0);
      final t15 = DateTime(2026, 9, 12, 15, 0);

      final taskA = MainTask(
        id: 'task_a',
        name: 'Task 9 to 5',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_a',
            name: 'Sub A',
            sessions: [TaskSession(id: 'sa', startTime: t9, endTime: t17)],
          )
        ],
      );

      final taskB = MainTask(
        id: 'task_b',
        name: 'Task B',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_b',
            name: 'Sub B',
            sessions: [TaskSession(id: 'sb', startTime: t10, endTime: t12)],
          )
        ],
      );

      final taskC = MainTask(
        id: 'task_c',
        name: 'Task C',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_c',
            name: 'Sub C',
            sessions: [TaskSession(id: 'sc', startTime: t13, endTime: t15)],
          )
        ],
      );

      final taskD = MainTask(
        id: 'task_d',
        name: 'Task D',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_d',
            name: 'Sub D',
            sessions: [TaskSession(id: 'sd', startTime: t15, endTime: t17)],
          )
        ],
      );

      final result = TaskCalculations.recalculateAllTimeLogs([taskA, taskB, taskC, taskD]);
      final todayTimes = result.dailyTaskTimes['2026-09-12']!;

      // Total must be EXACTLY 28,800s (8 hours)
      final totalToday = todayTimes.values.reduce((a, b) => a + b);
      expect(totalToday, equals(28800));

      expect(todayTimes['task_a'], equals((28800 * 28800) ~/ 50400 + 1));
      expect(todayTimes['task_b'], equals((28800 * 7200) ~/ 50400));
      expect(todayTimes['task_c'], equals((28800 * 7200) ~/ 50400));
      expect(todayTimes['task_d'], equals((28800 * 7200) ~/ 50400));
    });
  });

  group('TimeValidationHelper concurrent session support', () {
    test('Allows concurrent sessions between different subtasks/tasks', () {
      final now = DateTime(2026, 9, 12, 10, 0);
      final existingSession = TaskSession(
        id: 'sess_1',
        startTime: now,
        endTime: now.add(const Duration(minutes: 30)),
      );
      final mainTask = MainTask(
        id: 'task_1',
        name: 'Task 1',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_1',
            name: 'Sub 1',
            sessions: [existingSession],
          ),
          SubTask(
            id: 'sub_2',
            name: 'Sub 2',
            sessions: [],
          ),
        ],
      );

      // Checking overlap for sub_2 against existing session on sub_1:
      final hasOverlapForSub2 = TimeValidationHelper.hasOverlap(
        start: now.add(const Duration(minutes: 5)),
        end: now.add(const Duration(minutes: 25)),
        allTasks: [mainTask],
        targetSubTaskId: 'sub_2',
      );

      expect(hasOverlapForSub2, isFalse);
    });

    test('Disallows duplicate overlapping session within the SAME subtask (> 5 min)', () {
      final now = DateTime(2026, 9, 12, 10, 0);
      final existingSession = TaskSession(
        id: 'sess_1',
        startTime: now,
        endTime: now.add(const Duration(minutes: 30)),
      );
      final mainTask = MainTask(
        id: 'task_1',
        name: 'Task 1',
        description: '',
        theme: 'general',
        subTasks: [
          SubTask(
            id: 'sub_1',
            name: 'Sub 1',
            sessions: [existingSession],
          ),
        ],
      );

      final hasOverlapForSub1 = TimeValidationHelper.hasOverlap(
        start: now.add(const Duration(minutes: 5)),
        end: now.add(const Duration(minutes: 25)),
        allTasks: [mainTask],
        targetSubTaskId: 'sub_1',
      );

      expect(hasOverlapForSub1, isTrue);
    });
  });

  group('ScheduleTimeline layout clustering tests', () {
    test('Isolated entry gets full width (totalCols = 1, col = 0, colSpan = 1)', () {
      final entry = TimelineEntry(
        id: 'e1',
        startTime: DateTime(2026, 9, 12, 10, 0),
        endTime: DateTime(2026, 9, 12, 11, 0),
        title: 'Solo Task',
        color: Colors.blue,
      );

      final layout = ScheduleTimeline.calculateTimelineLayout([entry]);
      expect(layout.length, equals(1));
      expect(layout[0].col, equals(0));
      expect(layout[0].totalCols, equals(1));
      expect(layout[0].colSpan, equals(1));
    });

    test('Two entries overlapping in same line divide only their cluster (totalCols = 2)', () {
      final e1 = TimelineEntry(
        id: 'e1',
        startTime: DateTime(2026, 9, 12, 14, 0),
        endTime: DateTime(2026, 9, 12, 15, 0),
        title: 'Task A',
        color: Colors.blue,
      );
      final e2 = TimelineEntry(
        id: 'e2',
        startTime: DateTime(2026, 9, 12, 14, 0),
        endTime: DateTime(2026, 9, 12, 15, 0),
        title: 'Task B',
        color: Colors.green,
      );

      final layout = ScheduleTimeline.calculateTimelineLayout([e1, e2]);
      expect(layout.length, equals(2));
      expect(layout[0].totalCols, equals(2));
      expect(layout[1].totalCols, equals(2));
      expect(layout[0].col, equals(0));
      expect(layout[1].col, equals(1));
    });

    test('When 2 tasks overlap, only those 2 tasks are divided; isolated tasks remain full width', () {
      // Morning task: 08:00 - 09:00 (isolated)
      final morning = TimelineEntry(
        id: 'morning',
        startTime: DateTime(2026, 9, 12, 8, 0),
        endTime: DateTime(2026, 9, 12, 9, 0),
        title: 'Morning Solo',
        color: Colors.amber,
      );

      // Afternoon concurrent tasks: 14:00 - 15:00
      final afternoon1 = TimelineEntry(
        id: 'aft1',
        startTime: DateTime(2026, 9, 12, 14, 0),
        endTime: DateTime(2026, 9, 12, 15, 0),
        title: 'Afternoon 1',
        color: Colors.blue,
      );
      final afternoon2 = TimelineEntry(
        id: 'aft2',
        startTime: DateTime(2026, 9, 12, 14, 0),
        endTime: DateTime(2026, 9, 12, 15, 0),
        title: 'Afternoon 2',
        color: Colors.purple,
      );

      // Evening task: 19:00 - 20:00 (isolated)
      final evening = TimelineEntry(
        id: 'evening',
        startTime: DateTime(2026, 9, 12, 19, 0),
        endTime: DateTime(2026, 9, 12, 20, 0),
        title: 'Evening Solo',
        color: Colors.red,
      );

      final layout = ScheduleTimeline.calculateTimelineLayout([
        morning,
        afternoon1,
        afternoon2,
        evening,
      ]);

      expect(layout.length, equals(4));

      final morningLayout = layout.firstWhere((l) => l.entry.id == 'morning');
      final aft1Layout = layout.firstWhere((l) => l.entry.id == 'aft1');
      final aft2Layout = layout.firstWhere((l) => l.entry.id == 'aft2');
      final eveningLayout = layout.firstWhere((l) => l.entry.id == 'evening');

      // Morning task has NO overlap -> must NOT be divided across sheet!
      expect(morningLayout.totalCols, equals(1));
      expect(morningLayout.col, equals(0));
      expect(morningLayout.colSpan, equals(1));

      // Afternoon overlapping tasks -> only this cluster is divided into 2 columns!
      expect(aft1Layout.totalCols, equals(2));
      expect(aft2Layout.totalCols, equals(2));
      expect(aft1Layout.col, isNot(equals(aft2Layout.col)));

      // Evening task has NO overlap -> must NOT be divided across sheet!
      expect(eveningLayout.totalCols, equals(1));
      expect(eveningLayout.col, equals(0));
      expect(eveningLayout.colSpan, equals(1));
    });

    test('Entry in multi-column cluster expands (colSpan > 1) if adjacent right column is unoccupied', () {
      // Cluster has 2 columns:
      // Entry 1: 10:00 - 12:00 (Col 0)
      // Entry 2: 10:00 - 11:00 (Col 1)
      // Entry 3: 11:00 - 12:00 (Col 1)
      final e1 = TimelineEntry(
        id: 'e1',
        startTime: DateTime(2026, 9, 12, 10, 0),
        endTime: DateTime(2026, 9, 12, 12, 0),
        title: 'Long 1',
        color: Colors.cyan,
      );
      final e2 = TimelineEntry(
        id: 'e2',
        startTime: DateTime(2026, 9, 12, 10, 0),
        endTime: DateTime(2026, 9, 12, 11, 0),
        title: 'Short 2',
        color: Colors.green,
      );
      final e3 = TimelineEntry(
        id: 'e3',
        startTime: DateTime(2026, 9, 12, 11, 0),
        endTime: DateTime(2026, 9, 12, 12, 0),
        title: 'Short 3',
        color: Colors.purple,
      );

      final layout = ScheduleTimeline.calculateTimelineLayout([e1, e2, e3]);
      expect(layout.length, equals(3));
      for (final le in layout) {
        expect(le.totalCols, equals(2));
      }
    });
  });
}
