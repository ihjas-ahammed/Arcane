import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/widgets/dialogs/add_edit_protocol_dialog.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class JweTaskOptionsDialog extends StatelessWidget {
  final MainTask task;

  const JweTaskOptionsDialog({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final isActive = task.isActive;

    return Dialog(
      backgroundColor: JweTheme.panel,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: JweTheme.accentCyan, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(MdiIcons.consoleLine, color: JweTheme.accentCyan, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "PROTOCOL CONFIG",
                      style: GoogleFonts.rajdhani(
                        color: JweTheme.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JweTheme.bgBase,
                  border: Border.all(color: JweTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TARGET:",
                      style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      task.name.toUpperCase(),
                      style: GoogleFonts.chakraPetch(color: JweTheme.accentAmber, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              OutlinedButton.icon(
                icon: Icon(MdiIcons.pencilOutline, size: 18),
                label: const Text("EDIT PROTOCOL"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: JweTheme.textWhite,
                  side: const BorderSide(color: JweTheme.border),
                  shape: const BeveledRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(context: context, builder: (_) => AddEditProtocolDialog(task: task));
                },
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                icon: Icon(isActive ? MdiIcons.pauseOctagonOutline : MdiIcons.playCircleOutline, size: 18),
                label: Text(isActive ? "SUSPEND PROTOCOL" : "REACTIVATE PROTOCOL"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isActive ? JweTheme.accentAmber : JweTheme.accentCyan,
                  side: BorderSide(color: isActive ? JweTheme.accentAmber : JweTheme.accentCyan),
                  shape: const BeveledRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  provider.taskActions.toggleTaskStatus(task.id, !isActive);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                icon: Icon(MdiIcons.deleteOutline, size: 18),
                label: const Text("DELETE PROTOCOL"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: JweTheme.accentRed,
                  side: const BorderSide(color: JweTheme.accentRed),
                  shape: const BeveledRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: JweTheme.panel,
                      title: Text("DELETE PROTOCOL?", style: GoogleFonts.rajdhani(color: JweTheme.accentRed, fontWeight: FontWeight.bold)),
                      content: const Text("This action cannot be undone and will delete all nested missions.", style: TextStyle(color: JweTheme.textMuted)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: JweTheme.textMuted))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentRed, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("DELETE")
                        )
                      ],
                    )
                  );
                  
                  if (confirm == true && context.mounted) {
                    provider.taskActions.deleteMainTask(task.id);
                    Navigator.pop(context);
                  }
                },
              ),

              const SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: JweTheme.textMuted,
                  side: const BorderSide(color: Colors.transparent),
                  shape: const BeveledRectangleBorder(),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL"),
              )
            ],
          ),
        ),
      ),
    );
  }
}