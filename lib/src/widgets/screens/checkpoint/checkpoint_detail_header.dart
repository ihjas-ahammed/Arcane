import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class CheckpointDetailHeader extends StatefulWidget {
  final Color agentColor;
  final bool hasReminder;
  final VoidCallback onBack;
  final VoidCallback onReminderPressed;
  final VoidCallback onCopyPressed;
  final VoidCallback onPasteTriggered;
  final VoidCallback onDeletePressed;
  final Function(String draggedId) onAcceptDrop;

  const CheckpointDetailHeader({
    super.key,
    required this.agentColor,
    required this.hasReminder,
    required this.onBack,
    required this.onReminderPressed,
    required this.onCopyPressed,
    required this.onPasteTriggered,
    required this.onDeletePressed,
    required this.onAcceptDrop,
  });

  @override
  State<CheckpointDetailHeader> createState() => _CheckpointDetailHeaderState();
}

class _CheckpointDetailHeaderState extends State<CheckpointDetailHeader> {
  bool _isHeaderHovered = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        widget.onAcceptDrop(details.data);
        setState(() => _isHeaderHovered = false);
      },
      onMove: (_) {
        if (!_isHeaderHovered) setState(() => _isHeaderHovered = true);
      },
      onLeave: (_) {
        if (_isHeaderHovered) setState(() => _isHeaderHovered = false);
      },
      builder: (context, candidateData, rejectedData) {
        final activeAccent = widget.agentColor;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isHeaderHovered
                    ? activeAccent
                    : JweTheme.border.withValues(alpha: 0.3),
              ),
            ),
            color: _isHeaderHovered
                ? activeAccent.withValues(alpha: 0.1)
                : JweTheme.panel,
          ),
          child: Row(
            children: [
              InkWell(
                onTap: widget.onBack,
                child: Icon(Icons.arrow_back, color: JweTheme.textMid, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _isHeaderHovered ? "DROP TO MOVE OUTSIDE" : "OBJECTIVE DETAIL",
                  style: TextStyle(
                    color: activeAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    fontFamily: AppTheme.fontDisplay,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  widget.hasReminder ? MdiIcons.bellRing : MdiIcons.bellOutline,
                  color: widget.hasReminder ? activeAccent : JweTheme.textMid,
                ),
                onPressed: widget.onReminderPressed,
                tooltip: 'Set Reminder',
              ),
              GestureDetector(
                onLongPress: widget.onPasteTriggered,
                onSecondaryTap: widget.onPasteTriggered,
                child: IconButton(
                  icon: Icon(MdiIcons.contentCopy, color: JweTheme.textMid),
                  onPressed: widget.onCopyPressed,
                  tooltip: 'Copy Objective Structure',
                ),
              ),
              IconButton(
                icon: Icon(MdiIcons.deleteOutline, color: JweTheme.accentRed),
                onPressed: widget.onDeletePressed,
                tooltip: 'Delete Objective',
              ),
            ],
          ),
        );
      },
    );
  }
}
