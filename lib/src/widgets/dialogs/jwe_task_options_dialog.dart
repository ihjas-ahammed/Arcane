import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
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
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: JweTheme.textMuted,
                  side: const BorderSide(color: JweTheme.border),
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