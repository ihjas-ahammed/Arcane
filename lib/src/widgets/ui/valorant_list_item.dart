import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:arcane/src/widgets/ui/linked_task_indicator.dart';

class ValorantListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isCompleted;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final bool isCompact;
  final String? linkedLabel;
  final VoidCallback? onUnlink;

  const ValorantListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.isCompleted = false,
    this.onToggle,
    this.onDelete,
    this.isCompact = false,
    this.linkedLabel,
    this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 8 : 12),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark.withValues(alpha: 0.6),
        border: Border(
          left: BorderSide(
            color: isCompleted ? AppTheme.fhAccentGreen : AppTheme.fhBorderColor,
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
          if (onToggle != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: RhombusCheckbox(
                checked: isCompleted,
                onChanged: (_) => onToggle!(),
                size: CheckboxSize.small,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: isCompleted ? AppTheme.fhTextDisabled : AppTheme.fhTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontBody,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    fontSize: isCompact ? 13 : 14,
                    letterSpacing: 0.5,
                  ),
                ),
                if (linkedLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: LinkedTaskIndicator(
                      label: linkedLabel!,
                      onUnlink: onUnlink,
                    ),
                  ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppTheme.fhTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.close, size: 16, color: AppTheme.fhTextSecondary.withValues(alpha: 0.5)),
              onPressed: onDelete,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
        ],
      ),
    );
  }
}