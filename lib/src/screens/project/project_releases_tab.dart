import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/screens/project/project_calculations.dart';
import 'package:missions/src/screens/project/project_dialogs.dart';

class ProjectReleasesTab extends StatelessWidget {
  final Project project;
  final AppProvider provider;
  final Color accentColor;

  const ProjectReleasesTab({
    super.key,
    required this.project,
    required this.provider,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final unreleased = project.releases.where((r) => !r.isReleased).toList();
    final released = project.releases.where((r) => r.isReleased).toList();
    final nextTask = resolveNextProjectTask(project, provider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (nextTask != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.06),
                border: Border(left: BorderSide(color: nextTask.color, width: 3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEXT ACTIVE CONTRACT STEP',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextTask.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          nextTask.parentName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(MdiIcons.checkboxBlankCircleOutline, color: accentColor, size: 22),
                    onPressed: () {
                      if (nextTask.targetCheckpointId != null) {
                        provider.taskActions.completeSubSubtask(
                          nextTask.mainTaskId,
                          nextTask.subTaskId,
                          nextTask.targetCheckpointId!,
                        );
                      } else {
                        provider.taskActions.completeSubtask(
                          nextTask.mainTaskId,
                          nextTask.subTaskId,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Text(
                'RELEASE MILESTONES',
                style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => showAddOrEditReleaseDialog(context, provider, project, accent: accentColor),
                icon: Icon(MdiIcons.plus, size: 14, color: accentColor),
                label: Text('PLAN RELEASE', style: TextStyle(color: accentColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (project.releases.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: JweTheme.border),
              ),
              alignment: Alignment.center,
              child: Text('NO PLANNED RELEASES AVAILABLE.', style: TextStyle(color: JweTheme.textMuted, fontSize: 12)),
            )
          else ...[
            if (unreleased.isNotEmpty) ...[
              Text(
                'PLANNED / NEXT RELEASES',
                style: GoogleFonts.jetBrainsMono(color: accentColor, fontSize: 9, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...unreleased.map((r) => ProjectReleaseCard(
                    project: project,
                    release: r,
                    provider: provider,
                    accentColor: accentColor,
                  )),
              const SizedBox(height: 16),
            ],
            if (released.isNotEmpty) ...[
              Text(
                'COMPLETED / SHIPPED RELEASES',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...released.map((r) => ProjectReleaseCard(
                    project: project,
                    release: r,
                    provider: provider,
                    accentColor: accentColor,
                  )),
            ],
          ],
        ],
      ),
    );
  }
}

class ProjectReleaseCard extends StatelessWidget {
  final Project project;
  final ProjectRelease release;
  final AppProvider provider;
  final Color accentColor;

  const ProjectReleaseCard({
    super.key,
    required this.project,
    required this.release,
    required this.provider,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: JweTheme.panel,
      shape: Border(left: BorderSide(color: release.isReleased ? JweTheme.accentTeal : accentColor, width: 3)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        color: release.isReleased
                            ? JweTheme.accentTeal.withValues(alpha: 0.12)
                            : accentColor.withValues(alpha: 0.12),
                        child: Text(
                          release.version,
                          style: GoogleFonts.jetBrainsMono(
                            color: release.isReleased ? JweTheme.accentTeal : accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          release.title.toUpperCase(),
                          style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  if (release.date != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'TARGET DATE: ${DateFormat('yyyy-MM-dd').format(release.date!)}',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(MdiIcons.pencilOutline, color: accentColor, size: 18),
              tooltip: 'Edit Release',
              onPressed: () => showAddOrEditReleaseDialog(
                context,
                provider,
                project,
                existingRelease: release,
                accent: accentColor,
              ),
            ),
            IconButton(
              icon: Icon(
                release.isReleased ? MdiIcons.checkboxMarkedCircleOutline : MdiIcons.checkboxBlankCircleOutline,
                color: release.isReleased ? JweTheme.accentTeal : JweTheme.textMuted,
              ),
              onPressed: () {
                final updatedReleases = project.releases.map((rel) {
                  if (rel.id == release.id) {
                    return ProjectRelease(
                      id: rel.id,
                      version: rel.version,
                      title: rel.title,
                      date: rel.date,
                      isReleased: !rel.isReleased,
                    );
                  }
                  return rel;
                }).toList();
                provider.updateProject(project.copyWith(releases: updatedReleases));
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: JweTheme.accentRed),
              onPressed: () {
                final updatedReleases = project.releases.where((rel) => rel.id != release.id).toList();
                provider.updateProject(project.copyWith(releases: updatedReleases));
              },
            ),
          ],
        ),
      ),
    );
  }
}
