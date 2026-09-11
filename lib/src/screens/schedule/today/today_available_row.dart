import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/app_theme.dart';

/// Collapsible dropdown group used in the "add to plan" list. Level 0 renders
/// a main-task header (uppercase, colored, letter-spaced); level 1 renders a
/// nested subtask header (indented). Tapping the header toggles its children so
/// the task → subtask → checkpoint hierarchy is visually obvious.
class CollapsibleGroup extends StatefulWidget {
  final String title;
  final Color color;
  final int level;
  final int queuedCount;
  final bool initiallyExpanded;
  final List<Widget> children;

  const CollapsibleGroup({
    super.key,
    required this.title,
    required this.color,
    required this.level,
    required this.queuedCount,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  State<CollapsibleGroup> createState() => _CollapsibleGroupState();
}

class _CollapsibleGroupState extends State<CollapsibleGroup> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final bool isMain = widget.level == 0;
    return Container(
      margin: EdgeInsets.only(
          top: isMain ? 8 : 4, left: isMain ? 0 : 12, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 8, vertical: isMain ? 6 : 5),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark
                    .withValues(alpha: isMain ? 0.85 : 0.5),
                border: Border(
                    left: BorderSide(
                        color: widget.color
                            .withValues(alpha: isMain ? 1.0 : 0.6),
                        width: isMain ? 3 : 2)),
              ),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(MdiIcons.chevronRight,
                        size: isMain ? 18 : 15,
                        color: isMain
                            ? widget.color
                            : AppTheme.fhTextSecondary),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      isMain ? widget.title.toUpperCase() : widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMain
                            ? widget.color
                            : AppTheme.fhTextPrimary,
                        fontWeight:
                            isMain ? FontWeight.bold : FontWeight.w600,
                        fontSize: isMain ? 11 : 12.5,
                        letterSpacing: isMain ? 1.5 : 0,
                      ),
                    ),
                  ),
                  if (widget.queuedCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.fhAccentTeal.withValues(alpha: 0.12),
                        border: Border.all(
                            color: AppTheme.fhAccentTeal
                                .withValues(alpha: 0.4)),
                      ),
                      child: Text('${widget.queuedCount}',
                          style: TextStyle(
                              color: AppTheme.fhAccentTeal,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.children),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class AvailableRow extends StatelessWidget {
  final String title;
  final Color color;
  final bool isCheckpoint;
  final int plannedCount;
  final VoidCallback onAdd;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;

  const AvailableRow({
    super.key,
    required this.title,
    required this.color,
    required this.isCheckpoint,
    required this.plannedCount,
    required this.onAdd,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isSelectionMode
          ? () => onSelectedChanged?.call(!isSelected)
          : onAdd,
      child: Container(
        margin: EdgeInsets.only(bottom: 4, left: isCheckpoint ? 16 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark.withValues(alpha: isCheckpoint ? 0.4 : 0.7),
          border: Border(
              left: BorderSide(color: color.withValues(alpha: isCheckpoint ? 0.4 : 1.0), width: 2)),
        ),
        child: Row(
          children: [
            if (isSelectionMode) ...[
              Theme(
                data: Theme.of(context).copyWith(
                  unselectedWidgetColor: AppTheme.fhTextDisabled,
                ),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: AppTheme.fhAccentTeal,
                    checkColor: Colors.black,
                    onChanged: onSelectedChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              isCheckpoint ? MdiIcons.rhombusOutline : MdiIcons.targetAccount,
              size: isCheckpoint ? 14 : 16,
              color: isCheckpoint ? AppTheme.fhTextSecondary : color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppTheme.fhTextPrimary,
                  fontSize: isCheckpoint ? 12 : 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isSelectionMode && plannedCount > 0) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.fhAccentTeal.withValues(alpha: 0.12),
                  border: Border.all(
                      color: AppTheme.fhAccentTeal.withValues(alpha: 0.5)),
                ),
                child: Text(
                  plannedCount == 1 ? 'QUEUED' : 'QUEUED ×$plannedCount',
                  style: TextStyle(
                      color: AppTheme.fhAccentTeal,
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.bold),
                ),
              )
                  .animate(key: ValueKey(plannedCount))
                  .scaleXY(
                      begin: 0.6,
                      end: 1.0,
                      duration: 280.ms,
                      curve: Curves.easeOutBack)
                  .fadeIn(duration: 120.ms),
            ],
            if (!isSelectionMode)
              Icon(Icons.add, color: AppTheme.fhAccentTeal, size: 18),
          ],
        ),
      ),
    );
  }
}
