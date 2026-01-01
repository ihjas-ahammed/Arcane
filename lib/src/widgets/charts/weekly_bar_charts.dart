import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';

class WeeklyActivityBarChart extends StatelessWidget {
  final Map<int, double> weeklyData;
  final Map<int, Color> dominantColors;
  final bool isVirtue;

  const WeeklyActivityBarChart({
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

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) =>
                AppTheme.fhBgDeepDark, // Updated to use getTooltipColor
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()}${isVirtue ? "XP" : "m"}',
                const TextStyle(
                    color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final daysAgo = 6 - value.toInt();
                final date = DateTime.now().subtract(Duration(days: daysAgo));
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.fhTextSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
              color: AppTheme.fhBorderColor.withValues(alpha: 0.1),
              strokeWidth: 1),
        ),
        barGroups: List.generate(7, (index) {
          final daysAgo = 6 - index;
          final value = weeklyData[daysAgo] ?? 0.0;
          final color = dominantColors[daysAgo] ?? AppTheme.fhBgMedium;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                color: color, // Valorant Red for bars
                width: 16,
                borderRadius: BorderRadius.zero, // Sharp edges
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: AppTheme.fhBgMedium.withValues(alpha: 0.3),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class WeeklyVirtueBarChart extends StatelessWidget {
  final Map<int, double> weeklyXp;
  final Map<int, Color> dominantVirtueColors;

  const WeeklyVirtueBarChart({
    super.key,
    required this.weeklyXp,
    this.dominantVirtueColors = const {},
  });

  @override
  Widget build(BuildContext context) {
    // Similar logic, just different data
    return WeeklyActivityBarChart(
        weeklyData: weeklyXp, dominantColors: dominantVirtueColors,isVirtue: true);
  }
}
