import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:intl/intl.dart';

class ProjectProgressChart extends StatelessWidget {
  final Project project;
  final List<Map<String, dynamic>> history;

  const ProjectProgressChart({
    super.key,
    required this.project,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Text("NO DATA AVAILABLE", style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: AppTheme.fontDisplay)),
      );
    }

    final startDate = history.first['date'] as DateTime;
    final now = DateTime.now();
    // Ensure we cover at least one day
    final totalDuration = now.difference(startDate).inHours.clamp(24, 99999).toDouble();

    // Prepare Progress Spots
    // We iterate events and accumulate completion count to get %
    final List<FlSpot> progressSpots = [];
    final List<FlSpot> timeSpots = [];
    
    // Initial State
    progressSpots.add(const FlSpot(0, 0));
    timeSpots.add(const FlSpot(0, 0));

    double currentProgressSteps = 0;
    double accumulatedTime = 0;
    final totalSteps = project.steps.isNotEmpty ? project.steps.length : 1;

    for (var event in history) {
      final date = event['date'] as DateTime;
      final x = date.difference(startDate).inHours.toDouble();
      
      // Add current state point before change for step-like graph (optional, but curved line prefers smooth points)
      // progressSpots.add(FlSpot(x, (currentProgressSteps / totalSteps) * 100));
      // timeSpots.add(FlSpot(x, accumulatedTime / 60)); // Time in Minutes

      if (event['type'] == 'completion') {
        currentProgressSteps++;
      } else if (event['type'] == 'session') {
        accumulatedTime += (event['duration'] as double);
      }

      progressSpots.add(FlSpot(x, (currentProgressSteps / totalSteps) * 100));
      timeSpots.add(FlSpot(x, accumulatedTime / 3600)); // Time in Hours
    }

    // Add final point at Now
    final finalX = now.difference(startDate).inHours.toDouble();
    progressSpots.add(FlSpot(finalX, (currentProgressSteps / totalSteps) * 100));
    timeSpots.add(FlSpot(finalX, accumulatedTime / 3600));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("MISSION TIMELINE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            Row(
              children: [
                _LegendItem("PROGRESS", AppTheme.fhAccentTeal),
                const SizedBox(width: 8),
                _LegendItem("HOURS", AppTheme.fhAccentPurple),
              ],
            )
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) => Text("${value.toInt()}%", style: TextStyle(color: Colors.white24, fontSize: 8)),
                )),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                // Progress Line
                LineChartBarData(
                  spots: progressSpots,
                  isCurved: true,
                  color: AppTheme.fhAccentTeal,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: AppTheme.fhAccentTeal.withOpacity(0.1)),
                ),
                // Time Line (Scaled to fit 0-100 roughly for visualization overlap, purely aesthetic here or use dual axis)
                // Since FLChart doesn't support dual Y easily, we'll just plot Time hours directly. 
                // If hours > 100, it goes off chart. We might need normalization. 
                // For simplicity, let's assume valid range or let it scale.
                LineChartBarData(
                  spots: timeSpots,
                  isCurved: true,
                  color: AppTheme.fhAccentPurple,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  dashArray: [5, 5],
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (group) => AppTheme.fhBgDark,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      if (spot.barIndex == 0) return LineTooltipItem("${spot.y.toInt()}% Complete", TextStyle(color: AppTheme.fhAccentTeal));
                      return LineTooltipItem("${spot.y.toStringAsFixed(1)} Hrs", TextStyle(color: AppTheme.fhAccentPurple));
                    }).toList();
                  }
                )
              )
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}