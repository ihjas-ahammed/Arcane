import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// Progress % vs real wall-clock time chart.
/// X = elapsed minutes since the first recorded event.
/// Y = completion % at that moment.
/// When a timer is actively running the chart ticks every 5 s so the
/// live session always appears as the rightmost point on the curve.
class SubtaskProgressTimeChart extends StatefulWidget {
  final SubTask subTask;
  final Color accentColor;
  final VoidCallback? onSaveDataPoint;
  final bool isRunning;
  final DateTime? timerStartTime;

  const SubtaskProgressTimeChart({
    super.key,
    required this.subTask,
    required this.accentColor,
    this.onSaveDataPoint,
    this.isRunning = false,
    this.timerStartTime,
  });

  @override
  State<SubtaskProgressTimeChart> createState() => _SubtaskProgressTimeChartState();
}

class _SubtaskProgressTimeChartState extends State<SubtaskProgressTimeChart> {
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isRunning) _startTick();
  }

  @override
  void didUpdateWidget(SubtaskProgressTimeChart old) {
    super.didUpdateWidget(old);
    if (widget.isRunning && !old.isRunning) {
      _startTick();
    } else if (!widget.isRunning && old.isRunning) {
      _stopTick();
    }
  }

  @override
  void dispose() {
    _stopTick();
    super.dispose();
  }

  void _startTick() {
    _stopTick();
    _liveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTick() {
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  // ── Data helpers ─────────────────────────────────────────────

  double _sstProgressAt(SubSubTask sst, DateTime t) {
    final checkables = sst.substeps.where((s) => s.type != 'info').toList();
    if (checkables.isEmpty) {
      if (!sst.completed) return 0.0;
      if (sst.completionTimestamp == null) return 0.0;
      final ts = DateTime.tryParse(sst.completionTimestamp!);
      return (ts != null && !ts.isAfter(t)) ? 1.0 : 0.0;
    }
    double total = 0;
    for (final sub in checkables) {
      total += _sstProgressAt(sub, t);
    }
    return total / checkables.length;
  }

  double _progressAt(List<SubSubTask> checkables, DateTime t) {
    if (checkables.isEmpty) return widget.subTask.completed ? 1.0 : 0.0;
    double total = 0;
    for (final sst in checkables) {
      total += _sstProgressAt(sst, t);
    }
    return total / checkables.length;
  }

  void _collectTimestamps(SubSubTask sst, List<DateTime> out) {
    if (sst.type == 'info') return;
    if (sst.completed && sst.completionTimestamp != null) {
      final ts = DateTime.tryParse(sst.completionTimestamp!);
      if (ts != null) out.add(ts);
    }
    for (final sub in sst.substeps) {
      _collectTimestamps(sub, out);
    }
  }

  List<_Point> _buildPoints() {
    final sub = widget.subTask;
    final checkables = sub.subSubTasks.where((s) => s.type != 'info').toList();

    final events = <_Event>[];

    for (final s in sub.sessions) {
      events.add(_Event(time: s.startTime, type: _EventType.step));
      events.add(_Event(time: s.endTime, type: _EventType.session));
    }

    final completionTimes = <DateTime>[];
    for (final sst in checkables) {
      _collectTimestamps(sst, completionTimes);
    }
    if (sub.completed && sub.lastCompletedDate != null) {
      completionTimes.add(sub.lastCompletedDate!);
    }
    for (final ts in completionTimes) {
      events.add(_Event(time: ts, type: _EventType.step));
    }

    for (final dp in sub.progressDataPoints) {
      events.add(_Event(time: dp.timestamp, type: _EventType.snapshot));
    }

    // Live point — extend X to current moment while timer is running
    if (widget.isRunning && widget.timerStartTime != null) {
      events.add(_Event(time: DateTime.now(), type: _EventType.live));
    }

    if (events.isEmpty) return [];

    events.sort((a, b) => a.time.compareTo(b.time));
    final origin = events.first.time;

    final points = <_Point>[const _Point(0, 0)];

    for (final e in events) {
      final elapsedMins = e.time.difference(origin).inSeconds / 60.0;
      final prog = _progressAt(checkables, e.time);
      final last = points.last;
      if (elapsedMins != last.x || prog != last.y) {
        points.add(_Point(elapsedMins, prog));
      }
    }

    final finalProg = sub.calculateProgress();
    if (finalProg > points.last.y) {
      points.add(_Point(points.last.x, finalProg));
    }

    return points;
  }

  double get _totalSessionMins =>
      widget.subTask.sessions.fold(0.0, (s, sess) => s + sess.durationSeconds / 60.0);

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints();
    final hasData = points.length > 1;

    final totalElapsedMins = hasData ? points.last.x : 0.0;
    final currentProg = hasData ? points.last.y : 0.0;
    final sessionMins = _totalSessionMins;
    final sessionHours = sessionMins / 60.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: HudPanel(
        clip: HudClip.br,
        accent: widget.accentColor,
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: widget.accentColor.withValues(alpha: 0.20))),
            ),
            child: Row(children: [
              Container(width: 4, height: 12, color: widget.accentColor),
              const SizedBox(width: 10),
              Text('// PROGRESS TIMELINE',
                  style: GoogleFonts.jetBrainsMono(
                    color: widget.accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  )),
              const Spacer(),
              if (widget.isRunning)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: JweTheme.accentRed,
                    boxShadow: [BoxShadow(color: JweTheme.accentRed.withValues(alpha: 0.5), blurRadius: 4)],
                  ),
                ),
              if (widget.onSaveDataPoint != null)
                GestureDetector(
                  onTap: widget.onSaveDataPoint,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: widget.accentColor.withValues(alpha: 0.40)),
                      color: widget.accentColor.withValues(alpha: 0.08),
                    ),
                    child: Text('◉ MARK',
                        style: GoogleFonts.jetBrainsMono(
                          color: widget.accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        )),
                  ),
                ),
              if (hasData)
                Text(
                  '${(currentProg * 100).round()}%'
                  '${sessionMins > 0 ? ' · ${sessionHours >= 1 ? '${sessionHours.toStringAsFixed(1)}h' : '${sessionMins.round()}m'}' : ''}',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                ),
            ]),
          ),

          // ── Chart ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: hasData
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(
                      height: 130,
                      child: _ProgressLinePainterWidget(
                        points: points,
                        accent: widget.accentColor,
                        isLive: widget.isRunning,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _XAxisLabels(totalElapsedMins: totalElapsedMins),
                    const SizedBox(height: 10),
                    Row(children: [
                      _TelChip(
                        label: 'PROGRESS',
                        value: '${(currentProg * 100).round()}%',
                        color: JweTheme.accentCyan,
                      ),
                      if (sessionMins > 0) ...[
                        const SizedBox(width: 6),
                        _TelChip(
                          label: 'TIME IN',
                          value: sessionHours >= 1
                              ? '${sessionHours.toStringAsFixed(1)}h'
                              : '${sessionMins.round()}m',
                          color: widget.accentColor,
                        ),
                        if (currentProg > 0) ...[
                          const SizedBox(width: 6),
                          _TelChip(
                            label: 'RATE',
                            value: '${(currentProg * 100 / sessionMins).toStringAsFixed(1)}%/m',
                            color: JweTheme.accentAmber,
                          ),
                        ],
                      ],
                    ]),
                  ])
                : SizedBox(
                    height: 80,
                    child: Center(
                      child: Text(
                        'NO PROGRESS DATA YET',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Data types
// ─────────────────────────────────────────────────
class _Point {
  final double x;
  final double y;
  const _Point(this.x, this.y);
}

enum _EventType { session, step, snapshot, live }

class _Event {
  final DateTime time;
  final _EventType type;
  const _Event({required this.time, required this.type});
}

// ─────────────────────────────────────────────────
// X-axis labels widget
// ─────────────────────────────────────────────────
class _XAxisLabels extends StatelessWidget {
  final double totalElapsedMins;

  const _XAxisLabels({required this.totalElapsedMins});

  String _fmt(double m) {
    if (m == 0) return '0';
    if (m < 60) return '${m.round()}m';
    if (m < 60 * 24) {
      final h = (m / 60).floor();
      final rem = (m % 60).round();
      return rem == 0 ? '${h}h' : '${h}h${rem}m';
    }
    final d = (m / (60 * 24)).floor();
    final remH = ((m % (60 * 24)) / 60).round();
    return remH == 0 ? '${d}d' : '${d}d${remH}h';
  }

  @override
  Widget build(BuildContext context) {
    const count = 5;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(count, (i) {
        final t = totalElapsedMins * i / (count - 1);
        return Text(
          _fmt(t),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            color: JweTheme.textMuted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────
// Painter widget wrapper
// ─────────────────────────────────────────────────
class _ProgressLinePainterWidget extends StatelessWidget {
  final List<_Point> points;
  final Color accent;
  final bool isLive;

  const _ProgressLinePainterWidget({
    required this.points,
    required this.accent,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ProgressLinePainter(points: points, accent: accent, isLive: isLive),
      child: const SizedBox.expand(),
    );
  }
}

// ─────────────────────────────────────────────────
// Custom painter — smooth cubic bezier curve
// ─────────────────────────────────────────────────
class _ProgressLinePainter extends CustomPainter {
  final List<_Point> points;
  final Color accent;
  final bool isLive;

  _ProgressLinePainter({required this.points, required this.accent, required this.isLive});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final maxX = points.last.x;
    if (maxX <= 0) return;

    // ── Y-axis grid lines ──────────────────────────
    final gridPaint = Paint()
      ..color = JweTheme.accentCyan.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    final labelStyle = GoogleFonts.jetBrainsMono(
      fontSize: 8,
      color: JweTheme.textMuted.withValues(alpha: 0.60),
      fontWeight: FontWeight.w500,
      letterSpacing: 0.6,
    );

    for (final pct in [0.25, 0.5, 0.75, 1.0]) {
      final y = size.height - pct * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '${(pct * 100).round()}%', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height - 1));
    }

    // ── Canvas mapping ─────────────────────────────
    Offset toCanvas(_Point p) => Offset(
          (p.x / maxX) * size.width,
          size.height - p.y * size.height,
        );

    // ── Build smooth cubic bezier path ─────────────
    // Uses horizontal tension S-curve: leaves each point horizontally,
    // arrives at next point horizontally. Monotone — never overshoots.
    Path buildCurve() {
      final path = Path();
      final o0 = toCanvas(points[0]);
      path.moveTo(o0.dx, o0.dy);
      for (var i = 1; i < points.length; i++) {
        final prev = toCanvas(points[i - 1]);
        final curr = toCanvas(points[i]);
        final midX = (prev.dx + curr.dx) / 2;
        path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      }
      return path;
    }

    final curvePath = buildCurve();

    // ── Filled area under curve ────────────────────
    final fillPath = Path.from(curvePath);
    final last = toCanvas(points.last);
    fillPath.lineTo(last.dx, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.01),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // ── Glow pass ──────────────────────────────────
    canvas.drawPath(
      curvePath,
      Paint()
        ..color = accent.withValues(alpha: 0.30)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // ── Main curve ─────────────────────────────────
    canvas.drawPath(
      curvePath,
      Paint()
        ..color = accent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Live trailing dashed extension ─────────────
    if (isLive && points.length >= 2) {
      final secondLast = toCanvas(points[points.length - 2]);
      final lastPt = toCanvas(points.last);
      const dashLen = 4.0;
      const gapLen = 3.0;
      final dx = lastPt.dx - secondLast.dx;
      final dy = lastPt.dy - secondLast.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len > 0) {
        final ux = dx / len;
        final uy = dy / len;
        var traveled = 0.0;
        var drawing = true;
        var cx = secondLast.dx;
        var cy = secondLast.dy;
        final dashPaint = Paint()
          ..color = accent.withValues(alpha: 0.45)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        while (traveled < len) {
          final segLen = math.min(drawing ? dashLen : gapLen, len - traveled);
          if (drawing) {
            canvas.drawLine(
              Offset(cx, cy),
              Offset(cx + ux * segLen, cy + uy * segLen),
              dashPaint,
            );
          }
          cx += ux * segLen;
          cy += uy * segLen;
          traveled += segLen;
          drawing = !drawing;
        }
      }
    }

    // ── Dots at significant points ─────────────────
    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      final prev = points[i - 1];
      final isLast = i == points.length - 1;
      final progressJump = p.y - prev.y > 0.01;

      if (!isLast && !progressJump) continue;

      final o = toCanvas(p);
      final r = isLast ? 4.5 : 3.0;
      final dotColor = isLast && isLive ? JweTheme.accentRed : accent;

      canvas.drawCircle(
        o, r + 2.5,
        Paint()
          ..color = dotColor.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(o, r, Paint()..color = dotColor);
      canvas.drawCircle(o, r * 0.4, Paint()..color = Colors.white.withValues(alpha: 0.85));

      if (progressJump || isLast) {
        final label = isLast && isLive ? 'LIVE' : '${(p.y * 100).round()}%';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              color: dotColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final lx = (o.dx - tp.width / 2).clamp(0.0, size.width - tp.width);
        final ly = math.max(0.0, o.dy - r - tp.height - 3);
        tp.paint(canvas, Offset(lx, ly));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressLinePainter old) =>
      old.points.length != points.length ||
      old.isLive != isLive ||
      old.accent != accent ||
      (points.isNotEmpty && old.points.isNotEmpty && points.last.x != old.points.last.x);
}

// ─────────────────────────────────────────────────
// Telemetry chip
// ─────────────────────────────────────────────────
class _TelChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TelChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9, color: color, fontWeight: FontWeight.w600, letterSpacing: 1.4,
            )),
        const SizedBox(width: 4),
        Text(value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.6,
            )),
      ]),
    );
  }
}
