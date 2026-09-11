import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:uuid/uuid.dart';

class SubmissionPasteDialog {
  static void showPasteAlertDialog(
    BuildContext context,
    String title,
    Function(String) onImport,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(
          title,
          style: GoogleFonts.rajdhani(
            color: JweTheme.accentCyan,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Paste the copied structure text here to import:",
              style: TextStyle(color: JweTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 6,
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textWhite,
                fontSize: 11,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: JweTheme.bgDeep,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: JweTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: JweTheme.accentCyan),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL", style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentCyan,
              foregroundColor: JweTheme.onAccent,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                onImport(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text("IMPORT"),
          ),
        ],
      ),
    );
  }

  static void handlePaste(
    BuildContext context,
    AppProvider provider,
    String parentTaskId,
    SubTask liveSubTask,
  ) {
    showPasteAlertDialog(context, "PASTE OBJECTIVE STRUCTURE", (pastedText) {
      final parsed = parseTaskOutline(pastedText);
      if (parsed.isNotEmpty) {
        final newCheckpoint = SubSubTask(
          id: const Uuid().v4(),
          name: parsed['name'] as String? ?? 'Unnamed Objective',
          why: parsed['why'] as String? ?? '',
          what: parsed['what'] as String? ?? '',
          type: 'check',
          substeps: (parsed['children'] as List<dynamic>).map((c) {
            return SubSubTask(
              id: const Uuid().v4(),
              name: c['name'] as String? ?? 'Unnamed Objective',
              why: c['why'] as String? ?? '',
              what: c['what'] as String? ?? '',
              type: 'check',
            );
          }).toList(),
        );

        provider.taskActions.updateSubtask(
          parentTaskId,
          liveSubTask.id,
          {
            'subSubTasks': [...liveSubTask.subSubTasks, newCheckpoint],
          },
        );
        showGlobalToast("Objective pasted as new child");
      }
    });
  }
}
