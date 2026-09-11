import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/day_budget_helper.dart';
import 'tactical_planner_painters.dart';
import 'tactical_subtasks_panel.dart';
import 'today_animated_entry.dart';
import 'today_planner_models.dart';

class TacticalCardMenuButton extends StatelessWidget {
  final PlanEntry entry;
  final String mainTaskId;
  final String subTaskId;
  final String subTaskName;
  final int rowIndex;
  final bool isInMultiRow;
  final void Function(String action) onActionSelected;

  const TacticalCardMenuButton({
    super.key,
    required this.entry,
    required this.mainTaskId,
    required this.subTaskId,
    required this.subTaskName,
    required this.rowIndex,
    required this.isInMultiRow,
    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 16, color: JweTheme.textMuted),
      color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: JweTheme.border),
      ),
      padding: EdgeInsets.zero,
      onSelected: onActionSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'duplicate_mission',
          child: Row(
            children: [
              Icon(Icons.copy, size: 16, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Text('DUPLICATE MISSION',
                  style: GoogleFonts.rajdhani(
                      color: JweTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'add_subtask',
          child: Row(
            children: [
              Icon(Icons.add, size: 16, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Text('ADD CHECKPOINT',
                  style: GoogleFonts.rajdhani(
                      color: JweTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'view_subtasks',
          child: Row(
            children: [
              Icon(Icons.checklist, size: 16, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Text('VIEW CHECKPOINTS',
                  style: GoogleFonts.rajdhani(
                      color: JweTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'merge_top_row',
          child: Row(
            children: [
              Icon(Icons.vertical_align_top_rounded, size: 16, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Text('MERGE TO TOP ROW',
                  style: GoogleFonts.rajdhani(
                      color: JweTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'merge_bottom_row',
          child: Row(
            children: [
              Icon(Icons.vertical_align_bottom_rounded, size: 16, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Text('MERGE TO BOTTOM ROW',
                  style: GoogleFonts.rajdhani(
                      color: JweTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        if (isInMultiRow)
          PopupMenuItem(
            value: 'move_own_row',
            child: Row(
              children: [
                const Icon(Icons.table_rows_outlined, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Text('MOVE TO OWN ROW',
                    style: GoogleFonts.rajdhani(
                        color: JweTheme.textWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'multitask_add',
          child: Row(
            children: [
              const Icon(Icons.view_column_outlined, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text('MULTITASK / ADD TO ROW',
                  style: GoogleFonts.rajdhani(
                      color: JweTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'adjust_duration',
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: JweTheme.textMid),
              const SizedBox(width: 8),
              Text('ADJUST DURATION',
                  style: GoogleFonts.rajdhani(
                      color: JweTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'reminder',
          child: Row(
            children: [
              Icon(Icons.notifications_outlined, size: 16, color: JweTheme.textMid),
              const SizedBox(width: 8),
              Text('SET REMINDER',
                  style: GoogleFonts.rajdhani(
                      color: JweTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 16, color: Color(0xFFFF2A4B)),
              const SizedBox(width: 8),
              Text('DELETE MISSION',
                  style: GoogleFonts.rajdhani(
                      color: const Color(0xFFFF2A4B),
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}

class TacticalCard1 extends StatelessWidget {
  final AppProvider provider;
  final PlanEntry entry;
  final int rowIndex;
  final int colIndex;
  final LeaveKind? leaving;
  final VoidCallback onLeft;
  final int minutes;
  final bool isCustomEstimate;
  final bool isDone;
  final bool hasReminder;
  final VoidCallback onEditEstimate;
  final VoidCallback onRemoveFromPlan;
  final VoidCallback onEditReminder;
  final VoidCallback onCompletePlanItem;
  final void Function(String action) onMenuAction;
  final bool isSubtasksExpanded;
  final VoidCallback onToggleSubtasksExpanded;
  final void Function(PlanCheckpoint cp) onToggleCheckpoint;
  final void Function(PlanCheckpoint cp) onRemoveCheckpoint;
  final VoidCallback onPromptAddCheckpoint;

  const TacticalCard1({
    super.key,
    required this.provider,
    required this.entry,
    required this.rowIndex,
    required this.colIndex,
    required this.leaving,
    required this.onLeft,
    required this.minutes,
    required this.isCustomEstimate,
    required this.isDone,
    required this.hasReminder,
    required this.onEditEstimate,
    required this.onRemoveFromPlan,
    required this.onEditReminder,
    required this.onCompletePlanItem,
    required this.onMenuAction,
    required this.isSubtasksExpanded,
    required this.onToggleSubtasksExpanded,
    required this.onToggleCheckpoint,
    required this.onRemoveCheckpoint,
    required this.onPromptAddCheckpoint,
  });

  @override
  Widget build(BuildContext context) {
    final parts = entry.id.split('|');
    if (parts.length < 2) return const SizedBox.shrink();

    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    if (task == null || sub == null || task.isDeleted || sub.isDeleted) {
      return const SizedBox.shrink();
    }

    final isCheckpoint = parts.length == 3;
    SubSubTask? cp;
    if (isCheckpoint) {
      cp = sub.findCheckpoint(parts[2]);
      if (cp == null) return const SizedBox.shrink();
    }

    final title = isCheckpoint ? cp!.name : sub.name;
    final parent = isCheckpoint ? '${task.name} > ${findParentPath(sub, cp!)}' : task.name;
    final taskColor = task.taskColor;

    return AnimatedPlanEntry(
      key: ValueKey(entry.key),
      animateIn: entry.addedAtRuntime,
      leaving: leaving,
      onLeft: onLeft,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isDone ? 0.55 : 1.0,
        child: ClipPath(
          clipper: const Chamfer4CornerClipper(chamfer: 10.0),
          child: CustomPaint(
            foregroundPainter: TacticalCardBorderPainter(
              themeColor: taskColor,
              chamfer: 10.0,
              bracketSize: 12.0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
                boxShadow: [
                  BoxShadow(
                    color: taskColor.withValues(alpha: JweTheme.isLight ? 0.08 : 0.05),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ReorderableDragStartListener(
                        index: rowIndex,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.fromLTRB(2, 6, 8, 6),
                            child: Icon(Icons.drag_indicator,
                                size: 18, color: JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              parent.toUpperCase(),
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onEditEstimate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: JweTheme.isLight ? 0.06 : 0.35),
                            border: Border.all(
                              color: isCustomEstimate ? JweTheme.accentCyan : taskColor,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            formatMinutes(minutes),
                            style: GoogleFonts.rajdhani(
                              color: isCustomEstimate ? JweTheme.accentCyan : taskColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: onRemoveFromPlan,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close, color: JweTheme.textMuted, size: 16),
                        ),
                      ),
                      TacticalCardMenuButton(
                        entry: entry,
                        mainTaskId: task.id,
                        subTaskId: sub.id,
                        subTaskName: sub.name,
                        rowIndex: rowIndex,
                        isInMultiRow: false,
                        onActionSelected: onMenuAction,
                      ),
                    ],
                  ),
                  if (!isCheckpoint && entry.checkpoints.isNotEmpty)
                    TacticalSubtasksPanel(
                      entry: entry,
                      isExpanded: isSubtasksExpanded,
                      onToggleExpanded: onToggleSubtasksExpanded,
                      onToggleCheckpoint: onToggleCheckpoint,
                      onRemoveCheckpoint: onRemoveCheckpoint,
                      onPromptAdd: onPromptAddCheckpoint,
                    ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: JweTheme.lineSoft, width: 1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: onEditReminder,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Icon(
                              hasReminder ? MdiIcons.bellRing : MdiIcons.bellOutline,
                              color: hasReminder ? JweTheme.accentCyan : JweTheme.textMuted,
                              size: 18,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: onCompletePlanItem,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Icon(
                              Icons.check,
                              color: isDone
                                  ? (JweTheme.isLight ? JweTheme.accentTeal : const Color(0xFF10B981))
                                  : JweTheme.accentCyan,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TacticalCard2 extends StatelessWidget {
  final AppProvider provider;
  final PlanEntry entry;
  final int rowIndex;
  final int colIndex;
  final LeaveKind? leaving;
  final VoidCallback onLeft;
  final int minutes;
  final bool isCustomEstimate;
  final bool isDone;
  final bool hasReminder;
  final VoidCallback onEditEstimate;
  final VoidCallback onRemoveFromPlan;
  final VoidCallback onEditReminder;
  final VoidCallback onCompletePlanItem;
  final void Function(String action) onMenuAction;
  final VoidCallback onShowSubtasksModal;

  const TacticalCard2({
    super.key,
    required this.provider,
    required this.entry,
    required this.rowIndex,
    required this.colIndex,
    required this.leaving,
    required this.onLeft,
    required this.minutes,
    required this.isCustomEstimate,
    required this.isDone,
    required this.hasReminder,
    required this.onEditEstimate,
    required this.onRemoveFromPlan,
    required this.onEditReminder,
    required this.onCompletePlanItem,
    required this.onMenuAction,
    required this.onShowSubtasksModal,
  });

  @override
  Widget build(BuildContext context) {
    final parts = entry.id.split('|');
    if (parts.length < 2) return const SizedBox.shrink();

    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    if (task == null || sub == null || task.isDeleted || sub.isDeleted) {
      return const SizedBox.shrink();
    }

    final isCheckpoint = parts.length == 3;
    SubSubTask? cp;
    if (isCheckpoint) {
      cp = sub.findCheckpoint(parts[2]);
      if (cp == null) return const SizedBox.shrink();
    }

    final title = isCheckpoint ? cp!.name : sub.name;
    final parent = isCheckpoint ? '${task.name} > ${findParentPath(sub, cp!)}' : task.name;
    final taskColor = task.taskColor;
    final checkpoints = entry.checkpoints;
    final totalCps = checkpoints.length;
    final completedCps = checkpoints.where((c) => c.completed).length;

    return AnimatedPlanEntry(
      key: ValueKey(entry.key),
      animateIn: entry.addedAtRuntime,
      leaving: leaving,
      onLeft: onLeft,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isDone ? 0.55 : 1.0,
        child: ClipPath(
          clipper: const Chamfer4CornerClipper(chamfer: 6.0),
          child: CustomPaint(
            foregroundPainter: TacticalCardBorderPainter(
              themeColor: taskColor,
              chamfer: 6.0,
              bracketSize: 8.0,
            ),
            child: Container(
              height: double.infinity,
              constraints: const BoxConstraints(minHeight: 84),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReorderableDragStartListener(
                        index: rowIndex,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.fromLTRB(1, 4, 6, 4),
                            child: Icon(Icons.drag_indicator,
                                size: 14, color: JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              parent.toUpperCase(),
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (totalCps > 0) ...[
                              const SizedBox(height: 2),
                              InkWell(
                                onTap: onShowSubtasksModal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.checklist_rounded,
                                      size: 12,
                                      color: JweTheme.isLight ? JweTheme.textMid : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$completedCps/$totalCps',
                                      style: GoogleFonts.rajdhani(
                                        color: JweTheme.isLight ? JweTheme.textMid : const Color(0xFF94A3B8),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 3),
                      InkWell(
                        onTap: onEditEstimate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: JweTheme.isLight ? 0.06 : 0.35),
                            border: Border.all(
                              color: isCustomEstimate ? JweTheme.accentCyan : taskColor,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            formatMinutes(minutes),
                            style: GoogleFonts.rajdhani(
                              color: isCustomEstimate ? JweTheme.accentCyan : taskColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: JweTheme.lineSoft, width: 1)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: onEditReminder,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                hasReminder ? MdiIcons.bellRing : MdiIcons.bellOutline,
                                color: hasReminder ? JweTheme.accentCyan : JweTheme.textMuted,
                                size: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: onCompletePlanItem,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.check,
                                color: isDone
                                    ? (JweTheme.isLight ? JweTheme.accentTeal : const Color(0xFF10B981))
                                    : JweTheme.accentCyan,
                                size: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: onRemoveFromPlan,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(Icons.close,
                                  color: JweTheme.isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B), size: 13),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TacticalCardMenuButton(
                            entry: entry,
                            mainTaskId: task.id,
                            subTaskId: sub.id,
                            subTaskName: sub.name,
                            rowIndex: rowIndex,
                            isInMultiRow: true,
                            onActionSelected: onMenuAction,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TacticalCard3 extends StatelessWidget {
  final AppProvider provider;
  final PlanEntry entry;
  final int rowIndex;
  final int colIndex;
  final LeaveKind? leaving;
  final VoidCallback onLeft;
  final int minutes;
  final bool isCustomEstimate;
  final bool isDone;
  final bool hasReminder;
  final VoidCallback onEditEstimate;
  final VoidCallback onRemoveFromPlan;
  final VoidCallback onEditReminder;
  final VoidCallback onCompletePlanItem;
  final void Function(String action) onMenuAction;
  final VoidCallback onShowSubtasksModal;

  const TacticalCard3({
    super.key,
    required this.provider,
    required this.entry,
    required this.rowIndex,
    required this.colIndex,
    required this.leaving,
    required this.onLeft,
    required this.minutes,
    required this.isCustomEstimate,
    required this.isDone,
    required this.hasReminder,
    required this.onEditEstimate,
    required this.onRemoveFromPlan,
    required this.onEditReminder,
    required this.onCompletePlanItem,
    required this.onMenuAction,
    required this.onShowSubtasksModal,
  });

  @override
  Widget build(BuildContext context) {
    final parts = entry.id.split('|');
    if (parts.length < 2) return const SizedBox.shrink();

    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    if (task == null || sub == null || task.isDeleted || sub.isDeleted) {
      return const SizedBox.shrink();
    }

    final isCheckpoint = parts.length == 3;
    SubSubTask? cp;
    if (isCheckpoint) {
      cp = sub.findCheckpoint(parts[2]);
      if (cp == null) return const SizedBox.shrink();
    }

    final title = isCheckpoint ? cp!.name : sub.name;
    final parent = isCheckpoint ? '${task.name} > ${findParentPath(sub, cp!)}' : task.name;
    final taskColor = task.taskColor;
    final checkpoints = entry.checkpoints;
    final totalCps = checkpoints.length;
    final completedCps = checkpoints.where((c) => c.completed).length;

    return AnimatedPlanEntry(
      key: ValueKey(entry.key),
      animateIn: entry.addedAtRuntime,
      leaving: leaving,
      onLeft: onLeft,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isDone ? 0.55 : 1.0,
        child: ClipPath(
          clipper: const Chamfer4CornerClipper(chamfer: 4.0),
          child: CustomPaint(
            foregroundPainter: TacticalCardBorderPainter(
              themeColor: taskColor,
              chamfer: 4.0,
              bracketSize: 6.0,
            ),
            child: Container(
              height: double.infinity,
              constraints: const BoxConstraints(minHeight: 80),
              padding: const EdgeInsets.fromLTRB(5, 6, 5, 5),
              decoration: BoxDecoration(
                color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReorderableDragStartListener(
                        index: rowIndex,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.fromLTRB(1, 3, 5, 3),
                            child: Icon(Icons.drag_indicator,
                                size: 11, color: JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              parent.toUpperCase(),
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textMuted,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (totalCps > 0) ...[
                              const SizedBox(height: 2),
                              InkWell(
                                onTap: onShowSubtasksModal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.checklist_rounded,
                                      size: 10,
                                      color: JweTheme.isLight ? JweTheme.textMid : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$completedCps/$totalCps',
                                      style: GoogleFonts.rajdhani(
                                        color: JweTheme.isLight ? JweTheme.textMid : const Color(0xFF94A3B8),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: onEditEstimate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: JweTheme.isLight ? 0.06 : 0.35),
                            border: Border.all(
                              color: isCustomEstimate ? JweTheme.accentCyan : taskColor,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            formatMinutes(minutes),
                            style: GoogleFonts.rajdhani(
                              color: isCustomEstimate ? JweTheme.accentCyan : taskColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: JweTheme.lineSoft, width: 1)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: onEditReminder,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                hasReminder ? MdiIcons.bellRing : MdiIcons.bellOutline,
                                color: hasReminder ? JweTheme.accentCyan : JweTheme.textMuted,
                                size: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            onTap: onCompletePlanItem,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.check,
                                color: isDone
                                    ? (JweTheme.isLight ? JweTheme.accentTeal : const Color(0xFF10B981))
                                    : JweTheme.accentCyan,
                                size: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            onTap: onRemoveFromPlan,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(Icons.close,
                                  color: JweTheme.isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B), size: 11),
                            ),
                          ),
                          const SizedBox(width: 2),
                          TacticalCardMenuButton(
                            entry: entry,
                            mainTaskId: task.id,
                            subTaskId: sub.id,
                            subTaskName: sub.name,
                            rowIndex: rowIndex,
                            isInMultiRow: true,
                            onActionSelected: onMenuAction,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
