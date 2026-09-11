import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class SubmissionDetailHeader extends StatelessWidget {
  final MainTask parentTask;
  final SubTask liveSubTask;
  final bool isRunning;
  final Color activeAccent;
  final bool hasReminder;
  final VoidCallback onBack;
  final VoidCallback onOpenReminders;
  final VoidCallback onEdit;
  final VoidCallback onCopyStructure;
  final VoidCallback onPasteStructure;
  final void Function(int?) onSelectDepth;

  const SubmissionDetailHeader({
    super.key,
    required this.parentTask,
    required this.liveSubTask,
    required this.isRunning,
    required this.activeAccent,
    required this.hasReminder,
    required this.onBack,
    required this.onOpenReminders,
    required this.onEdit,
    required this.onCopyStructure,
    required this.onPasteStructure,
    required this.onSelectDepth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        border: Border(bottom: BorderSide(color: JweTheme.line)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                border: Border.all(color: JweTheme.border),
                color: JweTheme.bgBase,
              ),
              child: Icon(Icons.arrow_back, color: JweTheme.textMid, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parentTask.name.toUpperCase(),
                  style: TextStyle(
                    color: activeAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    liveSubTask.name.toUpperCase(),
                    style: GoogleFonts.rajdhani(
                      color: JweTheme.textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (liveSubTask.completed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: JweTheme.accentTeal.withValues(alpha: 0.6),
                ),
                color: JweTheme.accentTeal.withValues(alpha: 0.08),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DONE',
                    style: TextStyle(
                      color: JweTheme.accentTeal,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  if (liveSubTask.lastCompletedDate != null)
                    Text(
                      DateFormat('MMM d · HH:mm')
                          .format(liveSubTask.lastCompletedDate!),
                      style: TextStyle(
                        color: JweTheme.accentTeal.withValues(alpha: 0.7),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isRunning
                      ? JweTheme.accentRed.withValues(alpha: 0.6)
                      : JweTheme.border,
                ),
                color: isRunning
                    ? JweTheme.accentRed.withValues(alpha: 0.1)
                    : Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRunning
                          ? JweTheme.accentRed
                          : JweTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isRunning ? "ACTIVE" : "STANDBY",
                    style: TextStyle(
                      color: isRunning
                          ? JweTheme.accentRed
                          : JweTheme.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          PopupMenuButton<int?>(
            tooltip: 'Set Checkpoint Depth',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: JweTheme.panel,
            initialValue: liveSubTask.depth,
            onSelected: onSelectDepth,
            itemBuilder: (context) => [
              PopupMenuItem<int?>(
                value: null,
                height: 32,
                child: Text(
                  'MAX (Deepest)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: liveSubTask.depth == null
                        ? activeAccent
                        : JweTheme.textWhite,
                    fontWeight: liveSubTask.depth == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              PopupMenuItem<int?>(
                value: 1,
                height: 32,
                child: Text(
                  'LEVEL 1 (Top)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: liveSubTask.depth == 1
                        ? activeAccent
                        : JweTheme.textWhite,
                    fontWeight: liveSubTask.depth == 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              PopupMenuItem<int?>(
                value: 2,
                height: 32,
                child: Text(
                  'LEVEL 2 (Substeps)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: liveSubTask.depth == 2
                        ? activeAccent
                        : JweTheme.textWhite,
                    fontWeight: liveSubTask.depth == 2
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              PopupMenuItem<int?>(
                value: 3,
                height: 32,
                child: Text(
                  'LEVEL 3 (Nested)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: liveSubTask.depth == 3
                        ? activeAccent
                        : JweTheme.textWhite,
                    fontWeight: liveSubTask.depth == 3
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: liveSubTask.depth != null
                    ? activeAccent.withValues(alpha: 0.12)
                    : JweTheme.panel2,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: liveSubTask.depth != null
                      ? activeAccent.withValues(alpha: 0.5)
                      : JweTheme.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    liveSubTask.depthLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: liveSubTask.depth != null
                          ? activeAccent
                          : JweTheme.textMid,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    MdiIcons.menuDown,
                    size: 11,
                    color: liveSubTask.depth != null
                        ? activeAccent
                        : JweTheme.textMid,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onOpenReminders,
            child: Icon(
              MdiIcons.bellOutline,
              color: hasReminder ? JweTheme.accentAmber : JweTheme.textMid,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onEdit,
            child: Icon(MdiIcons.pencilOutline, color: JweTheme.textMid, size: 20),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onCopyStructure,
            onLongPress: onPasteStructure,
            onSecondaryTap: onPasteStructure,
            child: Icon(MdiIcons.contentCopy, color: JweTheme.textMid, size: 20),
          ),
        ],
      ),
    );
  }
}
