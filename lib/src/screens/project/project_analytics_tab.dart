import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/project/project_calculations.dart';
import 'package:missions/src/screens/project/project_dialogs.dart';
import 'package:missions/src/screens/project/project_weekly_chart.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class ProjectPlanBriefingHero extends StatelessWidget {
  final Project project;
  final Color accentColor;
  final AppProvider provider;

  const ProjectPlanBriefingHero({
    super.key,
    required this.project,
    required this.accentColor,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final planText = project.files.isNotEmpty
        ? project.files.first.content
        : (project.description.isNotEmpty ? project.description : 'NO OPERATIONAL PLAN INITIALIZED.');
    final planTitle = project.files.isNotEmpty ? project.files.first.name : 'OPERATIONAL DIRECTIVE';

    return HudPanel(
      clip: HudClip.both,
      accent: accentColor,
      brackets: true,
      allBrackets: true,
      background: accentColor.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(MdiIcons.shieldAlertOutline, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '// ${planTitle.toUpperCase()}',
                  style: GoogleFonts.jetBrainsMono(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (project.files.isNotEmpty) ...[
                IconButton(
                  icon: Icon(MdiIcons.pencilOutline, color: accentColor, size: 16),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () => showFileEditor(context, provider, project, project.files.first),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(MdiIcons.deleteOutline, color: JweTheme.accentRed, size: 16),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    final updated = project.files.where((x) => x.id != project.files.first.id).toList();
                    provider.updateProject(project.copyWith(files: updated));
                  },
                ),
              ] else
                IconButton(
                  icon: Icon(MdiIcons.plus, color: accentColor, size: 16),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () => showAddFileDialog(context, provider, project),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ArcSurfaces.dim(0.4),
              border: Border.all(color: accentColor.withValues(alpha: 0.15)),
            ),
            child: Text(
              planText,
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMid,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectAnalyticsTab extends StatelessWidget {
  final Project project;
  final AppProvider provider;
  final Color accentColor;

  const ProjectAnalyticsTab({
    super.key,
    required this.project,
    required this.provider,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final streak = calculateProjectStreak(project, provider);

    double totalSeconds = 0;
    for (final key in project.linkedTaskKeys) {
      final parts = key.split('|');
      if (parts.length < 2) continue;
      final mainId = parts[0];
      final subId = parts[1];

      final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == mainId);
      final sub = mainTask?.subTasks.firstWhereOrNull((s) => s.id == subId);
      if (sub == null) continue;

      for (final session in sub.sessions) {
        totalSeconds += session.durationSeconds;
      }

      final timer = provider.activeTimers[sub.id];
      if (timer != null && timer.isRunning) {
        final elapsed = DateTime.now().difference(timer.startTime).inSeconds;
        totalSeconds += elapsed;
      }
    }

    final totalHours = (totalSeconds / 3600).floor();
    final totalMinutes = ((totalSeconds / 60) % 60).floor();
    final totalTimeDisplay = '${totalHours}h ${totalMinutes.toString().padLeft(2, '0')}m';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProjectPlanBriefingHero(
            project: project,
            accentColor: accentColor,
            provider: provider,
          ),
          const SizedBox(height: 16),
          HudPanel(
            clip: HudClip.br,
            accent: accentColor,
            brackets: true,
            allBrackets: true,
            background: accentColor.withValues(alpha: 0.06),
            child: Row(
              children: [
                Icon(MdiIcons.fire, color: JweTheme.accentRed, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROJECT OPERATION STREAK',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$streak DAYS ACTIVE',
                        style: GoogleFonts.rajdhani(
                          color: JweTheme.textWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'MIN 15m / DAY',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HudPanel(
            clip: HudClip.br,
            accent: accentColor,
            brackets: true,
            allBrackets: true,
            background: accentColor.withValues(alpha: 0.06),
            child: Row(
              children: [
                Icon(MdiIcons.clockOutline, color: accentColor, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL TIME SPENT',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalTimeDisplay,
                        style: GoogleFonts.rajdhani(
                          color: JweTheme.textWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'WEEKLY GRAPH USAGE',
            style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 10),
          ProjectWeeklyChart(project: project, accentColor: accentColor),
        ],
      ),
    );
  }
}
