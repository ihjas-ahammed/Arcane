import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';

class VirtuePieChart extends StatefulWidget {
  final List<ReflectionLog> logs;

  const VirtuePieChart({super.key, required this.logs});

  @override
  State<VirtuePieChart> createState() => _VirtuePieChartState();
}

class _VirtuePieChartState extends State<VirtuePieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.logs.isEmpty) {
      return Center(
        child: Text(
          "No virtue data logged today.",
          style: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic),
        ),
      );
    }

    Map<String, int> totals = {};
    for (var log in widget.logs) {
      log.xpGained.forEach((key, value) {
        totals[key] = (totals[key] ?? 0) + value;
      });
    }

    // Filter out zero values
    totals.removeWhere((key, value) => value <= 0);

    if (totals.isEmpty) {
      return Center(
        child: Text(
          "No XP gained yet.",
          style: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic),
        ),
      );
    }

    final List<PieChartSectionData> sections = totals.entries.map((entry) {
      final isTouched = totals.keys.toList().indexOf(entry.key) == _touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      final color = _getVirtueColor(entry.key);

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      );
    }).toList();

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  _touchedIndex = -1;
                  return;
                }
                _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: sections,
        ),
      ),
    );
  }

  Color _getVirtueColor(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom': return Colors.blueAccent;
      case 'courage': return Colors.redAccent;
      case 'humanity': return Colors.pinkAccent;
      case 'justice': return Colors.amber;
      case 'temperance': return Colors.tealAccent;
      case 'transcendence': return Colors.purpleAccent;
      default: return Colors.grey;
    }
  }
}