import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/charts/manual_project_chart.dart';
import 'package:arcane/src/widgets/dialogs/snapshot_dialog.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final snapshots = widget.project.snapshots;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false, // Default closed
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(MdiIcons.chartTimelineVariant, color: AppTheme.fhAccentTeal, size: 20),
            const SizedBox(width: 8),
            const Text(
              "VELOCITY GRAPH",
              style: TextStyle(
                color: AppTheme.fhTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontDisplay,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => _handleAddSnapshot(context, provider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.fhAccentTeal.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "+ LOG SNAPSHOT",
                        style: TextStyle(
                          color: AppTheme.fhAccentTeal,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 220,
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
                
                // Manual Data Point List
                if (snapshots.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
                      color: AppTheme.fhBgDark.withOpacity(0.3),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: AppTheme.fhBgMedium.withOpacity(0.5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text("DATE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text("TIME INVESTED", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text("PROGRESS", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                              SizedBox(width: 24),
                            ],
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshots.length,
                          itemBuilder: (context, index) {
                            // Sort descending for list
                            final sortedList = List.from(snapshots)..sort((a,b) => b.timestamp.compareTo(a.timestamp));
                            final snap = sortedList[index];
                            return InkWell(
                              onTap: () => _handlePointTap(context, provider, snap),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(DateFormat('MMM dd').format(snap.timestamp), style: const TextStyle(color: AppTheme.fhTextPrimary, fontSize: 12)),
                                    Text(helper.formatTime(snap.totalSecondsInvested.toDouble()), style: const TextStyle(color: AppTheme.fhTextPrimary, fontFamily: 'RobotoMono', fontSize: 12)),
                                    Text("${(snap.progress * 100).toInt()}%", style: const TextStyle(color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold, fontSize: 12)),
                                    Icon(MdiIcons.pencilOutline, size: 14, color: AppTheme.fhTextSecondary),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}