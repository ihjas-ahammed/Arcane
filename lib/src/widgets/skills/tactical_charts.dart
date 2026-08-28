import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/tracked_skill_model.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/skills/tactical_hud_widgets.dart';

/// Exact replication of the Line Chart SVG from the user's HTML design
class TacticalProgressLineChart extends StatelessWidget {
  final List<SkillTrainingLog> logs;
  final double currentValue;
  final Color? accent;

  const TacticalProgressLineChart({
    super.key,
    required this.logs,
    required this.currentValue,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: CustomPaint(
        painter: _TacticalLineChartPainter(
          logs: logs,
          currentValue: currentValue,
          accent: accent ?? TacColors.primaryRed,
        ),
      ),
    );
  }
}

class _TacticalLineChartPainter extends CustomPainter {
  final List<SkillTrainingLog> logs;
  final double currentValue;
  final Color accent;

  _TacticalLineChartPainter({
    required this.logs,
    required this.currentValue,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Collect data points
    final sorted = List<SkillTrainingLog>.from(logs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final values = sorted.isNotEmpty
        ? sorted.map((l) => l.value).toList()
        : [currentValue * 0.85, currentValue * 0.9, currentValue * 0.92, currentValue * 0.96, currentValue];

    final dates = sorted.isNotEmpty
        ? sorted.map((l) => DateFormat('dd MMM').format(l.timestamp).toUpperCase()).toList()
        : ['29 JUL', '05 AUG', '12 AUG', '19 AUG', '27 AUG'];

    double minV = values.reduce(math.min);
    double maxV = values.reduce(math.max);
    if (minV == maxV) {
      minV *= 0.9;
      maxV *= 1.1;
    } else {
      final pad = (maxV - minV) * 0.15;
      minV -= pad;
      maxV += pad;
    }

    final leftMargin = 32.0;
    final bottomMargin = 16.0;
    final topMargin = 8.0;
    final chartW = w - leftMargin - 10.0;
    final chartH = h - bottomMargin - topMargin;

    // 4 Horizontal Grid Lines & Y-Labels
    final textStyle = GoogleFonts.rajdhani(
      color: TacColors.textDim,
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );

    final ySteps = 4;
    for (int i = 0; i < ySteps; i++) {
      final frac = i / (ySteps - 1);
      final y = topMargin + chartH * frac;
      final val = maxV - (maxV - minV) * frac;

      // Draw label
      final tp = TextPainter(
        text: TextSpan(text: '${val.round()}', style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));

      // Draw dashed horizontal line
      final gridPaint = Paint()
        ..color = TacColors.gridLine
        ..strokeWidth = 1.0;

      double startX = leftMargin;
      final dashWidth = 4.0;
      final dashSpace = 3.0;
      while (startX < w - 4) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(math.min(startX + dashWidth, w - 4), y),
          gridPaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    // Map points to canvas coordinates
    final points = <Offset>[];
    final count = values.length;
    for (int i = 0; i < count; i++) {
      final x = leftMargin + (count > 1 ? (i / (count - 1)) * chartW : chartW / 2);
      final fracY = (values[i] - minV) / (maxV - minV);
      final y = topMargin + chartH * (1.0 - fracY.clamp(0.0, 1.0));
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    // Build smooth cubic bezier or line path
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    // Gradient Area Fill below path
    final fillPath = Path.from(linePath);
    fillPath.lineTo(points.last.dx, topMargin + chartH);
    fillPath.lineTo(points.first.dx, topMargin + chartH);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: JweTheme.isLight ? 0.22 : 0.32),
          accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, topMargin, w, chartH))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw Line Trajectory
    final strokePaint = Paint()
      ..color = accent
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, strokePaint);

    // Draw Data Nodes
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isLast = i == points.length - 1;

      // Inner solid dot
      final dotPaint = Paint()..color = accent..style = PaintingStyle.fill;
      canvas.drawCircle(pt, isLast ? 3.5 : 2.2, dotPaint);

      // Outer glow pulse ring on latest point
      if (isLast) {
        final ringPaint = Paint()
          ..color = accent.withValues(alpha: JweTheme.isLight ? 0.35 : 0.5)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(pt, 7.0, ringPaint);
      }
    }

    // X-Axis Date Labels
    final xLabelCount = math.min(dates.length, 5);
    for (int i = 0; i < xLabelCount; i++) {
      final index = (i * (dates.length - 1) / (xLabelCount - 1)).round();
      final label = dates[index];
      final pt = points[index];

      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pt.dx - tp.width / 2, h - bottomMargin + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalLineChartPainter old) => true;
}

/// Exact replication of the Trials vs Outcome Grouped Bar Chart from HTML SVG
class TacticalTrialsOutcomeChart extends StatelessWidget {
  final List<SkillTrainingLog> logs;

  const TacticalTrialsOutcomeChart({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      width: double.infinity,
      child: CustomPaint(
        painter: _TacticalOutcomeBarPainter(logs: logs),
      ),
    );
  }
}

class _TacticalOutcomeBarPainter extends CustomPainter {
  final List<SkillTrainingLog> logs;
  _TacticalOutcomeBarPainter({required this.logs});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final leftMargin = 22.0;
    final bottomMargin = 16.0;
    final topMargin = 8.0;
    final chartW = w - leftMargin - 10.0;
    final chartH = h - bottomMargin - topMargin;

    final textStyle = GoogleFonts.rajdhani(
      color: TacColors.textDim,
      fontSize: 8.5,
      fontWeight: FontWeight.w600,
    );

    // 4 Horizontal Grid Lines (15, 10, 5, 0)
    final yValues = [15, 10, 5, 0];
    for (int i = 0; i < yValues.length; i++) {
      final frac = i / (yValues.length - 1);
      final y = topMargin + chartH * frac;

      // Label
      final tp = TextPainter(
        text: TextSpan(text: '${yValues[i]}', style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));

      // Grid line
      final gridPaint = Paint()
        ..color = i == yValues.length - 1 ? TacColors.borderOuter : TacColors.gridLine
        ..strokeWidth = 1.0;

      if (i == yValues.length - 1) {
        canvas.drawLine(Offset(leftMargin, y), Offset(w, y), gridPaint);
      } else {
        double startX = leftMargin;
        while (startX < w) {
          canvas.drawLine(Offset(startX, y), Offset(math.min(startX + 4, w), y), gridPaint);
          startX += 7;
        }
      }
    }

    // 5 Date Groups matching the HTML SVG
    final dateLabels = ['29 JUL', '05 AUG', '12 AUG', '19 AUG', '27 AUG'];
    final groupData = [
      [10.0, 3.0, 5.0],
      [14.0, 3.5, 12.0],
      [6.0, 4.0, 13.0],
      [7.0, 3.0, 10.0],
      [9.0, 4.0, 10.0],
    ];

    final groupCount = groupData.length;
    final groupSpacing = chartW / groupCount;
    final baseY = topMargin + chartH;

    for (int i = 0; i < groupCount; i++) {
      final groupCenterX = leftMargin + (i + 0.5) * groupSpacing;
      final data = groupData[i];

      final winH = (data[0] / 15.0) * chartH;
      final drawH = (data[1] / 15.0) * chartH;
      final lossH = (data[2] / 15.0) * chartH;

      // Win Bar (Teal)
      final winPaint = Paint()..color = TacColors.accentTeal.withValues(alpha: 0.9);
      final winRect = Rect.fromLTWH(groupCenterX - 14, baseY - winH, 9, winH);
      canvas.drawRect(winRect, winPaint);

      // Draw Bar (Grey)
      final drawPaint = Paint()..color = TacColors.accentDraw;
      final drawRect = Rect.fromLTWH(groupCenterX - 3, baseY - drawH, 6, drawH);
      canvas.drawRect(drawRect, drawPaint);

      // Loss Bar (Red)
      final lossPaint = Paint()..color = TacColors.primaryRed;
      final lossRect = Rect.fromLTWH(groupCenterX + 5, baseY - lossH, 9, lossH);
      canvas.drawRect(lossRect, lossPaint);

      // X Label
      final tp = TextPainter(
        text: TextSpan(text: dateLabels[i], style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(groupCenterX - tp.width / 2, h - bottomMargin + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalOutcomeBarPainter old) => true;
}
