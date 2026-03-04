import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/widgets/ui/linked_task_indicator.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CheckpointItem extends StatefulWidget {
  final String title;
  final bool isCompleted;
  final String? linkedLabel;
  final String type; // 'check' or 'info'
  final VoidCallback? onUnlink;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onToggleType;

  const CheckpointItem({
    super.key,
    required this.title,
    required this.isCompleted,
    this.linkedLabel,
    this.type = 'check',
    this.onUnlink,
    required this.onToggle,
    required this.onDelete,
    this.onDuplicate,
    this.onToggleType,
  });

  @override
  State<CheckpointItem> createState() => _CheckpointItemState();
}

class _CheckpointItemState extends State<CheckpointItem> {
  late bool _localCompleted;

  @override
  void initState() {
    super.initState();
    _localCompleted = widget.isCompleted;
  }

  @override
  void didUpdateWidget(covariant CheckpointItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCompleted != oldWidget.isCompleted) {
      _localCompleted = widget.isCompleted;
    }
  }

  void _handleToggle() {
    if (widget.type == 'info') return;
    setState(() {
      _localCompleted = !_localCompleted;
    });
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final isInfo = widget.type == 'info';
    final textColor = isInfo 
        ? AppTheme.fhAccentTeal 
        : (_localCompleted ? AppTheme.fhTextDisabled : AppTheme.fhTextPrimary);
    final bgColor = isInfo 
        ? AppTheme.fhAccentTeal.withValues(alpha: 0.1) 
        : AppTheme.fhBgDark.withValues(alpha: 0.6);
    final borderColor = isInfo
        ? AppTheme.fhAccentTeal.withValues(alpha: 0.3)
        : (_localCompleted ? AppTheme.fhAccentGreen : AppTheme.fhBorderColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          left: BorderSide(
            color: borderColor,
            width: 4,
          ),
          bottom: BorderSide(
            color: AppTheme.fhBorderColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (!isInfo)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: RhombusCheckbox(
                checked: _localCompleted,
                onChanged: (_) => _handleToggle(),
                size: CheckboxSize.small,
              ),
            )
          else 
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(MdiIcons.informationOutline, size: 18, color: AppTheme.fhAccentTeal),
            ),
            
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title.toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isInfo ? FontWeight.w900 : FontWeight.bold,
                    fontFamily: AppTheme.fontBody,
                    decoration: (!isInfo && _localCompleted) ? TextDecoration.lineThrough : null,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                if (widget.linkedLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: LinkedTaskIndicator(
                      label: widget.linkedLabel!,
                      onUnlink: widget.onUnlink,
                    ),
                  ),
              ],
            ),
          ),
          
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 16, color: AppTheme.fhTextSecondary.withValues(alpha: 0.7)),
            color: AppTheme.fhBgDark,
            onSelected: (value) {
              if (value == 'delete') widget.onDelete();
              if (value == 'duplicate' && widget.onDuplicate != null) widget.onDuplicate!();
              if (value == 'toggle_type' && widget.onToggleType != null) widget.onToggleType!();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'duplicate',
                child: Row(children: [Icon(MdiIcons.contentCopy, size: 16, color: AppTheme.fhTextPrimary), const SizedBox(width: 8), const Text("Duplicate", style: TextStyle(color: AppTheme.fhTextPrimary))]),
              ),
              PopupMenuItem(
                value: 'toggle_type',
                child: Row(children: [
                  Icon(isInfo ? MdiIcons.checkboxMarkedOutline : MdiIcons.informationOutline, size: 16, color: AppTheme.fhTextPrimary), 
                  const SizedBox(width: 8), 
                  Text(isInfo ? "Make Checkable" : "Make Info", style: const TextStyle(color: AppTheme.fhTextPrimary))
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [Icon(MdiIcons.deleteOutline, size: 16, color: AppTheme.fhAccentRed), const SizedBox(width: 8), const Text("Delete", style: TextStyle(color: AppTheme.fhAccentRed))]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}