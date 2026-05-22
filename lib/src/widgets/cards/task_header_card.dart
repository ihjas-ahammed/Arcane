import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

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

                  // ── Telemetry & Weekly Panel ───────────
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: JweTheme.bgDeep.withOpacity(0.4),
                      border: Border(
                        left: BorderSide(color: task.taskColor, width: 3),
                        top: BorderSide(color: JweTheme.lineSoft, width: 1),
                        bottom: BorderSide(color: JweTheme.lineSoft, width: 1),
                        right: BorderSide(color: JweTheme.lineSoft, width: 1),
                      ),
                    ),
                    child: Column(
                      children: [
                        // ── Stats row ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              // TODAY cell
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: JweTheme.accentAmber.withOpacity(0.6), width: 2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('SESSION',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9, color: JweTheme.textMuted,
                                            fontWeight: FontWeight.w600, letterSpacing: 1.6,
                                          )),
                                      const SizedBox(height: 3),
                                      Text(timeDisplay,
                                          style: GoogleFonts.saira(
                                            fontSize: 18, fontWeight: FontWeight.w700,
                                            color: JweTheme.accentAmber, height: 1,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                              // YESTERDAY cell
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: JweTheme.accentCyan.withOpacity(0.6), width: 2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('YESTERDAY',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9, color: JweTheme.textMuted,
                                            fontWeight: FontWeight.w600, letterSpacing: 1.6,
                                          )),
                                      const SizedBox(height: 3),
                                      Text(_fmtSeconds(yesterdayTime),
                                          style: GoogleFonts.saira(
                                            fontSize: 18, fontWeight: FontWeight.w700,
                                            color: JweTheme.accentCyan, height: 1,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                              // Order Type chip
                              HudChip(
                                label: task.theme,
                                tone: tone,
                                icon: MdiIcons.hexagonOutline,
                              ),
                            ],
                          ),
                        ),
                        // ── Divider ──
                        Container(height: 1, color: JweTheme.lineSoft.withOpacity(0.5)),
                        // ── Weekly strip ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                          child: Row(children: [
                            Icon(MdiIcons.calendarWeek, size: 11, color: JweTheme.textMuted),
                            const SizedBox(width: 6),
                            Text('WEEK',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9, color: JweTheme.textMuted,
                                  fontWeight: FontWeight.w600, letterSpacing: 1.4,
                                )),
                            const Spacer(),
                            ...List.generate(weeklyCompletion.length, (i) {
                              final on = weeklyCompletion[i];
                              final dayLabel = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i % 7];
                              return Padding(
                                padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 26, height: 5,
                                      decoration: BoxDecoration(
                                        color: on ? task.taskColor : JweTheme.textMuted.withValues(alpha: 0.12),
                                        border: Border.all(
                                          color: on ? task.taskColor.withValues(alpha: 0.8) : JweTheme.textMuted.withValues(alpha: 0.25),
                                          width: 1,
                                        ),
                                        boxShadow: on ? [
                                          BoxShadow(color: task.taskColor.withValues(alpha: 0.5), blurRadius: 4),
                                        ] : null,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(dayLabel,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 7,
                                          color: on ? task.taskColor.withValues(alpha: 0.8) : JweTheme.textMuted.withValues(alpha: 0.4),
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ],
                                ),
                              );
                            }),
                          ]),
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
