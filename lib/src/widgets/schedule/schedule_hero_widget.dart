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
  final List<ResolvedDayPlanItem> multitaskItems;
  final void Function(ResolvedDayPlanItem item)? onCheckMultitaskItem;

  const ScheduleHeroWidget({
    super.key,
    this.mainTask,
    this.subTask,
    this.checkpoint,
    required this.isRunning,
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
    this.multitaskItems = const [],
    this.onCheckMultitaskItem,
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
    final resolvedCheckpoint = widget.checkpoint ?? (isEmpty ? null : TaskCalculations.nextCheckpoint(widget.subTask!));
    final isCheckpoint = resolvedCheckpoint != null;

    final accent = isEmpty
        ? JweTheme.textMuted
        : (isCheckpoint
            ? JweTheme.accentCyan
            : (widget.mainTask?.taskColor ?? JweTheme.accentAmber));
    final tone = _toneFor(accent);

    final title = isEmpty
        ? 'NO PLAN SET'
        : (isCheckpoint ? resolvedCheckpoint.name.toUpperCase() : widget.subTask!.name.toUpperCase());
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
        // The 1 Hz session ticker repaints this panel; the boundary keeps
        // that from invalidating the rest of the schedule page layer.
        child: RepaintBoundary(
          child: ClipPath(
            clipper: const Chamfer4CornerClipper(chamfer: 10.0),
            child: CustomPaint(
              foregroundPainter: TacticalCardBorderPainter(
                themeColor: accent,
                chamfer: 10.0,
                bracketSize: 12.0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: JweTheme.isLight ? 0.08 : 0.05),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ── Status bar ───────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.25))),
              ),
              child: Row(children: [
                HudDot(tone: tone),
                const SizedBox(width: 10),
                Text(
                  isEmpty && widget.multitaskItems.isEmpty
                      ? 'QUEUE EMPTY'
                      : (widget.multitaskItems.length > 1
                          ? 'MULTITASK PROTOCOL · [${widget.multitaskItems.length} ACTIVE]'
                          : (isCheckpoint
                              ? 'CHECKPOINT · ${widget.isRunning ? "ENGAGED" : "STANDBY"}'
                              : (widget.isRunning ? 'ACTIVE · ENGAGED' : 'ACTIVE · STANDBY'))),
                  style: GoogleFonts.rajdhani(
                    fontSize: 11, color: accent, fontWeight: FontWeight.bold, letterSpacing: 1.6,
                  ),
                ),
                const Spacer(),
                if (widget.isRunning)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('REC',
                        style: GoogleFonts.rajdhani(
                          fontSize: 10, color: accent, fontWeight: FontWeight.bold, letterSpacing: 1.4,
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
                          style: GoogleFonts.rajdhani(
                            fontSize: 10, color: JweTheme.textMid, fontWeight: FontWeight.bold, letterSpacing: 1.4,
                          )),
                    ]),
                  ),
                ),
              ]),
            ),
  
            // ── Body ─────────────────────────────────────
            if (widget.multitaskItems.length > 1)
              _buildMultitaskBody(context, accent, tone)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: isEmpty ? null : widget.onTitleTap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.rajdhani(
                              color: JweTheme.textWhite,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (sub.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.08),
                                border: Border(left: BorderSide(color: accent, width: 2)),
                              ),
                              child: Text(
                                sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.rajdhani(
                                  color: JweTheme.textMid,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          HudRing(
                            value: ringPct,
                            size: 64,
                            stroke: 5,
                            tone: tone,
                            label: _ringLabel(ringSec),
                            sub: widget.isRunning ? 'SESSION' : 'TODAY',
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OPERATIONAL CAPACITY',
                                  style: GoogleFonts.rajdhani(
                                    color: JweTheme.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.realisticMinutes > 0
                                      ? '${formatMinutes(widget.plannedMinutes)} PLANNED / ${formatMinutes(widget.realisticMinutes)} CAPACITY'
                                      : 'NO TARGET ESTIMATES SET',
                                  style: GoogleFonts.rajdhani(
                                    color: widget.plannedMinutes > widget.realisticMinutes
                                        ? (JweTheme.isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B))
                                        : JweTheme.textWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'ENGAGEMENT STATUS',
                                  style: GoogleFonts.rajdhani(
                                    color: JweTheme.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.isRunning ? 'REC LIVE TICKING' : 'STANDBY IDLE',
                                  style: GoogleFonts.rajdhani(
                                    color: widget.isRunning
                                        ? (JweTheme.isLight ? JweTheme.accentTeal : const Color(0xFF10B981))
                                        : JweTheme.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            // ── Top Five Tasks Checklist (visible when expanded) ─────────
            if (_isExpanded) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                     Divider(color: JweTheme.lineSoft, height: 16),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.saira(
                                        color: JweTheme.textWhite,
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
                                      color: JweTheme.accentTeal,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.transparent,
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
            if (!isEmpty || widget.multitaskItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: _HudActionButton(
                      label: widget.isRunning ? 'HALT SESSION' : 'ENGAGE',
                      icon: widget.isRunning ? MdiIcons.pause : MdiIcons.play,
                      primary: !widget.isRunning,
                      accent: widget.isRunning
                          ? (JweTheme.isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B))
                          : (JweTheme.isLight ? JweTheme.accentCyan : const Color(0xFF00F0FF)),
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
      ),
    ),
  ),
).animate().fadeIn(duration: 360.ms).slideY(begin: -0.04, end: 0);
  }

  Widget _buildMultitaskBody(BuildContext context, Color accent, HudTone tone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.multitaskItems.map((item) {
                final itemBorderColor = item.isRunning
                    ? (JweTheme.isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B))
                    : (JweTheme.isLight ? JweTheme.calibrate(item.color) : item.color);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ClipPath(
                      clipper: const Chamfer4CornerClipper(chamfer: 6.0),
                      child: CustomPaint(
                        foregroundPainter: TacticalCardBorderPainter(
                          themeColor: itemBorderColor,
                          chamfer: 6.0,
                          bracketSize: 8.0,
                        ),
                        child: Container(
                          height: double.infinity,
                          padding: const EdgeInsets.all(8),
                          color: JweTheme.isLight ? JweTheme.panel2 : const Color(0xFF05080C),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.parentName.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.rajdhani(
                                            color: JweTheme.isLight ? JweTheme.calibrate(item.color) : item.color,
                                            fontSize: 9.5,
                                            letterSpacing: 1.2,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.name.toUpperCase(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.rajdhani(
                                      color: JweTheme.textWhite,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.checklist_rounded,
                                        size: 11,
                                        color: item.totalCheckpoints > 0
                                            ? JweTheme.accentCyan
                                            : JweTheme.textMuted,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        item.totalCheckpoints > 0
                                            ? '${item.completedCheckpoints}/${item.totalCheckpoints}'
                                            : '0/0',
                                        style: GoogleFonts.rajdhani(
                                          color: item.totalCheckpoints > 0
                                              ? JweTheme.accentCyan
                                              : JweTheme.textMuted,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: () => widget.onCheckMultitaskItem?.call(item),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: JweTheme.accentCyan.withValues(alpha: JweTheme.isLight ? 0.7 : 0.6),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check, size: 12, color: JweTheme.accentCyan),
                                        const SizedBox(width: 3),
                                        Text(
                                          'DONE',
                                          style: GoogleFonts.rajdhani(
                                            color: JweTheme.accentCyan,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.realisticMinutes > 0
                    ? '${formatMinutes(widget.plannedMinutes)} PLANNED / ${formatMinutes(widget.realisticMinutes)} CAPACITY'
                    : 'TARGET CAPACITY',
                style: GoogleFonts.rajdhani(
                  color: widget.plannedMinutes > widget.realisticMinutes
                      ? (JweTheme.isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B))
                      : JweTheme.textMid,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.isRunning ? 'REC LIVE TICKING' : 'STANDBY IDLE',
                style: GoogleFonts.rajdhani(
                  color: widget.isRunning
                      ? (JweTheme.isLight ? JweTheme.accentTeal : const Color(0xFF10B981))
                      : JweTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
    final fg = primary ? JweTheme.onAccent : accent;
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
