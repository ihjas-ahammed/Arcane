import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// Operator HUD 7-day activity panel — vertical bar telemetry with
/// peak glow, mean dotted line, JetBrainsMono telemetry caption.
class SubtaskWeeklyChart extends StatelessWidget {
  final SubTask subTask;
  final Color accentColor;

  const SubtaskWeeklyChart({super.key, required this.subTask, required this.accentColor});

  HudTone _toneFor(Color c) {
    if (c == JweTheme.accentCyan) return HudTone.cyan;
    if (c == JweTheme.accentTeal) return HudTone.teal;
    if (c == JweTheme.accentRed) return HudTone.red;
    return HudTone.amber;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <DateTime>[];
    final mins = <double>[];

    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      days.add(d);
      double sec = 0;
      for (var s in subTask.sessions) {
        if (s.startTime.year == d.year && s.startTime.month == d.month && s.startTime.day == d.day) {
          sec += s.durationSeconds;
        }
      }
      mins.add(sec / 60.0);
    }

    final hasData = mins.any((v) => v > 0);
    final maxV = hasData ? mins.reduce(math.max) : 0.0;
    final avg = mins.reduce((a, b) => a + b) / 7.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: HudPanel(
        clip: HudClip.br,
        accent: accentColor,
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.20))),
            ),
            child: Row(children: [
              Container(width: 4, height: 12, color: accentColor),
              const SizedBox(width: 10),
              Text('// 7-DAY ACTIVITY',
                  style: GoogleFonts.jetBrainsMono(
                    color: accentColor, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.8,
                  )),
              const Spacer(),
              if (hasData)
                Text('μ ${avg.round()}m/d',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1.0,
                    )),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: hasData
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(
                      height: 110,
                      child: _Bars(
                        mins: mins,
                        maxV: maxV,
                        avg: avg,
                        accent: accentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children: List.generate(7, (i) {
                      final isToday = i == 6;
                      return Expanded(
                        child: Center(
                          child: Text(
                            DateFormat('E').format(days[i]).toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              color: isToday ? accentColor : JweTheme.textMuted,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      );
                    })),
                    const SizedBox(height: 6),
                    Row(children: [
                      _TelemetryChip(label: 'PEAK', value: '${maxV.round()}m', tone: _toneFor(accentColor)),
                      const SizedBox(width: 6),
                      _TelemetryChip(label: 'TODAY', value: '${mins.last.round()}m', tone: HudTone.cyan),
                      const Spacer(),
                      Text(
                        'TOTAL ${mins.reduce((a, b) => a + b).round()}m',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: JweTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ]),
                  ])
                : SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        'NO RECENT ACTIVITY',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted, fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w600,
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

class _Bars extends StatelessWidget {
  final List<double> mins;
  final double maxV;
  final double avg;
  final Color accent;

  const _Bars({required this.mins, required this.maxV, required this.avg, required this.accent});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarsPainter(mins: mins, maxV: maxV, avg: avg, accent: accent),
      child: const SizedBox.expand(),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> mins;
  final double maxV;
  final double avg;
  final Color accent;

  _BarsPainter({required this.mins, required this.maxV, required this.avg, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (mins.isEmpty || maxV <= 0) return;

    final n = mins.length;
    final gap = 6.0;
    final barW = (size.width - gap * (n - 1)) / n;

    // Avg dotted line
    final avgY = size.height - (avg / maxV).clamp(0.0, 1.0) * size.height;
    final dashedPaint = Paint()
      ..color = accent.withValues(alpha: 0.30)
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, avgY), Offset(x + 4, avgY), dashedPaint);
      x += 8;
    }

    // Avg label
    final avgPainter = TextPainter(
      text: TextSpan(
        text: 'μ ${avg.round()}m',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 8,
          color: accent.withValues(alpha: 0.60),
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (avgY > 12) {
      avgPainter.paint(canvas, Offset(size.width - avgPainter.width - 2, avgY - avgPainter.height - 2));
    }

    // Bars
    for (var i = 0; i < n; i++) {
      final v = mins[i];
      final ratio = (v / maxV).clamp(0.0, 1.0);
      final h = ratio * size.height;
      final left = i * (barW + gap);
      final isToday = i == n - 1;
      final isPeak = v > 0 && v == maxV;

      final color = v == 0
          ? const Color(0x1AA8B3C7)
          : (isToday || isPeak ? accent : accent.withValues(alpha: 0.40));

      // Bar with optional glow
      final paint = Paint()..color = color;
      final rect = Rect.fromLTWH(left, size.height - h, barW, math.max(2.0, h));
      if (isToday || isPeak) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = accent.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawRect(rect, paint);

      // Top notch (HUD detail)
      if (v > 0) {
        canvas.drawRect(
          Rect.fromLTWH(left, size.height - h - 2, barW, 2),
          Paint()..color = accent,
        );
      }

      // Value label above bar
      if (v > 0) {
        final valStr = v >= 60 ? '${(v / 60).toStringAsFixed(1)}h' : '${v.round()}m';
        final p = TextPainter(
          text: TextSpan(
            text: valStr,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              color: isToday || isPeak ? accent : JweTheme.textMid,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: barW + gap);
        final ly = math.max(0.0, size.height - h - p.height - 4);
        p.paint(canvas, Offset(left + (barW - p.width) / 2, ly));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.mins != mins || old.maxV != maxV || old.avg != avg || old.accent != accent;
}

class _TelemetryChip extends StatelessWidget {
  final String label;
  final String value;
  final HudTone tone;
  const _TelemetryChip({required this.label, required this.value, required this.tone});

  @override
  Widget build(BuildContext context) {
    final c = tone == HudTone.cyan
        ? JweTheme.accentCyan
        : tone == HudTone.teal
            ? JweTheme.accentTeal
            : tone == HudTone.red
                ? JweTheme.accentRed
                : JweTheme.accentAmber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        border: Border.all(color: c.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9, color: c, fontWeight: FontWeight.w600, letterSpacing: 1.4,
            )),
        const SizedBox(width: 4),
        Text(value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10, color: c, fontWeight: FontWeight.w700, letterSpacing: 0.6,
            )),
      ]),
    );
  }
}
