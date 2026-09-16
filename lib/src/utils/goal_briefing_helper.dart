import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/drawers/goals/create_goal_sheet.dart';

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

    // Tomorrow's planned daily goals
    final tomorrowGoals = getTomorrowGoals(provider, date);
    buffer.writeln("\nTOMORROW'S PLANNED DAILY GOALS:");
    if (tomorrowGoals.isNotEmpty) {
      for (var g in tomorrowGoals) {
        final targetStr = g.targetValue > 1 ? ' (Target: ${g.targetValue})' : '';
        buffer.writeln("- [ ] ${g.title}$targetStr");
      }
    } else {
      buffer.writeln("- No daily goals scheduled for tomorrow yet.");
    }

    return buffer.toString();
  }

  /// Returns next week's Monday date relative to [date]
  static DateTime getNextWeekMonday(DateTime date) {
    final currentMonday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(currentMonday.year, currentMonday.month, currentMonday.day + 7);
  }

  /// Returns tomorrow date relative to [date]
  static DateTime getTomorrow(DateTime date) {
    return DateTime(date.year, date.month, date.day + 1);
  }

  /// Returns daily goals planned for tomorrow relative to [date]
  static List<GoalModel> getTomorrowGoals(AppProvider provider, DateTime date) {
    final tomorrow = getTomorrow(date);
    return provider.getGoalsForDate(tomorrow, GoalScope.daily);
  }

  /// Checks if at least one daily goal exists for tomorrow
  static bool hasTomorrowGoals(AppProvider provider, DateTime date) {
    return getTomorrowGoals(provider, date).isNotEmpty;
  }

  /// Returns weekly goals planned for next week relative to [date]
  static List<GoalModel> getNextWeekGoals(AppProvider provider, DateTime date) {
    final nextWeekMonday = getNextWeekMonday(date);
    return provider.getGoalsForDate(nextWeekMonday, GoalScope.weekly);
  }

  /// Checks if at least two weekly goals are planned for next week
  static bool hasNextWeekGoals(AppProvider provider, DateTime date) {
    return getNextWeekGoals(provider, date).length >= 2;
  }

  /// Checks if at least two weekly goals are set for next week.
  /// If not, displays a tactical alert prompt asking the user to add them.
  /// Returns true if generation should proceed (user already has >= 2 goals or chose "PROCEED ANYWAY").
  /// Returns false if canceled or if user opted to add goals.
  static Future<bool> showWeeklyGoalsCheckDialog(
    BuildContext context,
    AppProvider provider,
    DateTime date,
  ) async {
    if (hasNextWeekGoals(provider, date)) {
      return true;
    }

    final nextWeekGoals = getNextWeekGoals(provider, date);
    final nextWeekMonday = getNextWeekMonday(date);
    final nextWeekEnd = nextWeekMonday.add(const Duration(days: 6));
    final dateRangeStr =
        '${DateFormat('MMM d').format(nextWeekMonday)} – ${DateFormat('MMM d, yyyy').format(nextWeekEnd)}';

    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: JweTheme.accentWarn, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Icon(Icons.flag_outlined, color: JweTheme.accentWarn, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'WEEKLY BRIEFING: NEXT WEEK GOALS',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Before synthesizing your weekly review, please set at least 2 weekly goals for next week ($dateRangeStr) to maintain forward strategic momentum.',
                style: GoogleFonts.inter(
                  color: JweTheme.textMid,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JweTheme.panel2,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: JweTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(MdiIcons.target, size: 16, color: JweTheme.accentWarn),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'NEXT WEEK GOALS: ${nextWeekGoals.length} OF 2 SET',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentWarn,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (nextWeekGoals.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...nextWeekGoals.map((g) => Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 2, left: 4),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 13, color: JweTheme.accentTeal),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    g.title,
                                    style: GoogleFonts.inter(
                                      color: JweTheme.textWhite,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: JweTheme.accentAmber),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => Navigator.pop(ctx, 'add_goal'),
                      icon: Icon(Icons.add, size: 14, color: JweTheme.accentAmber),
                      label: Text(
                        'ADD NEXT WEEK GOAL',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: JweTheme.accentAmber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Weekly briefings without target goals for the upcoming week omit strategic alignment and predictive guidance from your AI synthesis.',
                style: GoogleFonts.inter(
                  color: JweTheme.textMuted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'add_goal'),
              child: Text(
                'ADD GOALS FIRST',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentWarn,
                foregroundColor: JweTheme.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'PROCEED ANYWAY',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == 'add_goal') {
      if (!context.mounted) return false;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => CreateGoalSheet(
          initialScope: GoalScope.weekly,
          selectedDate: nextWeekMonday,
        ),
      );
      return false;
    }

    return result == true;
  }
}
