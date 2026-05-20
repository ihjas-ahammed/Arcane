import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:missions/src/theme/jwe_theme.dart';

String _fmtValue(double v, String unit) {
  if (unit != 'm') return '${v.round()}$unit';
  final m = v.round();
  if (m < 60) return '${m}m';
  final h = m ~/ 60;
  final rem = m % 60;
  return rem == 0 ? '${h}h' : '${h}h${rem}m';
}

/// Operator HUD weekly bar chart. Replaces fl_chart line chart.
/// Vertical bars for last 7 days, dotted mean line, peak/today glow,
/// JetBrainsMono telemetry labels.
class WeeklyActivityLineChart extends StatelessWidget {
  /// keys are daysAgo (0 = today, 6 = oldest); values are minutes (or XP).
  final Map<int, double> weeklyData;
  final Map<int, Color> dominantColors;
  final bool isVirtue;

  const WeeklyActivityLineChart({
    super.key,
    required this.weeklyData,
    required this.dominantColors,
    required this.isVirtue,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final values = <double>[];
    final colors = <Color>[];
    final days = <DateTime>[];

    Color overallDominant = JweTheme.accentCyan;
    var maxObserved = -1.0;

    for (var i = 6; i >= 0; i--) {
      final v = weeklyData[i] ?? 0.0;
      values.add(v);
      colors.add(dominantColors[i] ?? JweTheme.accentCyan);
      days.add(today.subtract(Duration(days: i)));
      if (v > maxObserved) {
        maxObserved = v;
        if (dominantColors[i] != null) overallDominant = dominantColors[i]!;
      }
    }

    final hasData = values.any((v) => v > 0);
    if (!hasData) overallDominant = JweTheme.textMuted;

    final maxV = hasData ? values.reduce(math.max) : 0.0;
    final avg = values.reduce((a, b) => a + b) / 7.0;
    final unit = isVirtue ? 'XP' : 'm';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Header strip ────────────────────────────
        Row(children: [
          Container(width: 3, height: 12, color: overallDominant),
          const SizedBox(width: 8),
          Text(
            isVirtue ? '// WEEKLY XP DELTA' : '// 7-DAY PERFORMANCE',
            style: GoogleFonts.jetBrainsMono(
              color: overallDominant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
          const Spacer(),
          if (hasData)
            Text(
              'μ ${_fmtValue(avg, unit)}/d',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1.0,
              ),
            ),
        ]),
        const SizedBox(height: 10),
        // ── Bars ────────────────────────────────────
        Expanded(
          child: hasData
              ? CustomPaint(
                  painter: _HudBarsPainter(
                    values: values,
                    maxV: maxV,
                    avg: avg,
                    accent: overallDominant,
                    perBarColor: colors,
                    unit: unit,
                  ),
                  child: const SizedBox.expand(),
                )
              : Center(
                  child: Text(
                    'NO RECENT ACTIVITY',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted, fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        // ── Day labels ──────────────────────────────
        Row(children: List.generate(7, (i) {
          final isToday = i == 6;
          return Expanded(
            child: Center(
              child: Text(
                DateFormat('E').format(days[i]).toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  color: isToday ? overallDominant : JweTheme.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          );
        })),
        // ── Telemetry chips ─────────────────────────
        if (hasData) ...[
          const SizedBox(height: 8),
          Row(children: [
            _TelemetryChip(label: 'PEAK', value: _fmtValue(maxV, unit), color: overallDominant),
            const SizedBox(width: 6),
            _TelemetryChip(label: 'TODAY', value: _fmtValue(values.last, unit), color: JweTheme.accentCyan),
            const Spacer(),
            Text(
              'Σ ${_fmtValue(values.reduce((a, b) => a + b), unit)}',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2,
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class WeeklyVirtueLineChart extends StatelessWidget {
  final Map<int, double> weeklyXp;
  final Map<int, Color> dominantVirtueColors;

  const WeeklyVirtueLineChart({
    super.key,
    required this.weeklyXp,
    this.dominantVirtueColors = const {},
  });

  @override
  Widget build(BuildContext context) {
    return WeeklyActivityLineChart(
      weeklyData: weeklyXp,
      dominantColors: dominantVirtueColors,
      isVirtue: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────
class _HudBarsPainter extends CustomPainter {
  final List<double> values;
  final double maxV;
  final double avg;
  final Color accent;
  final List<Color> perBarColor;
  final String unit;

  _HudBarsPainter({
    required this.values,
    required this.maxV,
    required this.avg,
    required this.accent,
    required this.perBarColor,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || maxV <= 0) return;

    final n = values.length;
    const gap = 6.0;
    final barW = (size.width - gap * (n - 1)) / n;

    // Avg dotted line
    final avgY = size.height - (avg / maxV).clamp(0.0, 1.0) * size.height;
    final dashed = Paint()
      ..color = accent.withValues(alpha: 0.30)
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, avgY), Offset(x + 4, avgY), dashed);
      x += 8;
    }

    // Avg label
    final avgPainter = TextPainter(
      text: TextSpan(
        text: 'μ ${_fmtValue(avg, unit)}',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 8,
          color: accent.withValues(alpha: 0.60),
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    if (avgY > 12) {
      avgPainter.paint(canvas, Offset(size.width - avgPainter.width - 2, avgY - avgPainter.height - 2));
    }

    // Bars
    for (var i = 0; i < n; i++) {
      final v = values[i];
      final ratio = (v / maxV).clamp(0.0, 1.0);
      final h = ratio * size.height;
      final left = i * (barW + gap);
      final isToday = i == n - 1;
      final isPeak = v > 0 && v == maxV;

      final dayColor = perBarColor[i];
      final color = v == 0
          ? const Color(0x1AA8B3C7)
          : (isToday || isPeak ? dayColor : dayColor.withValues(alpha: 0.40));

      final rect = Rect.fromLTWH(left, size.height - h, barW, math.max(2.0, h));
      if ((isToday || isPeak) && v > 0) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = dayColor.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawRect(rect, Paint()..color = color);

      // Top notch
      if (v > 0) {
        canvas.drawRect(
          Rect.fromLTWH(left, size.height - h - 2, barW, 2),
          Paint()..color = dayColor,
        );
      }

      // Value above bar
      if (v > 0) {
        final valStr = _fmtValue(v, unit);
        final p = TextPainter(
          text: TextSpan(
            text: valStr,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              color: isToday || isPeak ? dayColor : JweTheme.textMid,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: barW + gap);
        final ly = math.max(0.0, size.height - h - p.height - 4);
        p.paint(canvas, Offset(left + (barW - p.width) / 2, ly));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HudBarsPainter old) =>
      old.values != values || old.maxV != maxV || old.avg != avg || old.accent != accent;
}

class _TelemetryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TelemetryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
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
