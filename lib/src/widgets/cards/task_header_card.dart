import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/atoms/valorant_timer_text.dart';
import 'package:missions/src/widgets/screens/submission_detail_screen.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/ui/step_bars_row.dart';
import 'package:provider/provider.dart';

/// Operator HUD active-mission card. Replaces the older
/// "Spider-Man gadget" style with the tactical clip-corner panel.
class TaskHeaderCard extends StatelessWidget {
  final MainTask task;
  final int yesterdayTime;
  final List<bool> weeklyCompletion;

  const TaskHeaderCard({
    super.key,
    required this.task,
    required this.yesterdayTime,
    required this.weeklyCompletion,
  });

  @override
  Widget build(BuildContext context) {
    final hours = (task.dailyTimeSpent / 3600).floor();
    final minutes = ((task.dailyTimeSpent / 60) % 60).floor();
    final timeDisplay = '${hours}H ${minutes.toString().padLeft(2, '0')}M';

    final tone = _toneFor(task.taskColor);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: HudPanel(
        clip: HudClip.both,
        accent: task.taskColor,
        allBrackets: true,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status bar ──────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: task.taskColor.withOpacity(0.25))),
              ),
              child: Row(children: [
                HudDot(tone: tone),
                const SizedBox(width: 10),
                Text('ACTIVE PROTOCOL',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: task.taskColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.8,
                    )),
                const Spacer(),
                Text('REC',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: task.taskColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    )).animate(onPlay: (c) => c.repeat()).fadeOut(duration: 700.ms, delay: 700.ms),
              ]),
            ),

            // ── Body ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.name.toUpperCase(),
                      style: GoogleFonts.saira(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: JweTheme.textWhite,
                        height: 1.05,
                        letterSpacing: 0.6,
                      )),
                  const SizedBox(height: 10),
                  if (task.description.trim().isNotEmpty)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 2, height: 36, color: task.taskColor.withOpacity(0.40)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(task.description,
                            maxLines: 3, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: JweTheme.textMid,
                              fontSize: 12,
                              height: 1.45,
                            )),
                      ),
                    ]),
                  const SizedBox(height: 18),

                  // ── Telemetry strip ───────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    decoration: BoxDecoration(
                      color: JweTheme.bgDeep.withOpacity(0.55),
                      border: Border.all(color: JweTheme.lineSoft),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: HudStat(
                          label: 'Session time',
                          value: timeDisplay,
                          tone: HudTone.amber,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: HudStat(
                          label: 'Yesterday',
                          value: _fmtSeconds(yesterdayTime),
                          tone: HudTone.cyan,
                          size: 20,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: task.taskColor.withOpacity(0.10),
                          border: Border.all(color: task.taskColor.withOpacity(0.40)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(MdiIcons.targetAccount, color: task.taskColor, size: 14),
                          const SizedBox(width: 6),
                          Text(task.theme.toUpperCase(),
                              style: GoogleFonts.jetBrainsMono(
                                color: task.taskColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.6,
                              )),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // ── Weekly completion strip ───────────
                  Row(children: [
                    Text('WEEK',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10, color: JweTheme.textMuted,
                          fontWeight: FontWeight.w600, letterSpacing: 1.6,
                        )),
                    const SizedBox(width: 10),
                    ...List.generate(weeklyCompletion.length, (i) {
                      final on = weeklyCompletion[i];
                      return Container(
                        margin: const EdgeInsets.only(right: 4),
                        width: 18, height: 6,
                        decoration: BoxDecoration(
                          color: on ? task.taskColor : const Color(0x1AA8B3C7),
                          boxShadow: on ? [BoxShadow(color: task.taskColor.withOpacity(0.5), blurRadius: 4)] : null,
                        ),
                      );
                    }),
                  ]),

                  // ── Live running-session strip (interactive) ──
                  _LiveSessionStrip(task: task),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }

  HudTone _toneFor(Color c) {
    if (c == JweTheme.accentCyan) return HudTone.cyan;
    if (c == JweTheme.accentTeal) return HudTone.teal;
    if (c == JweTheme.accentRed) return HudTone.red;
    return HudTone.amber;
  }

  String _fmtSeconds(int sec) {
    final h = (sec / 3600).floor();
    final m = ((sec / 60) % 60).floor();
    return '${h}H ${m.toString().padLeft(2, '0')}M';
  }
}

/// Surfaces the currently running subtask under [task]. Tappable strip with
/// live timer, HALT button, and inline step-bars for quick toggles. Hides
/// itself when no subtask of this main task is running.
class _LiveSessionStrip extends StatefulWidget {
  final MainTask task;
  const _LiveSessionStrip({required this.task});

  @override
  State<_LiveSessionStrip> createState() => _LiveSessionStripState();
}

class _LiveSessionStripState extends State<_LiveSessionStrip> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Find a running subtask scoped to this main task.
    final runningEntry = provider.activeTimers.entries.firstWhereOrNull(
        (e) => e.value.isRunning &&
            e.value.type == 'subtask' &&
            e.value.mainTaskId == widget.task.id);

    if (runningEntry == null) return const SizedBox.shrink();

    final liveSub = widget.task.subTasks
        .firstWhereOrNull((s) => s.id == runningEntry.key && !s.isDeleted);
    if (liveSub == null) return const SizedBox.shrink();

    final accent = widget.task.taskColor;
    final timerState = runningEntry.value;
    final accumulated = TaskCalculations.getHistoricalTodaySeconds(liveSub);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ClipPath(
        clipper: HudCutClipper(clip: HudClip.br, cut: 10),
        child: Container(
          decoration: BoxDecoration(
            color: accent.withOpacity(0.10),
            border: Border.all(color: accent.withOpacity(0.55), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header row: LIVE badge, name, timer, halt ───────────
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubmissionDetailScreen(
                        parentTask: widget.task, subTask: liveSub),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Animated REC dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: accent.withOpacity(0.7), blurRadius: 6)
                          ],
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat())
                          .fadeOut(duration: 700.ms, delay: 700.ms),
                      const SizedBox(width: 8),
                      Text('LIVE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            color: accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                          )),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 14, color: accent.withOpacity(0.4)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              liveSub.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.saira(
                                color: JweTheme.textWhite,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            ValorantTimerText(
                              isRunning: true,
                              startTime: timerState.startTime,
                              accumulatedTime: accumulated,
                              style: GoogleFonts.jetBrainsMono(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // HALT button
                      InkWell(
                        onTap: () {
                          provider.timerActions.pauseTimer(liveSub.id);
                          provider.timerActions.logTimerAndReset(liveSub.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: JweTheme.accentRed.withOpacity(0.18),
                            border: Border.all(color: JweTheme.accentRed),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(MdiIcons.pause,
                                  size: 12, color: JweTheme.accentRed),
                              const SizedBox(width: 4),
                              Text('HALT',
                                  style: GoogleFonts.saira(
                                    color: JweTheme.accentRed,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Quick-toggle bars for this subtask's nested steps ──
              if (liveSub.subSubTasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: StepBarsRow(
                    steps: liveSub.subSubTasks,
                    accent: accent,
                    padding: EdgeInsets.zero,
                    collapsible: false,
                    onToggle: (step) {
                      if (step.completed) {
                        provider.taskActions.uncompleteSubSubtask(
                            widget.task.id, liveSub.id, step.id);
                      } else {
                        provider.taskActions.completeSubSubtask(
                            widget.task.id, liveSub.id, step.id);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
