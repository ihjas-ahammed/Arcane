import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class ProjectNoteCard extends StatefulWidget {
  final ProjectNote note;
  final Color accentColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProjectNoteCard({
    super.key,
    required this.note,
    required this.accentColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ProjectNoteCard> createState() => _ProjectNoteCardState();
}

class _ProjectNoteCardState extends State<ProjectNoteCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final deleteFg = JweTheme.isLight ? JweTheme.panel : Colors.white;

    return Dismissible(
      key: ValueKey(widget.note.id),
      direction: DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: JweTheme.accentRed.withValues(alpha: 0.85),
        ),
        child: Row(
          children: [
            Icon(Icons.delete_outline, color: deleteFg, size: 20),
            const SizedBox(width: 8),
            Text(
              'DELETE ENTRY',
              style: GoogleFonts.jetBrainsMono(
                color: deleteFg,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (confirmCtx) => AlertDialog(
            backgroundColor: JweTheme.panel,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: JweTheme.accentRed, width: 2),
              borderRadius: BorderRadius.zero,
            ),
            title: Text(
              'DELETE NOTE ENTRY?',
              style: GoogleFonts.rajdhani(color: JweTheme.accentRed, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Delete note "${widget.note.title}"?',
              style: TextStyle(color: JweTheme.textMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(confirmCtx, false),
                child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: JweTheme.accentRed,
                  foregroundColor: deleteFg,
                  shape: const BeveledRectangleBorder(),
                ),
                onPressed: () => Navigator.pop(confirmCtx, true),
                child: const Text('DELETE'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        widget.onDelete();
      },
      child: Card(
        color: JweTheme.panel,
        margin: const EdgeInsets.only(bottom: 10),
        shape: Border(left: BorderSide(color: widget.accentColor.withValues(alpha: 0.8), width: 3)),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          onLongPress: widget.onEdit,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.note.title.toUpperCase(),
                            style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm').format(widget.note.createdAt),
                            style: TextStyle(color: JweTheme.textMuted, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                      color: JweTheme.textMuted,
                      size: 18,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ArcSurfaces.dim(0.3),
                      border: Border.all(color: JweTheme.border),
                    ),
                    child: Text(
                      widget.note.content,
                      style: GoogleFonts.inter(color: JweTheme.textMid, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
