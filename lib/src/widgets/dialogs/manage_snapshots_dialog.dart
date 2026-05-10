import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/widgets/dialogs/snapshot_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ManageSnapshotsDialog extends StatelessWidget {
  final String mainTaskId;
  final String projectId;
  final List<ProjectSnapshot> snapshots;

  const ManageSnapshotsDialog({
    super.key,
    required this.mainTaskId,
    required this.projectId,
    required this.snapshots,
  });

  void _handlePointTap(BuildContext context, AppProvider provider, ProjectSnapshot snapshot) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SnapshotDialog(
        totalSeconds: snapshot.totalSecondsInvested,
        progress: snapshot.progress,
        initialNote: snapshot.note,
        isEditing: true,
      ),
    );

    if (result != null) {
      if (result['action'] == 'delete') {
        provider.projectActions.deleteSnapshot(mainTaskId, projectId, snapshot.id);
      } else if (result['action'] == 'save') {
        provider.projectActions.updateSnapshot(mainTaskId, projectId, snapshot.id, result['note']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Get live snapshots in case of deletion
    List<ProjectSnapshot> liveSnapshots = snapshots;
    try {
      final task = provider.mainTasks.firstWhere((t) => t.id == mainTaskId);
      final project = task.projects.firstWhere((p) => p.id == projectId);
      liveSnapshots = List.from(project.snapshots)..sort((a,b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {}

    return Dialog(
      backgroundColor: JweTheme.panel,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: JweTheme.accentCyan, width: 2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: JweTheme.border)),
              ),
              child: Row(
                children: [
                   Icon(MdiIcons.databaseEditOutline, color: JweTheme.accentCyan),
                  const SizedBox(width: 12),
                  Text("DATA POINTS", style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: JweTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: JweTheme.bgBase,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("DATE", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text("TIME", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text("PROGRESS", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                  SizedBox(width: 24),
                ],
              ),
            ),
            
            Expanded(
              child: liveSnapshots.isEmpty
                ? const Center(child: Text("NO DATA POINTS LOGGED", style: TextStyle(color: JweTheme.textMuted)))
                : ListView.builder(
                    itemCount: liveSnapshots.length,
                    itemBuilder: (context, index) {
                      final snap = liveSnapshots[index];
                      return InkWell(
                        onTap: () => _handlePointTap(context, provider, snap),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: JweTheme.border)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('MMM dd').format(snap.timestamp), style: const TextStyle(color: JweTheme.textWhite, fontSize: 12)),
                              Text(helper.formatTime(snap.totalSecondsInvested.toDouble()), style: const TextStyle(color: JweTheme.textWhite, fontFamily: 'RobotoMono', fontSize: 12)),
                              Text("${(snap.progress * 100).toInt()}%", style: const TextStyle(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                               Icon(MdiIcons.pencilOutline, size: 14, color: JweTheme.textMuted),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}