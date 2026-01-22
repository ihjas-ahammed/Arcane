import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/charts/manual_project_chart.dart';
import 'package:arcane/src/widgets/dialogs/snapshot_dialog.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
    // Determine current stats from project state
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final snapshots = widget.project.snapshots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "PROGRESS TIMELINE",
              style: TextStyle(
                color: AppTheme.fhTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            InkWell(
              onTap: () => _handleAddSnapshot(context, provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.fhAccentTeal.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(MdiIcons.chartTimelineVariant, size: 14, color: AppTheme.fhAccentTeal),
                    const SizedBox(width: 4),
                    const Text(
                      "LOG SNAPSHOT",
                      style: TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.2)),
          ),
          child: ManualProjectChart(
            snapshots: snapshots,
            onPointTap: (s) => _handlePointTap(context, provider, s),
          ),
        ),
        if (snapshots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              "Tap points to edit or delete entries.",
              style: TextStyle(color: AppTheme.fhTextSecondary.withOpacity(0.5), fontSize: 10, fontStyle: FontStyle.italic),
            ),
          )
      ],
    );
  }
}