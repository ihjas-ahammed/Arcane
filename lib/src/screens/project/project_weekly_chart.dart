import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/utils/task_calculations.dart';

class ProjectWeeklyChart extends StatelessWidget {
  final Project project;
  final Color accentColor;

  const ProjectWeeklyChart({
    super.key,
    required this.project,
    required this.accentColor,
  });

  String _fmtMins(double v) {
    final m = v.round();
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <DateTime>[];
    final mins = <double>[];

    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      days.add(d);
      double sec = 0;

      for (final key in project.linkedTaskKeys) {
        final parts = key.split('|');
        if (parts.length < 2) continue;
        final mainId = parts[0];
        final subId = parts[1];

        final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == mainId);
        final sub = mainTask?.subTasks.firstWhereOrNull((s) => s.id == subId);

        if (sub != null) {
          sec += TaskCalculations.getSubtaskSecondsForDay(sub, d, provider.mainTasks).toDouble();
          final timer = provider.activeTimers[sub.id];
          if (timer != null && timer.isRunning) {
            final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
            final checkStr = DateFormat('yyyy-MM-dd').format(d);
            if (dateStr == checkStr) {
              final elapsed = DateTime.now().difference(timer.startTime).inSeconds;
              sec += elapsed;
            }
          }
        }
      }
      mins.add(sec / 60.0);
    }

    final hasData = mins.any((v) => v > 0);
    final maxV = hasData ? mins.reduce(math.max) : 0.0;
    final avg = mins.reduce((a, b) => a + b) / 7.0;

    return HudPanel(
      clip: HudClip.br,
      accent: accentColor,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.20))),
            ),
            child: Row(
              children: [
                Container(width: 4, height: 12, color: accentColor),
                const SizedBox(width: 10),
                Text(
                  '// PROJECT WEEKLY TIME USAGE',
                  style: GoogleFonts.jetBrainsMono(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                const Spacer(),
                if (hasData)
                  Text(
                    'μ ${_fmtMins(avg)}/d',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: hasData
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 110,
                        child: CustomPaint(
                          painter: ProjectWeeklyPainter(mins: mins, maxV: maxV, avg: avg, accent: accentColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(7, (i) {
                          final isToday = i == 6;
                          return Expanded(
                            child: Center(
                              child: Text(
                                DateFormat('E').format(days[i]).toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  color: isToday ? accentColor : JweTheme.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            color: accentColor.withValues(alpha: 0.12),
                            child: Text(
                              'TOTAL ${_fmtMins(mins.reduce((a, b) => a + b))}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        'NO RECENT ACTIVITY DETECTED',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ProjectWeeklyPainter extends CustomPainter {
  final List<double> mins;
  final double maxV;
  final double avg;
  final Color accent;

  ProjectWeeklyPainter({
    required this.mins,
    required this.maxV,
    required this.avg,
    required this.accent,
  });

  String _fmtMins(double v) {
    final m = v.round();
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h${rem}m';
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (mins.isEmpty || maxV <= 0) return;

    final n = mins.length;
    const gap = 6.0;
    final barW = (size.width - gap * (n - 1)) / n;

    final avgY = size.height - (avg / maxV).clamp(0.0, 1.0) * size.height;
    final dashedPaint = Paint()
      ..color = accent.withValues(alpha: 0.30)
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, avgY), Offset(x + 4, avgY), dashedPaint);
      x += 8;
    }

    for (var i = 0; i < n; i++) {
      final v = mins[i];
      final ratio = (v / maxV).clamp(0.0, 1.0);
      final h = ratio * size.height;
      final left = i * (barW + gap);
      final isToday = i == n - 1;
      final isPeak = v > 0 && v == maxV;

      final color = v == 0
          ? ArcStrokes.hairline
          : (isToday || isPeak ? accent : accent.withValues(alpha: 0.40));

      final rect = Rect.fromLTWH(left, size.height - h, barW, math.max(2.0, h));
      if (isToday || isPeak) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = accent.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawRect(rect, Paint()..color = color);

      if (v > 0) {
        canvas.drawRect(
          Rect.fromLTWH(left, size.height - h - 2, barW, 2),
          Paint()..color = accent,
        );

        final valStr = _fmtMins(v);
        final p = TextPainter(
          text: TextSpan(
            text: valStr,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              color: isToday || isPeak ? accent : JweTheme.textMid,
              fontWeight: FontWeight.w700,
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
  bool shouldRepaint(covariant ProjectWeeklyPainter old) =>
      old.mins != mins || old.maxV != maxV || old.avg != avg || old.accent != accent;
}
