import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/atoms/valorant_timer_text.dart';
import 'package:missions/src/widgets/screens/submission_detail_screen.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/ui/linked_task_indicator.dart';
import 'package:provider/provider.dart';

/// Operator HUD QueueRow — ported submission card. Preserves
/// Dismissible (delete/complete), timer engage, linked indicator,
/// recurring marker, hierarchical bar.
class SubmissionCard extends StatelessWidget {
  final MainTask parentTask;
  final SubTask subTask;

  const SubmissionCard({super.key, required this.parentTask, required this.subTask});

  void _openDetailScreen(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SubmissionDetailScreen(parentTask: parentTask, subTask: subTask),
    ));
  }

  HudTone _toneFor(Color c) {
    if (c == JweTheme.accentCyan) return HudTone.cyan;
    if (c == JweTheme.accentTeal) return HudTone.teal;
    if (c == JweTheme.accentRed) return HudTone.red;
    return HudTone.amber;
  }

  String _shortCode(String id) {
    final h = id.hashCode.abs() % 9000 + 1000;
    return 'M-$h';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final timerState = provider.activeTimers[subTask.id];

    SubTask current = subTask;
    try {
      final liveParent = provider.mainTasks.firstWhere((t) => t.id == parentTask.id);
      current = liveParent.subTasks.firstWhere((s) => s.id == subTask.id);
    } catch (_) {}

    final linkedInfo = provider.findLinkedProjectStepInfo(current.id);
    final isRunning = timerState?.isRunning ?? false;
    final isCompleted = current.completed;

    final displayBaseTime = isRunning
        ? TaskCalculations.getHistoricalTodaySeconds(current)
        : TaskCalculations.getTodaySeconds(current, timerState);

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    var total7Days = 0.0;
    for (var s in current.sessions) {
      if (s.startTime.isAfter(sevenDaysAgo)) total7Days += s.durationSeconds;
    }
    var avgSeconds = total7Days / 7.0;
    if (avgSeconds < 300) avgSeconds = 300;

    final fullTotalToday = TaskCalculations.getTodaySeconds(current, timerState);
    final usagePct = isCompleted ? 1.0 : (fullTotalToday / avgSeconds).clamp(0.0, 1.0);
    final hierarchical = current.calculateProgress();

    final accent = parentTask.taskColor;
    final tone = _toneFor(accent);

    final code = _shortCode(current.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('subtask_${current.id}'),
        direction: DismissDirection.horizontal,
        background: _swipeAction(
          alignment: Alignment.centerLeft,
          color: AppTheme.fhAccentRed,
          icon: Icons.delete_forever,
          label: 'DELETE',
        ),
        secondaryBackground: _swipeAction(
          alignment: Alignment.centerRight,
          color: isCompleted ? JweTheme.textMuted : JweTheme.accentTeal,
          icon: isCompleted ? MdiIcons.restore : MdiIcons.archiveArrowDownOutline,
          label: isCompleted ? 'RESTORE' : 'COMPLETE',
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            return await _showDeleteConfirm(context);
          } else if (direction == DismissDirection.endToStart) {
            if (isCompleted) {
              provider.taskActions.uncompleteSubtask(parentTask.id, current.id);
            } else {
              provider.taskActions.completeSubtask(parentTask.id, current.id);
            }
            return false;
          }
          return false;
        },
        onDismissed: (direction) {
          if (direction == DismissDirection.startToEnd) {
            provider.taskActions.deleteSubtask(parentTask.id, current.id);
          }
        },
        child: GestureDetector(
          onTap: () => _openDetailScreen(context),
          child: HudPanel(
            clip: HudClip.br,
            accent: accent,
            padding: EdgeInsets.zero,
            allBrackets: isRunning,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ── Left color bar ───────────────────
                Container(width: 4, color: accent),
                // ── Content ──────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      // header row
                      Row(children: [
                        Text(code,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10, color: JweTheme.textMuted, letterSpacing: 1.4, fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(width: 6),
                        Text('· ${parentTask.name.toUpperCase()}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10, color: accent, letterSpacing: 1.4, fontWeight: FontWeight.w600,
                            )),
                        const Spacer(),
                        if (current.isRecurring) ...[
                          Icon(MdiIcons.syncIcon, size: 11, color: JweTheme.textMuted),
                          const SizedBox(width: 6),
                        ],
                        if (isRunning)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            HudDot(tone: tone),
                            const SizedBox(width: 4),
                            Text('RUN',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9, color: accent, fontWeight: FontWeight.w700, letterSpacing: 1.4,
                                )),
                          ])
                        else if (isCompleted)
                          HudChip(label: 'ARCH', tone: HudTone.neutral)
                        else
                          HudChip(label: 'PEND', tone: HudTone.neutral),
                      ]),
                      const SizedBox(height: 6),
                      // title
                      Text(
                        current.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isCompleted ? JweTheme.textMuted : JweTheme.textWhite,
                          height: 1.3,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (linkedInfo != null) ...[
                        const SizedBox(height: 6),
                        LinkedTaskIndicator(
                          label: '${linkedInfo['projectTitle']} · ${linkedInfo['stepTitle']}',
                          onUnlink: () => provider.projectActions.unlinkStep(
                            linkedInfo['mainTaskId'], linkedInfo['projectId'], linkedInfo['stepId'],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // bar + telemetry row
                      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Expanded(
                          child: HudBar(
                            value: (current.hasCheckableSubsteps ? hierarchical : usagePct) * 100,
                            tone: tone,
                            height: 4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (current.hasCheckableSubsteps)
                          Text(
                            '${(hierarchical * 100).round()}%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10, color: JweTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1.0,
                            ),
                          ),
                        const SizedBox(width: 8),
                        ValorantTimerText(
                          isRunning: isRunning,
                          startTime: timerState?.startTime,
                          accumulatedTime: displayBaseTime,
                          style: GoogleFonts.jetBrainsMono(
                            color: isRunning ? accent : JweTheme.textMid,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ),
                // ── Engage button ────────────────────
                if (!isCompleted)
                  GestureDetector(
                    onTap: () {
                      if (isRunning) {
                        provider.timerActions.pauseTimer(subTask.id);
                        provider.timerActions.logTimerAndReset(subTask.id);
                      } else {
                        provider.timerActions.startTimer(subTask.id, 'subtask', parentTask.id);
                      }
                    },
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        color: isRunning ? accent.withOpacity(0.18) : Colors.transparent,
                        border: Border(left: BorderSide(color: JweTheme.lineSoft)),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(
                          isRunning ? MdiIcons.pause : MdiIcons.play,
                          size: 20,
                          color: isRunning ? accent : JweTheme.textMid,
                        ).animate(target: isRunning ? 1 : 0).scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.15, 1.15),
                              duration: 800.ms,
                              curve: Curves.easeInOut,
                            ).then().scale(
                              begin: const Offset(1.15, 1.15),
                              end: const Offset(1, 1),
                            ),
                        const SizedBox(height: 2),
                        Text(
                          isRunning ? 'HALT' : 'ENGAGE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8.5,
                            color: isRunning ? accent : JweTheme.textMid,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipeAction({required Alignment alignment, required Color color, required IconData icon, required String label}) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft
            ? [Icon(icon, color: Colors.white), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]
            : [Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(width: 8), Icon(icon, color: Colors.white)],
      ),
    );
  }

  Future<bool> _showDeleteConfirm(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.fhBgDark,
            title: const Text('DELETE MISSION?', style: TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay)),
            content: const Text('This action cannot be undone.', style: TextStyle(color: AppTheme.fhTextSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('DELETE'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
