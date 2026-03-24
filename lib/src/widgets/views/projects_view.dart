import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
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
import 'package:google_fonts/google_fonts.dart';

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

    final activeOngoing = allProjects.where((i) => i.project.isActive && i.project.calculateProgress() < 1.0).toList()
      ..sort((a, b) => a.project.sortOrder.compareTo(b.project.sortOrder));

    final inactiveOngoing = allProjects.where((i) => !i.project.isActive && i.project.calculateProgress() < 1.0).toList();
    final completed = allProjects.where((i) => i.project.calculateProgress() >= 1.0).toList();

    return Column(
      children: [
        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PROJECT PROTOCOLS",
                    style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 28, letterSpacing: 1.5)),
                const Text("ACTIVE OPERATIONS", style: TextStyle(color: JweTheme.textMuted, fontSize: 12, letterSpacing: 2.0, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),

                OverallProjectProgressCard(activeProjects: activeOngoing.map((e) => e.project).toList()),
                const SizedBox(height: 32),

                Row(
                  children: [
                    Container(width: 4, height: 16, color: JweTheme.accentAmber),
                    const SizedBox(width: 8),
                    Text("ONGOING OPS",
                        style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (activeOngoing.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: JweTheme.panel.withOpacity(0.5),
                        border: Border.all(color: JweTheme.border)),
                    child: Column(
                      children: [
                        Icon(MdiIcons.folderOutline, size: 48, color: JweTheme.textMuted.withOpacity(0.6)),
                        const SizedBox(height: 12),
                        const Text("NO ACTIVE PROJECTS", style: TextStyle(color: JweTheme.textMuted, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _showCreateProjectSheet(context),
                          child: const Text("INITIALIZE NEW PROJECT", style: TextStyle(color: JweTheme.accentCyan)),
                        )
                      ],
                    ),
                  ),
              ],
            ),
            
            onReorder: (int oldIndex, int newIndex) {
              if (oldIndex < newIndex) newIndex -= 1;
              final item = activeOngoing.removeAt(oldIndex);
              activeOngoing.insert(newIndex, item);
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

            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                
                if (inactiveOngoing.isNotEmpty) ...[
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Icon(MdiIcons.pauseCircleOutline, color: JweTheme.textMuted, size: 20),
                          const SizedBox(width: 8),
                          const Text("INACTIVE OPS", style: TextStyle(color: JweTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: JweTheme.panel, borderRadius: BorderRadius.circular(4)),
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

                Row(
                  children: [
                    Container(width: 4, height: 16, color: JweTheme.accentCyan),
                    const SizedBox(width: 8),
                    Text("QUICK ACTIONS",
                        style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
                  ],
                ),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () => _showCreateProjectSheet(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                        color: JweTheme.accentCyan.withOpacity(0.1),
                        border: Border.all(color: JweTheme.accentCyan)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(MdiIcons.plus, color: JweTheme.accentCyan),
                        const SizedBox(width: 8),
                        Text("CREATE NEW PROJECT",
                            style: GoogleFonts.rajdhani(
                                color: JweTheme.accentCyan,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                fontSize: 16)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

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
            children: activeOngoing.map((item) {
              return Container(
                key: ValueKey("proj_${item.project.id}"),
                margin: const EdgeInsets.only(bottom: 4), 
                child: ProjectDashboardCard(
                  project: item.project,
                  mainTaskId: item.mainTaskId,
                  mainTaskName: item.mainTaskName,
                  accentColor: item.color,
                  onTap: () => _navigateToDetail(context, item),
                ),
              );
            }).toList(),
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