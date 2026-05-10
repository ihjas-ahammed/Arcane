import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

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
