import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/day_budget_helper.dart' show formatMinutes;
import 'package:missions/src/widgets/ui/hud_components.dart';

import 'package:missions/src/utils/task_calculations.dart';

/// Operator HUD active-mission card. Live-ticking radial elapsed ring,
/// engagement controls, finish action.
class ScheduleHeroWidget extends StatefulWidget {
  final MainTask? mainTask;
  final SubTask? subTask;
  final SubSubTask? checkpoint;
  final bool isRunning;

  /// True when the headlined item is today's Phoenix (most-important task).
  final bool isPhoenix;

  /// Day-capacity readout: total planned vs realistic (buffer-aware) minutes.
  final int plannedMinutes;
  final int realisticMinutes;

  /// Static accumulated time today, NOT including the current run.
  /// Hero adds live elapsed-since-[sessionStart] internally each tick.
  final double accumulatedTodaySeconds;

  /// Wall-clock start of the current running session (null if not running).
  final DateTime? sessionStart;

  final VoidCallback onPlayPause;
  final VoidCallback onOpenPlan;
  final VoidCallback onFinishCheckpoint;
  final VoidCallback onFinishSubTask;
  final VoidCallback onTitleTap;

  final List<ResolvedDayPlanItem> topFiveTasks;
  final void Function(ResolvedDayPlanItem item) onCheckTask;

  const ScheduleHeroWidget({
    super.key,
    this.mainTask,
    this.subTask,
    this.checkpoint,
    required this.isRunning,
    this.isPhoenix = false,
    this.plannedMinutes = 0,
    this.realisticMinutes = 0,
    required this.accumulatedTodaySeconds,
    this.sessionStart,
    required this.onPlayPause,
    required this.onOpenPlan,
    required this.onFinishCheckpoint,
    required this.onFinishSubTask,
    required this.onTitleTap,
    this.topFiveTasks = const [],
    required this.onCheckTask,
  });

  @override
  State<ScheduleHeroWidget> createState() => _ScheduleHeroWidgetState();
}

class _ScheduleHeroWidgetState extends State<ScheduleHeroWidget> {
  Timer? _ticker;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _restartTickerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ScheduleHeroWidget old) {
    super.didUpdateWidget(old);
    if (old.isRunning != widget.isRunning) _restartTickerIfNeeded();
  }

  void _restartTickerIfNeeded() {
    _ticker?.cancel();
    if (widget.isRunning) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  HudTone _toneFor(Color c) {
    if (c == JweTheme.accentCyan) return HudTone.cyan;
    if (c == JweTheme.accentTeal) return HudTone.teal;
    if (c == JweTheme.accentRed) return HudTone.red;
    return HudTone.amber;
  }

  /// Compact ring label. <1h: MM:SS. ≥1h: Hh MMm.
  String _ringLabel(double sec) {
    final s = sec.floor();
    if (s < 3600) {
      final m = (s ~/ 60).toString().padLeft(2, '0');
      final ss = (s % 60).toString().padLeft(2, '0');
      return '$m:$ss';
    }
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.subTask == null;
    final isCheckpoint = widget.checkpoint != null;

    final accent = isEmpty
        ? JweTheme.textMuted
        : (widget.isPhoenix
            ? JweTheme.accentAmber
            : (isCheckpoint
                ? JweTheme.accentCyan
                : (widget.mainTask?.taskColor ?? JweTheme.accentAmber)));
    final tone = _toneFor(accent);

    final title = isEmpty
        ? 'NO PLAN SET'
        : (isCheckpoint ? widget.checkpoint!.name.toUpperCase() : widget.subTask!.name.toUpperCase());
    final sub = isEmpty
        ? 'QUEUE STANDBY'
        : (isCheckpoint
            ? '${widget.mainTask?.name ?? ''} · ${widget.subTask!.name}'.toUpperCase()
            : (widget.mainTask?.name ?? '').toUpperCase());

    // ── Live time math ─────────────────────────────────
    double liveSeconds = 0;
    if (widget.isRunning && widget.sessionStart != null) {
      liveSeconds = DateTime.now().difference(widget.sessionStart!).inSeconds.toDouble();
      if (liveSeconds < 0) liveSeconds = 0;
    }
    final displayTotal = widget.accumulatedTodaySeconds + liveSeconds;

    // Ring indicator: live session within current hour (loops). Standby:
    // total today vs an aspirational 60min target. Either way: bounded 0–100.
    final ringSec = widget.isRunning ? liveSeconds : displayTotal;
    final ringPct = ((ringSec % 3600) / 3600 * 100).clamp(0.0, 100.0);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0) {
            setState(() => _isExpanded = true);
          } else if (details.primaryVelocity! < 0) {
            setState(() => _isExpanded = false);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: HudPanel(
          clip: HudClip.both,
          accent: accent,
          allBrackets: true,
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ── Status bar ───────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.25))),
              ),
              child: Row(children: [
                if (widget.isPhoenix && !isEmpty) ...[
                  Icon(MdiIcons.fire, size: 12, color: accent),
                  const SizedBox(width: 6),
                ] else ...[
                  HudDot(tone: tone),
                  const SizedBox(width: 10),
                ],
                Text(
                  isEmpty
                      ? 'QUEUE EMPTY'
                      : (widget.isPhoenix
                          ? 'PHOENIX · ${widget.isRunning ? "ENGAGED" : "STANDBY"}'
                          : (isCheckpoint
                              ? 'CHECKPOINT · ${widget.isRunning ? "ENGAGED" : "STANDBY"}'
                              : (widget.isRunning ? 'ACTIVE · ENGAGED' : 'ACTIVE · STANDBY'))),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10, color: accent, fontWeight: FontWeight.w600, letterSpacing: 1.6,
                  ),
                ),
                const Spacer(),
                if (widget.isRunning)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('REC',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9, color: accent, fontWeight: FontWeight.w700, letterSpacing: 1.4,
                        )).animate(onPlay: (c) => c.repeat()).fadeOut(duration: 700.ms, delay: 700.ms),
                  ),
                InkWell(
                  onTap: widget.onOpenPlan,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: JweTheme.lineSoft),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(MdiIcons.formatListBulleted, size: 11, color: JweTheme.textMid),
                      const SizedBox(width: 4),
                      Text('DAY PLAN',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9, color: JweTheme.textMid, fontWeight: FontWeight.w600, letterSpacing: 1.4,
                          )),
                    ]),
                  ),
                ),
              ]),
            ),
  
            // ── Body ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                if (!isEmpty)
                  HudRing(
                    value: ringPct,
                    size: 58,
                    stroke: 4,
                    tone: tone,
                    label: _ringLabel(ringSec),
                    sub: widget.isRunning ? 'SESSION' : 'TODAY',
                  ),
                if (!isEmpty) const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: isEmpty ? null : widget.onTitleTap,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                            letterSpacing: 0.4,
                          )),
                      if (sub.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textMid,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.4,
                            )),
                      ],
                      if (!isEmpty && widget.realisticMinutes > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'CAP ${formatMinutes(widget.plannedMinutes)} / ${formatMinutes(widget.realisticMinutes)}',
                          style: GoogleFonts.jetBrainsMono(
                            color: widget.plannedMinutes > widget.realisticMinutes
                                ? JweTheme.accentRed
                                : JweTheme.textMuted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),

            // ── Top Five Tasks Checklist (visible when expanded) ─────────
            if (_isExpanded) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(color: JweTheme.lineSoft, height: 16),
                    Text(
                      'DAILY QUEUE (TOP 5)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: JweTheme.textMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.topFiveTasks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'NO PLAN SET',
                          style: GoogleFonts.saira(
                            fontSize: 12,
                            color: JweTheme.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...widget.topFiveTasks.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: JweTheme.bgBase.withValues(alpha: 0.4),
                            border: Border(left: BorderSide(color: item.color, width: 2.5)),
                          ),
                          child: Row(
                            children: [
                              if (item.isPhoenix) ...[
                                Icon(Icons.fireplace, size: 13, color: JweTheme.accentAmber),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.saira(
                                        color: item.isPhoenix ? JweTheme.accentAmber : JweTheme.textWhite,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      item.parentName.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.textMuted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Check button
                              InkWell(
                                onTap: () => widget.onCheckTask(item),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: item.isPhoenix ? JweTheme.accentAmber : JweTheme.accentTeal,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 14,
                                    color: item.isPhoenix ? JweTheme.accentAmber : JweTheme.accentTeal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
  
            // ── Action row ───────────────────────────────
            if (!isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: _HudActionButton(
                      label: widget.isRunning ? 'HALT SESSION' : 'ENGAGE',
                      icon: widget.isRunning ? MdiIcons.pause : MdiIcons.play,
                      primary: !widget.isRunning,
                      accent: widget.isRunning ? JweTheme.accentRed : accent,
                      onTap: widget.onPlayPause,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HudActionButton(
                    label: 'FINISH',
                    icon: MdiIcons.checkAll,
                    primary: false,
                    accent: accent,
                    onTap: isCheckpoint ? widget.onFinishCheckpoint : widget.onFinishSubTask,
                  ),
                ]),
              ),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 360.ms).slideY(begin: -0.04, end: 0);
  }
}

class _HudActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool primary;
  final VoidCallback onTap;

  const _HudActionButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary ? JweTheme.bgDeep : accent;
    final bg = primary ? accent : Colors.transparent;
    return InkWell(
      onTap: onTap,
      child: ClipPath(
        clipper: HudCutClipper(clip: HudClip.br, cut: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: accent, width: 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.saira(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                )),
          ]),
        ),
      ),
    );
  }
}
