import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/project/project_dialogs.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/screens/submission_detail_screen.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class ProjectTasksTab extends StatelessWidget {
  final Project project;
  final AppProvider provider;
  final Color accentColor;

  const ProjectTasksTab({
    super.key,
    required this.project,
    required this.provider,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [];

    for (var i = 0; i < project.linkedTaskKeys.length; i++) {
      final key = project.linkedTaskKeys[i];
      final parts = key.split('|');
      if (parts.length < 2) continue;
      final mainId = parts[0];
      final subId = parts[1];

      final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == mainId);
      final sub = mainTask?.subTasks.firstWhereOrNull((s) => s.id == subId);

      if (mainTask != null && sub != null) {
        final timerState = provider.activeTimers[sub.id];
        final isRunning = timerState?.isRunning ?? false;

        final displayBaseTime = isRunning
            ? TaskCalculations.getHistoricalTodaySeconds(sub)
            : TaskCalculations.getTodaySeconds(sub, timerState);

        final hours = (displayBaseTime / 3600).floor();
        final minutes = ((displayBaseTime / 60) % 60).floor();
        final timeDisplay = '${hours}h ${minutes.toString().padLeft(2, '0')}m';

        final progress = sub.calculateProgress();

        cards.add(
          Padding(
            key: ValueKey(key),
            padding: const EdgeInsets.only(bottom: 10.0),
            child: HudPanel(
              clip: HudClip.br,
              accent: mainTask.taskColor,
              brackets: true,
              allBrackets: false,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(MdiIcons.drag, color: JweTheme.textMuted, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              color: mainTask.taskColor.withValues(alpha: 0.12),
                              child: Text(
                                mainTask.name.toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  color: mainTask.taskColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sub.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: JweTheme.textWhite,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (isRunning) ...[
                              const HudDot(tone: HudTone.red, size: 5),
                              const SizedBox(width: 4),
                            ],
                            IconButton(
                              icon: Icon(MdiIcons.openInNew, color: accentColor, size: 16),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SubmissionDetailScreen(parentTask: mainTask, subTask: sub),
                                  ),
                                );
                              },
                              tooltip: 'Open Task Details',
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(MdiIcons.linkOff, color: JweTheme.accentRed, size: 16),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (confirmCtx) => AlertDialog(
                                    backgroundColor: JweTheme.panel,
                                    title: Text('UNLINK CONTRACT?', style: TextStyle(color: JweTheme.accentRed)),
                                    content: Text('Unlink "${sub.name}" from project?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(confirmCtx, false), child: const Text('CANCEL')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentRed),
                                        onPressed: () => Navigator.pop(confirmCtx, true),
                                        child: const Text('UNLINK'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final updatedKeys = project.linkedTaskKeys.where((k) => k != key).toList();
                                  provider.updateProject(project.copyWith(linkedTaskKeys: updatedKeys));
                                }
                              },
                              tooltip: 'Unlink Task',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'STATUS: ',
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8.5),
                            ),
                            Text(
                              isRunning ? 'RUNNING' : (sub.completed ? 'COMPLETED' : 'PENDING'),
                              style: GoogleFonts.jetBrainsMono(
                                color: isRunning ? JweTheme.accentRed : (sub.completed ? JweTheme.accentTeal : JweTheme.textMid),
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'TIME SPENT: ',
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8.5),
                            ),
                            Text(
                              timeDisplay,
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 8.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: HudProgressBar(
                                value: progress * 100,
                                tone: sub.completed ? HudTone.teal : HudTone.cyan,
                                segments: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(progress * 100).round()}%',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.textWhite,
                                fontSize: 10,
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
          ),
        );
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'LINKED MISSION CONTRACTS',
                style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => showLinkTasksSearchDialog(context, provider, project),
                icon: Icon(MdiIcons.link, size: 14, color: accentColor),
                label: Text('LINK CONTRACT', style: TextStyle(color: accentColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (cards.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: JweTheme.border),
              ),
              alignment: Alignment.center,
              child: Text('NO CONTRACTS LINKED TO THIS MISSION.', style: TextStyle(color: JweTheme.textMuted, fontSize: 12)),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final updatedKeys = List<String>.from(project.linkedTaskKeys);
                final item = updatedKeys.removeAt(oldIndex);
                updatedKeys.insert(newIndex, item);
                provider.updateProject(project.copyWith(linkedTaskKeys: updatedKeys));
              },
              children: cards,
            ),
        ],
      ),
    );
  }
}
