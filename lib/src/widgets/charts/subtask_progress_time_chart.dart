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
    final ctrl = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints();
    final hasData = points.length >= 2;
    final dataPoints = [...widget.subTask.progressDataPoints]
      ..sort((a, b) => a.spentSeconds.compareTo(b.spentSeconds));

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
                            ),
                          ),
                          const SizedBox(height: 8),
                          _XAxisLabels(maxSeconds: points.last.x),
                          const SizedBox(height: 10),
                          Row(children: [
                            _TelChip(
                              label: 'PROGRESS',
                              value: '${(points.last.y * 100).round()}%',
                              color: JweTheme.accentCyan,
                            ),
                            const SizedBox(width: 6),
                            _TelChip(
                              label: 'TIME IN',
                              value: _fmtSeconds(widget.currentSpentSeconds),
                              color: widget.accentColor,
                            ),
                            if (points.last.x > 0 && points.last.y > 0) ...[
                              const SizedBox(width: 6),
                              _TelChip(
                                label: 'RATE',
                                value:
                                    '${(points.last.y * 100 / (points.last.x / 60)).toStringAsFixed(1)}%/h',
                                color: JweTheme.accentAmber,
                              ),
                            ],
                          ]),
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

// ── Custom painter ────────────────────────────────────────────────────────────
class _ProgressLinePainter extends CustomPainter {
  final List<_Point> points;
  final Color accent;

  _ProgressLinePainter({required this.points, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final maxX = points.last.x;
    if (maxX <= 0) return;

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
          (p.x / maxX) * size.width,
          size.height - p.y * size.height,
        );

    // Smooth cubic bezier path
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

    // Dots at each data point
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

      // Label
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

  @override
  bool shouldRepaint(covariant _ProgressLinePainter old) =>
      old.points.length != points.length || old.accent != accent;
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
