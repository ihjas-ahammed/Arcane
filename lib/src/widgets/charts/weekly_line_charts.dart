import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:intl/intl.dart';

class WeeklyActivityLineChart extends StatelessWidget {
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
    final double maxY = weeklyData.values.isEmpty
        ? 60.0
        : (weeklyData.values.reduce((a, b) => a > b ? a : b) * 1.2)
            .clamp(60.0, double.infinity);

    final List<FlSpot> spots = [];
    Color overallDominant = JweTheme.accentCyan;
    
    double maxVal = -1;
    for (int i = 0; i < 7; i++) {
      final daysAgo = 6 - i;
      final val = weeklyData[daysAgo] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), val));
      if (val > maxVal && dominantColors[daysAgo] != null) {
        maxVal = val;
        overallDominant = dominantColors[daysAgo]!;
      }
    }

    if (maxVal == 0) overallDominant = JweTheme.textMuted;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
              color: JweTheme.border.withOpacity(0.5), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1, // Forces interval to whole numbers (1 day)
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink(); // Safety check for fractional values
                final daysAgo = 6 - value.toInt();
                final date = DateTime.now().subtract(Duration(days: daysAgo));
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: const TextStyle(
                        color: JweTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (group) => JweTheme.panel,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toInt()}${isVirtue ? " XP" : "m"}',
                  TextStyle(color: overallDominant, fontWeight: FontWeight.bold),
                );
              }).toList();
            }
          )
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: overallDominant,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: overallDominant.withOpacity(0.15),
            ),
          ),
        ],
      ),
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
        weeklyData: weeklyXp, dominantColors: dominantVirtueColors, isVirtue: true);
  }
}