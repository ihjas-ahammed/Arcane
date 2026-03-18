import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:intl/intl.dart';

class WellbeingTrendChart extends StatelessWidget {
  final Map<int, double> weeklyXp;
  final Color color;

  const WellbeingTrendChart({super.key, required this.weeklyXp, required this.color});

  @override
  Widget build(BuildContext context) {
    if (weeklyXp.isEmpty || !weeklyXp.values.any((v) => v > 0)) {
      return const SizedBox.shrink(); // Hide if no data
    }

    final List<FlSpot> spots = [];
    for (int i = 0; i <= 6; i++) {
      spots.add(FlSpot(i.toDouble(), weeklyXp[i] ?? 0.0));
    }

    return Container(
      height: 80,
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withValues(alpha: 0.5),
        border: Border.all(color: JweTheme.border),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (val) => FlLine(color: JweTheme.border.withValues(alpha: 0.5), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (group) => JweTheme.panel,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final daysAgo = 6 - spot.x.toInt();
                  final date = DateTime.now().subtract(Duration(days: daysAgo));
                  return LineTooltipItem(
                    "${DateFormat('MMM dd').format(date)}\n+${spot.y.toInt()} XP",
                    TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)
                  );
                }).toList();
              }
            )
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: color,
              isCurved: true,
              dotData: const FlDotData(show: true),
              barWidth: 2,
              belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
            ),
          ]
        )
      ),
    );
  }
}