import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/widgets/cards/project_dashboard_card.dart';
import 'package:arcane/src/widgets/cards/quick_action_card.dart';
import 'package:arcane/src/widgets/cards/overall_project_progress_card.dart';
import 'package:arcane/src/widgets/ui/completed_projects_section.dart';
import 'package:arcane/src/widgets/sheets/create_project_sheet.dart';
import 'package:arcane/src/widgets/sheets/link_submission_sheet.dart';
import 'package:arcane/src/widgets/views/ai_prompts_view.dart';
import 'package:arcane/src/screens/project_detail_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

// Helper class to wrap project data for the view
class _ProjectViewItem {
  final Project project;
  final String mainTaskId;
  final String mainTaskName;
  final Color color;

  _ProjectViewItem({
    required this.project,
    required this.mainTaskId,
    required this.mainTaskName,
    required this.color,
  });
}

class ProjectsView extends StatefulWidget {
  const ProjectsView({super.key});

  @override
  State<ProjectsView> createState() => _ProjectsViewState();
}

class _ProjectsViewState extends State<ProjectsView> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    // Flatten all projects from all agents
    final List<_ProjectViewItem> allProjects = [];
    
    for (var task in provider.mainTasks) {
      for (var project in task.projects) {
        allProjects.add(_ProjectViewItem(
          project: project,
          mainTaskId: task.id,
          mainTaskName: task.name,
          color: task.taskColor,
        ));
      }
    }

    // Filter and Sort
    // 1. Ongoing Active
    final activeOngoing = allProjects.where((i) => i.project.isActive && i.project.calculateProgress() < 1.0).toList()
      ..sort((a, b) => a.project.sortOrder.compareTo(b.project.sortOrder));

    // 2. Ongoing Inactive
    final inactiveOngoing = allProjects.where((i) => !i.project.isActive && i.project.calculateProgress() < 1.0).toList();

    // 3. Completed
    final completed = allProjects.where((i) => i.project.calculateProgress() >= 1.0).toList();

    // For ReorderableListView, we need a list of widgets or a list of items to map.
    // However, ReorderableListView requires the full list to be reorderable or we use a CustomScrollView with SliverReorderableList.
    // Given we want headers above, we can use ReorderableListView with headers if we treat headers as non-reorderable items (complex).
    // OR we use the `header` parameter of `ReorderableListView` (available in Flutter 3+).
    
    return Column(
      children: [
        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text("PROJECT PROTOCOLS",
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold, fontFamily: AppTheme.fontDisplay, letterSpacing: 1.5)),
                const Text("ACTIVE OPERATIONS", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, letterSpacing: 2.0, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),

                // Overall Progress
                OverallProjectProgressCard(activeProjects: activeOngoing.map((e) => e.project).toList()),
                const SizedBox(height: 32),

                // Active Header
                Row(
                  children: [
                    Container(width: 4, height: 16, color: AppTheme.fhAccentOrange),
                    const SizedBox(width: 8),
                    Text("ONGOING OPS",
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold, fontFamily: AppTheme.fontDisplay, letterSpacing: 1.0)),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (activeOngoing.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: AppTheme.fhBgDark.withValues(alpha: 0.5),
                        border: Border.all(
                          color: AppTheme.fhBgMedium.withValues(alpha: 0.5),
                        )),
                    child: Column(
                      children: [
                        Icon(MdiIcons.folderOutline, size: 48, color: AppTheme.fhTextSecondary.withValues(alpha: 0.6)),
                        const SizedBox(height: 12),
                        const Text("NO ACTIVE PROJECTS", style: TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _showCreateProjectSheet(context),
                          child: const Text("INITIALIZE NEW PROJECT", style: TextStyle(color: AppTheme.fhAccentTeal)),
                        )
                      ],
                    ),
                  ),
              ],
            ),
            
            // The Reorderable Items (Active Projects)
            onReorder: (int oldIndex, int newIndex) {
              if (oldIndex < newIndex) newIndex -= 1;
              
              final item = activeOngoing.removeAt(oldIndex);
              activeOngoing.insert(newIndex, item);
              
              // Persist order
              // We need to pass the list of Project objects to the provider to update sortOrder
              provider.projectActions.reorderProjectsGlobal(activeOngoing.map((e) => e.project).toList());
            },
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                elevation: 5,
                shadowColor: Colors.black,
                child: child,
              );
            },
            children: activeOngoing.map((item) {
              return Container(
                key: ValueKey("proj_${item.project.id}"),
                margin: const EdgeInsets.only(bottom: 4), // Small margin handled by padding in card usually, but list view needs care
                child: ProjectDashboardCard(
                  project: item.project,
                  mainTaskId: item.mainTaskId,
                  mainTaskName: item.mainTaskName,
                  accentColor: item.color,
                  onTap: () => _navigateToDetail(context, item),
                ),
              );
            }).toList(),

            // Footer (Inactive, Completed, Actions)
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                
                // Inactive Ops
                if (inactiveOngoing.isNotEmpty) ...[
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Icon(MdiIcons.pauseCircleOutline, color: AppTheme.fhTextSecondary, size: 20),
                          const SizedBox(width: 8),
                          const Text("INACTIVE OPS", style: TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.fhBgMedium, borderRadius: BorderRadius.circular(4)),
                            child: Text("${inactiveOngoing.length}", style: const TextStyle(fontSize: 10, color: Colors.white)),
                          )
                        ],
                      ),
                      children: inactiveOngoing.map((item) {
                        return ProjectDashboardCard(
                          project: item.project,
                          mainTaskId: item.mainTaskId,
                          mainTaskName: item.mainTaskName,
                          accentColor: AppTheme.fhTextDisabled,
                          onTap: () => _navigateToDetail(context, item),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Completed
                if (completed.isNotEmpty)
                  CompletedProjectsSection(
                    completedProjects: completed.map((e) => {
                      'project': e.project,
                      'mainTaskId': e.mainTaskId,
                      'mainTaskName': e.mainTaskName,
                      'color': e.color
                    }).toList()
                  ),

                const SizedBox(height: 32),

                // Actions
                Row(
                  children: [
                    Container(width: 4, height: 16, color: AppTheme.fhAccentTeal),
                    const SizedBox(width: 8),
                    Text("QUICK ACTIONS",
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold, fontFamily: AppTheme.fontDisplay, letterSpacing: 1.0)),
                  ],
                ),
                const SizedBox(height: 16),

                // Primary Create Button
                GestureDetector(
                  onTap: () => _showCreateProjectSheet(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                        color: AppTheme.fhAccentRed,
                        borderRadius: BorderRadius.circular(0),
                        border: Border.all(color: AppTheme.fhAccentRed.withValues(alpha: 0.5))
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(MdiIcons.plus, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text("CREATE NEW PROJECT",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: AppTheme.fontDisplay,
                                letterSpacing: 1.5,
                                fontSize: 16)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Secondary Actions
                Row(
                  children: [
                    Expanded(
                      child: QuickActionCard(
                        icon: MdiIcons.robotOutline,
                        label: "AI PROMPTS",
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const AiPromptsView())),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: QuickActionCard(
                        icon: MdiIcons.targetVariant,
                        label: "LINK TASK",
                        onTap: () => _showLinkSubmissionSheet(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToDetail(BuildContext context, _ProjectViewItem item) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ProjectDetailScreen(
                project: item.project,
                mainTaskId: item.mainTaskId)));
  }

  void _showCreateProjectSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateProjectSheet(),
    );
  }

  void _showLinkSubmissionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LinkSubmissionSheet(),
    );
  }
}