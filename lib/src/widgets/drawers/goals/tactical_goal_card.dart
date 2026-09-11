import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/widgets/drawers/goals/add_sub_check_item_row.dart';
import 'package:missions/src/widgets/drawers/goals/tactical_goal_painters.dart';

class TacticalGoalCard extends StatelessWidget {
  final GoalModel goal;
  final double timeMins;
  final Color themeColor;
  final bool isLight;
  final bool isSubExpanded;
  final AppProvider appProvider;
  final VoidCallback onEdit;
  final VoidCallback onToggleSubExpanded;

  const TacticalGoalCard({
    super.key,
    required this.goal,
    required this.timeMins,
    required this.themeColor,
    required this.isLight,
    required this.isSubExpanded,
    required this.appProvider,
    required this.onEdit,
    required this.onToggleSubExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = goal.getIsEffectiveCompleted(dynamicTimeMinutes: timeMins);
    final ratio = goal.getProgressRatio(dynamicTimeMinutes: timeMins);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: CustomPaint(
        painter: TacticalCardPainter(
          activeColor: themeColor,
          isLight: isLight,
          isDone: isDone,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Goal Title on left, Edit Button & Metric Badge on top right
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
                  InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Icon(
                        MdiIcons.squareEditOutline,
                        size: 16,
                        color: themeColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GoalMetricBadge(type: goal.metricType, themeColor: themeColor),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: JweTheme.accentTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: JweTheme.accentTeal.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'RECURRING',
                        style: GoogleFonts.orbitron(
                            fontSize: 8.5,
                            color: JweTheme.accentTeal,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  if (goal.linkedTaskIds.isNotEmpty) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.linkVariant,
                            size: 11,
                            color: isLight ? Colors.black54 : Colors.white54),
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
                    painter: TacticalProgressBarPainter(
                      progress: ratio,
                      activeColor:
                          isDone ? themeColor.darken(0.15) : themeColor,
                      isLight: isLight,
                    ),
                  ),
                ),
              ] else if (goal.metricType == GoalMetricType.counter) ...[
                Row(
                  children: [
                    InkWell(
                      onTap: () =>
                          appProvider.updateGoalCounter(goal.id, -1),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : const Color(0xFF1C1E2A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: themeColor.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.remove, size: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: themeColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${goal.currentValue.toInt()} / ${goal.targetValue.toInt()}',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                              isDone ? themeColor.darken(0.15) : themeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        appProvider.updateGoalCounter(goal.id, 1);
                        if (goal.currentValue + 1 >= goal.targetValue) {
                          showGlobalToast(
                              'Counter Target Reached! +${goal.xpReward} XP');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : const Color(0xFF1C1E2A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: themeColor.withValues(alpha: 0.3)),
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
                          painter: TacticalProgressBarPainter(
                            progress: ratio,
                            activeColor: isDone
                                ? themeColor.darken(0.15)
                                : themeColor,
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
                                color: isDone
                                    ? themeColor.darken(0.15)
                                    : themeColor,
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
                        painter: TacticalProgressBarPainter(
                          progress: ratio,
                          activeColor: isDone
                              ? themeColor.darken(0.15)
                              : themeColor,
                          isLight: isLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (goal.metricType == GoalMetricType.check) ...[
                const SizedBox(height: 8),
                _buildSubchecklist(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubchecklist(BuildContext context) {
    final completedCount =
        goal.subChecklist.where((i) => i.isCompleted).length;
    final totalCount = goal.subChecklist.length;
    final subRatio =
        totalCount == 0 ? 0.0 : (completedCount / totalCount);

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.black.withValues(alpha: 0.03)
            : const Color(0xFF0F1018),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (goal.isCompleted ? themeColor.darken(0.15) : themeColor)
              .withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subchecklist Header Bar
          InkWell(
            onTap: onToggleSubExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isSubExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
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

          if (isSubExpanded) ...[
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
                              appProvider.toggleGoalSubCheckItem(
                                  goal.id, item.id);
                            },
                            child: Icon(
                              item.isCompleted
                                  ? MdiIcons.checkboxMarkedCircleOutline
                                  : MdiIcons.checkboxBlankCircleOutline,
                              size: 15,
                              color: item.isCompleted
                                  ? themeColor.darken(0.15)
                                  : themeColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                decoration: item.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.isCompleted
                                    ? (isLight
                                        ? Colors.black38
                                        : Colors.white38)
                                    : (isLight
                                        ? Colors.black87
                                        : Colors.white),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              appProvider.deleteGoalSubCheckItem(
                                  goal.id, item.id);
                            },
                            child: Icon(Icons.close,
                                size: 14,
                                color: isLight
                                    ? Colors.black38
                                    : Colors.white38),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 6),

                  // Add Subchecklist Item Input Row
                  AddSubCheckItemRow(
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
}

class GoalMetricBadge extends StatelessWidget {
  final GoalMetricType type;
  final Color themeColor;

  const GoalMetricBadge({
    super.key,
    required this.type,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
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
