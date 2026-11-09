import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/widgets/drawers/goals/add_sub_check_item_row.dart';
import 'package:missions/src/widgets/drawers/goals/goal_panel_widgets.dart';
import 'package:missions/src/widgets/drawers/goals/tactical_goal_painters.dart';

enum _GoalPanel { checklist, keyResults, collaborators }

class TacticalGoalCard extends StatefulWidget {
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
  State<TacticalGoalCard> createState() => _TacticalGoalCardState();
}

class _TacticalGoalCardState extends State<TacticalGoalCard> {
  bool _isReorderMode = false;
  // The checklist opens by default, so its items are visible as soon as the goal is expanded.
  final Set<_GoalPanel> _openPanels = {_GoalPanel.checklist};

  void _toggleReorderMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isReorderMode = !_isReorderMode;
      if (_isReorderMode) {
        _openPanels.add(_GoalPanel.checklist);
        if (!widget.isSubExpanded) widget.onToggleSubExpanded();
      }
    });
  }

  void _moveItem(int currentIndex, int delta) {
    final targetIndex = currentIndex + delta;
    if (targetIndex < 0 || targetIndex >= widget.goal.subChecklist.length) return;
    HapticFeedback.selectionClick();
    widget.appProvider.reorderGoalSubCheckItem(widget.goal.id, currentIndex, targetIndex);
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final timeMins = widget.timeMins;
    final themeColor = widget.themeColor;
    final isLight = widget.isLight;
    final appProvider = widget.appProvider;
    final onEdit = widget.onEdit;

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

              // Recurring Tag, Place Tag, Reminder Tag & Linked Tasks
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...goal.placeIds.map(
                    (placeId) => Builder(
                      builder: (context) {
                        final place = appProvider.getGoalPlace(placeId);
                        if (place == null) return const SizedBox.shrink();
                        final placeColor = Color(place.colorValue);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: placeColor.withValues(alpha: isLight ? 0.15 : 0.22),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: placeColor.withValues(alpha: 0.6),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.place, size: 10, color: placeColor),
                              const SizedBox(width: 3),
                              Text(
                                place.name.toUpperCase(),
                                style: GoogleFonts.orbitron(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: placeColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (goal.scope == GoalScope.daily && goal.reminderTimes.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: isLight ? 0.12 : 0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: themeColor.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 10, color: themeColor),
                          const SizedBox(width: 3),
                          Text(
                            goal.reminderTimes.join(', '),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: isLight ? Colors.black87 : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                          showGlobalToast('Counter Target Reached!');
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
                        if (goal.countAllTime)
                          Text(
                            'All-Time History',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              color: isLight ? Colors.black54 : Colors.white54,
                            ),
                          )
                        else if (goal.startDateTime != null)
                          Text(
                            'From: ${DateFormat('MM/dd').format(goal.startDateTime!)} 12 AM',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              color: isLight ? Colors.black54 : Colors.white54,
                            ),
                          )
                        else
                          Text(
                            'From 12 AM',
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

  Widget _buildChecklistBody(BuildContext context) {
    final goal = widget.goal;
    final themeColor = widget.themeColor;
    final isLight = widget.isLight;
    final appProvider = widget.appProvider;
    final totalCount = goal.subChecklist.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                  ...goal.subChecklist.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isFirst = index == 0;
                    final isLast = index == totalCount - 1;
                    return Padding(
                      key: ValueKey('sub_${item.id}'),
                      padding: EdgeInsets.symmetric(
                          vertical: _isReorderMode ? 3 : 2),
                      child: Row(
                        children: [
                          if (_isReorderMode)
                            Container(
                              width: 18,
                              margin: const EdgeInsets.only(right: 6),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor,
                                ),
                              ),
                            ),
                          InkWell(
                            onTap: () {
                              appProvider.toggleGoalSubCheckItem(
                                  goal.id, item.id);
                            },
                            onDoubleTap: _toggleReorderMode,
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
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              // Tapping the name ticks the checkpoint, so the small icon is not the only target.
                              onTap: () {
                                HapticFeedback.selectionClick();
                                appProvider.toggleGoalSubCheckItem(goal.id, item.id);
                              },
                              onDoubleTap: _toggleReorderMode,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
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
                            ),
                          ),
                          if (_isReorderMode) ...[
                              const SizedBox(width: 4),
                              // UP ARROW BUTTON
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isFirst
                                      ? null
                                      : () => _moveItem(index, -1),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isFirst
                                          ? (isLight
                                              ? Colors.black
                                                  .withValues(alpha: 0.03)
                                              : Colors.white
                                                  .withValues(alpha: 0.03))
                                          : themeColor.withValues(
                                              alpha: isLight ? 0.15 : 0.22),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isFirst
                                            ? Colors.transparent
                                            : themeColor
                                                .withValues(alpha: 0.45),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      size: 18,
                                      color: isFirst
                                          ? (isLight
                                              ? Colors.black26
                                              : Colors.white24)
                                          : (isLight
                                              ? themeColor.darken(0.1)
                                              : themeColor),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // DOWN ARROW BUTTON
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isLast
                                      ? null
                                      : () => _moveItem(index, 1),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isLast
                                          ? (isLight
                                              ? Colors.black
                                                  .withValues(alpha: 0.03)
                                              : Colors.white
                                                  .withValues(alpha: 0.03))
                                          : themeColor.withValues(
                                              alpha: isLight ? 0.15 : 0.22),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isLast
                                            ? Colors.transparent
                                            : themeColor
                                                .withValues(alpha: 0.45),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: isLast
                                          ? (isLight
                                              ? Colors.black26
                                              : Colors.white24)
                                          : (isLight
                                              ? themeColor.darken(0.1)
                                              : themeColor),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            InkWell(
                              onTap: () {
                                appProvider.deleteGoalSubCheckItem(
                                    goal.id, item.id);
                              },
                              onDoubleTap: _toggleReorderMode,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: isLight
                                      ? Colors.black38
                                      : Colors.white38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
        const SizedBox(height: 6),
        AddSubCheckItemRow(
          goalId: goal.id,
          themeColor: themeColor,
          isLight: isLight,
        ),
      ],
    );
  }

  Widget _reorderRow() {
    final themeColor = widget.themeColor;
    if (_isReorderMode) {
      return Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          onTap: _toggleReorderMode,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: themeColor.withValues(alpha: 0.5), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 12, color: themeColor),
                const SizedBox(width: 3),
                Text(
                  'DONE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: _toggleReorderMode,
        borderRadius: BorderRadius.circular(4),
        child: Tooltip(
          message: 'Double click to rearrange subchecklist',
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(MdiIcons.swapVertical, size: 14, color: themeColor),
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value) {
    final themeColor = widget.themeColor;
    final isLight = widget.isLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: isLight ? 0.10 : 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: themeColor.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: isLight ? Colors.black54 : Colors.white60,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: themeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubchecklist(BuildContext context) {
    final goal = widget.goal;
    final themeColor = widget.themeColor;
    final isLight = widget.isLight;
    final isSubExpanded = widget.isSubExpanded;
    final appProvider = widget.appProvider;

    final completedCount = goal.subChecklist.where((i) => i.isCompleted).length;
    final totalCount = goal.subChecklist.length;
    final percent = totalCount == 0 ? 0 : (completedCount * 100 ~/ totalCount);

    Widget panel({
      required _GoalPanel id,
      required String label,
      required String count,
      required Widget child,
    }) {
      final open = _openPanels.contains(id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GoalDropdownHeader(
            label: label,
            countText: count,
            isOpen: open,
            themeColor: themeColor,
            isLight: isLight,
            onTap: () => setState(() {
              if (open) {
                _openPanels.remove(id);
              } else {
                _openPanels.add(id);
              }
            }),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? (_isReorderMode
                ? themeColor.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03))
            : (_isReorderMode
                ? themeColor.withValues(alpha: 0.08)
                : const Color(0xFF0F1018)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isReorderMode
              ? themeColor.withValues(alpha: 0.65)
              : (goal.isCompleted ? themeColor.darken(0.15) : themeColor)
                  .withValues(alpha: 0.25),
          width: _isReorderMode ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single tap on the bar expands the three dropdowns.
          InkWell(
            onTap: widget.onToggleSubExpanded,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _summaryChip('CHECKLIST', '$completedCount/$totalCount'),
                  _summaryChip('KEY RESULTS', '${goal.keyResults.length}'),
                  _summaryChip('COLLABORATORS', '${goal.collaborators.length}'),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isSubExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1, thickness: 0.8),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            panel(
                              id: _GoalPanel.checklist,
                              label: _isReorderMode ? 'REORDER' : 'SUBCHECKLIST',
                              count: _isReorderMode ? 'ARRANGE' : '$completedCount/$totalCount ($percent%)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _reorderRow(),
                                  _buildChecklistBody(context),
                                ],
                              ),
                            ),
                            panel(
                              id: _GoalPanel.keyResults,
                              label: 'KEY RESULTS',
                              count: '${goal.keyResults.length}',
                              child: GoalItemListPanel(
                                items: goal.keyResults,
                                themeColor: themeColor,
                                isLight: isLight,
                                hint: 'Add a key result...',
                                emptyText: 'No key results yet.',
                                onAdd: (text) => appProvider.addGoalListItem(
                                    goal.id, GoalListKind.keyResults, text),
                                onDelete: (id) => appProvider.deleteGoalListItem(
                                    goal.id, GoalListKind.keyResults, id),
                              ),
                            ),
                            panel(
                              id: _GoalPanel.collaborators,
                              label: 'COLLABORATORS',
                              count: '${goal.collaborators.length}',
                              child: GoalItemListPanel(
                                items: goal.collaborators,
                                themeColor: themeColor,
                                isLight: isLight,
                                hint: 'Add a collaborator...',
                                emptyText: 'No collaborators yet.',
                                onAdd: (text) => appProvider.addGoalListItem(
                                    goal.id, GoalListKind.collaborators, text),
                                onDelete: (id) => appProvider.deleteGoalListItem(
                                    goal.id, GoalListKind.collaborators, id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
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
