import 'package:intl/intl.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';

class ExpectedIncrementInfo {
  final double valueIncrement;
  final double ratioIncrement;
  final String label;

  ExpectedIncrementInfo({
    required this.valueIncrement,
    required this.ratioIncrement,
    required this.label,
  });
}

class BriefingIncrementInfo {
  final double valueIncrement;
  final double ratioIncrement;
  final double startValue;
  final double currentValue;
  final String label;

  BriefingIncrementInfo({
    required this.valueIncrement,
    required this.ratioIncrement,
    required this.startValue,
    required this.currentValue,
    required this.label,
  });
}

class GoalBriefingHelper {
  /// Builds snapshot of active weekly and monthly goals at startup time
  static List<Map<String, dynamic>> buildWeeklyMonthlyGoalsSnapshot(
      AppProvider provider, DateTime date) {
    final weeklyGoals = provider.getGoalsForDate(date, GoalScope.weekly);
    final monthlyGoals = provider.getGoalsForDate(date, GoalScope.monthly);
    final periodGoals = [...weeklyGoals, ...monthlyGoals];

    return periodGoals.map((goal) {
      return {
        'id': goal.id,
        'title': goal.title,
        'scope': goal.scope.name,
        'metricType': goal.metricType.name,
        'currentValue': goal.currentValue,
        'targetValue': goal.targetValue,
        'ratio': goal.getProgressRatio(),
        'isCompleted': goal.getIsEffectiveCompleted(),
      };
    }).toList();
  }

  /// Calculates expected daily increment for a weekly or monthly goal based on average past startup snapshots
  static ExpectedIncrementInfo getExpectedDailyIncrement(
      AppProvider provider, GoalModel goal, DateTime date) {
    final totalDays = goal.scope == GoalScope.weekly ? 7.0 : 30.0;
    
    // Look at past startup snapshots in completedByDay
    final pastIncrements = <double>[];
    final pastRatioIncrements = <double>[];
    
    final daysToLook = goal.scope == GoalScope.weekly ? 7 : 30;
    for (int i = 1; i <= daysToLook; i++) {
      final pastDate = date.subtract(Duration(days: i));
      final pastDateStr = DateFormat('yyyy-MM-dd').format(pastDate);
      final report = provider.getStartDayReport(pastDateStr);
      if (report != null && report['weekly_monthly_goals_snapshot'] != null) {
        final snapshots = report['weekly_monthly_goals_snapshot'] as List<dynamic>?;
        if (snapshots != null) {
          final snap = snapshots.firstWhere(
            (s) => s is Map && (s['id'] == goal.id || s['title'] == goal.title),
            orElse: () => null,
          );
          if (snap != null && snap is Map) {
            final val = (snap['currentValue'] as num?)?.toDouble() ?? 0.0;
            final ratio = (snap['ratio'] as num?)?.toDouble() ?? 0.0;
            pastIncrements.add(val);
            pastRatioIncrements.add(ratio);
          }
        }
      }
    }

    double expectedValueInc = 0.0;
    double expectedRatioInc = 0.0;
    bool isFromHistory = false;

    if (pastIncrements.length >= 2) {
      // Calculate differences between consecutive daily snapshots
      double sumValueDiff = 0.0;
      double sumRatioDiff = 0.0;
      int count = 0;
      for (int i = 0; i < pastIncrements.length - 1; i++) {
        final diffVal = (pastIncrements[i] - pastIncrements[i + 1]).clamp(0.0, 999999.0);
        final diffRatio = (pastRatioIncrements[i] - pastRatioIncrements[i + 1]).clamp(0.0, 1.0);
        sumValueDiff += diffVal;
        sumRatioDiff += diffRatio;
        count++;
      }
      if (count > 0 && sumRatioDiff > 0) {
        expectedValueInc = sumValueDiff / count;
        expectedRatioInc = sumRatioDiff / count;
        isFromHistory = true;
      }
    }

    if (!isFromHistory) {
      // Default pace calculation: target / totalDays
      expectedValueInc = goal.targetValue > 0 ? goal.targetValue / totalDays : 0.0;
      expectedRatioInc = 1.0 / totalDays;
    }

    String formattedVal;
    if (goal.metricType == GoalMetricType.timeCounter) {
      formattedVal = '+${expectedValueInc.toStringAsFixed(0)}m/day';
    } else if (goal.metricType == GoalMetricType.counter) {
      formattedVal = '+${expectedValueInc % 1 == 0 ? expectedValueInc.toStringAsFixed(0) : expectedValueInc.toStringAsFixed(1)}/day';
    } else {
      formattedVal = '+${(expectedRatioInc * 100).toStringAsFixed(0)}%/day';
    }

    final sourceLabel = isFromHistory ? 'avg history' : 'expected pace';
    final label = '$formattedVal ($sourceLabel)';

    return ExpectedIncrementInfo(
      valueIncrement: expectedValueInc,
      ratioIncrement: expectedRatioInc,
      label: label,
    );
  }

  /// Calculates actual progress increment achieved today in Daily Briefing compared to startup snapshot
  static BriefingIncrementInfo getDailyBriefingIncrement(
      AppProvider provider, GoalModel goal, DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final startupReport = provider.getStartDayReport(dateStr);

    double startVal = 0.0;
    double startRatio = 0.0;

    if (startupReport != null && startupReport['weekly_monthly_goals_snapshot'] != null) {
      final snapshots = startupReport['weekly_monthly_goals_snapshot'] as List<dynamic>?;
      if (snapshots != null) {
        final snap = snapshots.firstWhere(
          (s) => s is Map && (s['id'] == goal.id || s['title'] == goal.title),
          orElse: () => null,
        );
        if (snap != null && snap is Map) {
          startVal = (snap['currentValue'] as num?)?.toDouble() ?? 0.0;
          startRatio = (snap['ratio'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    final currentVal = goal.currentValue;
    final currentRatio = goal.getProgressRatio();

    final valueInc = (currentVal - startVal).clamp(0.0, 999999.0);
    final ratioInc = (currentRatio - startRatio).clamp(0.0, 1.0);

    String label;
    if (valueInc <= 0 && ratioInc <= 0) {
      label = 'No change today';
    } else if (goal.metricType == GoalMetricType.timeCounter) {
      label = '+${valueInc.toStringAsFixed(0)}m today (+${(ratioInc * 100).toStringAsFixed(0)}%)';
    } else if (goal.metricType == GoalMetricType.counter) {
      label = '+${valueInc % 1 == 0 ? valueInc.toStringAsFixed(0) : valueInc.toStringAsFixed(1)} today (+${(ratioInc * 100).toStringAsFixed(0)}%)';
    } else {
      label = '+${(ratioInc * 100).toStringAsFixed(0)}% today';
    }

    return BriefingIncrementInfo(
      valueIncrement: valueInc,
      ratioIncrement: ratioInc,
      startValue: startVal,
      currentValue: currentVal,
      label: label,
    );
  }

  /// Yesterday's completed goals for motivation
  static List<GoalModel> getYesterdayCompletedGoals(AppProvider provider, DateTime date) {
    final yesterday = date.subtract(const Duration(days: 1));
    final yesterdayGoals = provider.getGoalsForDate(yesterday, GoalScope.daily);
    return yesterdayGoals.where((g) => g.getIsEffectiveCompleted()).toList();
  }

  /// Today's goals to complete for Startup
  static List<GoalModel> getTodayGoalsToComplete(AppProvider provider, DateTime date) {
    final todayGoals = provider.getGoalsForDate(date, GoalScope.daily);
    return todayGoals.where((g) => !g.getIsEffectiveCompleted()).toList();
  }

  /// Today's goals ordered for Briefing (completed goals first, then in-progress)
  static Map<String, List<GoalModel>> getTodayGoalsForBriefing(AppProvider provider, DateTime date) {
    final todayGoals = provider.getGoalsForDate(date, GoalScope.daily);
    final completed = todayGoals.where((g) => g.getIsEffectiveCompleted()).toList();
    final inProgress = todayGoals.where((g) => !g.getIsEffectiveCompleted()).toList();
    return {
      'completed': completed,
      'inProgress': inProgress,
    };
  }

  /// Formats goals context text for Startup AI prompt
  static String buildStartupGoalsAIContext(AppProvider provider, DateTime date) {
    final buffer = StringBuffer();

    // Yesterday completed
    final yesterdayCompleted = getYesterdayCompletedGoals(provider, date);
    if (yesterdayCompleted.isNotEmpty) {
      buffer.writeln("YESTERDAY'S COMPLETED GOALS (FOR MOTIVATION):");
      for (var g in yesterdayCompleted) {
        buffer.writeln("- ✓ ${g.title}");
      }
    } else {
      buffer.writeln("YESTERDAY'S COMPLETED GOALS: None");
    }

    // Today's goals to complete
    final todayToComplete = getTodayGoalsToComplete(provider, date);
    buffer.writeln("\nTODAY'S DAILY GOALS TO COMPLETE:");
    if (todayToComplete.isNotEmpty) {
      for (var g in todayToComplete) {
        final targetStr = g.targetValue > 1 ? ' (Target: ${g.targetValue})' : '';
        buffer.writeln("- [ ] ${g.title}$targetStr");
      }
    } else {
      buffer.writeln("- All daily goals completed or no daily goals set yet.");
    }

    // Weekly & Monthly expectations
    final weekly = provider.getGoalsForDate(date, GoalScope.weekly);
    final monthly = provider.getGoalsForDate(date, GoalScope.monthly);
    if (weekly.isNotEmpty || monthly.isNotEmpty) {
      buffer.writeln("\nACTIVE WEEKLY & MONTHLY GOALS EXPECTATIONS:");
      for (var g in [...weekly, ...monthly]) {
        final exp = getExpectedDailyIncrement(provider, g, date);
        buffer.writeln("- [${g.scope.name.toUpperCase()}] ${g.title}: Expected increment today: ${exp.label}");
      }
    }

    return buffer.toString();
  }

  /// Formats goals context text for Daily Briefing AI prompt
  static String buildTacticalBriefingGoalsAIContext(AppProvider provider, DateTime date) {
    final buffer = StringBuffer();

    // Yesterday completed
    final yesterdayCompleted = getYesterdayCompletedGoals(provider, date);
    if (yesterdayCompleted.isNotEmpty) {
      buffer.writeln("YESTERDAY'S COMPLETED GOALS (MOTIVATION):");
      for (var g in yesterdayCompleted) {
        buffer.writeln("- ✓ ${g.title}");
      }
    }

    // Today's goals
    final todayGoals = getTodayGoalsForBriefing(provider, date);
    final completed = todayGoals['completed']!;
    final inProgress = todayGoals['inProgress']!;

    buffer.writeln("\nTODAY'S DAILY GOALS STATUS:");
    if (completed.isNotEmpty) {
      buffer.writeln("COMPLETED TODAY:");
      for (var g in completed) {
        buffer.writeln("- ✓ ${g.title} (100% completed)");
      }
    }
    if (inProgress.isNotEmpty) {
      buffer.writeln("IN PROGRESS TODAY:");
      for (var g in inProgress) {
        final pct = (g.getProgressRatio() * 100).toStringAsFixed(0);
        buffer.writeln("- [ ] ${g.title} ($pct% progress, value: ${g.currentValue}/${g.targetValue})");
      }
    }
    if (completed.isEmpty && inProgress.isEmpty) {
      buffer.writeln("- No daily goals logged today.");
    }

    // Weekly & Monthly Increments
    final weekly = provider.getGoalsForDate(date, GoalScope.weekly);
    final monthly = provider.getGoalsForDate(date, GoalScope.monthly);
    if (weekly.isNotEmpty || monthly.isNotEmpty) {
      buffer.writeln("\nWEEKLY & MONTHLY GOALS TODAY'S INCREMENTS:");
      for (var g in [...weekly, ...monthly]) {
        final inc = getDailyBriefingIncrement(provider, g, date);
        buffer.writeln("- [${g.scope.name.toUpperCase()}] ${g.title}: Increment today: ${inc.label} (Total progress: ${(g.getProgressRatio() * 100).toStringAsFixed(0)}%)");
      }
    }

    return buffer.toString();
  }
}
