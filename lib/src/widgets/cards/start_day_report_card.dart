import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/ui/startup_wellbeing_metrics.dart';
import 'package:missions/src/screens/nora_ai_screen.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/models/task_models.dart';

class StartDayReportCard extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback? onRegenerate;
  final bool isRegenerating;

  const StartDayReportCard({
    super.key,
    required this.report,
    this.onRegenerate,
    this.isRegenerating = false,
  });

  @override
  State<StartDayReportCard> createState() => _StartDayReportCardState();
}

class _StartDayReportCardState extends State<StartDayReportCard> {
  bool _isExpanded = false;

  void _startWithNora(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final forecast = widget.report['forecast'] as String? ?? "System Started.";
    final directives = (widget.report['directives'] as List?)?.join(', ') ?? "";

    final customContext = """
    STARTUP CONTEXT:
    Forecast: $forecast
    Directives: $directives

    The user has just initiated the system. Act as a supportive tactical commander or friend to prepare them for the day.
    """;

    provider.createNoraSession(
      title: "STARTUP LINK",
      tone: "Tactician",
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      endDate: DateTime.now(),
      customContext: customContext,
    );

    Navigator.push(context, MaterialPageRoute(builder: (_) => const NoraAiScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final forecast = widget.report['forecast'] as String? ??
        widget.report['briefing'] as String? ??
        "Systems nominal. Ready for input.";
    final directives = (widget.report['directives'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final metrics = widget.report['metrics'] as List<dynamic>?;
    final snapshotTimeStr = widget.report['snapshot_time'] as String?;
    final reportDate = snapshotTimeStr != null ? DateTime.parse(snapshotTimeStr) : DateTime.now();
    final yesterday = reportDate.subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

    return HudPanel(
      clip: HudClip.both,
      accent: JweTheme.accentCyan,
      allBrackets: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: JweTheme.accentCyan.withValues(alpha: 0.22))),
              ),
              child: Row(children: [
                Container(width: 4, height: 14, color: JweTheme.accentCyan),
                const SizedBox(width: 10),
                Icon(MdiIcons.power, color: JweTheme.accentCyan, size: 13),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SYSTEM STARTUP OVERVIEW',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                if (widget.onRegenerate != null && _isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: widget.isRegenerating ? null : widget.onRegenerate,
                      child: widget.isRegenerating
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.4,
                                  valueColor:   AlwaysStoppedAnimation<Color>(
                                      JweTheme.accentCyan)),
                            )
                          : Icon(MdiIcons.refresh,
                              size: 15, color: JweTheme.textMuted),
                    ),
                  ),
                HudDot(tone: HudTone.cyan, size: 5),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                  color: JweTheme.textMuted,
                  size: 18,
                ),
              ]),
            ),
          ),

          // ── Collapsed preview ────────────────────────────
          if (!_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Text(
                forecast,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: JweTheme.textMid,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),

          // ── Expanded body ────────────────────────────────
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Forecast
                  Row(
                    children: [
                      Container(width: 3, height: 10, color: JweTheme.accentCyan),
                      const SizedBox(width: 8),
                      Text('COGNITIVE FORECAST MATRIX',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.bgDeep.withValues(alpha: 0.65),
                      border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      forecast,
                      style: GoogleFonts.inter(
                        color: JweTheme.textWhite,
                        fontSize: 12.5,
                        height: 1.45,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  // Directives
                  if (directives.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(width: 3, height: 10, color: JweTheme.accentAmber),
                      const SizedBox(width: 8),
                      Text('TACTICAL DIRECTIVES',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentAmber,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          )),
                    ]),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: JweTheme.accentAmber.withValues(alpha: 0.04),
                        border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.25)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: directives.map((d) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('> ',
                                      style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.accentAmber,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                  Expanded(
                                    child: Text(d,
                                        style: GoogleFonts.saira(
                                          color: JweTheme.textWhite,
                                          fontSize: 12.5,
                                          height: 1.35,
                                          fontWeight: FontWeight.w500,
                                        )),
                                  ),
                                ],
                              ),
                            )).toList(),
                      ),
                    ),
                  ],

                  // Yesterday's Task Progress
                  const SizedBox(height: 18),
                  _buildYesterdaysTaskProgress(context, provider, yesterdayStr),

                  // Yesterday's Health Data
                  const SizedBox(height: 18),
                  _buildYesterdaysHealthData(context, provider, yesterdayStr),

                  // Metrics
                  if (metrics != null) ...[
                    const SizedBox(height: 18),
                    StartupWellbeingMetrics(metrics: metrics),
                  ],

                  // Recommended Tasks
                  const SizedBox(height: 18),
                  _buildRecommendedTasks(context, provider),

                  // Suggested Interactions
                  _buildSuggestedInteractions(context, provider),

                  const SizedBox(height: 18),

                  // NORA LINK button
                  InkWell(
                    onTap: () => _startWithNora(context),
                    child: ClipPath(
                      clipper: HudCutClipper(clip: HudClip.br, cut: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: JweTheme.accentCyan.withValues(alpha: 0.10),
                          border: Border.all(
                              color: JweTheme.accentCyan.withValues(alpha: 0.45)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(MdiIcons.brain,
                                size: 14, color: JweTheme.accentCyan),
                            const SizedBox(width: 8),
                            Text('INITIATE NORA LINK',
                                style: GoogleFonts.saira(
                                  color: JweTheme.accentCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.6,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.06, end: 0);
  }

  Widget _buildYesterdaysTaskProgress(BuildContext context, AppProvider provider, String yesterdayStr) {
    final yesterdayData = provider.completedByDay[yesterdayStr];
    final completedSubs = yesterdayData?['subtasksCompleted'] as List<dynamic>? ?? [];
    final taskTimes = yesterdayData?['taskTimes'] as Map<dynamic, dynamic>? ?? {};

    bool hasAnyTime = taskTimes.values.any((v) => (v as num) > 0);

    if (completedSubs.isEmpty && !hasAnyTime) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 10, color: JweTheme.accentCyan),
            const SizedBox(width: 8),
            Icon(MdiIcons.history, size: 11, color: JweTheme.accentCyan),
            const SizedBox(width: 5),
            Text(
              'YESTERDAY\'S TASK PROGRESS',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentCyan,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JweTheme.bgBase,
              border: Border.all(color: JweTheme.border),
            ),
            child: Text(
              'No task activity recorded yesterday.',
              style: GoogleFonts.inter(
                color: JweTheme.textMuted,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      );
    }

    // Prepare active time rows
    final timeRows = <Widget>[];
    taskTimes.forEach((taskId, timeSec) {
      final secs = (timeSec as num).toInt();
      if (secs <= 0) return;
      final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == taskId.toString());
      if (mainTask == null) return;

      final mins = secs ~/ 60;
      final timeStr = mins >= 60 ? '${mins ~/ 60}h ${mins % 60}m' : '${mins}m';
      final color = Color(int.parse('0xFF${mainTask.colorHex}'));

      timeRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Row(
            children: [
              Container(width: 4, height: 10, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mainTask.name.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    color: JweTheme.textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                timeStr,
                style: GoogleFonts.robotoMono(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    });

    // Prepare completed subtasks rows
    final subtaskRows = <Widget>[];
    for (final entry in completedSubs) {
      final name = entry['name'] as String? ?? 'Unnamed Objective';
      final parentTaskId = entry['parentTaskId'] as String? ?? '';
      final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == parentTaskId);
      final color = mainTask != null ? Color(int.parse('0xFF${mainTask.colorHex}')) : JweTheme.accentCyan;

      subtaskRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(MdiIcons.checkboxMarkedCircleOutline, size: 13, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.inter(
                    color: JweTheme.textMid,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
              if (mainTask != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    mainTask.name.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 10, color: JweTheme.accentCyan),
          const SizedBox(width: 8),
          Icon(MdiIcons.history, size: 11, color: JweTheme.accentCyan),
          const SizedBox(width: 5),
          Text(
            'YESTERDAY\'S TASK PROGRESS',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.accentCyan,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: JweTheme.bgBase,
            border: Border.all(color: JweTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (timeRows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 10, bottom: 6),
                  child: Text(
                    'ACTIVE TIME LOGGED',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...timeRows,
                const SizedBox(height: 6),
              ],
              if (timeRows.isNotEmpty && subtaskRows.isNotEmpty)
                 Divider(color: JweTheme.lineSoft, height: 1),
              if (subtaskRows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 10, bottom: 6),
                  child: Text(
                    'COMPLETED OBJECTIVES',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...subtaskRows,
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYesterdaysHealthData(BuildContext context, AppProvider provider, String yesterdayStr) {
    final yesterdayHealthLog = provider.getDailyHealthLog(yesterdayStr);

    final sleepLogs = yesterdayHealthLog.sleepLogs;
    final totalSleepMins = sleepLogs.fold<int>(0, (sum, s) => sum + s.durationMinutes);

    final waterGlasses = yesterdayHealthLog.waterGlasses;

    final walkDist = yesterdayHealthLog.activityLogs.fold<double>(0.0, (sum, a) => sum + a.walkDistanceKm);
    final workoutMins = yesterdayHealthLog.activityLogs.fold<int>(0, (sum, a) => sum + a.workoutMinutes);

    final mealsWithFood = yesterdayHealthLog.meals.map((meal) {
      return provider.foodItems.firstWhereOrNull((f) => f.id == meal.foodItemId);
    }).nonNulls.toList();

    final totalCalories = mealsWithFood.fold<int>(0, (sum, f) => sum + f.calories);
    final totalProtein = mealsWithFood.fold<double>(0.0, (sum, f) => sum + f.protein);
    final totalCarbs = mealsWithFood.fold<double>(0.0, (sum, f) => sum + f.carbs);
    final totalFat = mealsWithFood.fold<double>(0.0, (sum, f) => sum + f.fat);

    final hasAnyHealth = totalSleepMins > 0 || waterGlasses > 0 || walkDist > 0 || workoutMins > 0 || totalCalories > 0;

    if (!hasAnyHealth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 10, color: JweTheme.accentTeal),
            const SizedBox(width: 8),
            Icon(MdiIcons.heartPulse, size: 11, color: JweTheme.accentTeal),
            const SizedBox(width: 5),
            Text(
              'YESTERDAY\'S HEALTH DIAGNOSTICS',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentTeal,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JweTheme.bgBase,
              border: Border.all(color: JweTheme.border),
            ),
            child: Text(
              'No health metrics logged yesterday.',
              style: GoogleFonts.inter(
                color: JweTheme.textMuted,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      );
    }

    final sleepStr = totalSleepMins > 0
        ? '${totalSleepMins ~/ 60}h ${totalSleepMins % 60}m'
        : 'No sleep logged';

    final waterStr = waterGlasses > 0
        ? '$waterGlasses glasses'
        : 'No water logged';

    final activityStr = (walkDist > 0 || workoutMins > 0)
        ? '${walkDist > 0 ? "${walkDist.toStringAsFixed(1)} km walked" : ""}${walkDist > 0 && workoutMins > 0 ? " • " : ""}${workoutMins > 0 ? "${workoutMins}m workout" : ""}'
        : 'No activity logged';

    final nutritionStr = totalCalories > 0
        ? '$totalCalories kcal (P: ${totalProtein.toStringAsFixed(1)}g • C: ${totalCarbs.toStringAsFixed(1)}g • F: ${totalFat.toStringAsFixed(1)}g)'
        : 'No nutrition logged';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 10, color: JweTheme.accentTeal),
          const SizedBox(width: 8),
          Icon(MdiIcons.heartPulse, size: 11, color: JweTheme.accentTeal),
          const SizedBox(width: 5),
          Text(
            'YESTERDAY\'S HEALTH DIAGNOSTICS',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.accentTeal,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: JweTheme.bgBase,
            border: Border.all(color: JweTheme.border),
          ),
          child: Column(
            children: [
              _buildHealthRow(MdiIcons.sleep, 'SLEEP', sleepStr, JweTheme.accentCyan, showDivider: true),
              _buildHealthRow(MdiIcons.water, 'HYDRATION', waterStr, JweTheme.accentCyan, showDivider: true),
              _buildHealthRow(MdiIcons.run, 'ACTIVITY', activityStr, JweTheme.accentTeal, showDivider: true),
              _buildHealthRow(MdiIcons.foodApple, 'NUTRITION', nutritionStr, JweTheme.accentWarn, showDivider: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthRow(IconData icon, String label, String value, Color color, {required bool showDivider}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 10),
              SizedBox(
                width: 85,
                child: Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    color: JweTheme.textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
           Divider(color: JweTheme.lineSoft, height: 1),
      ],
    );
  }

  List<({MainTask task, SubTask sub})> getRecommendedTasks(AppProvider provider) {
    final list = <({MainTask task, SubTask sub})>[];
    final todayStr = helper.getTodayDateString();

    for (final task in provider.mainTasks) {
      if (task.isDeleted || !task.isActive) continue;

      // Filter subtasks to active, uncompleted ones
      final uncompletedSubs = task.subTasks.where((sub) {
        if (sub.isDeleted || !sub.isActive) return false;
        if (sub.isRecurring && sub.completed) {
          if (sub.completedDate == todayStr) return false;
        }
        return !sub.completed;
      }).toList();

      if (uncompletedSubs.isEmpty) continue;

      // Score/sort them:
      // 1. Recurring
      // 2. In-progress (has progress > 0 or time spent > 0)
      // 3. Strategic (has description or why/what)
      // 4. Default
      uncompletedSubs.sort((a, b) {
        int scoreA = 0;
        if (a.isRecurring) scoreA += 10;
        if (a.calculateProgress() > 0.0 || a.currentTimeSpent > 0) scoreA += 5;
        if (a.why.isNotEmpty || a.what.isNotEmpty) scoreA += 2;

        int scoreB = 0;
        if (b.isRecurring) scoreB += 10;
        if (b.calculateProgress() > 0.0 || b.currentTimeSpent > 0) scoreB += 5;
        if (b.why.isNotEmpty || b.what.isNotEmpty) scoreB += 2;

        return scoreB.compareTo(scoreA); // descending
      });

      // Pick top 1 or 2 from this mission
      final countToTake = uncompletedSubs.length >= 2 ? 2 : uncompletedSubs.length;
      for (int i = 0; i < countToTake; i++) {
        list.add((task: task, sub: uncompletedSubs[i]));
      }
    }

    // Sort the final recommendations list: show recurring first, then in-progress, etc.
    list.sort((a, b) {
      int scoreA = 0;
      if (a.sub.isRecurring) scoreA += 10;
      if (a.sub.calculateProgress() > 0.0 || a.sub.currentTimeSpent > 0) scoreA += 5;

      int scoreB = 0;
      if (b.sub.isRecurring) scoreB += 10;
      if (b.sub.calculateProgress() > 0.0 || b.sub.currentTimeSpent > 0) scoreB += 5;

      return scoreB.compareTo(scoreA);
    });

    return list;
  }

  Widget _buildRecommendedTasks(BuildContext context, AppProvider provider) {
    final recommendations = getRecommendedTasks(provider);
    final todayStr = helper.getTodayDateString();
    final plan = List<String>.from(provider.taskActions.getDayPlan(todayStr));

    if (recommendations.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 10, color: JweTheme.accentWarn),
            const SizedBox(width: 8),
            Icon(MdiIcons.starOutline, size: 11, color: JweTheme.accentWarn),
            const SizedBox(width: 5),
            Text(
              'TACTICAL RECOMMENDATIONS',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentWarn,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JweTheme.bgBase,
              border: Border.all(color: JweTheme.border),
            ),
            child: Text(
              'No recommendations available. All tasks completed!',
              style: GoogleFonts.inter(
                color: JweTheme.textMuted,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 10, color: JweTheme.accentWarn),
          const SizedBox(width: 8),
          Icon(MdiIcons.starOutline, size: 11, color: JweTheme.accentWarn),
          const SizedBox(width: 5),
          Text(
            'TACTICAL RECOMMENDATIONS',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.accentWarn,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: JweTheme.bgBase,
            border: Border.all(color: JweTheme.border),
          ),
          child: Column(
            children: List.generate(recommendations.length, (index) {
              final rec = recommendations[index];
              final task = rec.task;
              final sub = rec.sub;
              final color = Color(int.parse('0xFF${task.colorHex}'));

              final compoundId = '${task.id}|${sub.id}';
              final isQueued = plan.contains(compoundId);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Row(
                      children: [
                        Container(width: 4, height: 12, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sub.name,
                                style: GoogleFonts.inter(
                                  color: JweTheme.textWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    task.name.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      color: color,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (sub.isRecurring) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: JweTheme.accentCyan.withValues(alpha: 0.1),
                                        border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        'RECURRING',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.accentCyan,
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (sub.calculateProgress() > 0.0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: JweTheme.accentTeal.withValues(alpha: 0.1),
                                        border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        '${(sub.calculateProgress() * 100).toInt()}% DONE',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.accentTeal,
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            isQueued ? MdiIcons.minus : MdiIcons.plus,
                            size: 16,
                            color: isQueued ? JweTheme.accentRed : JweTheme.accentCyan,
                          ),
                          tooltip: isQueued ? 'Remove from Day Plan' : 'Add to Day Plan',
                          style: IconButton.styleFrom(
                            backgroundColor: (isQueued ? JweTheme.accentRed : JweTheme.accentCyan).withValues(alpha: 0.08),
                            padding: const EdgeInsets.all(6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            if (isQueued) {
                              plan.remove(compoundId);
                            } else {
                              plan.add(compoundId);
                            }
                            provider.taskActions.updateDayPlan(todayStr, plan);
                          },
                        ),
                      ],
                    ),
                  ),
                  if (index < recommendations.length - 1)
                     Divider(color: JweTheme.lineSoft, height: 1),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestedInteractions(BuildContext context, AppProvider provider) {
    final now = DateTime.now();
    final logs = provider.reflectionLogs;
    final people = provider.chatbotMemory.people;

    if (people.isEmpty) return const SizedBox.shrink();

    // Map to keep track of recommendations
    final recommendations = <Map<String, dynamic>>[];

    for (final person in people) {
      final personNameLower = person.name.toLowerCase();
      final personLogs = logs.where((l) {
        final text = '${l.trigger} ${l.emotion} ${l.reason} ${l.action}'.toLowerCase();
        return text.contains(personNameLower);
      }).toList();

      personLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (personLogs.isNotEmpty) {
        final latestLog = personLogs.first;
        final daysSince = now.difference(latestLog.timestamp).inDays;

        if (daysSince > 7 && daysSince <= 21) {
          recommendations.add({
            'name': person.name,
            'relation': person.relation,
            'type': 'RECONNECT',
            'reason': 'No contact recorded in $daysSince days. Plan a check-in.',
            'icon': MdiIcons.accountClockOutline,
            'color': JweTheme.accentAmber,
          });
        } else if (daysSince <= 7) {
          final negEmotions = ['stressed', 'anxious', 'sad', 'angry', 'overwhelmed', 'tired', 'frustrated', 'worried'];
          final isNeg = negEmotions.any((e) => latestLog.emotion.toLowerCase().contains(e) || latestLog.reason.toLowerCase().contains(e));
          if (isNeg) {
            recommendations.add({
              'name': person.name,
              'relation': person.relation,
              'type': 'FOLLOW UP',
              'reason': 'Follow up regarding recent tension or stress.',
              'icon': MdiIcons.heartHalfFull,
              'color': JweTheme.accentRed,
            });
          } else {
            recommendations.add({
              'name': person.name,
              'relation': person.relation,
              'type': 'APPRECIATION',
              'reason': 'Keep the momentum going. Share a quick word of support.',
              'icon': MdiIcons.heartFlash,
              'color': JweTheme.accentTeal,
            });
          }
        }
      } else {
        recommendations.add({
          'name': person.name,
          'relation': person.relation,
          'type': 'STAY IN TOUCH',
          'reason': 'No recent reflection logs mention them. Ping to catch up.',
          'icon': MdiIcons.accountNetworkOutline,
          'color': JweTheme.accentCyan,
        });
      }
    }

    recommendations.shuffle();
    final displaySuggestions = recommendations.take(3).toList();

    if (displaySuggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Row(children: [
          Container(width: 3, height: 10, color: JweTheme.accentCyan),
          const SizedBox(width: 8),
          Icon(MdiIcons.accountMultipleOutline, size: 11, color: JweTheme.accentCyan),
          const SizedBox(width: 5),
          Text(
            'SUGGESTED INTERACTIONS (PEOPLE)',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.accentCyan,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: JweTheme.bgDeep.withValues(alpha: 0.65),
            border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: displaySuggestions.map((s) {
              final color = s['color'] as Color;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(s['icon'] as IconData, size: 14, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                (s['name'] as String).toUpperCase(),
                                style: GoogleFonts.saira(
                                  color: JweTheme.textWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${s['relation']})',
                                style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.textMuted,
                                  fontSize: 8.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  border: Border.all(color: color.withValues(alpha: 0.5)),
                                  color: color.withValues(alpha: 0.08),
                                ),
                                child: Text(
                                  s['type'] as String,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: color,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s['reason'] as String,
                            style: GoogleFonts.inter(
                              color: JweTheme.textMid,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
