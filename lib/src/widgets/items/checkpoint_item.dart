import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/ui/linked_task_indicator.dart';
import 'package:missions/src/widgets/ui/rhombus_checkbox.dart';
import 'package:missions/src/widgets/ui/jwe_progress_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CheckpointItem extends StatefulWidget {
  final String title;
  final bool isCompleted;
  final String? linkedLabel;
  final String type; // 'check' or 'info'
  final Color accentColor;
  final VoidCallback? onUnlink;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onToggleType;
  final VoidCallback? onTap; 
  final VoidCallback? onPlay; 
  final bool isRunning;
  final bool hasCheckableSubsteps; 
  final double progress; 

  const CheckpointItem({
    super.key,
    required this.title,
    required this.isCompleted,
    this.linkedLabel,
    this.type = 'check',
    required this.accentColor,
    this.onUnlink,
    required this.onToggle,
    required this.onDelete,
    this.onDuplicate,
    this.onToggleType,
    this.onTap,
    this.onPlay,
    this.isRunning = false,
    this.hasCheckableSubsteps = false,
    this.progress = 0.0,
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
    final color = widget.accentColor;

    final borderColor = isInfo ? color : (_localCompleted ? color : AppTheme.fhBorderColor);
    final bgColor = isInfo ? color.withValues(alpha: 0.1) : (_localCompleted ? color.withValues(alpha: 0.15) : AppTheme.fhBgDark.withValues(alpha: 0.6));
    final iconColor = isInfo ? color : (_localCompleted ? color : AppTheme.fhTextSecondary);
    final textColor = AppTheme.fhTextPrimary; 

    return Dismissible(
      key: widget.key ?? ValueKey("cp_${widget.title}_${widget.hashCode}"),
      direction: DismissDirection.horizontal,
      background: Container(
        color: AppTheme.fhAccentRed,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: _localCompleted ? AppTheme.fhTextSecondary : AppTheme.fhAccentTeal,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(_localCompleted ? MdiIcons.restore : MdiIcons.check, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Slide right -> Delete
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.fhBgDark,
              title: const Text("Delete Objective?", style: TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay)),
              content: const Text("This action cannot be undone.", style: TextStyle(color: AppTheme.fhTextSecondary)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Delete")
                ),
              ],
            )
          );
          if (confirm == true) {
            widget.onDelete();
            return true;
          }
          return false;
        } else if (direction == DismissDirection.endToStart) {
          // Slide left -> Complete
          if (!isInfo) _handleToggle();
          return false; // bounce back
        }
        return false;
      },
      child: GestureDetector(
        onTap: widget.onTap, 
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(left: BorderSide(color: borderColor, width: 4)),
          ),
          child: Column(
            children: [
              Row(
                children:[
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
                      child: Icon(MdiIcons.informationOutline, size: 18, color: iconColor),
                    ),
      
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        Text(
                          widget.title.toUpperCase(),
                          style: GoogleFonts.chakraPetch(
                            color: textColor,
                            fontWeight: isInfo ? FontWeight.w900 : FontWeight.bold,
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
                  
                  if (widget.hasCheckableSubsteps)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(MdiIcons.fileTree, size: 14, color: color),
                    ),
      
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 18, color: AppTheme.fhTextSecondary),
                    color: AppTheme.fhBgDark,
                    onSelected: (value) {
                      if (value == 'delete') widget.onDelete();
                      if (value == 'duplicate' && widget.onDuplicate != null) widget.onDuplicate!();
                      if (value == 'toggle_type' && widget.onToggleType != null) widget.onToggleType!();
                      if (value == 'open' && widget.onTap != null) widget.onTap!();
                    },
                    itemBuilder: (context) =>[
                        PopupMenuItem(
                        value: 'open',
                        child: Row(children:[Icon(MdiIcons.arrowRight, size: 16, color: color), const SizedBox(width: 8), Text("Open Details", style: TextStyle(color: color))]),
                      ),
                        PopupMenuItem(
                        value: 'duplicate',
                        child: Row(children:[Icon(MdiIcons.contentCopy, size: 16, color: AppTheme.fhTextPrimary), const SizedBox(width: 8), const Text("Duplicate", style: TextStyle(color: AppTheme.fhTextPrimary))]),
                      ),
                      PopupMenuItem(
                        value: 'toggle_type',
                        child: Row(children:[
                          Icon(isInfo ? MdiIcons.checkboxMarkedOutline : MdiIcons.informationOutline, size: 16, color: AppTheme.fhTextPrimary), 
                          const SizedBox(width: 8), 
                          Text(isInfo ? "Make Checkable" : "Make Info", style: const TextStyle(color: AppTheme.fhTextPrimary))
                        ]),
                      ),
                        PopupMenuItem(
                        value: 'delete',
                        child: Row(children:[Icon(MdiIcons.deleteOutline, size: 16, color: AppTheme.fhAccentRed), const SizedBox(width: 8), const Text("Delete", style: TextStyle(color: AppTheme.fhAccentRed))]),
                      ),
                    ],
                  ),
                ],
              ),
              
              // JWE Progress Bar if it has checkable sub-steps
              if (widget.hasCheckableSubsteps && !_localCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: JweProgressBar(
                    progress: widget.progress,
                    color: color,
                    label: "NESTED [ ${(widget.progress * 100).toInt()}% ]"
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}