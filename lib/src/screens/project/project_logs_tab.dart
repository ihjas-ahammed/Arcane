import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/project/project_dialogs.dart';
import 'package:missions/src/screens/project/project_note_card.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class ProjectLogsTab extends StatelessWidget {
  final Project project;
  final AppProvider provider;
  final Color accentColor;

  const ProjectLogsTab({
    super.key,
    required this.project,
    required this.provider,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'LOGS & NOTES',
                style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => showAddOrEditNoteDialog(context, provider, project, accent: accentColor),
                icon: Icon(MdiIcons.plus, size: 14, color: accentColor),
                label: Text('ADD LOG ENTRY', style: TextStyle(color: accentColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (project.notes.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: JweTheme.border),
              ),
              alignment: Alignment.center,
              child: Text('NO LOG ENTRIES CREATED.', style: TextStyle(color: JweTheme.textMuted, fontSize: 12)),
            )
          else
            ...project.notes.map((n) => ProjectNoteCard(
                  key: ValueKey(n.id),
                  note: n,
                  accentColor: accentColor,
                  onEdit: () => showAddOrEditNoteDialog(
                    context,
                    provider,
                    project,
                    existingNote: n,
                    accent: accentColor,
                  ),
                  onDelete: () {
                    final updatedNotes = project.notes.where((note) => note.id != n.id).toList();
                    provider.updateProject(project.copyWith(notes: updatedNotes));
                  },
                )),
        ],
      ),
    );
  }
}
