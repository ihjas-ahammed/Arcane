import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class CheckpointTimeSpentCard extends StatelessWidget {
  final SubSubTask checkpoint;
  final Color accentColor;
  final VoidCallback onEdit;

  const CheckpointTimeSpentCard({
    super.key,
    required this.checkpoint,
    required this.accentColor,
    required this.onEdit,
  });

  static void showEditDialog({
    required BuildContext context,
    required AppProvider provider,
    required String mainTaskId,
    required String parentSubTaskId,
    required SubSubTask checkpoint,
    required Color accentColor,
  }) {
    final ctrl = TextEditingController(
      text: checkpoint.timeSpentMinutes > 0
          ? checkpoint.timeSpentMinutes.toString()
          : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(
          'LOG STEP TIME',
          style: GoogleFonts.rajdhani(
            color: accentColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TIME SPENT (MINUTES)',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              autofocus: true,
              style: TextStyle(color: JweTheme.textWhite, fontSize: 16),
              decoration: InputDecoration(
                suffixText: 'm',
                suffixStyle: TextStyle(
                    color: accentColor, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: JweTheme.bgCanvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: JweTheme.lineSoft),
                ),
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
                provider.taskActions.updateSubSubtask(
                  mainTaskId,
                  parentSubTaskId,
                  checkpoint.id,
                  {'timeSpentMinutes': parsed},
                );
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: JweTheme.onAccent,
            ),
            child: const Text('SAVE',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: JweTheme.panel,
          border: Border.all(
            color: checkpoint.timeSpentMinutes > 0
                ? accentColor
                : JweTheme.lineSoft,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(MdiIcons.timerOutline, color: accentColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TIME LOGGED ON THIS STEP",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 9,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    checkpoint.timeSpentMinutes > 0
                        ? "${checkpoint.timeSpentMinutes} MINUTES"
                        : "0 MINUTES LOGGED",
                    style: GoogleFonts.jetBrainsMono(
                      color: checkpoint.timeSpentMinutes > 0
                          ? accentColor
                          : JweTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: onEdit,
              icon: Icon(MdiIcons.clockOutline, size: 14),
              label: Text(
                "LOG TIME",
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: JweTheme.onAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
