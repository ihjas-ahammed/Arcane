import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/widgets/header_widget.dart';
import 'package:missions/src/widgets/analytics/jwe_date_selector.dart';

/// Goals & Metrics Operator Drawer
/// Logbook-themed tactical HUD replica with date/period clean sheets,
/// subchecklists support, manual count input, and accurate progress tracking.
class GoalsBottomDrawer extends StatefulWidget {
  final DateTime? initialDate;

  const GoalsBottomDrawer({super.key, this.initialDate});

  static Future<void> show(BuildContext context, {DateTime? initialDate}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: JweTheme.isLight ? 0.4 : 0.65),
      builder: (ctx) => GoalsBottomDrawer(initialDate: initialDate),
    );
  }

  @override
  State<GoalsBottomDrawer> createState() => _GoalsBottomDrawerState();
}

class _GoalsBottomDrawerState extends State<GoalsBottomDrawer> {
  GoalScope _activeScope = GoalScope.daily;
  late DateTime _selectedDate;
  final Map<String, bool> _expandedSublists = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  /// Calculates spent time in minutes for linked tasks based on session time
  double _calculateLinkedTimeMinutes(AppProvider provider, GoalModel goal) {
    if (goal.linkedTaskIds.isEmpty) return goal.currentValue;

    double totalMinutes = 0.0;
    final activeMainTasks = provider.mainTasks.where((t) => t.isActive && !t.isDeleted);

    for (var mainTask in activeMainTasks) {
      final bool mainLinked = goal.linkedTaskIds.contains(mainTask.id);

      for (var subTask in mainTask.subTasks) {
        if (subTask.isDeleted) continue;
        final subCompoundId = '${mainTask.id}|${subTask.id}';
        final bool subLinked = mainLinked ||
            goal.linkedTaskIds.contains(subTask.id) ||
            goal.linkedTaskIds.contains(subCompoundId);

        if (subLinked) {
          totalMinutes += subTask.currentTimeSpent > 0
              ? (subTask.currentTimeSpent / 60.0)
              : 0.0;
        }
      }
    }
    return totalMinutes;
  }

  void _openCreateGoalDialog(BuildContext context, {GoalModel? goalToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateGoalSheet(
        initialScope: goalToEdit?.scope ?? _activeScope,
        selectedDate: goalToEdit?.startDateTime ?? _selectedDate,
        goalToEdit: goalToEdit,
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, Color themeColor) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: themeColor,
              onPrimary: Colors.black,
              surface: const Color(0xFF14151E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isLight = JweTheme.isLight;
    final themeColor = appProvider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;

    // Get period goals for current selected date & scope
    final goals = appProvider.getGoalsForDate(_selectedDate, _activeScope);

    final completedCount = goals.where((g) {
      final timeMins = _calculateLinkedTimeMinutes(appProvider, g);
      return g.getIsEffectiveCompleted(dynamicTimeMinutes: timeMins);
    }).length;

    final totalXp = goals.fold<int>(0, (sum, g) {
      final timeMins = _calculateLinkedTimeMinutes(appProvider, g);
      final isDone = g.getIsEffectiveCompleted(dynamicTimeMinutes: timeMins);
      return sum + (isDone ? g.xpReward : 0);
    });

    final double overallProgressRatio = goals.isEmpty
        ? 0.0
        : goals.fold<double>(0.0, (sum, g) {
            final timeMins = _calculateLinkedTimeMinutes(appProvider, g);
            return sum + g.getProgressRatio(dynamicTimeMinutes: timeMins);
          }) / goals.length;

    final sheetBg = isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14);
    final periodKeyStr = GoalModel.getPeriodKey(_activeScope, _selectedDate);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: themeColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: isLight ? 0.12 : 0.25),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Top Handle Bar
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 12),

              // Header Row: Left Icon Box, Non-Overflowing Titles, Right XP Badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1.2),
                      ),
                      child: Center(
                        child: ArcaneAppIcon(
                          size: 22,
                          color: themeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.orbitron(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'GOALS & METRICS ',
                                    style: TextStyle(color: isLight ? Colors.black87 : Colors.white),
                                  ),
                                  TextSpan(
                                    text: 'OPERATOR',
                                    style: TextStyle(color: themeColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Period: $periodKeyStr · Track count, time & subchecklists',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              color: isLight ? const Color(0xFF475569) : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          ArcaneAppIcon(size: 13, color: themeColor),
                          const SizedBox(width: 4),
                          Text(
                            '+$totalXp XP',
                            style: GoogleFonts.orbitron(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Date Inspection Bar (Logbook Theme)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: JweDateSelector(
                  dateStr: DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                  accentColor: themeColor,
                  onTap: () => _pickDate(context, themeColor),
                ),
              ),

              const SizedBox(height: 10),

              // 3 Custom Scope Tabs: DAILY, WEEKLY, MONTHLY
              _buildScopeTabRow(themeColor, isLight),

              const SizedBox(height: 10),

              // Overview Progress Banner
              _buildProgressBanner(themeColor, isLight, overallProgressRatio, completedCount, goals.length),

              const SizedBox(height: 10),

              // Goals List Body
              Expanded(
                child: goals.isEmpty
                    ? _buildEmptyState(isLight, themeColor)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: goals.length,
                        itemBuilder: (ctx, i) {
                          final goal = goals[i];
                          final timeMins = _calculateLinkedTimeMinutes(appProvider, goal);
                          return Dismissible(
                            key: ValueKey(goal.id),
                            direction: DismissDirection.horizontal,
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                appProvider.toggleGoalCheck(goal.id);
                                if (!goal.isCompleted) {
                                  showGlobalToast('⚡ Goal Completed! +${goal.xpReward} XP');
                                } else {
                                  showGlobalToast('Goal marked incomplete');
                                }
                                return false;
                              }
                              return true;
                            },
                            onDismissed: (direction) {
                              if (direction == DismissDirection.endToStart) {
                                appProvider.deleteGoal(goal.id);
                                showGlobalToast('Goal deleted');
                              }
                            },
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.only(left: 16),
                              alignment: Alignment.centerLeft,
                              decoration: BoxDecoration(
                                color: AppTheme.fhAccentGreen.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(MdiIcons.checkboxMarkedCircle, color: Colors.white, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    'COMPLETE',
                                    style: GoogleFonts.orbitron(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            secondaryBackground: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.only(right: 16),
                              alignment: Alignment.centerRight,
                              decoration: BoxDecoration(
                                color: JweTheme.accentRed.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(MdiIcons.deleteOutline, color: Colors.white, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    'DELETE',
                                    style: GoogleFonts.orbitron(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            child: _buildTacticalGoalCard(
                                context, appProvider, goal, timeMins, themeColor, isLight),
                          );
                        },
                      ),
              ),

              // Bottom Primary Action Button
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 10,
                ),
                child: ElevatedButton(
                  onPressed: () => _openCreateGoalDialog(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    backgroundColor: themeColor,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shadowColor: themeColor.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, size: 18, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        'INITIALIZE NEW ${_activeScope.name.toUpperCase()} GOAL',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Custom Scope Segmented Tab Row
  Widget _buildScopeTabRow(Color themeColor, bool isLight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFE8E4DA) : const Color(0xFF14151E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.12)
                : JweTheme.lineSoft.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: GoalScope.values.asMap().entries.map((entry) {
            final idx = entry.key;
            final scope = entry.value;
            final isSelected = scope == _activeScope;
            final label = scope.name.toUpperCase();

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  border: idx < GoalScope.values.length - 1 && !isSelected
                      ? Border(
                          right: BorderSide(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        )
                      : null,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeScope = scope;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? themeColor.withValues(alpha: isLight ? 0.22 : 0.20)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected
                          ? Border.all(color: themeColor, width: 1.2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: GoogleFonts.orbitron(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: isSelected
                              ? (isLight ? Colors.black87 : Colors.white)
                              : (isLight ? const Color(0xFF475569) : const Color(0xFF8E9BAE)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Overview Progress Banner Container
  Widget _buildProgressBanner(
    Color themeColor,
    bool isLight,
    double progressRatio,
    int completedCount,
    int totalCount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF12131C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.1)
                : JweTheme.lineSoft.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${_activeScope.name.toUpperCase()} PROGRESS',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.orbitron(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isLight ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$completedCount / $totalCount COMPLETED (${(progressRatio * 100).toInt()}%)',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 8,
              width: double.infinity,
              child: CustomPaint(
                painter: _TacticalProgressBarPainter(
                  progress: progressRatio,
                  activeColor: themeColor,
                  isLight: isLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLight, Color themeColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            MdiIcons.target,
            size: 40,
            color: themeColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 10),
          Text(
            'NO ${_activeScope.name.toUpperCase()} GOALS FOR THIS PERIOD',
            style: GoogleFonts.orbitron(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isLight ? Colors.black54 : Colors.white60,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the button below to initialize a clean goal sheet',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: isLight ? Colors.black45 : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalGoalCard(
    BuildContext context,
    AppProvider appProvider,
    GoalModel goal,
    double timeMins,
    Color themeColor,
    bool isLight,
  ) {
    final isDone = goal.getIsEffectiveCompleted(dynamicTimeMinutes: timeMins);
    final ratio = goal.getProgressRatio(dynamicTimeMinutes: timeMins);
    final isSubExpanded = _expandedSublists[goal.id] ?? false;

    return GestureDetector(
      onLongPress: () => _openCreateGoalDialog(context, goalToEdit: goal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: CustomPaint(
          painter: _TacticalCardPainter(
            activeColor: themeColor,
            isLight: isLight,
            isDone: isDone,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Goal Title on left, Metric Badge on top right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        goal.title,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          color: isDone
                              ? (isLight ? Colors.black45 : Colors.white54)
                              : (isLight ? Colors.black87 : Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricBadge(goal.metricType, themeColor),
                  ],
                ),
                const SizedBox(height: 4),

                // XP Badge, Recurring Tag & Linked Tasks
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '+${goal.xpReward} XP',
                      style: GoogleFonts.orbitron(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                    if (goal.isRecurring) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: JweTheme.accentTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'RECURRING',
                          style: GoogleFonts.orbitron(fontSize: 8.5, color: JweTheme.accentTeal, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    if (goal.linkedTaskIds.isNotEmpty) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MdiIcons.linkVariant, size: 11, color: isLight ? Colors.black54 : Colors.white54),
                          const SizedBox(width: 3),
                          Text(
                            '${goal.linkedTaskIds.length} Linked Task(s)',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              color: isLight ? Colors.black54 : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),

              const SizedBox(height: 8),

              // Metric Specific Operations
              if (goal.metricType == GoalMetricType.check) ...[
                SizedBox(
                  height: 6,
                  child: CustomPaint(
                    size: const Size(double.infinity, 6),
                    painter: _TacticalProgressBarPainter(
                      progress: ratio,
                      activeColor: isDone ? AppTheme.fhAccentGreen : themeColor,
                      isLight: isLight,
                    ),
                  ),
                ),
              ] else if (goal.metricType == GoalMetricType.counter) ...[
                Row(
                  children: [
                    InkWell(
                      onTap: () => appProvider.updateGoalCounter(goal.id, -1),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF1C1E2A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.remove, size: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: themeColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${goal.currentValue.toInt()} / ${goal.targetValue.toInt()}',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDone ? AppTheme.fhAccentGreen : themeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        appProvider.updateGoalCounter(goal.id, 1);
                        if (goal.currentValue + 1 >= goal.targetValue) {
                          showGlobalToast('⚡ Counter Target Reached! +${goal.xpReward} XP');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF1C1E2A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.add, size: 14),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 7,
                        child: CustomPaint(
                          size: const Size(double.infinity, 7),
                          painter: _TacticalProgressBarPainter(
                            progress: ratio,
                            activeColor: isDone ? AppTheme.fhAccentGreen : themeColor,
                            isLight: isLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (goal.metricType == GoalMetricType.timeCounter) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'LOGGED: ',
                              style: GoogleFonts.orbitron(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isLight ? Colors.black87 : Colors.white,
                              ),
                            ),
                            Text(
                              '${timeMins.toInt()}m / ${goal.targetValue.toInt()}m Target',
                              style: GoogleFonts.orbitron(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isDone ? AppTheme.fhAccentGreen : themeColor,
                              ),
                            ),
                          ],
                        ),
                        if (goal.startDateTime != null)
                          Text(
                            'From: ${DateFormat('MM/dd HH:mm').format(goal.startDateTime!)}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              color: isLight ? Colors.black54 : Colors.white54,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 7,
                      child: CustomPaint(
                        size: const Size(double.infinity, 7),
                        painter: _TacticalProgressBarPainter(
                          progress: ratio,
                          activeColor: isDone ? AppTheme.fhAccentGreen : themeColor,
                          isLight: isLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (goal.metricType == GoalMetricType.check) ...[
                const SizedBox(height: 8),
                _buildSubchecklistWidget(context, appProvider, goal, isSubExpanded, themeColor, isLight),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSubchecklistWidget(
    BuildContext context,
    AppProvider appProvider,
    GoalModel goal,
    bool isExpanded,
    Color themeColor,
    bool isLight,
  ) {
    final completedCount = goal.subChecklist.where((i) => i.isCompleted).length;
    final totalCount = goal.subChecklist.length;
    final subRatio = totalCount == 0 ? 0.0 : (completedCount / totalCount);

    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.black.withValues(alpha: 0.03) : const Color(0xFF0F1018),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subchecklist Header Bar
          InkWell(
            onTap: () {
              setState(() {
                _expandedSublists[goal.id] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 16,
                    color: themeColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SUBCHECKLIST',
                    style: GoogleFonts.orbitron(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isLight ? Colors.black87 : Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$completedCount/$totalCount (${(subRatio * 100).toInt()}%)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(MdiIcons.playlistPlus, size: 14, color: themeColor),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1, thickness: 0.8),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                children: [
                  ...goal.subChecklist.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              appProvider.toggleGoalSubCheckItem(goal.id, item.id);
                            },
                            child: Icon(
                              item.isCompleted
                                  ? MdiIcons.checkboxMarkedCircleOutline
                                  : MdiIcons.checkboxBlankCircleOutline,
                              size: 15,
                              color: item.isCompleted ? AppTheme.fhAccentGreen : themeColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                color: item.isCompleted
                                    ? (isLight ? Colors.black38 : Colors.white38)
                                    : (isLight ? Colors.black87 : Colors.white),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              appProvider.deleteGoalSubCheckItem(goal.id, item.id);
                            },
                            child: Icon(Icons.close, size: 14, color: isLight ? Colors.black38 : Colors.white38),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 6),

                  // Add Subchecklist Item Input Row
                  _AddSubCheckItemRow(
                    goalId: goal.id,
                    themeColor: themeColor,
                    isLight: isLight,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBadge(GoalMetricType type, Color themeColor) {
    IconData icon;
    String label;

    switch (type) {
      case GoalMetricType.check:
        icon = MdiIcons.target;
        label = 'CHECK';
        break;
      case GoalMetricType.counter:
        icon = MdiIcons.counter;
        label = 'COUNTER';
        break;
      case GoalMetricType.timeCounter:
        icon = MdiIcons.clockOutline;
        label = 'TIME';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: themeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: themeColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSubCheckItemRow extends StatefulWidget {
  final String goalId;
  final Color themeColor;
  final bool isLight;

  const _AddSubCheckItemRow({
    required this.goalId,
    required this.themeColor,
    required this.isLight,
  });

  @override
  State<_AddSubCheckItemRow> createState() => _AddSubCheckItemRowState();
}

class _AddSubCheckItemRowState extends State<_AddSubCheckItemRow> {
  final _subController = TextEditingController();

  @override
  void dispose() {
    _subController.dispose();
    super.dispose();
  }

  void _submit(AppProvider provider) {
    final text = _subController.text.trim();
    if (text.isNotEmpty) {
      provider.addGoalSubCheckItem(widget.goalId, text);
      _subController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _subController,
            onSubmitted: (_) => _submit(provider),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              color: widget.isLight ? Colors.black87 : Colors.white,
            ),
            decoration: InputDecoration(
              hintText: '+ Add subchecklist task...',
              hintStyle: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: widget.isLight ? Colors.black38 : Colors.white38,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: widget.themeColor.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => _submit(provider),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: widget.themeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'ADD',
              style: GoogleFonts.orbitron(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom Slanted Progress Bar Painter with Slit Cutouts (///)
class _TacticalProgressBarPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final bool isLight;

  _TacticalProgressBarPainter({
    required this.progress,
    required this.activeColor,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;
    final clamped = progress.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = isLight ? Colors.black.withValues(alpha: 0.08) : const Color(0xFF1B1D28)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isLight
          ? Colors.black.withValues(alpha: 0.15)
          : JweTheme.lineSoft.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final RRect trackRect = RRect.fromLTRBR(0, 0, W, H, const Radius.circular(2));
    canvas.drawRRect(trackRect, trackPaint);
    canvas.drawRRect(trackRect, borderPaint);

    if (clamped <= 0) return;

    final fillW = W * clamped;

    final fillPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final RRect fillRect = RRect.fromLTRBR(0, 0, fillW, H, const Radius.circular(2));
    canvas.drawRRect(fillRect, fillPaint);

    // Slanted end cap lines /// (if progress fill > 16px)
    if (fillW > 16) {
      final slitPaint = Paint()
        ..color = isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      for (int i = 0; i < 3; i++) {
        final x = fillW - 4 - (i * 3.5);
        canvas.drawLine(Offset(x, 0.5), Offset(x - 2.5, H - 0.5), slitPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.isLight != isLight;
  }
}

/// Custom Painter for Tactical Goal Card Chassis with Chamfered Corners & Left Color Bar
class _TacticalCardPainter extends CustomPainter {
  final Color activeColor;
  final bool isLight;
  final bool isDone;

  _TacticalCardPainter({
    required this.activeColor,
    required this.isLight,
    required this.isDone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;
    final chamfer = 12.0;

    final cardColor = isDone ? AppTheme.fhAccentGreen : activeColor;

    final bgPaint = Paint()
      ..color = isLight ? const Color(0xFFEDE9DF) : const Color(0xFF11121A)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = cardColor.withValues(alpha: isDone ? 0.8 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..moveTo(chamfer, 0)
      ..lineTo(W - 4, 0)
      ..lineTo(W, 4)
      ..lineTo(W, H - 4)
      ..lineTo(W - 4, H)
      ..lineTo(4, H)
      ..lineTo(0, H - 4)
      ..lineTo(0, chamfer)
      ..close();

    canvas.drawPath(path, bgPaint);
    canvas.drawPath(path, borderPaint);

    final accentPaint = Paint()
      ..color = cardColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final leftBar = Path()
      ..moveTo(chamfer, 0)
      ..lineTo(0, chamfer)
      ..lineTo(0, H / 2);

    canvas.drawPath(leftBar, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _TacticalCardPainter oldDelegate) {
    return oldDelegate.activeColor != activeColor ||
        oldDelegate.isLight != isLight ||
        oldDelegate.isDone != isDone;
  }
}

/// Create / Edit Goal Form Bottom Sheet (with Slider + Manual Input Field & Subchecklist planner)
class _CreateGoalSheet extends StatefulWidget {
  final GoalScope initialScope;
  final DateTime selectedDate;
  final GoalModel? goalToEdit;

  const _CreateGoalSheet({
    required this.initialScope,
    required this.selectedDate,
    this.goalToEdit,
  });

  @override
  State<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<_CreateGoalSheet> {
  final _titleController = TextEditingController();
  final _filterController = TextEditingController();
  final _targetValueController = TextEditingController();
  late GoalScope _selectedScope;
  GoalMetricType _selectedMetric = GoalMetricType.check;
  double _targetValue = 1.0;
  bool _isRecurring = false;
  DateTime? _startDateTime;
  final Set<String> _selectedTaskIds = {};
  String _taskSearchQuery = '';
  final Map<String, bool> _expandedTasks = {};
  final List<String> _initialSubItems = [];
  final _newSubController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedScope = widget.goalToEdit?.scope ?? widget.initialScope;
    _startDateTime = widget.goalToEdit?.startDateTime ?? widget.selectedDate;
    if (widget.goalToEdit != null) {
      final g = widget.goalToEdit!;
      _titleController.text = g.title;
      _selectedMetric = g.metricType;
      _targetValue = g.targetValue;
      _targetValueController.text = g.targetValue.toInt().toString();
      _isRecurring = g.isRecurring;
      _selectedTaskIds.addAll(g.linkedTaskIds);
      _initialSubItems.addAll(g.subChecklist.map((s) => s.title));
    } else {
      _targetValueController.text = '1';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _filterController.dispose();
    _targetValueController.dispose();
    _newSubController.dispose();
    super.dispose();
  }

  void _onTargetValueInputChanged(String text) {
    final val = double.tryParse(text);
    if (val != null && val > 0) {
      setState(() {
        _targetValue = val;
      });
    }
  }

  void _onSliderChanged(double val) {
    setState(() {
      _targetValue = val;
      _targetValueController.text = val.toInt().toString();
    });
  }

  void _saveGoal(AppProvider provider) {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showGlobalToast('Please enter a goal title');
      return;
    }

    final periodKey = GoalModel.getPeriodKey(_selectedScope, _startDateTime ?? DateTime.now());

    if (widget.goalToEdit != null) {
      final existingGoal = widget.goalToEdit!;
      final existingSubTitles = existingGoal.subChecklist.map((s) => s.title).toSet();
      final updatedSubChecklist = List<GoalSubCheckItem>.from(existingGoal.subChecklist);

      for (var t in _initialSubItems) {
        if (!existingSubTitles.contains(t)) {
          updatedSubChecklist.add(GoalSubCheckItem(
            id: 'sub_${DateTime.now().millisecondsSinceEpoch}_${t.hashCode}',
            title: t,
            isCompleted: false,
          ));
        }
      }

      final updatedGoal = existingGoal.copyWith(
        title: title,
        scope: _selectedScope,
        metricType: _selectedMetric,
        targetValue: _targetValue <= 0 ? 1.0 : _targetValue,
        startDateTime: _startDateTime,
        linkedTaskIds: _selectedTaskIds.toList(),
        dateKey: periodKey,
        isRecurring: _isRecurring,
        subChecklist: updatedSubChecklist,
      );

      provider.updateGoal(updatedGoal);
      Navigator.of(context).pop();
      showGlobalToast('Goal updated!');
    } else {
      final subItems = _initialSubItems
          .map((t) => GoalSubCheckItem(
                id: 'sub_${DateTime.now().millisecondsSinceEpoch}_${t.hashCode}',
                title: t,
                isCompleted: false,
              ))
          .toList();

      final goal = GoalModel(
        id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        scope: _selectedScope,
        metricType: _selectedMetric,
        targetValue: _targetValue <= 0 ? 1.0 : _targetValue,
        startDateTime: _startDateTime,
        linkedTaskIds: _selectedTaskIds.toList(),
        xpReward: 50,
        dateKey: periodKey,
        isRecurring: _isRecurring,
        subChecklist: subItems,
      );

      provider.addGoal(goal);
      Navigator.of(context).pop();
      showGlobalToast('New Goal Initialized!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isLight = JweTheme.isLight;
    final themeColor = appProvider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;
    final sheetBg = isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14);

    final activeTasks = appProvider.mainTasks
        .where((t) => t.isActive && !t.isDeleted)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: themeColor, width: 1.5),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.goalToEdit != null ? 'EDIT GOAL PROTOCOL' : 'INITIALIZE NEW GOAL',
                    style: GoogleFonts.orbitron(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title Field
              TextField(
                controller: _titleController,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.5,
                  color: isLight ? Colors.black87 : Colors.white,
                ),
                decoration: InputDecoration(
                  labelText: 'GOAL TITLE',
                  hintText: 'e.g., Complete 3 Coding Checkpoints',
                  labelStyle: GoogleFonts.orbitron(fontSize: 10, color: themeColor),
                  filled: true,
                  fillColor: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 14),

              // Scope Selector
              Text(
                'TARGET SCOPE',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isLight ? const Color(0xFF475569) : Colors.white60,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: GoalScope.values.map((scope) {
                  final selected = scope == _selectedScope;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        label: Text(
                          scope.name.toUpperCase(),
                          style: GoogleFonts.orbitron(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? Colors.black
                                : (isLight ? const Color(0xFF475569) : Colors.white60),
                          ),
                        ),
                        selected: selected,
                        selectedColor: themeColor,
                        onSelected: (_) => setState(() => _selectedScope = scope),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // Metric Type Selector
              Text(
                'METRIC TYPE',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isLight ? const Color(0xFF475569) : Colors.white60,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: GoalMetricType.values.map((metric) {
                  final selected = metric == _selectedMetric;
                  String label = 'CHECK';
                  if (metric == GoalMetricType.counter) label = 'COUNTER';
                  if (metric == GoalMetricType.timeCounter) label = 'TIME COUNTER';

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        label: Text(
                          label,
                          style: GoogleFonts.orbitron(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? Colors.black
                                : (isLight ? const Color(0xFF475569) : Colors.white60),
                          ),
                        ),
                        selected: selected,
                        selectedColor: themeColor,
                        onSelected: (_) => setState(() => _selectedMetric = metric),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // Metric Specific Settings (Slider + Manual Input)
              if (_selectedMetric == GoalMetricType.counter) ...[
                Text(
                  'TARGET COUNT',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLight ? const Color(0xFF475569) : Colors.white60,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Slider(
                        value: _targetValue.clamp(1.0, 100.0),
                        min: 1.0,
                        max: 100.0,
                        divisions: 99,
                        activeColor: themeColor,
                        onChanged: _onSliderChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _targetValueController,
                        keyboardType: TextInputType.number,
                        onChanged: _onTargetValueInputChanged,
                        style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor),
                        decoration: InputDecoration(
                          labelText: 'COUNT',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_selectedMetric == GoalMetricType.timeCounter) ...[
                Text(
                  'TARGET TIME DURATION (MINUTES)',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLight ? const Color(0xFF475569) : Colors.white60,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Slider(
                        value: _targetValue.clamp(5.0, 480.0),
                        min: 5.0,
                        max: 480.0,
                        divisions: 95,
                        activeColor: themeColor,
                        onChanged: _onSliderChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _targetValueController,
                        keyboardType: TextInputType.number,
                        onChanged: _onTargetValueInputChanged,
                        style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor),
                        decoration: InputDecoration(
                          labelText: 'MINS',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Recurring Toggle Switch
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: themeColor,
                title: Text(
                  'RECUR EVERY PERIOD (CLEAN SHEET)',
                  style: GoogleFonts.orbitron(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isLight ? Colors.black87 : Colors.white,
                  ),
                ),
                subtitle: Text(
                  'Auto-creates a fresh goal instance for each new day/week/month',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    color: isLight ? Colors.black45 : Colors.white38,
                  ),
                ),
                value: _isRecurring,
                onChanged: (val) => setState(() => _isRecurring = val),
              ),

              const SizedBox(height: 12),

              // INITIAL SUBCHECKLIST CREATION (ONLY FOR CHECK GOALS)
              if (_selectedMetric == GoalMetricType.check) ...[
                Text(
                  'SUBCHECKLIST TASKS (OPTIONAL)',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLight ? const Color(0xFF475569) : Colors.white60,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _initialSubItems.map((item) {
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: themeColor.withValues(alpha: 0.15),
                      side: BorderSide(color: themeColor),
                      label: Text(
                        item,
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: isLight ? Colors.black87 : Colors.white),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        setState(() => _initialSubItems.remove(item));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newSubController,
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: isLight ? Colors.black87 : Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type sub-task & press Add...',
                          isDense: true,
                          filled: true,
                          fillColor: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.black),
                      onPressed: () {
                        final t = _newSubController.text.trim();
                        if (t.isNotEmpty) {
                          setState(() {
                            _initialSubItems.add(t);
                            _newSubController.clear();
                          });
                        }
                      },
                      child: const Text('ADD'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // PLANNER-STYLE TASK SELECTOR
              Text(
                'LINK TASKS (OPTIONAL)',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isLight ? const Color(0xFF475569) : Colors.white60,
                ),
              ),
              const SizedBox(height: 6),

              if (_selectedTaskIds.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selectedTaskIds.map<Widget>((id) {
                    final label = _getTaskNameById(activeTasks, id);
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: themeColor.withValues(alpha: 0.18),
                      side: BorderSide(color: themeColor),
                      label: Text(
                        label,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLight ? Colors.black87 : Colors.white,
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        setState(() => _selectedTaskIds.remove(id));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              TextField(
                controller: _filterController,
                onChanged: (v) => setState(() => _taskSearchQuery = v.trim().toLowerCase()),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: isLight ? Colors.black87 : Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Filter tasks...',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  isDense: true,
                  filled: true,
                  fillColor: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: themeColor.withValues(alpha: 0.3)),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.12)
                        : JweTheme.lineSoft.withValues(alpha: 0.5),
                  ),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: _buildTaskTreeNodes(activeTasks, themeColor, isLight),
                ),
              ),

              const SizedBox(height: 18),

              ElevatedButton(
                onPressed: () => _saveGoal(appProvider),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  backgroundColor: themeColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  widget.goalToEdit != null ? 'SAVE GOAL' : 'CREATE GOAL',
                  style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTaskNameById(List<MainTask> tasks, String id) {
    for (var main in tasks) {
      if (main.id == id) return main.name;
      for (var sub in main.subTasks) {
        final subCompound = '${main.id}|${sub.id}';
        if (sub.id == id || subCompound == id) return '${main.name} → ${sub.name}';
      }
    }
    return id;
  }

  List<Widget> _buildTaskTreeNodes(List<MainTask> tasks, Color themeColor, bool isLight) {
    final List<Widget> nodes = [];
    final q = _taskSearchQuery;

    for (var main in tasks) {
      final activeSubs = main.subTasks.where((s) => !s.isDeleted).toList();
      final bool mainMatch = q.isEmpty || main.name.toLowerCase().contains(q);

      final matchingSubs = activeSubs.where((sub) {
        if (mainMatch) return true;
        return sub.name.toLowerCase().contains(q);
      }).toList();

      if (!mainMatch && matchingSubs.isEmpty) continue;

      final isExpanded = _expandedTasks[main.id] ?? (q.isNotEmpty);
      final isMainSelected = _selectedTaskIds.contains(main.id);

      nodes.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: main.taskColor.withValues(alpha: isLight ? 0.08 : 0.14),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      size: 18,
                      color: main.taskColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _expandedTasks[main.id] = !isExpanded;
                      });
                    },
                  ),
                  Checkbox(
                    value: isMainSelected,
                    activeColor: main.taskColor,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedTaskIds.add(main.id);
                        } else {
                          _selectedTaskIds.remove(main.id);
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      main.name,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isLight ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: main.taskColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${matchingSubs.length} subtask(s)',
                      style: GoogleFonts.orbitron(fontSize: 9, color: main.taskColor),
                    ),
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  children: matchingSubs.map((sub) {
                    final subCompound = '${main.id}|${sub.id}';
                    final isSubSelected = _selectedTaskIds.contains(sub.id) ||
                        _selectedTaskIds.contains(subCompound);

                    return CheckboxListTile(
                      dense: true,
                      title: Text(
                        sub.name,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: isLight ? Colors.black87 : Colors.white70,
                        ),
                      ),
                      activeColor: main.taskColor,
                      value: isSubSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedTaskIds.add(subCompound);
                          } else {
                            _selectedTaskIds.remove(subCompound);
                            _selectedTaskIds.remove(sub.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      );
    }

    if (nodes.isEmpty) {
      nodes.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No active tasks found',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: JweTheme.textMuted),
            ),
          ),
        ),
      );
    }

    return nodes;
  }
}
