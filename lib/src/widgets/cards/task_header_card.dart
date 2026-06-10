import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/dialogs/jwe_task_options_dialog.dart';

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
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
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
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: task.taskColor.withValues(alpha: 0.2))),
              ),
              child: Row(children: [
                HudDot(tone: tone, size: 5),
                const SizedBox(width: 8),
                Text('ACTIVE PROTOCOL',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: task.taskColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    )),
                const Spacer(),
                Text('REC',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8,
                      color: task.taskColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    )).animate(onPlay: (c) => c.repeat()).fadeOut(duration: 700.ms, delay: 700.ms),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(MdiIcons.cogOutline, size: 13, color: task.taskColor.withValues(alpha: 0.6)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => JweTaskOptionsDialog(task: task),
                    );
                  },
                  tooltip: 'PROTOCOL OPTIONS',
                ),
              ]),
            ),

            // ── Body ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.name.toUpperCase(),
                      style: GoogleFonts.saira(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: JweTheme.textWhite,
                        height: 1.1,
                        letterSpacing: 0.5,
                      )),
                  if (task.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 1.5, height: 24, color: task.taskColor.withValues(alpha: 0.35)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(task.description,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: JweTheme.textMid,
                              fontSize: 11,
                              height: 1.35,
                            )),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 10),

                  // ── Telemetry Strip ───────────
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: JweTheme.bgDeep.withValues(alpha: 0.3),
                      border: Border(
                        left: BorderSide(color: task.taskColor, width: 2),
                        top: const BorderSide(color: JweTheme.lineSoft, width: 0.8),
                        bottom: const BorderSide(color: JweTheme.lineSoft, width: 0.8),
                        right: const BorderSide(color: JweTheme.lineSoft, width: 0.8),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // TODAY
                            Text('SESSION: ', style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: JweTheme.textMuted, fontWeight: FontWeight.w700)),
                            Text(timeDisplay, style: GoogleFonts.saira(fontSize: 12, color: JweTheme.accentAmber, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 14),
                            // YESTERDAY
                            Text('YDAY: ', style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: JweTheme.textMuted, fontWeight: FontWeight.w700)),
                            Text(_fmtSeconds(yesterdayTime), style: GoogleFonts.saira(fontSize: 12, color: JweTheme.accentCyan, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            // Theme Chip (Compact)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                border: Border.all(color: task.taskColor.withValues(alpha: 0.4)),
                                borderRadius: BorderRadius.circular(2.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(MdiIcons.hexagonOutline, size: 9, color: task.taskColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    task.theme.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(fontSize: 7.5, color: task.taskColor, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(height: 0.5, color: JweTheme.lineSoft),
                        const SizedBox(height: 6),
                        // WEEK
                        Row(
                          children: [
                            Icon(MdiIcons.calendarWeek, size: 10, color: JweTheme.textMuted),
                            const SizedBox(width: 4),
                            Text('WEEK',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 8, color: JweTheme.textMuted,
                                  fontWeight: FontWeight.w700, letterSpacing: 1.2,
                                )),
                            const Spacer(),
                            ...List.generate(weeklyCompletion.length, (i) {
                              final on = weeklyCompletion[i];
                              final dayLabel = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i % 7];
                              return Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 14, height: 3,
                                      decoration: BoxDecoration(
                                        color: on ? task.taskColor : JweTheme.textMuted.withValues(alpha: 0.1),
                                        border: Border.all(
                                          color: on ? task.taskColor.withValues(alpha: 0.7) : JweTheme.textMuted.withValues(alpha: 0.2),
                                          width: 0.6,
                                        ),
                                        boxShadow: on ? [
                                          BoxShadow(color: task.taskColor.withValues(alpha: 0.4), blurRadius: 2),
                                        ] : null,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(dayLabel,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 6,
                                          color: on ? task.taskColor : JweTheme.textMuted.withValues(alpha: 0.5),
                                          fontWeight: FontWeight.w700,
                                        )),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
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
