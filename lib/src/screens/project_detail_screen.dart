import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/project_step_list_tile.dart';
import 'package:arcane/src/widgets/cards/project_stats_card.dart';
import 'package:arcane/src/widgets/cards/project_progress_chart.dart'; // Import Chart
import 'package:arcane/src/widgets/dialogs/project_dialogs.dart'; 
import 'package:arcane/src/widgets/dialogs/ai_generation_prompt_dialog.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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

    // Live Data Fetch
    Project currentProject = project;
    try {
      final task = provider.mainTasks.firstWhere((t) => t.id == mainTaskId);
      currentProject = task.projects.firstWhere((p) => p.id == project.id);
    } catch (e) {
      // Fallback
    }

    final double progress = currentProject.calculateProgress();
    final int percentage = (progress * 100).toInt();
    final history = provider.getProjectProgressHistory(currentProject); // Get History

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(MdiIcons.pencilOutline, size: 20, color: Colors.white),
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
                size: 20, color: AppTheme.fhAccentRed),
            onPressed: () {
              _confirmDelete(context, provider, currentProject);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Section
            Text(
              "PROJECT // PROTOCOL",
              style: TextStyle(
                color: AppTheme.fhAccentTeal,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentProject.title.toUpperCase(),
              style: const TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppTheme.fhTextPrimary,
                height: 0.9,
                letterSpacing: 1.5
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: AppTheme.fhAccentRed, width: 3))
              ),
              child: Text(
                currentProject.description.isNotEmpty
                    ? currentProject.description
                    : "NO DESCRIPTION DATA.",
                style: const TextStyle(
                  color: AppTheme.fhTextSecondary,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 24),
            
            // New Stats Card
            ProjectStatsCard(
              project: currentProject,
              allTasks: provider.mainTasks,
            ),

            const SizedBox(height: 24),

            // Progress Graph (Root Level)
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.2)),
              ),
              child: ProjectProgressChart(project: currentProject, history: history),
            ),

            const SizedBox(height: 32),

            // Progress Bar (Simple)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text("COMPLETION STATUS", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                Text("$percentage%", style: const TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 32, color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 8,
              width: double.infinity,
              color: AppTheme.fhBgDark,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(color: AppTheme.fhAccentRed),
              ),
            ),

            const SizedBox(height: 40),

            // Steps List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "OBJECTIVES",
                  style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 1.0,
                      color: AppTheme.fhTextPrimary),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _showAiStepGenerationDialog(context, provider, currentProject),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(border: Border.all(color: AppTheme.fhAccentPurple)),
                        child: Icon(MdiIcons.robotExcitedOutline, size: 16, color: AppTheme.fhAccentPurple),
                      ),
                    ),
                    InkWell(
                      onTap: () => _showAddRootStepDialog(context, provider),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(border: Border.all(color: AppTheme.fhAccentTeal)),
                        child: Icon(Icons.add, size: 16, color: AppTheme.fhAccentTeal),
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
                          color: AppTheme.fhTextSecondary.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      const Text(
                        "NO OBJECTIVES SET",
                        style: TextStyle(color: AppTheme.fhTextSecondary, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentProject.steps.length,
                onReorder: (oldIndex, newIndex) {
                  provider.projectActions.reorderRootSteps(
                      mainTaskId, currentProject.id, oldIndex, newIndex);
                },
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final step = currentProject.steps[index];
                  return KeyedSubtree(
                    key: ValueKey(step.id),
                    child: ProjectStepListTile(
                      step: step,
                      mainTaskId: mainTaskId,
                      projectId: currentProject.id,
                      indexPrefix: "${index + 1}",
                    ),
                  );
                },
              ),

            const SizedBox(height: 40),
            
            Row(
              children: [
                Expanded(
                  child: ValorantButton(
                    label: "ADD OBJECTIVE",
                    onPressed: () => _showAddRootStepDialog(context, provider),
                    isPrimary: false,
                    icon: Icons.add,
                  ),
                ),
                const SizedBox(width: 16),
                
              ],
            ),
            
            const SizedBox(height: 40),
          ],
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
              backgroundColor: AppTheme.fhBgMedium,
              title: const Text("DELETE PROJECT?",
                  style: TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay)),
              content: const Text("This action cannot be undone."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("CANCEL")),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.fhAccentRed),
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