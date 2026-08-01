import 'package:flutter/material.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/ui/linked_task_indicator.dart';
import 'package:missions/src/widgets/ui/rhombus_checkbox.dart';
import 'package:missions/src/widgets/ui/step_bars_row.dart';
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
  final List<SubSubTask>? substeps;
  final void Function(SubSubTask step)? onToggleSubstep;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;

  final bool isActive;
  final int timeSpentMinutes;
  final VoidCallback? onToggleActive;
  final VoidCallback? onLogTime;
  final ValueChanged<int>? onUpdateTimeSpent;

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
    this.substeps,
    this.onToggleSubstep,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    this.isActive = true,
    this.timeSpentMinutes = 0,
    this.onToggleActive,
    this.onLogTime,
    this.onUpdateTimeSpent,
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

  HudTone _toneFor(Color c) {
    if (c == JweTheme.accentCyan) return HudTone.cyan;
    if (c == JweTheme.accentTeal) return HudTone.teal;
    if (c == JweTheme.accentRed) return HudTone.red;
    return HudTone.amber;
  }

  void _showEditTimeSpentDialog(BuildContext context) {
    final ctrl = TextEditingController(text: widget.timeSpentMinutes > 0 ? widget.timeSpentMinutes.toString() : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgDark,
        title: Text(
          'LOG STEP TIME',
          style: GoogleFonts.jetBrainsMono(color: widget.accentColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TIME SPENT (MINUTES)', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: JweTheme.textWhite, fontSize: 14),
              decoration: InputDecoration(
                suffixText: 'm',
                suffixStyle: TextStyle(color: widget.accentColor),
                filled: true,
                fillColor: JweTheme.bgCanvas,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(ctrl.text.trim());
              if (parsed != null && parsed >= 0) {
                widget.onUpdateTimeSpent?.call(parsed);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: AppTheme.fhBgDark),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInfo = widget.type == 'info';
    final color = widget.accentColor;
    final isInactive = !widget.isActive;

    final borderColor = isInactive
        ? JweTheme.lineSoft
        : (isInfo ? color : (_localCompleted ? color : AppTheme.fhBorderColor));
    final bgColor = isInactive
        ? AppTheme.fhBgDark.withValues(alpha: 0.3)
        : (isInfo ? color.withValues(alpha: 0.1) : (_localCompleted ? color.withValues(alpha: 0.15) : AppTheme.fhBgDark.withValues(alpha: 0.6)));
    final iconColor = isInactive
        ? JweTheme.textMuted
        : (isInfo ? color : (_localCompleted ? color : AppTheme.fhTextSecondary));
    final textColor = isInactive ? JweTheme.textMuted : AppTheme.fhTextPrimary;

    return Dismissible(
      key: widget.key ?? ValueKey("cp_${widget.title}_${widget.hashCode}"),
      direction: widget.isSelectionMode ? DismissDirection.none : DismissDirection.horizontal,
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
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.fhBgDark,
              title: Text("Delete Objective?", style: TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay)),
              content: Text("This action cannot be undone.", style: TextStyle(color: AppTheme.fhTextSecondary)),
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
          if (!isInfo && widget.isActive) _handleToggle();
          return false;
        }
        return false;
      },
      child: GestureDetector(
        onTap: widget.isSelectionMode
            ? () => widget.onSelectedChanged?.call(!widget.isSelected)
            : widget.onTap,
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
                children: [
                  if (widget.isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: widget.isSelected,
                          onChanged: widget.onSelectedChanged,
                          activeColor: color,
                          checkColor: AppTheme.fhBgDark,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    )
                  else if (!isInfo)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: RhombusCheckbox(
                        checked: _localCompleted,
                        onChanged: isInactive ? null : (_) => _handleToggle(),
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
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title.toUpperCase(),
                                style: GoogleFonts.chakraPetch(
                                  color: textColor,
                                  fontWeight: isInfo ? FontWeight.w900 : FontWeight.bold,
                                  decoration: (isInactive || (!isInfo && _localCompleted)) ? TextDecoration.lineThrough : null,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (isInactive)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.fhAccentRed.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  'INACTIVE',
                                  style: GoogleFonts.jetBrainsMono(color: AppTheme.fhAccentRed, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
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

                  if (widget.timeSpentMinutes > 0)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        border: Border.all(color: color),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MdiIcons.clockOutline, size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.timeSpentMinutes}m',
                            style: GoogleFonts.jetBrainsMono(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
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

                  if (!widget.isSelectionMode)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 18, color: AppTheme.fhTextSecondary),
                      color: AppTheme.fhBgDark,
                      onSelected: (value) {
                        if (value == 'delete') widget.onDelete();
                        if (value == 'duplicate' && widget.onDuplicate != null) widget.onDuplicate!();
                        if (value == 'toggle_type' && widget.onToggleType != null) widget.onToggleType!();
                        if (value == 'toggle_active' && widget.onToggleActive != null) widget.onToggleActive!();
                        if (value == 'log_time') {
                          _showEditTimeSpentDialog(context);
                        }
                        if (value == 'open' && widget.onTap != null) widget.onTap!();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'open',
                          child: Row(children: [Icon(MdiIcons.arrowRight, size: 16, color: color), const SizedBox(width: 8), Text("Open Details", style: TextStyle(color: color))]),
                        ),
                        PopupMenuItem(
                          value: 'log_time',
                          child: Row(children: [Icon(MdiIcons.timerOutline, size: 16, color: JweTheme.accentCyan), const SizedBox(width: 8), const Text("Log Step Time", style: TextStyle(color: Colors.white))]),
                        ),
                        PopupMenuItem(
                          value: 'toggle_active',
                          child: Row(children: [
                            Icon(isInactive ? MdiIcons.eyeOutline : MdiIcons.eyeOffOutline, size: 16, color: isInactive ? AppTheme.fhAccentGreen : AppTheme.fhAccentOrange),
                            const SizedBox(width: 8),
                            Text(isInactive ? "Re-activate Step" : "Deactivate Step", style: TextStyle(color: isInactive ? AppTheme.fhAccentGreen : AppTheme.fhAccentOrange)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Row(children: [Icon(MdiIcons.contentCopy, size: 16, color: AppTheme.fhTextPrimary), const SizedBox(width: 8), const Text("Duplicate", style: TextStyle(color: Colors.white))]),
                        ),
                        PopupMenuItem(
                          value: 'toggle_type',
                          child: Row(children: [
                            Icon(isInfo ? MdiIcons.checkboxMarkedOutline : MdiIcons.informationOutline, size: 16, color: AppTheme.fhTextPrimary),
                            const SizedBox(width: 8),
                            Text(isInfo ? "Make Checkable" : "Make Info", style: const TextStyle(color: Colors.white))
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [Icon(MdiIcons.deleteOutline, size: 16, color: AppTheme.fhAccentRed), const SizedBox(width: 8), Text("Delete", style: TextStyle(color: AppTheme.fhAccentRed))]),
                        ),
                      ],
                    ),
                ],
              ),

              // Progress bar + telemetry — matches the submission card's
              // HudBar layout. StepBarsRow is added below it when the caller
              // wires [onToggleSubstep], for quick-toggle of nested steps.
              if (widget.hasCheckableSubsteps && !_localCompleted) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: HudBar(
                          value: widget.progress * 100,
                          tone: _toneFor(color),
                          height: 4,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(widget.progress * 100).round()}%',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: JweTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.substeps != null &&
                    widget.substeps!.isNotEmpty &&
                    widget.onToggleSubstep != null)
                  StepBarsRow(
                    steps: widget.substeps!,
                    accent: color,
                    onToggle: widget.onToggleSubstep!,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}