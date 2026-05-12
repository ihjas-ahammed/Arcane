import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// Progress % vs cumulative time chart.
/// X = total minutes worked so far, Y = completion % at that moment.
/// Each data point is plotted after a session ends or a step is completed.
class SubtaskProgressTimeChart extends StatelessWidget {
  final SubTask subTask;
  final Color accentColor;

  const SubtaskProgressTimeChart({
    super.key,
    required this.subTask,
    required this.accentColor,
  });

  /// Builds an ordered list of (cumulativeMinutes, progressFraction) points.
  List<_Point> _buildPoints() {
    final checkables = subTask.subSubTasks.where((s) => s.type != 'info').toList();
    final totalSteps = checkables.length;

    // Collect session spans sorted chronologically
    final sessions = List<TaskSession>.from(subTask.sessions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (sessions.isEmpty) return [];

    // Map of timestamp -> cumulative minutes up to that moment
    // Walk sessions in order, accumulating time
    // For progress: at each moment T, count steps completed with timestamp <= T

    // Build a merged event list
    // Event types: 'session_end' (adds time) or 'step' (may shift progress)
    final events = <_Event>[];

    double cumMins = 0;
    for (final s in sessions) {
      events.add(_Event(
        time: s.endTime,
        durationMins: s.durationSeconds / 60.0,
        type: _EventType.session,
      ));
    }

    // Step completion events (no time added, just mark progress)
    for (final step in checkables) {
      if (step.completed && step.completionTimestamp != null) {
        final ts = DateTime.tryParse(step.completionTimestamp!);
        if (ts != null) {
          events.add(_Event(time: ts, durationMins: 0, type: _EventType.step));
        }
      }
    }

    events.sort((a, b) => a.time.compareTo(b.time));

    // Walk events, build points
    final points = <_Point>[const _Point(0, 0)]; // origin
    cumMins = 0;

    for (final e in events) {
      cumMins += e.durationMins;

      // Current progress: steps completed at or before e.time
      double prog = 0;
      if (totalSteps > 0) {
        int done = 0;
        for (final step in checkables) {
          if (step.completed) {
            if (step.completionTimestamp != null) {
              final ts = DateTime.tryParse(step.completionTimestamp!);
              if (ts != null && !ts.isAfter(e.time)) done++;
            }
          }
        }
        prog = done / totalSteps;
      } else {
        prog = subTask.completed ? 1.0 : 0.0;
      }

      // Only add if different from last point (avoid duplicate x with same y)
      final last = points.last;
      if (cumMins != last.x || prog != last.y) {
        points.add(_Point(cumMins, prog));
      }
    }

    // If completed steps had no timestamps, approximate: put them at last session
    if (totalSteps > 0 && points.last.y < 1.0) {
      final noTimestampDone = checkables.where(
        (s) => s.completed && s.completionTimestamp == null,
      ).length;
      if (noTimestampDone > 0) {
        final approxProg = checkables.where((s) => s.completed).length / totalSteps;
        if (approxProg > points.last.y) {
          points.add(_Point(cumMins, approxProg));
        }
      }
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints();
    final hasData = points.length > 1;

    final totalMins = hasData ? points.last.x : 0.0;
    final currentProg = hasData ? points.last.y : 0.0;
    final totalHours = totalMins / 60.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: HudPanel(
        clip: HudClip.br,
        accent: accentColor,
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: accentColor.withValues(alpha: 0.20))),
            ),
            child: Row(children: [
              Container(width: 4, height: 12, color: accentColor),
              const SizedBox(width: 10),
              Text('// PROGRESS vs TIME INVESTED',
                  style: GoogleFonts.jetBrainsMono(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  )),
              const Spacer(),
              if (hasData)
                Text(
                  '${(currentProg * 100).round()}% · ${totalHours >= 1 ? '${totalHours.toStringAsFixed(1)}h' : '${totalMins.round()}m'}',
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
                        accent: accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // X-axis time labels
                    _XAxisLabels(points: points, totalMins: totalMins),
                    const SizedBox(height: 10),
                    // Chips
                    Row(children: [
                      _TelChip(
                        label: 'PROGRESS',
                        value: '${(currentProg * 100).round()}%',
                        color: JweTheme.accentCyan,
                      ),
                      const SizedBox(width: 6),
                      _TelChip(
                        label: 'TIME IN',
                        value: totalHours >= 1
                            ? '${totalHours.toStringAsFixed(1)}h'
                            : '${totalMins.round()}m',
                        color: accentColor,
                      ),
                      const SizedBox(width: 6),
                      if (totalMins > 0 && currentProg > 0)
                        _TelChip(
                          label: 'RATE',
                          value: '${(currentProg * 100 / totalMins).toStringAsFixed(1)}%/m',
                          color: JweTheme.accentAmber,
                        ),
                    ]),
                  ])
                : SizedBox(
                    height: 80,
                    child: Center(
                      child: Text(
                        'NO SESSION DATA YET',
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
  final double x; // cumulative minutes
  final double y; // progress 0.0–1.0
  const _Point(this.x, this.y);
}

enum _EventType { session, step }

class _Event {
  final DateTime time;
  final double durationMins;
  final _EventType type;
  const _Event({required this.time, required this.durationMins, required this.type});
}

// ─────────────────────────────────────────────────
// X-axis labels widget
// ─────────────────────────────────────────────────
class _XAxisLabels extends StatelessWidget {
  final List<_Point> points;
  final double totalMins;

  const _XAxisLabels({required this.points, required this.totalMins});

  String _fmt(double m) {
    if (m == 0) return '0';
    if (m < 60) return '${m.round()}m';
    final h = (m / 60).floor();
    final rem = (m % 60).round();
    return rem == 0 ? '${h}h' : '${h}h${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    // Show up to 5 evenly spaced time labels
    const count = 5;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(count, (i) {
        final t = totalMins * i / (count - 1);
        return Text(
          _fmt(t),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            color: i == count - 1 ? accentColorFor(points) : JweTheme.textMuted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        );
      }),
    );
  }

  Color accentColorFor(List<_Point> _) => JweTheme.textMuted;
}

// ─────────────────────────────────────────────────
// Painter widget wrapper
// ─────────────────────────────────────────────────
class _ProgressLinePainterWidget extends StatelessWidget {
  final List<_Point> points;
  final Color accent;

  const _ProgressLinePainterWidget({required this.points, required this.accent});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ProgressLinePainter(points: points, accent: accent),
      child: const SizedBox.expand(),
    );
  }
}

// ─────────────────────────────────────────────────
// Custom painter: progress line only
// ─────────────────────────────────────────────────
class _ProgressLinePainter extends CustomPainter {
  final List<_Point> points;
  final Color accent;

  _ProgressLinePainter({required this.points, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final maxX = points.last.x;
    if (maxX <= 0) return;

    // ── Y-axis grid lines at 25 / 50 / 75 / 100% ──────
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

    // ── Map point to canvas coordinates ───────────────
    Offset toCanvas(_Point p) => Offset(
          (p.x / maxX) * size.width,
          size.height - p.y * size.height,
        );

    // ── Filled area under line ─────────────────────────
    final fillPath = Path();
    fillPath.moveTo(0, size.height); // bottom-left origin
    for (var i = 0; i < points.length; i++) {
      final o = toCanvas(points[i]);
      if (i == 0) {
        fillPath.lineTo(o.dx, o.dy);
      } else {
        final prev = toCanvas(points[i - 1]);
        final ctrlX = (prev.dx + o.dx) / 2;
        fillPath.cubicTo(ctrlX, prev.dy, ctrlX, o.dy, o.dx, o.dy);
      }
    }
    final last = toCanvas(points.last);
    fillPath.lineTo(last.dx, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            JweTheme.accentCyan.withValues(alpha: 0.18),
            JweTheme.accentCyan.withValues(alpha: 0.01),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // ── Glow pass ──────────────────────────────────────
    final glowPath = Path();
    for (var i = 0; i < points.length; i++) {
      final o = toCanvas(points[i]);
      if (i == 0) {
        glowPath.moveTo(o.dx, o.dy);
      } else {
        final prev = toCanvas(points[i - 1]);
        final ctrlX = (prev.dx + o.dx) / 2;
        glowPath.cubicTo(ctrlX, prev.dy, ctrlX, o.dy, o.dx, o.dy);
      }
    }
    canvas.drawPath(
      glowPath,
      Paint()
        ..color = JweTheme.accentCyan.withValues(alpha: 0.28)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ── Main line ──────────────────────────────────────
    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final o = toCanvas(points[i]);
      if (i == 0) {
        linePath.moveTo(o.dx, o.dy);
      } else {
        final prev = toCanvas(points[i - 1]);
        final ctrlX = (prev.dx + o.dx) / 2;
        linePath.cubicTo(ctrlX, prev.dy, ctrlX, o.dy, o.dx, o.dy);
      }
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = JweTheme.accentCyan
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Dots at significant points ─────────────────────
    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      final prev = points[i - 1];
      final isLast = i == points.length - 1;
      final progressJump = p.y - prev.y > 0.01; // step was completed here

      if (!isLast && !progressJump) continue;

      final o = toCanvas(p);
      final r = isLast ? 4.5 : 3.0;

      // Glow
      canvas.drawCircle(
        o, r + 2,
        Paint()
          ..color = JweTheme.accentCyan.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // Fill
      canvas.drawCircle(o, r, Paint()..color = JweTheme.accentCyan);
      // Inner white
      canvas.drawCircle(o, r * 0.4, Paint()..color = Colors.white.withValues(alpha: 0.85));

      // Label: progress % above dot, time below (for last point only)
      if (progressJump || isLast) {
        final progStr = '${(p.y * 100).round()}%';
        final tp = TextPainter(
          text: TextSpan(
            text: progStr,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              color: JweTheme.accentCyan,
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
      old.points != points || old.accent != accent;
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
