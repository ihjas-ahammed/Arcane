import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'weekly_common_widgets.dart';
import 'weekly_completed_log_widget.dart';
import 'weekly_people_log_widget.dart';

class WeeklyRawMetricsSection extends StatelessWidget {
  final AppProvider provider;
  final DateTime effectiveDate;
  final Map<String, dynamic> currentReportData;

  const WeeklyRawMetricsSection({
    super.key,
    required this.provider,
    required this.effectiveDate,
    required this.currentReportData,
  });

  @override
  Widget build(BuildContext context) {
    final now = effectiveDate;
    final weekAgo = now.subtract(const Duration(days: 7));

    // Gather infinitely nested completed tasks & checkpoints tree
    CompletedNode? buildSubSubTaskNode(SubSubTask cp, Color color) {
      bool selfCompleted = false;
      String? compDateStr;
      if (cp.completed && cp.completionTimestamp != null) {
        try {
          final compDate = DateTime.parse(cp.completionTimestamp!);
          if (compDate.isAfter(weekAgo) && compDate.isBefore(now)) {
            selfCompleted = true;
            compDateStr = DateFormat('yyyy-MM-dd').format(compDate);
          }
        } catch (_) {}
      }

      final childNodes = <CompletedNode>[];
      for (final childCp in cp.substeps) {
        final node = buildSubSubTaskNode(childCp, color);
        if (node != null) {
          childNodes.add(node);
        }
      }

      if (selfCompleted || childNodes.isNotEmpty) {
        return CompletedNode(
          id: cp.id,
          name: cp.name,
          nodeType: 'checkpoint',
          color: color,
          date: compDateStr,
          isCompleted: selfCompleted,
          children: childNodes,
        );
      }
      return null;
    }

    CompletedNode? buildSubTaskNode(SubTask sub, Color color) {
      if (sub.isRecurring) return null;
      bool selfCompleted = false;
      String? compDateStr;
      if (sub.completed && sub.completedDate != null) {
        try {
          final compDate = DateTime.parse(sub.completedDate!);
          if (compDate.isAfter(weekAgo) && compDate.isBefore(now)) {
            selfCompleted = true;
            compDateStr = sub.completedDate;
          }
        } catch (_) {}
      }

      final childNodes = <CompletedNode>[];
      for (final cp in sub.subSubTasks) {
        final node = buildSubSubTaskNode(cp, color);
        if (node != null) {
          childNodes.add(node);
        }
      }

      if (selfCompleted || childNodes.isNotEmpty) {
        return CompletedNode(
          id: sub.id,
          name: sub.name,
          nodeType: 'subtask',
          color: color,
          date: compDateStr,
          isCompleted: selfCompleted,
          children: childNodes,
        );
      }
      return null;
    }

    final missionNodes = <CompletedNode>[];
    for (final task in provider.mainTasks.where((t) => !t.isDeleted)) {
      final childNodes = <CompletedNode>[];
      for (final sub in task.subTasks.where((s) => !s.isDeleted)) {
        final node = buildSubTaskNode(sub, task.taskColor);
        if (node != null) {
          childNodes.add(node);
        }
      }

      if (childNodes.isNotEmpty) {
        missionNodes.add(CompletedNode(
          id: task.id,
          name: task.name,
          nodeType: 'mission',
          color: task.taskColor,
          children: childNodes,
        ));
      }
    }

    // Gather finance metrics (static saved snapshot when archived, else calculated)
    double weekIncome = 0, weekExpense = 0, balance = provider.financeActions.currentBalance;
    final savedFinance = currentReportData['saved_finance'] as Map<String, dynamic>?;
    if (savedFinance != null) {
      weekIncome = (savedFinance['income'] as num?)?.toDouble() ?? 0;
      weekExpense = (savedFinance['expense'] as num?)?.toDouble() ?? 0;
      balance = (savedFinance['balance'] as num?)?.toDouble() ?? 0;
    } else {
      for (final t in provider.transactions) {
        if (t.timestamp.isAfter(weekAgo) && t.timestamp.isBefore(now)) {
          if (t.isIncome) {
            weekIncome += t.amount;
          } else {
            weekExpense += t.amount;
          }
        }
      }
    }

    // Gather health metrics
    double totalWater = 0;
    double totalSleepMins = 0;
    double totalWalkKm = 0;
    double totalWorkoutMins = 0;
    for (int i = 0; i < 7; i++) {
      final dStr = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      final log = provider.getDailyHealthLog(dStr);
      totalWater += log.waterGlasses;
      totalSleepMins += log.sleepLogs.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      totalWalkKm += log.activityLogs.fold<double>(0, (sum, a) => sum + a.walkDistanceKm);
      totalWorkoutMins += log.activityLogs.fold<int>(0, (sum, a) => sum + a.workoutMinutes);
    }
    final avgWater = totalWater / 7;
    final avgSleep = totalSleepMins / 7 / 60;

    // Gather people (active/known) grouped by standard DEFAULT category
    final people = provider.chatbotMemory.people;
    const defaultCategories = [
      'FAMILY & PARTNER',
      'FRIENDS',
      'PROFESSIONAL & MENTORS',
      'ACQUAINTANCES & OTHERS',
    ];
    final groupedPeople = <String, List<PersonInfo>>{};
    for (final p in people) {
      final relationCategory = PersonInfo.getRelationCategory(p.relation).toUpperCase();
      groupedPeople.putIfAbsent(relationCategory, () => []).add(p);
    }

    final sortedCategories = groupedPeople.keys.toList()
      ..sort((a, b) {
        final idxA = defaultCategories.indexOf(a);
        final idxB = defaultCategories.indexOf(b);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. COMPLETED TASKS & CHECKPOINTS (INFINITELY NESTED DROPDOWN) ──
        WeeklyCompletedLogWidget(missions: missionNodes),
        const SizedBox(height: 24),

        // ── 2. METRIC DASHBOARDS (FINANCE & HEALTH) ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Finance Brief Card
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionLabel(
                    title: 'FINANCE BRIEF',
                    icon: MdiIcons.currencyInr,
                    color: JweTheme.accentAmber,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.bgBase.withOpacity(0.4),
                      border: Border.all(color: JweTheme.lineSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBriefMetricRow('INFLOW', '₹${weekIncome.toStringAsFixed(0)}', JweTheme.accentTeal),
                        const SizedBox(height: 8),
                        _buildBriefMetricRow('OUTFLOW', '₹${weekExpense.toStringAsFixed(0)}', JweTheme.accentRed),
                        const SizedBox(height: 8),
                        _buildBriefMetricRow('NET INFLOW', '₹${(weekIncome - weekExpense).toStringAsFixed(0)}', (weekIncome - weekExpense) >= 0 ? JweTheme.accentTeal : JweTheme.accentRed),
                        Divider(color: JweTheme.lineSoft, height: 16),
                        _buildBriefMetricRow('BALANCE', '₹${balance.toStringAsFixed(0)}', JweTheme.textWhite),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Health Brief Card
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionLabel(
                    title: 'HEALTH BRIEF',
                    icon: MdiIcons.heartPulse,
                    color: JweTheme.accentCyan,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.bgBase.withOpacity(0.4),
                      border: Border.all(color: JweTheme.lineSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBriefMetricRow('SLEEP AVG', '${avgSleep.toStringAsFixed(1)} H/DAY', JweTheme.accentCyan),
                        const SizedBox(height: 8),
                        _buildBriefMetricRow('WATER AVG', '${avgWater.toStringAsFixed(1)} GL/DAY', JweTheme.accentCyan),
                        const SizedBox(height: 8),
                        _buildBriefMetricRow('WALKS TOTAL', '${totalWalkKm.toStringAsFixed(1)} KM', JweTheme.accentCyan),
                        const SizedBox(height: 8),
                        _buildBriefMetricRow('WORKOUTS', '${(totalWorkoutMins / 60).toStringAsFixed(1)} H', JweTheme.accentCyan),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── 3. INTERACTION BRIEF (CLASSIFIED DROPDOWN) ──
        WeeklyPeopleLogWidget(
          sortedCategories: sortedCategories,
          groupedPeople: groupedPeople,
          provider: provider,
        ),
      ],
    );
  }

  Widget _buildBriefMetricRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.chakraPetch(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
