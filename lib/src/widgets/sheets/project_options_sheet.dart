import 'package:flutter/material.dart';
import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/sheets/change_agent_sheet.dart';
import 'package:missions/src/widgets/dialogs/project_dialogs.dart';
import 'package:missions/src/widgets/dialogs/downgrade_to_mission_dialog.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

class ProjectOptionsSheet extends StatelessWidget {
  final Project project;
  final String currentMainTaskId;

  const ProjectOptionsSheet({
    super.key,
    required this.project,
    required this.currentMainTaskId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Container(
      color: AppTheme.fhBgDeepDark,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(color: AppTheme.fhBorderColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            
            Text(
              project.title.toUpperCase(),
              style: const TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.fhTextPrimary,
                letterSpacing: 1.2
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),

            _buildOption(
              context,
              icon: MdiIcons.pencilOutline,
              label: "EDIT DETAILS",
              onTap: () async {
                Navigator.pop(context); // Close sheet first
                final result = await showDialog<Map<String, String>>(
                  context: context,
                  builder: (ctx) => AddEditProjectDialog(
                    mainTaskId: currentMainTaskId,
                    projectId: project.id,
                    initialTitle: project.title,
                    initialDescription: project.description,
                  ),
                );
                if (result != null) {
                  provider.projectActions.updateProjectDetails(
                    currentMainTaskId, project.id, result['title']!, result['desc']!
                  );
                }
              },
            ),

            _buildOption(
              context,
              icon: MdiIcons.accountSwitchOutline,
              label: "CHANGE AGENT",
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => ChangeAgentSheet(projectId: project.id, currentMainTaskId: currentMainTaskId),
                );
              },
            ),

            _buildOption(
              context,
              icon: project.isActive ? MdiIcons.pauseCircleOutline : MdiIcons.playCircleOutline,
              label: project.isActive ? "DEACTIVATE OPERATION" : "ACTIVATE OPERATION",
              color: project.isActive ? AppTheme.fhAccentOrange : AppTheme.fhAccentGreen,
              onTap: () {
                provider.projectActions.toggleProjectStatus(currentMainTaskId, project.id, !project.isActive);
                Navigator.pop(context);
              },
            ),

            _buildOption(
              context,
              icon: MdiIcons.arrowCollapseDown,
              label: "DOWNGRADE TO MISSION",
              color: AppTheme.fhAccentPurple,
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => DowngradeToMissionDialog(projectName: project.title),
                );
                if (confirm == true) {
                  provider.projectActions.downgradeProjectToSubtask(currentMainTaskId, project);
                }
              },
            ),

            Divider(color: AppTheme.fhBorderColor.withValues(alpha: 0.2)),

            _buildOption(
              context,
              icon: MdiIcons.deleteOutline,
              label: "DELETE PROJECT",
              color: AppTheme.fhAccentRed,
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, provider);
              },
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    final effectiveColor = color ?? AppTheme.fhTextPrimary;
    return ListTile(
      leading: Icon(icon, color: effectiveColor),
      title: Text(label, style: TextStyle(color: effectiveColor, fontWeight: FontWeight.bold, fontFamily: AppTheme.fontBody, fontSize: 14)),
      onTap: onTap,
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgMedium,
        title: const Text("DELETE PROJECT?", style: TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay)),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed),
            onPressed: () {
              provider.projectActions.deleteProject(currentMainTaskId, project.id);
              Navigator.pop(ctx);
            },
            child: const Text("DELETE")
          )
        ],
      )
    );
  }
}