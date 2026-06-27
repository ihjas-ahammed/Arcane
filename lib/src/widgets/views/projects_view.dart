import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/screens/project_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

class ProjectsView extends StatefulWidget {
  const ProjectsView({super.key});

  @override
  State<ProjectsView> createState() => _ProjectsViewState();
}

class _ProjectsViewState extends State<ProjectsView> {
  void _createNewProjectDialog(BuildContext context, AppProvider provider) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: JweTheme.accentAmber, width: 2),
          borderRadius: BorderRadius.zero,
        ),
        title: Text(
          'INITIALIZE PROJECT PROTOCOL',
          style: GoogleFonts.rajdhani(
            color: JweTheme.textWhite,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'PROJECT CODE / NAME',
                labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'OPERATIONAL OUTLINE / PLAN',
                labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ABORT', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentAmber,
              foregroundColor: Colors.black,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final project = Project(
                  id: const Uuid().v4(),
                  name: name,
                  description: descController.text.trim(),
                );
                provider.addProject(project);
                Navigator.pop(ctx);
              }
            },
            child: Text('DEPLOY', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showProjectOptions(BuildContext context, AppProvider provider, Project project) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: JweTheme.panel,
        title: Text(
          project.name.toUpperCase(),
          style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _editProjectDialog(context, provider, project);
            },
            child: Row(
              children: [
                Icon(MdiIcons.pencilOutline, color: JweTheme.accentAmber, size: 18),
                const SizedBox(width: 12),
                Text('Modify Protocol Details', style: GoogleFonts.inter(color: JweTheme.textWhite)),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (confirmCtx) => AlertDialog(
                  backgroundColor: JweTheme.panel,
                  title: Text(
                    'TERMINATE PROJECT PROTOCOL?',
                    style: GoogleFonts.rajdhani(color: JweTheme.accentRed, fontWeight: FontWeight.bold),
                  ),
                  content: const Text(
                    'This will delete the project plan and releases. Linked tasks themselves will NOT be deleted.',
                    style: TextStyle(color: JweTheme.textMuted),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmCtx, false),
                      child: const Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentRed, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(confirmCtx, true),
                      child: const Text('TERMINATE'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                provider.deleteProject(project.id);
              }
            },
            child: Row(
              children: [
                Icon(MdiIcons.deleteOutline, color: JweTheme.accentRed, size: 18),
                const SizedBox(width: 12),
                Text('Terminate Protocol', style: GoogleFonts.inter(color: JweTheme.accentRed)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editProjectDialog(BuildContext context, AppProvider provider, Project project) {
    final nameController = TextEditingController(text: project.name);
    final descController = TextEditingController(text: project.description);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: JweTheme.accentAmber, width: 2),
          borderRadius: BorderRadius.zero,
        ),
        title: Text(
          'MODIFY PROJECT CONFIG',
          style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'PROJECT NAME',
                labelStyle: const TextStyle(color: JweTheme.textMuted),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'PROJECT DESCRIPTION',
                labelStyle: const TextStyle(color: JweTheme.textMuted),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentAmber,
              foregroundColor: Colors.black,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final updated = project.copyWith(
                  name: name,
                  description: descController.text.trim(),
                );
                provider.updateProject(updated);
                Navigator.pop(ctx);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  double _calculateProgress(Project project, AppProvider provider) {
    int total = 0;
    int completed = 0;
    for (final key in project.linkedTaskKeys) {
      final parts = key.split('|');
      if (parts.length < 2) continue;
      final mainId = parts[0];
      final subId = parts[1];

      final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == mainId);
      final sub = mainTask?.subTasks.firstWhereOrNull((s) => s.id == subId);
      if (sub != null) {
        total++;
        if (sub.completed) completed++;
      }
    }
    if (total == 0) return 0.0;
    return completed / total;
  }

  ProjectRelease? _getNextRelease(Project project) {
    final unreleased = project.releases.where((r) => !r.isReleased).toList();
    if (unreleased.isEmpty) return null;
    unreleased.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });
    return unreleased.first;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final projectsList = provider.projects;
    final accentColor = provider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;

    if (provider.activeProjectId != null) {
      final activeProject = projectsList.firstWhereOrNull((p) => p.id == provider.activeProjectId);
      if (activeProject != null) {
        return ProjectDetailView(
          project: activeProject,
          onBack: () {
            provider.setActiveProjectId(null);
          },
        );
      } else {
        provider.setActiveProjectId(null);
      }
    }

    if (projectsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.folderAlertOutline, size: 48, color: JweTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'NO ACTIVE PROJECT NETWORKS DETECTED',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textWhite,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: Icon(MdiIcons.plus, color: accentColor),
              label: Text('INITIALIZE SYSTEM PROJECT', style: GoogleFonts.jetBrainsMono(color: accentColor)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                shape: const BeveledRectangleBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              onPressed: () => _createNewProjectDialog(context, provider),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: accentColor,
      backgroundColor: JweTheme.bgDeep,
      onRefresh: () async {
        await provider.performManualSync();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 4, height: 16, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  'MISSION PROJECTS',
                  style: GoogleFonts.jetBrainsMono(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(MdiIcons.plus, color: accentColor),
                  onPressed: () => _createNewProjectDialog(context, provider),
                  tooltip: 'Add Project',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: projectsList.length,
              itemBuilder: (context, index) {
                final project = projectsList[index];
                final progress = _calculateProgress(project, provider);
                final nextRelease = _getNextRelease(project);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: HudPanel(
                    clip: HudClip.br,
                    accent: accentColor,
                    brackets: true,
                    allBrackets: false,
                    padding: EdgeInsets.zero,
                    onTap: () {
                      provider.setActiveProjectId(project.id);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card Header
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: accentColor.withValues(alpha: 0.15)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(MdiIcons.hexagonMultipleOutline, color: accentColor, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  project.name.toUpperCase(),
                                  style: GoogleFonts.rajdhani(
                                    color: JweTheme.textWhite,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(MdiIcons.dotsVertical, color: JweTheme.textMuted, size: 16),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                onPressed: () => _showProjectOptions(context, provider, project),
                              ),
                            ],
                          ),
                        ),
                        // Card Body
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (project.description.isNotEmpty) ...[
                                Text(
                                  project.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: JweTheme.textMid,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'NEXT RELEASE',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: JweTheme.textMuted,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          nextRelease != null
                                              ? '${nextRelease.version} — ${nextRelease.title}'
                                              : 'NO ACTIVE PLANNED RELEASES',
                                          style: GoogleFonts.chakraPetch(
                                            color: nextRelease != null ? JweTheme.accentCyan : JweTheme.textMuted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'LINKED TASKS',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.textMuted,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${project.linkedTaskKeys.length} CONTRACTS',
                                        style: GoogleFonts.chakraPetch(
                                          color: accentColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Progress Bar
                              Row(
                                children: [
                                  Expanded(
                                    child: HudProgressBar(
                                      value: progress * 100,
                                      tone: progress >= 1.0 ? HudTone.teal : HudTone.amber,
                                      segments: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(progress * 100).round()}%',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: progress >= 1.0 ? JweTheme.accentTeal : accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
