import 'package:flutter/foundation.dart';
import 'package:missions/src/theme/wellbeing_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/ai_service.dart';
import 'package:missions/src/utils/helpers.dart';
import 'package:missions/src/utils/history_helper.dart';
import 'package:missions/src/utils/goal_briefing_helper.dart';
import 'package:intl/intl.dart';

class ReportActions {
  final AppProvider _provider;
  final AIService _aiService;

  ReportActions(this._provider) : _aiService = _provider.aiService;

  Future<List<Map<String, dynamic>>> generateStartDayReport() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final recentLogs = _provider.reflectionLogs.where((l) => l.timestamp.isAfter(sevenDaysAgo)).toList();
    final reflectionsStr = recentLogs.map((l) => "[${DateFormat('MM-dd').format(l.timestamp)}] ${l.trigger} -> ${l.emotion}").join("\n");

    final sessionsStrBuffer = StringBuffer();
    for (var task in _provider.mainTasks) {
      for (var sub in task.subTasks) {
        for (var session in sub.sessions) {
          if (session.startTime.isAfter(sevenDaysAgo)) {
            sessionsStrBuffer.writeln("[${DateFormat('MM-dd').format(session.startTime)}] ${task.name} - ${sub.name}: ${session.durationMinutes}m");
          }
        }
      }
    }

    // Snapshot current task progress before generating report
    final taskSnapshot = <String, dynamic>{};
    for (var task in _provider.mainTasks) {
      if (task.isDeleted || !task.isActive) continue;
      final subtaskData = <String, dynamic>{};
      for (var sub in task.subTasks) {
        if (sub.isDeleted || !sub.isActive) continue;
        if (sub.completed && !sub.isRecurring) continue;
        subtaskData[sub.id] = {
          'name': sub.name,
          'progress': sub.calculateProgress(),
          'time_spent': sub.currentTimeSpent,
          'completed': sub.completed,
        };
      }
      taskSnapshot[task.id] = {
        'name': task.name,
        'color_hex': task.colorHex,
        'subtasks': subtaskData,
      };
    }

    _provider.setLoadingTask("Generating Startup Report...");

    try {
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
      final startOfTodayMinus7 = startOfToday.subtract(const Duration(days: 7));
      final startOfYesterdayMinus7 = startOfYesterday.subtract(const Duration(days: 7));

      Map<String, int> yesterdayMetricsMap = {};
      Map<String, int> dayBeforeMetricsMap = {};

      for (var log in _provider.reflectionLogs) {
        if (log.timestamp.isAfter(startOfTodayMinus7) && log.timestamp.isBefore(startOfToday)) {
          log.xpGained.forEach((k, v) {
            final normalized = WellbeingTheme.normalizeSkillName(k);
            if (normalized != null) {
              yesterdayMetricsMap[normalized] = (yesterdayMetricsMap[normalized] ?? 0) + v;
            }
          });
        }
        if (log.timestamp.isAfter(startOfYesterdayMinus7) && log.timestamp.isBefore(startOfYesterday)) {
          log.xpGained.forEach((k, v) {
            final normalized = WellbeingTheme.normalizeSkillName(k);
            if (normalized != null) {
              dayBeforeMetricsMap[normalized] = (dayBeforeMetricsMap[normalized] ?? 0) + v;
            }
          });
        }
      }

      List<Map<String, dynamic>> metrics = [];
      for (var skill in _provider.getBaseWellbeingSkills()) {
        final y = yesterdayMetricsMap[skill.name] ?? 0;
        final db = dayBeforeMetricsMap[skill.name] ?? 0;
        metrics.add({'name': skill.name, 'today': y, 'yesterday': db, 'delta': y - db});
      }

      final peopleContext = _provider.chatbotMemory.people
          .map((p) => "${p.name} (${p.relation})")
          .join(', ');

      final goalsSnapshot = GoalBriefingHelper.buildWeeklyMonthlyGoalsSnapshot(_provider, now);
      final goalsContext = GoalBriefingHelper.buildStartupGoalsAIContext(_provider, now);

      final aiResult = await _aiService.generateStartDayReport(
        reflectionsList: reflectionsStr,
        sessionsList: sessionsStrBuffer.toString(),
        knownPeopleText: peopleContext,
        goalsText: goalsContext,
        modelCandidates: _provider.settings.heavyModels,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[ReportAI] $msg"),
        writingStyleMap: _provider.settings.adaptWritingStyle ? _provider.settings.writingStyleMap : null,
      );

      final result = Map<String, dynamic>.from(aiResult);
      result['metrics'] = metrics;
      result['task_snapshot'] = taskSnapshot;
      result['weekly_monthly_goals_snapshot'] = goalsSnapshot;
      result['snapshot_time'] = now.toIso8601String();

      if (aiResult['suggested_contacts'] != null) {
        final contacts = aiResult['suggested_contacts'] as List<dynamic>;
        for (var c in contacts) {
          if (c is Map) {
            final name = c['name'] as String? ?? '';
            final relation = c['relation'] as String? ?? 'Acquaintance';
            final reason = c['reason'] as String? ?? '';
            final type = c['type'] as String? ?? 'CONTACT';
            if (name.isNotEmpty) {
              _provider.logInteractionForPerson(
                name: name,
                relation: relation,
                interactionSummary: "Startup Recommendation [$type]: $reason",
                nextActionPlan: "[$type] $reason",
                date: now,
              );
            }
          }
        }
      }

      final today = getTodayDateString();
      _provider.saveStartDayReport(today, result);

      return [];
    } catch (e) {
      debugPrint("Error generating start day report: $e");
      rethrow;
    } finally {
      _provider.setLoadingTask(null);
    }
  }

  // ── Monthly briefing ──────────────────────────────────────────────────

  String _buildMonthlyWellbeingComparison(DateTime now) {
    final last30 = now.subtract(const Duration(days: 30));
    final prev30 = now.subtract(const Duration(days: 60));

    final Map<String, int> currentXp = {};
    final Map<String, int> prevXp = {};

    for (var log in _provider.reflectionLogs) {
      if (log.timestamp.isAfter(last30)) {
        log.xpGained.forEach((k, v) {
          final normalized = WellbeingTheme.normalizeSkillName(k);
          if (normalized != null) {
            currentXp[normalized] = (currentXp[normalized] ?? 0) + v;
          }
        });
      } else if (log.timestamp.isAfter(prev30) && log.timestamp.isBefore(last30)) {
        log.xpGained.forEach((k, v) {
          final normalized = WellbeingTheme.normalizeSkillName(k);
          if (normalized != null) {
            prevXp[normalized] = (prevXp[normalized] ?? 0) + v;
          }
        });
      }
    }

    final buffer = StringBuffer();
    for (var skill in _provider.getBaseWellbeingSkills()) {
      final curr = currentXp[skill.name] ?? 0;
      final prev = prevXp[skill.name] ?? 0;
      if (curr > 0 || prev > 0) {
        buffer.writeln("${skill.name}: $curr XP (Prev month: $prev XP)");
      }
    }
    return buffer.toString();
  }

  String _buildMonthlyFinanceContext(DateTime now) {
    final monthAgo = now.subtract(const Duration(days: 30));
    double income = 0, expense = 0;
    for (final t in _provider.transactions) {
      if (t.timestamp.isAfter(monthAgo)) {
        if (t.isIncome) {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
    }
    final balance = _provider.financeActions.currentBalance;
    return 'Month Income: ₹${income.toStringAsFixed(0)}, Expense: ₹${expense.toStringAsFixed(0)}, Net: ₹${(income - expense).toStringAsFixed(0)}, Balance: ₹${balance.toStringAsFixed(0)}';
  }

  String _buildMonthlyHealthContext(DateTime now) {
    double totalWater = 0;
    double totalSleepMins = 0;
    double totalWalkKm = 0;
    double totalWorkoutMins = 0;
    int daysWithData = 0;
    for (int i = 0; i < 30; i++) {
      final dStr = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      final log = _provider.getDailyHealthLog(dStr);
      final water = log.waterGlasses;
      final sleep = log.sleepLogs.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      final walk = log.activityLogs.fold<double>(0, (sum, a) => sum + a.walkDistanceKm);
      final workout = log.activityLogs.fold<int>(0, (sum, a) => sum + a.workoutMinutes);
      if (water > 0 || sleep > 0 || walk > 0 || workout > 0) daysWithData++;
      totalWater += water;
      totalSleepMins += sleep;
      totalWalkKm += walk;
      totalWorkoutMins += workout;
    }
    if (daysWithData == 0) return '';
    return 'Avg Water: ${(totalWater / 30).toStringAsFixed(1)} glasses/day, '
        'Avg Sleep: ${(totalSleepMins / 30 / 60).toStringAsFixed(1)} h/day, '
        'Walks: ${totalWalkKm.toStringAsFixed(1)} km total, '
        'Workouts: ${(totalWorkoutMins / 60).toStringAsFixed(1)} h total '
        '($daysWithData/30 days logged)';
  }

  Future<String> _buildWeeklyReportsContext(DateTime now) async {
    try {
      final reports = await _provider.getArchivedWeeklyReports();
      final cutoff = now.subtract(const Duration(days: 35));
      final buf = StringBuffer();
      for (final doc in reports) {
        final id = doc['id'] as String? ?? '';
        final date = DateTime.tryParse(id);
        if (date == null || date.isBefore(cutoff)) continue;
        final report = doc['report'] as Map<String, dynamic>? ?? {};
        final summary = report['summary'] as String? ?? '';
        final wellbeing = report['wellbeing_analysis'] as String? ?? '';
        if (summary.isEmpty && wellbeing.isEmpty) continue;
        buf.writeln('[$id] $summary ${wellbeing.isNotEmpty ? "| Wellbeing: $wellbeing" : ""}');
      }
      return buf.toString();
    } catch (e) {
      debugPrint("Monthly briefing: weekly context failed: $e");
      return '';
    }
  }

  Future<String> _buildPreviousMonthlyContext() async {
    try {
      final reports = await _provider.getArchivedMonthlyReports();
      if (reports.isEmpty) return '';
      final report = reports.first['report'] as Map<String, dynamic>? ?? {};
      final id = reports.first['id'] as String? ?? '';
      final narrative = report['narrative'] as String? ?? '';
      final woop = report['next_month_woop'] as List<dynamic>? ?? [];
      final buf = StringBuffer();
      if (narrative.isNotEmpty) buf.writeln('[$id] Narrative: $narrative');
      if (woop.isNotEmpty) {
        buf.writeln('Goals the user committed to for THIS month (check them in the after-action review):');
        for (final w in woop) {
          final m = w as Map<String, dynamic>;
          buf.writeln('- Wish: ${m['wish'] ?? ''} | Plan: ${m['plan'] ?? ''}');
        }
      }
      return buf.toString();
    } catch (e) {
      debugPrint("Monthly briefing: previous monthly context failed: $e");
      return '';
    }
  }

  /// Generates the monthly briefing from ~30 days of app data plus the
  /// month's archived weekly reports, saves it, and returns it for display.
  Future<Map<String, dynamic>> generateMonthlyReport() async {
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));

    final recentLogs = _provider.reflectionLogs
        .where((l) => l.timestamp.isAfter(monthAgo))
        .toList();
    final logsStr = recentLogs
        .map((l) => "[${DateFormat('MM-dd').format(l.timestamp)}] ${l.trigger} -> ${l.emotion}: ${l.reason}")
        .join("\n");

    final monthLabel =
        '${DateFormat('MMM d').format(monthAgo)} – ${DateFormat('MMM d, yyyy').format(now)}';

    _provider.setLoadingTask("Generating Monthly Briefing...");

    try {
      final weeklyContext = await _buildWeeklyReportsContext(now);
      final previousMonthlyContext = await _buildPreviousMonthlyContext();
      final peopleContext = _provider.chatbotMemory.people
          .map((p) => "${p.name} (${p.relation})")
          .join(', ');

      // Save static finance snapshot
      double monthIncome = 0, monthExpense = 0;
      for (final t in _provider.transactions) {
        if (t.timestamp.isAfter(monthAgo)) {
          if (t.isIncome) monthIncome += t.amount; else monthExpense += t.amount;
        }
      }

      final result = await _aiService.generateMonthlyReport(
        monthLabel: monthLabel,
        logsText: logsStr.isEmpty ? 'No reflections logged this month.' : logsStr,
        timeStatsText: HistoryHelper.getSessionHistoryString(_provider.mainTasks, 30),
        wellbeingStatsText: _buildMonthlyWellbeingComparison(now),
        financeText: _buildMonthlyFinanceContext(now),
        healthText: _buildMonthlyHealthContext(now),
        peopleContext: peopleContext,
        weeklyReportsContext: weeklyContext,
        previousMonthlyContext: previousMonthlyContext,
        modelCandidates: _provider.settings.heavyModels,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[MonthlyReport] $msg"),
        writingStyleMap: _provider.settings.adaptWritingStyle
            ? _provider.settings.writingStyleMap
            : null,
      );

      final data = Map<String, dynamic>.from(result);
      data['month_label'] = monthLabel;
      data['generated_at'] = now.toIso8601String();
      data['saved_finance'] = {
        'income': monthIncome,
        'expense': monthExpense,
        'net': monthIncome - monthExpense,
        'balance': _provider.financeActions.currentBalance,
      };
      return data;
    } catch (e) {
      debugPrint("Error generating monthly report: $e");
      rethrow;
    } finally {
      _provider.setLoadingTask(null);
    }
  }
}