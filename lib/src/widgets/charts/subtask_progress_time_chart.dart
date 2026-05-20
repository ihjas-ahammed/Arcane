import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// Progress % vs cumulative time-spent chart.
/// X = total seconds spent on the subtask at time of entry.
/// Y = user-entered completion % (0–100).
/// Data points are added manually via the "ADD ENTRY" button.
class SubtaskProgressTimeChart extends StatefulWidget {
  final SubTask subTask;
  final Color accentColor;
  final int currentSpentSeconds;
  final void Function(double progress, int spentSeconds) onAddEntry;
  final void Function(int index) onDeleteEntry;

  const SubtaskProgressTimeChart({
    super.key,
    required this.subTask,
    required this.accentColor,
    required this.currentSpentSeconds,
    required this.onAddEntry,
    required this.onDeleteEntry,
  });

  @override
  State<SubtaskProgressTimeChart> createState() => _SubtaskProgressTimeChartState();
}

class _SubtaskProgressTimeChartState extends State<SubtaskProgressTimeChart> {
  bool _showList = false;

  void _showAddEntryDialog() {
    // Pre-populate with hierarchical progress from nested tasks
    final calcPct = widget.subTask.calculateProgress() * 100;
    final initialText = calcPct > 0 ? calcPct.round().toString() : '';
    final ctrl = TextEditingController(text: initialText);
    ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    final totalSecs = widget.currentSpentSeconds;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        shape: Border.all(color: widget.accentColor, width: 2),
        title: Text(
          'ADD ENTRY',
          style: GoogleFonts.rajdhani(
            color: widget.accentColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.6,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TIME SPENT',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: JweTheme.textMuted,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fmtSeconds(totalSecs),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 20,
                color: widget.accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'PROGRESS (0 – 100)',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: JweTheme.textMuted,
                letterSpacing: 1.4,
              ),
            ),
            if (calcPct > 0) ...[
              const SizedBox(height: 2),
              Text(
                'pre-filled from task steps',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8,
                  color: widget.accentColor.withValues(alpha: 0.6),
                  letterSpacing: 0.8,
                ),
              ),
            ],
            const SizedBox(height: 4),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 24),
              decoration: InputDecoration(
                suffixText: '%',
                suffixStyle: TextStyle(color: widget.accentColor, fontSize: 20),
                hintText: '0',
                hintStyle: const TextStyle(color: JweTheme.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.black,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () {
              final pct = double.tryParse(ctrl.text);
              if (pct != null && pct >= 0 && pct <= 100) {
                widget.onAddEntry(pct / 100.0, totalSecs);
                Navigator.pop(ctx);
              }
            },
            child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<_Point> _buildPoints() {
    final pts = widget.subTask.progressDataPoints;
    if (pts.isEmpty) return [];
    final sorted = [...pts]..sort((a, b) => a.spentSeconds.compareTo(b.spentSeconds));
    return sorted.map((p) => _Point(p.spentSeconds.toDouble(), p.progress)).toList();
  }

  /// Linear regression over (spentSeconds, progress) points.
  /// Returns null if forecast is not possible (slope ≤ 0, too few points, already at 100%).
  _LinearForecast? _computeForecast(List<_Point> points) {
    if (points.length < 2) return null;
    // Already at or past 100% — no estimate needed
    if (points.last.y >= 1.0) return null;

    final n = points.length.toDouble();
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (final p in points) {
      sumX += p.x;
      sumY += p.y;
      sumXY += p.x * p.y;
      sumX2 += p.x * p.x;
    }
    final denom = n * sumX2 - sumX * sumX;
    if (denom.abs() < 1e-10) return null;

    final slope = (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;

    if (slope <= 0) return null;

    final xAt100 = (1.0 - intercept) / slope;
    if (xAt100 <= points.last.x) return null;

    return _LinearForecast(slope: slope, intercept: intercept, xAt100: xAt100);
  }

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints();
    final hasData = points.length >= 2;
    final dataPoints = [...widget.subTask.progressDataPoints]
      ..sort((a, b) => a.spentSeconds.compareTo(b.spentSeconds));

    final forecast = hasData ? _computeForecast(points) : null;

    // Extend chart x-axis to the full forecast so the visible distance matches the ETA chip
    final double chartMaxX = (hasData && forecast != null)
        ? forecast.xAt100
        : (hasData ? points.last.x : 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: HudPanel(
        clip: HudClip.br,
        accent: widget.accentColor,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: widget.accentColor.withValues(alpha: 0.20)),
                ),
              ),
              child: Row(
                children: [
                  Container(width: 4, height: 12, color: widget.accentColor),
                  const SizedBox(width: 10),
                  Text(
                    '// PROGRESS · TIME',
                    style: GoogleFonts.jetBrainsMono(
                      color: widget.accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const Spacer(),
                  if (dataPoints.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _showList = !_showList),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: JweTheme.textMuted.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          _showList ? 'CHART' : '${dataPoints.length} PTS',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: _showAddEntryDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: widget.accentColor.withValues(alpha: 0.40)),
                        color: widget.accentColor.withValues(alpha: 0.08),
                      ),
                      child: Text(
                        '+ ADD ENTRY',
                        style: GoogleFonts.jetBrainsMono(
                          color: widget.accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────
            if (_showList && dataPoints.isNotEmpty)
              _DataPointList(
                dataPoints: dataPoints,
                accentColor: widget.accentColor,
                onDelete: widget.onDeleteEntry,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                child: hasData
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 130,
                            child: _ProgressLinePainterWidget(
                              points: points,
                              accent: widget.accentColor,
                              chartMaxX: chartMaxX,
                              forecast: forecast,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _XAxisLabels(maxSeconds: chartMaxX),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _TelChip(
                                label: 'PROGRESS',
                                value: '${(points.last.y * 100).round()}%',
                                color: JweTheme.accentCyan,
                              ),
                              _TelChip(
                                label: 'TIME IN',
                                value: _fmtSeconds(widget.currentSpentSeconds),
                                color: widget.accentColor,
                              ),
                              if (points.last.x > 0 && points.last.y > 0)
                                _TelChip(
                                  label: 'RATE',
                                  value:
                                      '${(points.last.y * 100 / (points.last.x / 3600)).toStringAsFixed(1)}%/h',
                                  color: JweTheme.accentAmber,
                                ),
                              if (forecast != null && points.last.y < 1.0)
                                _TelChip(
                                  label: 'ETA 100%',
                                  value: _fmtSeconds(
                                    (forecast.xAt100 - widget.currentSpentSeconds).clamp(0, 999999999.0).round(),
                                  ),
                                  color: JweTheme.accentTeal,
                                ),
                            ],
                          ),
                        ],
                      )
                    : SizedBox(
                        height: 80,
                        child: Center(
                          child: Text(
                            dataPoints.length == 1
                                ? 'ADD ONE MORE ENTRY TO DRAW LINE'
                                : 'NO ENTRIES YET — TAP ADD ENTRY',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textMuted,
                              fontSize: 10,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Data point list ──────────────────────────────────────────────────────────
class _DataPointList extends StatelessWidget {
  final List<ProgressDataPoint> dataPoints;
  final Color accentColor;
  final void Function(int index) onDelete;

  const _DataPointList({
    required this.dataPoints,
    required this.accentColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(dataPoints.length, (i) {
        final dp = dataPoints[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: JweTheme.border.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 32,
                color: accentColor.withValues(alpha: 0.6),
                margin: const EdgeInsets.only(right: 10),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtSeconds(dp.spentSeconds),
                      style: GoogleFonts.jetBrainsMono(
                        color: accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d · HH:mm').format(dp.timestamp),
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 9,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(dp.progress * 100).round()}%',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => onDelete(i),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: JweTheme.accentRed.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.delete_outline, color: JweTheme.accentRed, size: 14),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────
String _fmtSeconds(int s) {
  if (s <= 0) return '0m';
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
  return '${m}m';
}

// ── X-axis labels ────────────────────────────────────────────────────────────
class _XAxisLabels extends StatelessWidget {
  final double maxSeconds;
  const _XAxisLabels({required this.maxSeconds});

  @override
  Widget build(BuildContext context) {
    const count = 5;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(count, (i) {
        final secs = (maxSeconds * i / (count - 1)).round();
        return Text(
          _fmtSeconds(secs),
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

// ── Painter widget wrapper ────────────────────────────────────────────────────
class _ProgressLinePainterWidget extends StatefulWidget {
  final List<_Point> points;
  final Color accent;
  final double chartMaxX;
  final _LinearForecast? forecast;

  const _ProgressLinePainterWidget({
    required this.points,
    required this.accent,
    required this.chartMaxX,
    this.forecast,
  });

  @override
  State<_ProgressLinePainterWidget> createState() => _ProgressLinePainterWidgetState();
}

class _ProgressLinePainterWidgetState extends State<_ProgressLinePainterWidget> {
  int? _selectedIndex;
  bool _forecastSelected = false;

  void _handleTap(Offset localPosition, Size size) {
    if (widget.chartMaxX <= 0 || widget.points.isEmpty) return;
    int? bestIdx;
    double bestDist = double.infinity;
    for (var i = 0; i < widget.points.length; i++) {
      final p = widget.points[i];
      final o = Offset(
        (p.x / widget.chartMaxX) * size.width,
        size.height - p.y * size.height,
      );
      final d = (localPosition - o).distance;
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    bool forecastBest = false;
    if (widget.forecast != null) {
      final fo = Offset(
        (widget.forecast!.xAt100 / widget.chartMaxX) * size.width,
        0, // y = 100% → top of chart
      );
      final df = (localPosition - fo).distance;
      if (df < bestDist) {
        bestDist = df;
        forecastBest = true;
      }
    }
    setState(() {
      if (bestDist > 24) {
        _selectedIndex = null;
        _forecastSelected = false;
      } else if (forecastBest) {
        _selectedIndex = null;
        _forecastSelected = true;
      } else {
        _selectedIndex = bestIdx;
        _forecastSelected = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _handleTap(d.localPosition, size),
        child: CustomPaint(
          painter: _ProgressLinePainter(
            points: widget.points,
            accent: widget.accent,
            chartMaxX: widget.chartMaxX,
            forecast: widget.forecast,
            selectedIndex: _selectedIndex,
            showForecastLabel: _forecastSelected,
          ),
          child: const SizedBox.expand(),
        ),
      );
    });
  }
}

// ── Custom painter ────────────────────────────────────────────────────────────
class _ProgressLinePainter extends CustomPainter {
  final List<_Point> points;
  final Color accent;
  final double chartMaxX;
  final _LinearForecast? forecast;
  final int? selectedIndex;
  final bool showForecastLabel;

  _ProgressLinePainter({
    required this.points,
    required this.accent,
    required this.chartMaxX,
    this.forecast,
    this.selectedIndex,
    this.showForecastLabel = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    if (chartMaxX <= 0) return;

    // Y-axis grid lines
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
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height - 1));
    }

    Offset toCanvas(_Point p) => Offset(
          (p.x / chartMaxX) * size.width,
          size.height - p.y * size.height,
        );

    // Straight-line path between data points
    Path buildCurve() {
      final path = Path();
      final o0 = toCanvas(points[0]);
      path.moveTo(o0.dx, o0.dy);
      for (var i = 1; i < points.length; i++) {
        final curr = toCanvas(points[i]);
        path.lineTo(curr.dx, curr.dy);
      }
      return path;
    }

    final curvePath = buildCurve();

    // Filled area
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
          colors: [accent.withValues(alpha: 0.22), accent.withValues(alpha: 0.01)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Glow
    canvas.drawPath(
      curvePath,
      Paint()
        ..color = accent.withValues(alpha: 0.30)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Main line
    canvas.drawPath(
      curvePath,
      Paint()
        ..color = accent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Forecast dashed line ─────────────────────────────────────────
    if (forecast != null) {
      final forecastEndX = forecast!.xAt100.clamp(0.0, chartMaxX * 1.0);
      final forecastEnd = Offset(
        (forecastEndX / chartMaxX) * size.width,
        size.height - 1.0 * size.height, // y = 100%
      );
      final lastOffset = toCanvas(points.last);

      // Draw dashed line from last data point to 100% forecast
      _drawDashed(
        canvas,
        lastOffset,
        forecastEnd,
        Paint()
          ..color = JweTheme.accentTeal.withValues(alpha: 0.70)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
        dashLength: 5,
        gapLength: 4,
      );

      // Forecast end marker (if within chart bounds)
      if (forecastEndX <= chartMaxX) {
        canvas.drawCircle(
          forecastEnd,
          5.0,
          Paint()
            ..color = JweTheme.accentTeal.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(forecastEnd, 3.5, Paint()..color = JweTheme.accentTeal);
        canvas.drawCircle(
          forecastEnd,
          1.5,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );

        // "100%" label at forecast point — only when tapped
        if (showForecastLabel) {
          final tp = TextPainter(
            text: TextSpan(
              text: '100%',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                color: JweTheme.accentTeal,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            textDirection: ui.TextDirection.ltr,
          )..layout();
          final lx = (forecastEnd.dx - tp.width / 2).clamp(0.0, size.width - tp.width);
          final ly = math.max(0.0, forecastEnd.dy + 5.0);
          tp.paint(canvas, Offset(lx, ly));
        }
      } else {
        // Arrow hint at right edge
        final edgeY = (1.0 - (forecast!.slope * chartMaxX + forecast!.intercept))
            .clamp(0.0, 1.0);
        final edgeOffset = Offset(size.width - 4, size.height - edgeY * size.height);
        canvas.drawCircle(
          edgeOffset,
          3.0,
          Paint()..color = JweTheme.accentTeal.withValues(alpha: 0.6),
        );
      }
    }

    // Dots at each data point (drawn on top of forecast line)
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final isLast = i == points.length - 1;
      final o = toCanvas(p);
      final r = isLast ? 4.5 : 3.0;

      canvas.drawCircle(
        o, r + 2.5,
        Paint()
          ..color = accent.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(o, r, Paint()..color = accent);
      canvas.drawCircle(o, r * 0.4, Paint()..color = Colors.white.withValues(alpha: 0.85));

      // Label — only when this dot is tapped
      if (selectedIndex == i) {
        final label = '${(p.y * 100).round()}%';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              color: accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        final lx = (o.dx - tp.width / 2).clamp(0.0, size.width - tp.width);
        final ly = math.max(0.0, o.dy - r - tp.height - 3);
        tp.paint(canvas, Offset(lx, ly));
      }
    }
  }

  void _drawDashed(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashLength = 6,
    double gapLength = 4,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final ux = dx / dist;
    final uy = dy / dist;
    double traveled = 0;
    bool drawing = true;
    while (traveled < dist) {
      final segLen = drawing ? dashLength : gapLength;
      final segEnd = math.min(traveled + segLen, dist);
      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + ux * traveled, start.dy + uy * traveled),
          Offset(start.dx + ux * segEnd, start.dy + uy * segEnd),
          paint,
        );
      }
      traveled = segEnd;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressLinePainter old) =>
      old.points.length != points.length ||
      old.accent != accent ||
      old.chartMaxX != chartMaxX ||
      old.forecast?.xAt100 != forecast?.xAt100 ||
      old.selectedIndex != selectedIndex ||
      old.showForecastLabel != showForecastLabel;
}

// ── Linear forecast result ────────────────────────────────────────────────────
class _LinearForecast {
  final double slope;
  final double intercept;
  final double xAt100; // seconds at which linear trend reaches 100%

  const _LinearForecast({
    required this.slope,
    required this.intercept,
    required this.xAt100,
  });
}

// ── Internal point ────────────────────────────────────────────────────────────
class _Point {
  final double x; // seconds
  final double y; // 0.0–1.0
  const _Point(this.x, this.y);
}

// ── Telemetry chip ────────────────────────────────────────────────────────────
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
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            )),
        const SizedBox(width: 4),
        Text(value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            )),
      ]),
    );
  }
}
