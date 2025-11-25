import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';

class WeeklyActivityBarChart extends StatelessWidget {
  final Map<int, double> weeklyData; // Key: 0 (Today) to 6 (6 days ago), Value: Total Mins
  final Map<int, Color> dominantColors; // Key matches above, Value: Color of focused task

  const WeeklyActivityBarChart({
    super.key,
    required this.weeklyData,
    required this.dominantColors,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final double maxY = weeklyData.values.isEmpty 
        ? 60.0 
        : (weeklyData.values.reduce((a, b) => a > b ? a : b) * 1.2).clamp(60.0, double.infinity);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppTheme.fhBgDeepDark,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()}m',
                const TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final dayIndex = value.toInt();
                final daysAgo = 6 - dayIndex;
                final date = today.subtract(Duration(days: daysAgo));
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(
                    DateFormat('E').format(date).substring(0, 1),
                    style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        barGroups: List.generate(7, (index) {
          final daysAgo = 6 - index;
          final value = weeklyData[daysAgo] ?? 0.0;
          final color = dominantColors[daysAgo] ?? AppTheme.fhBgLight;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                color: color,
                width: 12,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: AppTheme.fhBgDark,
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
  final Map<int, double> weeklyXp; // Key: 0 (Today) -> 6
  final Map<int, Color> dominantVirtueColors; // Key: 0 (Today) -> 6

  const WeeklyVirtueBarChart({
    super.key, 
    required this.weeklyXp,
    this.dominantVirtueColors = const {},
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final double maxY = weeklyXp.values.isEmpty 
        ? 50.0 
        : (weeklyXp.values.reduce((a, b) => a > b ? a : b) * 1.2).clamp(50.0, double.infinity);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppTheme.fhBgDeepDark,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '+${rod.toY.toInt()} XP',
                const TextStyle(color: AppTheme.fhAccentGold, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final dayIndex = value.toInt();
                final daysAgo = 6 - dayIndex;
                final date = today.subtract(Duration(days: daysAgo));
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(
                    DateFormat('E').format(date).substring(0, 1),
                    style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        barGroups: List.generate(7, (index) {
          final daysAgo = 6 - index;
          final value = weeklyXp[daysAgo] ?? 0.0;
          final color = dominantVirtueColors[daysAgo] ?? AppTheme.fhAccentGold;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                color: color,
                width: 12,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: AppTheme.fhBgDark,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}