import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/utils/math_utils.dart';
import 'dart:math';
import 'package:collection/collection.dart';

class ManualProjectChart extends StatelessWidget {
  final List<ProjectSnapshot> snapshots;
  final Function(ProjectSnapshot) onPointTap;

  const ManualProjectChart({
    super.key,
    required this.snapshots,
    required this.onPointTap,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) {
      return const Center(
        child: Text("NO DATA POINTS LOGGED",
          style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: AppTheme.fontDisplay)
        ),
      );
    }

    // Sort by Time Spent (X Axis is cumulative hours)
    final sortedSnapshots = List<ProjectSnapshot>.from(snapshots)
      ..sort((a, b) => a.totalSecondsInvested.compareTo(b.totalSecondsInvested));

    final spots = <FlSpot>[];
    final regressionPoints = <Point<double>>[];

    for (var snap in sortedSnapshots) {
      // X = Total Hours
      final x = snap.totalSecondsInvested / 3600.0;
      // Y = Progress % (0-100)
      final y = snap.progress * 100;
      spots.add(FlSpot(x, y));
      regressionPoints.add(Point(x, y));
    }

    // Calculate Regression Forecast
    final regResult = MathUtils.linearRegression(regressionPoints);
    final slope = regResult['slope']!;
    final intercept = regResult['intercept']!;
    
    // Forecast point (Target Y = 100)
    final forecastX = MathUtils.predictX(100, slope, intercept);
    
    final forecastSpots = <FlSpot>[];
    if (slope > 0 && forecastX > spots.last.x && forecastX < 1000) { // Limit absurd forecasts
      forecastSpots.add(spots.last);
      forecastSpots.add(FlSpot(forecastX, 100));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
          getDrawingVerticalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => Text("${value.toInt()}%", style: const TextStyle(color: Colors.white24, fontSize: 8)),
            )
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("${value.toInt()}h", style: const TextStyle(color: Colors.white24, fontSize: 8)),
                );
              }
            )
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Actual Data
          LineChartBarData(
            spots: spots,
            isCurved: true, 
            color: AppTheme.fhAccentTeal,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppTheme.fhAccentTeal.withValues(alpha: 0.1)),
          ),
          // Forecast Line
          if (forecastSpots.isNotEmpty)
            LineChartBarData(
              spots: forecastSpots,
              isCurved: true,
              color: AppTheme.fhAccentPurple.withValues(alpha: 0.5),
              barWidth: 2,
              dashArray: [5, 5],
              dotData: const FlDotData(show: false),
            )
        ],
        lineTouchData: LineTouchData(
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (event is FlTapUpEvent && response != null && response.lineBarSpots != null) {
              // Only handle taps on the main data line (index 0)
              final spot = response.lineBarSpots!.firstWhereOrNull(
                (s) => s.barIndex == 0
              );
              
              if (spot != null && spot.spotIndex < sortedSnapshots.length) {
                 onPointTap(sortedSnapshots[spot.spotIndex]);
              }
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (group) => AppTheme.fhBgDark,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                if (spot.barIndex == 1) return LineTooltipItem("Forecast: ${(spot.x).toStringAsFixed(1)}h", const TextStyle(color: AppTheme.fhAccentPurple));
                
                final snap = sortedSnapshots[spot.spotIndex];
                return LineTooltipItem(
                  "${(snap.progress * 100).toInt()}%\n${snap.totalSecondsInvested ~/ 3600}h invested",
                  const TextStyle(color: Colors.white, fontSize: 10),
                );
              }).toList();
            }
          )
        )
      ),
    );
  }
}