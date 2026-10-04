import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/utils/task_calculations.dart';

class BusWidgetData {
  final String origin;
  final String destination;
  final String nextTime;
  final String nextSubStop;
  final bool isOnBus;
  final int speedKmh;
  final int minutesRemaining;

  const BusWidgetData({
    required this.origin,
    required this.destination,
    required this.nextTime,
    required this.nextSubStop,
    required this.isOnBus,
    required this.speedKmh,
    required this.minutesRemaining,
  });
}

class TaskWidgetData {
  final bool hasTask;
  final String title;
  final String subtitle;
  final bool isRunning;
  final bool isCheckpoint;
  final int accumulatedSeconds;
  final double progress;
  final String capacity;
  final List<ResolvedDayPlanItem> multitaskTasks;

  const TaskWidgetData({
    required this.hasTask,
    required this.title,
    required this.subtitle,
    required this.isRunning,
    required this.isCheckpoint,
    required this.accumulatedSeconds,
    required this.progress,
    required this.capacity,
    required this.multitaskTasks,
  });
}

class FinanceWidgetData {
  final double balance;
  final double todaySpend;
  final double monthSpend;
  final int budgetPct;

  const FinanceWidgetData({
    required this.balance,
    required this.todaySpend,
    required this.monthSpend,
    required this.budgetPct,
  });
}

class JournalWidgetData {
  final int count;
  final bool wake;
  final bool morn;
  final bool aft;
  final bool eve;
  final bool night;

  const JournalWidgetData({
    required this.count,
    required this.wake,
    required this.morn,
    required this.aft,
    required this.eve,
    required this.night,
  });
}

class GoalsWidgetData {
  final int totalCount;
  final int completedCount;
  final double progress;
  final int totalXp;
  final int earnedXp;
  final List<GoalModel> goals;
  final GoalScope scope;

  const GoalsWidgetData({
    required this.totalCount,
    required this.completedCount,
    required this.progress,
    required this.totalXp,
    required this.earnedXp,
    required this.goals,
    this.scope = GoalScope.daily,
  });
}
