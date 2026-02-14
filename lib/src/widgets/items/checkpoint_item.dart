import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/widgets/ui/linked_task_indicator.dart';

/// A lightweight item widget for checkpoints to handle optimistic updates
/// and prevent full screen redraws on simple toggles.
class CheckpointItem extends StatefulWidget {
  final String title;
  final bool isCompleted;
  final String? linkedLabel;
  final VoidCallback? onUnlink;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const CheckpointItem({
    super.key,
    required this.title,
    required this.isCompleted,
    this.linkedLabel,
    this.onUnlink,
    required this.onToggle,
    required this.onDelete,
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
    setState(() {
      _localCompleted = !_localCompleted;
    });
    // Call the parent callback which triggers the provider update
    // The provider update is now async, so UI won't freeze.
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark.withValues(alpha: 0.6),
        border: Border(
          left: BorderSide(
            color: _localCompleted ? AppTheme.fhAccentGreen : AppTheme.fhBorderColor,
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: RhombusCheckbox(
              checked: _localCompleted,
              onChanged: (_) => _handleToggle(),
              size: CheckboxSize.small,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title.toUpperCase(),
                  style: TextStyle(
                    color: _localCompleted ? AppTheme.fhTextDisabled : AppTheme.fhTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontBody,
                    decoration: _localCompleted ? TextDecoration.lineThrough : null,
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
          IconButton(
            icon: Icon(Icons.close, size: 16, color: AppTheme.fhTextSecondary.withValues(alpha: 0.5)),
            onPressed: widget.onDelete,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }
}