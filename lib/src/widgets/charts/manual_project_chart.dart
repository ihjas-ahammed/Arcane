import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:intl/intl.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;

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
      return Center(
        child: Text("NO PROGRESS LOGGED",
          style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: AppTheme.fontDisplay)
        ),
      );
    }

    final sortedSnapshots = List<ProjectSnapshot>.from(snapshots)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final startDate = sortedSnapshots.first.timestamp;
    final spots = <FlSpot>[];

    for (int i = 0; i < sortedSnapshots.length; i++) {
      // X = Days since start (double)
      final diff = sortedSnapshots[i].timestamp.difference(startDate).inHours / 24.0;
      // Y = Progress % (0-100)
      spots.add(FlSpot(diff, sortedSnapshots[i].progress * 100));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
          getDrawingVerticalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                // Show date roughly
                if (value % 2 == 0) { // show every other day roughly to avoid crowd
                   final date = startDate.add(Duration(hours: (value * 24).toInt()));
                   return Padding(
                     padding: const EdgeInsets.only(top: 4.0),
                     child: Text(DateFormat('MM/dd').format(date), style: const TextStyle(color: Colors.white24, fontSize: 8)),
                   );
                }
                return const SizedBox.shrink();
              }
            )
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.fhAccentTeal,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppTheme.fhAccentTeal.withOpacity(0.1)),
          ),
        ],
        lineTouchData: LineTouchData(
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (event is FlTapUpEvent && response != null && response.lineBarSpots != null) {
              final spotIndex = response.lineBarSpots!.first.spotIndex;
              onPointTap(sortedSnapshots[spotIndex]);
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (group) => AppTheme.fhBgDark,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final snap = sortedSnapshots[spot.spotIndex];
                final timeStr = helper.formatTime(snap.totalSecondsInvested.toDouble());
                return LineTooltipItem(
                  "${(snap.progress * 100).toInt()}%\n$timeStr invested",
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