import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/screens/project/project_releases_tab.dart';
import 'package:missions/src/screens/project/project_tasks_tab.dart';
import 'package:missions/src/screens/project/project_logs_tab.dart';
import 'package:missions/src/screens/project/project_analytics_tab.dart';

export 'package:missions/src/screens/project/project_calculations.dart';
export 'package:missions/src/screens/project/project_weekly_chart.dart';
export 'package:missions/src/screens/project/project_dialogs.dart';
export 'package:missions/src/screens/project/project_note_card.dart';
export 'package:missions/src/screens/project/project_releases_tab.dart';
export 'package:missions/src/screens/project/project_tasks_tab.dart';
export 'package:missions/src/screens/project/project_logs_tab.dart';
export 'package:missions/src/screens/project/project_analytics_tab.dart';

class ProjectDetailView extends StatefulWidget {
  final Project project;
  final VoidCallback onBack;

  const ProjectDetailView({super.key, required this.project, required this.onBack});

  @override
  State<ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<ProjectDetailView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Project? _liveProject;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Project _getLiveProject(AppProvider provider) {
    try {
      return provider.projects.firstWhere((p) => p.id == widget.project.id);
    } catch (_) {
      return _liveProject ?? widget.project;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final project = _getLiveProject(provider);
    final accentColor = provider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;

    return Scaffold(
      backgroundColor: JweTheme.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: JweTheme.panel,
              child: TabBar(
                controller: _tabController,
                indicatorColor: accentColor,
                labelColor: accentColor,
                dividerColor: accentColor.withValues(alpha: 0.20),
                unselectedLabelColor: JweTheme.textMuted,
                labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(icon: Icon(MdiIcons.rocketLaunchOutline, size: 20)),
                  Tab(icon: Icon(MdiIcons.formatListCheckbox, size: 20)),
                  Tab(icon: Icon(MdiIcons.notebookOutline, size: 20)),
                  Tab(icon: Icon(MdiIcons.chartTimelineVariant, size: 20)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ProjectReleasesTab(project: project, provider: provider, accentColor: accentColor),
                  ProjectTasksTab(project: project, provider: provider, accentColor: accentColor),
                  ProjectLogsTab(project: project, provider: provider, accentColor: accentColor),
                  ProjectAnalyticsTab(project: project, provider: provider, accentColor: accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
