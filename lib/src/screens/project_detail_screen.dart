import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/ui/project_step_list_tile.dart';
import 'package:arcane/src/widgets/cards/project_stats_card.dart';
import 'package:arcane/src/widgets/ui/project_graph_section.dart'; 
import 'package:arcane/src/widgets/dialogs/project_dialogs.dart'; 
import 'package:arcane/src/widgets/dialogs/ai_generation_prompt_dialog.dart';
import 'package:arcane/src/widgets/ui/jwe_progress_bar.dart';
import 'package:arcane/src/widgets/items/draggable_step_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectDetailScreen extends StatelessWidget {
  final Project project;
  final String mainTaskId;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.mainTaskId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    Project currentProject = project;
    try {
      final task = provider.mainTasks.firstWhere((t) => t.id == mainTaskId);
      currentProject = task.projects.firstWhere((p) => p.id == project.id);
    } catch (e) {
      // Fallback
    }

    final double progress = currentProject.calculateProgress();
    final int percentage = (progress * 100).toInt();

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: JweTheme.textWhite),
        actions: [
          IconButton(
            icon: Icon(MdiIcons.pencilOutline, size: 20, color: JweTheme.textMuted),
            tooltip: "Edit Project Details",
            onPressed: () async {
              final result = await showDialog<Map<String, String>>(
                context: context,
                builder: (ctx) => AddEditProjectDialog(
                  mainTaskId: mainTaskId,
                  projectId: currentProject.id,
                  initialTitle: currentProject.title,
                  initialDescription: currentProject.description,
                ),
              );

              if (result != null) {
                provider.projectActions.updateProjectDetails(mainTaskId,
                    currentProject.id, result['title']!, result['desc']!);
              }
            },
          ),
          IconButton(
            icon: Icon(MdiIcons.deleteOutline,
                size: 20, color: JweTheme.accentRed),
            onPressed: () {
              _confirmDelete(context, provider, currentProject);
            },
          )
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PROJECT // PROTOCOL",
                    style: TextStyle(
                      color: JweTheme.accentCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentProject.title.toUpperCase(),
                    style: GoogleFonts.rajdhani(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: JweTheme.textWhite,
                      height: 0.9,
                      letterSpacing: 1.5
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(left: 12),
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: JweTheme.accentAmber, width: 3))
                    ),
                    child: Text(
                      currentProject.description.isNotEmpty
                          ? currentProject.description
                          : "NO DESCRIPTION DATA.",
                      style: const TextStyle(
                        color: JweTheme.textMuted,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  ProjectStatsCard(
                    project: currentProject,
                    allTasks: provider.mainTasks,
                  ),

                  const SizedBox(height: 24),

                  ProjectGraphSection(
                    project: currentProject,
                    mainTaskId: mainTaskId,
                  ),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("COMPLETION STATUS", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      Text("$percentage%", style: GoogleFonts.rajdhani(fontSize: 24, color: JweTheme.textWhite, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  JweProgressBar(progress: progress, color: JweTheme.accentCyan),

                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "OBJECTIVES",
                        style: GoogleFonts.rajdhani(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.0,
                            color: JweTheme.textWhite),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _showAiStepGenerationDialog(context, provider, currentProject),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF8A2BE2))),
                              child: Icon(MdiIcons.robotExcitedOutline, size: 16, color: const Color(0xFF8A2BE2)),
                            ),
                          ),
                          InkWell(
                            onTap: () => _showAddRootStepDialog(context, provider),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(border: Border.all(color: JweTheme.accentCyan)),
                              child: const Icon(Icons.add, size: 16, color: JweTheme.accentCyan),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (currentProject.steps.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(MdiIcons.textLong,
                                size: 48,
                                color: JweTheme.textMuted.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            const Text(
                              "NO OBJECTIVES SET",
                              style: TextStyle(color: JweTheme.textMuted, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentProject.steps.length,
                      itemBuilder: (context, index) {
                        final step = currentProject.steps[index];
                        return DraggableStepWrapper(
                          stepId: step.id,
                          onMove: (draggedId, targetId, pos) {
                            provider.projectActions.moveStepRelative(mainTaskId, currentProject.id, draggedId, targetId, pos);
                          },
                          child: ProjectStepListTile(
                            key: ValueKey(step.id),
                            step: step,
                            mainTaskId: mainTaskId,
                            projectId: currentProject.id,
                            indexPrefix: "${index + 1}",
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: Text("ADD OBJECTIVE", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: JweTheme.textWhite,
                        side: const BorderSide(color: JweTheme.border),
                        shape: const BeveledRectangleBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 16)
                      ),
                      onPressed: () => _showAddRootStepDialog(context, provider),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddRootStepDialog(
      BuildContext context, AppProvider provider) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddEditStepDialog(),
    );

    if (result != null) {
      provider.projectActions.addRootStep(
          mainTaskId, project.id, result['title']!, result['desc']!);
    }
  }

  void _showAiStepGenerationDialog(BuildContext context, AppProvider provider, Project currentProject) async {
    final prompt = await showDialog<String>(
      context: context,
      builder: (context) => const AiGenerationPromptDialog(
        title: "GENERATE STEPS", 
        hintText: "E.g., Suggest testing phases for this project...", 
        actionLabel: "GENERATE"
      ),
    );

    if (prompt != null && prompt.isNotEmpty) {
      provider.projectActions.generateStepsForProject(mainTaskId, currentProject.id, prompt);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Generation Initiated...")));
      }
    }
  }

  void _confirmDelete(
      BuildContext context, AppProvider provider, Project project) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: JweTheme.panel,
              title: Text("DELETE PROJECT?",
                  style: GoogleFonts.rajdhani(color: JweTheme.accentRed, fontWeight: FontWeight.bold)),
              content: const Text("This action cannot be undone.", style: TextStyle(color: JweTheme.textMuted)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("CANCEL", style: TextStyle(color: JweTheme.textMuted))),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: JweTheme.accentRed, foregroundColor: Colors.white),
                    onPressed: () {
                      provider.projectActions
                          .deleteProject(mainTaskId, project.id);
                      Navigator.pop(ctx);
                      Navigator.pop(context); 
                    },
                    child: const Text("DELETE"))
              ],
            ));
  }
}