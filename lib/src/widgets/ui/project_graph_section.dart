import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/charts/manual_project_chart.dart';
import 'package:arcane/src/widgets/dialogs/snapshot_dialog.dart';
import 'package:arcane/src/widgets/dialogs/manage_snapshots_dialog.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/widgets/ui/jwe_panel.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectGraphSection extends StatefulWidget {
  final Project project;
  final String mainTaskId;

  const ProjectGraphSection({
    super.key,
    required this.project,
    required this.mainTaskId,
  });

  @override
  State<ProjectGraphSection> createState() => _ProjectGraphSectionState();
}

class _ProjectGraphSectionState extends State<ProjectGraphSection> {

  void _handleAddSnapshot(BuildContext context, AppProvider provider) async {
    final totalSeconds = widget.project.calculateTotalTimeSeconds(provider.mainTasks);
    final progress = widget.project.calculateProgress();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SnapshotDialog(
        totalSeconds: totalSeconds,
        progress: progress,
      ),
    );

    if (result != null && result['action'] == 'save') {
      provider.projectActions.captureProjectSnapshot(
        widget.mainTaskId,
        widget.project.id,
        result['note']
      );
    }
  }

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
        provider.projectActions.deleteSnapshot(widget.mainTaskId, widget.project.id, snapshot.id);
      } else if (result['action'] == 'save') {
        provider.projectActions.updateSnapshot(widget.mainTaskId, widget.project.id, snapshot.id, result['note']);
      }
    }
  }
  
  void _showManageSnapshotsDialog(BuildContext context, AppProvider provider, List<ProjectSnapshot> snapshots) {
     showDialog(
       context: context,
       builder: (ctx) => ManageSnapshotsDialog(
         mainTaskId: widget.mainTaskId,
         projectId: widget.project.id,
         snapshots: snapshots,
       )
     );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final snapshots = widget.project.snapshots;

    return JwePanel(
      title: "VELOCITY GRAPH",
      accentColor: JweTheme.accentCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (snapshots.isNotEmpty)
                OutlinedButton.icon(
                  icon:  Icon(MdiIcons.databaseEditOutline, size: 14),
                  label: Text("MANAGE DATA POINTS", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 10)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.textMuted,
                    side: const BorderSide(color: JweTheme.border),
                    shape: const BeveledRectangleBorder()
                  ),
                  onPressed: () => _showManageSnapshotsDialog(context, provider, snapshots),
                )
              else
                const SizedBox.shrink(),

              InkWell(
                onTap: () => _handleAddSnapshot(context, provider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: JweTheme.accentCyan.withOpacity(0.5)),
                    color: JweTheme.accentCyan.withOpacity(0.1)
                  ),
                  child: const Text(
                    "+ LOG SNAPSHOT",
                    style: TextStyle(
                      color: JweTheme.accentCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: JweTheme.bgBase.withOpacity(0.5),
              border: Border.all(color: JweTheme.border),
            ),
            child: ManualProjectChart(
              snapshots: snapshots,
              onPointTap: (s) => _handlePointTap(context, provider, s),
            ),
          ),
        ],
      ),
    );
  }
}