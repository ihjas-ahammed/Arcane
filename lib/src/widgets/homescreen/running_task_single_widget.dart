import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'running_task_action_button.dart';

class RunningTaskSingleWidget extends StatelessWidget {
  final bool hasTask;
  final bool isCheckpoint;
  final bool isRunning;
  final int accumulatedSeconds;
  final String title;
  final String subtitle;
  final String capacity;
  final Color neonCyan;
  final Color neonRed;
  final HudTone Function(Color) toneFor;
  final String Function(double) ringLabel;

  const RunningTaskSingleWidget({
    super.key,
    required this.hasTask,
    required this.isCheckpoint,
    required this.isRunning,
    required this.accumulatedSeconds,
    required this.title,
    required this.subtitle,
    required this.capacity,
    required this.neonCyan,
    required this.neonRed,
    required this.toneFor,
    required this.ringLabel,
  });

  @override
  Widget build(BuildContext context) {
    final accent = !hasTask
        ? JweTheme.textMuted
        : (isCheckpoint
            ? JweTheme.accentCyan
            : JweTheme.accentAmber);
    final tone = toneFor(accent);

    final statusLabel = !hasTask
        ? 'QUEUE EMPTY'
        : (isCheckpoint
            ? (isRunning ? 'CHECKPOINT · ENGAGED' : 'CHECKPOINT · STANDBY')
            : (isRunning ? 'ACTIVE · ENGAGED' : 'ACTIVE · STANDBY'));

    final ringSec = accumulatedSeconds.toDouble();
    final ringPct = ((ringSec % 3600) / 3600 * 100).clamp(0.0, 100.0);

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 400,
        height: 200,
        child: ClipPath(
          clipper: const Chamfer4CornerClipper(chamfer: 10.0),
          child: CustomPaint(
            foregroundPainter: TacticalCardBorderPainter(
              themeColor: accent,
              chamfer: 10.0,
              bracketSize: 12.0,
            ),
            child: Container(
              color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Status Bar ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.25))),
                    ),
                    child: Row(
                      children: [
                        HudDot(tone: tone),
                        const SizedBox(width: 8),
                        Text(
                          statusLabel,
                          style: GoogleFonts.rajdhani(
                            fontSize: 10.5,
                            color: accent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        if (isRunning)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              'REC',
                              style: GoogleFonts.rajdhani(
                                fontSize: 10,
                                color: accent,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(color: JweTheme.lineSoft),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(MdiIcons.formatListBulleted, size: 10, color: JweTheme.textMid),
                              const SizedBox(width: 4),
                              Text(
                                'DAY PLAN',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 9.5,
                                  color: JweTheme.textMid,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Body ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          hasTask ? title.toUpperCase() : 'NO PLAN SET',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.rajdhani(
                            color: JweTheme.textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            height: 1.15,
                          ),
                        ),
                        if (hasTask && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.08),
                                  border: Border(left: BorderSide(color: accent, width: 2)),
                                ),
                                constraints: const BoxConstraints(maxWidth: 360),
                                child: Text(
                                  subtitle.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.rajdhani(
                                    color: JweTheme.textMid,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            HudRing(
                              value: ringPct,
                              size: 52,
                              stroke: 4.5,
                              tone: tone,
                              label: ringLabel(ringSec),
                              sub: isRunning ? 'SESSION' : 'TODAY',
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'OPERATIONAL CAPACITY',
                                    style: GoogleFonts.rajdhani(
                                      color: JweTheme.textMuted,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    capacity.isNotEmpty ? capacity : 'NO TARGET ESTIMATES SET',
                                    style: GoogleFonts.rajdhani(
                                      color: JweTheme.textWhite,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'ENGAGEMENT STATUS',
                                    style: GoogleFonts.rajdhani(
                                      color: JweTheme.textMuted,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    isRunning ? 'REC LIVE TICKING' : 'STANDBY IDLE',
                                    style: GoogleFonts.rajdhani(
                                      color: isRunning
                                          ? (JweTheme.isLight ? const Color(0xFF047857) : const Color(0xFF10B981))
                                          : JweTheme.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ── Action Row ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: RunningTaskActionButton(
                            label: hasTask ? (isRunning ? 'HALT SESSION' : 'ENGAGE') : 'OPEN PLAN',
                            icon: isRunning ? MdiIcons.pause : MdiIcons.play,
                            primary: !isRunning && hasTask,
                            accent: isRunning ? neonRed : neonCyan,
                          ),
                        ),
                        if (hasTask && isCheckpoint) ...[
                          const SizedBox(width: 8),
                          RunningTaskActionButton(
                            label: 'CHECK',
                            icon: Icons.check,
                            primary: false,
                            accent: neonCyan,
                            width: 80,
                          ),
                        ],
                        const SizedBox(width: 8),
                        RunningTaskActionButton(
                          label: hasTask ? 'FINISH' : 'REFRESH',
                          icon: hasTask ? MdiIcons.checkAll : Icons.refresh,
                          primary: false,
                          accent: hasTask ? JweTheme.accentAmber : JweTheme.textMuted,
                          width: 80,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
