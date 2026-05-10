import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:intl/intl.dart';

class HealthCombinedChart extends StatelessWidget {
  final AppProvider provider;

  const HealthCombinedChart({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final List<FlSpot> sleepSpots =[];
    final List<FlSpot> workSpots = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final log = provider.healthLogs[dateStr];
      final sleepMins = log?.sleepLogs.fold(0, (sum, item) => sum + item.durationMinutes) ?? 0;
      final sleepHrs = sleepMins / 60.0;
      sleepSpots.add(FlSpot((6 - i).toDouble(), sleepHrs));

      final hist = provider.completedByDay[dateStr];
      double workMins = 0;
      if (hist != null && hist['taskTimes'] != null) {
        (hist['taskTimes'] as Map<String, dynamic>).forEach((_, v) => workMins += (v as num));
      }
      workSpots.add(FlSpot((6 - i).toDouble(), workMins / 3600.0)); 
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children:[
            _LegendItem("SLEEP (HRS)", JweTheme.accentCyan),
            const SizedBox(width: 12),
            _LegendItem("WORK (HRS)", JweTheme.accentAmber),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (val) => const FlLine(color: JweTheme.border, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1, // Enforce whole numbers
                    getTitlesWidget: (value, meta) {
                      if (value % 1 != 0) return const SizedBox.shrink(); // Safety check
                      final date = now.subtract(Duration(days: 6 - value.toInt()));
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(DateFormat('E').format(date).toUpperCase(), style: const TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      );
                    }
                  )
                )
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (group) => JweTheme.panel,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      if (spot.barIndex == 0) return LineTooltipItem("${spot.y.toStringAsFixed(1)} h Sleep", const TextStyle(color: JweTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold));
                      if (spot.barIndex == 1) return LineTooltipItem("${spot.y.toStringAsFixed(1)} h Work", const TextStyle(color: JweTheme.accentAmber, fontSize: 12, fontWeight: FontWeight.bold));
                      return null;
                    }).whereType<LineTooltipItem>().toList();
                  }
                )
              ),
              lineBarsData:[
                LineChartBarData(
                  spots: sleepSpots, color: JweTheme.accentCyan, isCurved: true, dotData: const FlDotData(show: false), barWidth: 2, belowBarData: BarAreaData(show: true, color: JweTheme.accentCyan.withOpacity(0.1))
                ),
                LineChartBarData(
                  spots: workSpots, color: JweTheme.accentAmber, isCurved: true, dotData: const FlDotData(show: false), barWidth: 2, dashArray: [5, 5], belowBarData: BarAreaData(show: true, color: JweTheme.accentAmber.withOpacity(0.1))
                ),
              ]
            )
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
      children:[
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}