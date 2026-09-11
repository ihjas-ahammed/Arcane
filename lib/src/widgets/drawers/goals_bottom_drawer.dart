import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/utils/helpers.dart';
import 'package:missions/src/widgets/header_widget.dart';
import 'package:missions/src/widgets/analytics/jwe_date_selector.dart';
import 'package:missions/src/widgets/drawers/goals/create_goal_sheet.dart';
import 'package:missions/src/widgets/drawers/goals/goals_progress_banner.dart';
import 'package:missions/src/widgets/drawers/goals/goals_scope_tab_row.dart';
import 'package:missions/src/widgets/drawers/goals/tactical_goal_card.dart';
import 'package:missions/src/widgets/drawers/goals/tactical_goal_painters.dart';

export 'package:missions/src/widgets/drawers/goals/add_sub_check_item_row.dart';
export 'package:missions/src/widgets/drawers/goals/create_goal_sheet.dart';
export 'package:missions/src/widgets/drawers/goals/goals_progress_banner.dart';
export 'package:missions/src/widgets/drawers/goals/goals_scope_tab_row.dart';
export 'package:missions/src/widgets/drawers/goals/tactical_goal_card.dart';
export 'package:missions/src/widgets/drawers/goals/tactical_goal_painters.dart';

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
      barrierColor:
          Colors.black.withValues(alpha: JweTheme.isLight ? 0.4 : 0.65),
      builder: (ctx) => GoalsBottomDrawer(initialDate: initialDate),
    );
  }

  @override
  State<GoalsBottomDrawer> createState() => _GoalsBottomDrawerState();
}

class _GoalsBottomDrawerState extends State<GoalsBottomDrawer> {
  final GlobalKey<ScaffoldMessengerState> _drawerMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  GoalScope _activeScope = GoalScope.daily;
  late DateTime _selectedDate;
  final Map<String, bool> _expandedSublists = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    registerActiveScaffoldMessenger(_drawerMessengerKey);
  }

  @override
  void dispose() {
    unregisterActiveScaffoldMessenger(_drawerMessengerKey);
    super.dispose();
  }

  /// Calculates spent time in minutes for linked tasks based on session time
  double _calculateLinkedTimeMinutes(AppProvider provider, GoalModel goal) {
    if (goal.linkedTaskIds.isEmpty) return goal.currentValue;

    double totalMinutes = 0.0;
    final activeMainTasks =
        provider.mainTasks.where((t) => t.isActive && !t.isDeleted);

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
      builder: (ctx) => CreateGoalSheet(
        initialScope: goalToEdit?.scope ?? _activeScope,
        selectedDate: goalToEdit?.startDateTime ?? _selectedDate,
        goalToEdit: goalToEdit,
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, Color themeColor) async {
    final isLight = JweTheme.isLight;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: isLight
              ? ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: themeColor,
                    onPrimary: Colors.white,
                    surface: JweTheme.panel,
                    onSurface: JweTheme.textWhite,
                  ),
                )
              : ThemeData.dark().copyWith(
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

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isLight = JweTheme.isLight;
    final themeColor =
        appProvider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;

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
            }) /
            goals.length;

    final sheetBg = isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    return ScaffoldMessenger(
      key: _drawerMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.90,
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(
                  color: themeColor.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: isLight ? 0.12 : 0.25),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
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
                              border: Border.all(
                                  color: themeColor.withValues(alpha: 0.4),
                                  width: 1.2),
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
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'GOALS & ',
                                          style: TextStyle(
                                              color: isLight
                                                  ? Colors.black87
                                                  : Colors.white),
                                        ),
                                        TextSpan(
                                          text: 'METRICS',
                                          style: TextStyle(color: themeColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '// TARGET PROTOCOLS',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                    color: isLight
                                        ? const Color(0xFF475569)
                                        : Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: themeColor.withValues(alpha: 0.4),
                                  width: 1.2),
                            ),
                            child: Row(
                              children: [
                                ArcaneAppIcon(size: 13, color: themeColor),
                                const SizedBox(width: 4),
                                Text(
                                  '+${formatCompactXp(totalXp)} XP',
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
                        dateStr: DateFormat('EEEE, MMM d, yyyy')
                            .format(_selectedDate),
                        accentColor: themeColor,
                        onTap: () => _pickDate(context, themeColor),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 3 Custom Scope Tabs: DAILY, WEEKLY, MONTHLY
                    GoalsScopeTabRow(
                      activeScope: _activeScope,
                      themeColor: themeColor,
                      isLight: isLight,
                      onScopeChanged: (scope) =>
                          setState(() => _activeScope = scope),
                    ),

                    const SizedBox(height: 10),

                    // Overview Progress Banner
                    GoalsProgressBanner(
                      activeScope: _activeScope,
                      themeColor: themeColor,
                      isLight: isLight,
                      progressRatio: overallProgressRatio,
                      completedCount: completedCount,
                      totalCount: goals.length,
                    ),

                    const SizedBox(height: 10),

                    // Goals List Body
                    Expanded(
                      child: goals.isEmpty
                          ? _buildEmptyState(isLight, themeColor)
                          : ReorderableListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              itemCount: goals.length,
                              onReorderItem: (oldIndex, newIndex) {
                                appProvider.reorderGoalsForPeriod(
                                    _activeScope, _selectedDate, oldIndex, newIndex);
                              },
                              itemBuilder: (ctx, i) {
                                final goal = goals[i];
                                final timeMins =
                                    _calculateLinkedTimeMinutes(appProvider, goal);
                                return Dismissible(
                                  key: ValueKey('goal_${goal.id}'),
                                  direction: DismissDirection.horizontal,
                                  confirmDismiss: (direction) async {
                                    if (direction == DismissDirection.startToEnd) {
                                      appProvider.toggleGoalCheck(goal.id);
                                      return false;
                                    }
                                    return true;
                                  },
                                  onDismissed: (direction) {
                                    if (direction == DismissDirection.endToStart) {
                                      appProvider.deleteGoal(goal.id);
                                    }
                                  },
                                  background: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.only(left: 16),
                                    alignment: Alignment.centerLeft,
                                    decoration: BoxDecoration(
                                      color: themeColor
                                          .darken(0.15)
                                          .withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(MdiIcons.checkboxMarkedCircle,
                                            color: Colors.white, size: 20),
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
                                      color: JweTheme.accentRed
                                          .withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Icon(MdiIcons.deleteOutline,
                                            color: Colors.white, size: 20),
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
                                  child: TacticalGoalCard(
                                    goal: goal,
                                    timeMins: timeMins,
                                    themeColor: themeColor,
                                    isLight: isLight,
                                    isSubExpanded:
                                        _expandedSublists[goal.id] ?? false,
                                    appProvider: appProvider,
                                    onEdit: () => _openCreateGoalDialog(context,
                                        goalToEdit: goal),
                                    onToggleSubExpanded: () {
                                      setState(() {
                                        _expandedSublists[goal.id] =
                                            !(_expandedSublists[goal.id] ??
                                                false);
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),

                    // Bottom Primary Action Button (hidden when keyboard is open)
                    if (!isKeyboardOpen)
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
                            foregroundColor:
                                isLight ? Colors.white : Colors.black,
                            elevation: 4,
                            shadowColor: themeColor.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add,
                                  size: 18,
                                  color:
                                      isLight ? Colors.white : Colors.black),
                              const SizedBox(width: 8),
                              Text(
                                'INITIALIZE NEW ${_activeScope.name.toUpperCase()} GOAL',
                                style: GoogleFonts.orbitron(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: isLight ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
