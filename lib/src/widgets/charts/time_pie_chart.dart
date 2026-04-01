import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class TimePieChart extends StatelessWidget {
  final Map<String, double> taskData; // Task Name -> Minutes
  final Map<String, Color> taskColors; // Task Name -> Color
  final String? selectedTask;
  final Function(String?)? onTaskSelected;

  const TimePieChart({
    super.key,
    required this.taskData,
    required this.taskColors,
    this.selectedTask,
    this.onTaskSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out zero values
    final Map<String, double> activeData = {};
    taskData.forEach((k, v) {
      if (v > 0) activeData[k] = v;
    });

    if (activeData.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.clockAlertOutline, color: JweTheme.textMuted.withOpacity(0.3), size: 32),
            const SizedBox(height: 8),
            Text("NO TIME LOGS", style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final double totalTime = activeData.values.fold(0, (sum, item) => sum + item);
    final entries = activeData.entries.toList();

    // Default Center Text
    String centerTopText = "TOTAL TIME";
    String centerBottomText = "${totalTime.toInt()}m";
    Color centerColor = JweTheme.textWhite;

    // Dynamic Center Text based on selection
    if (selectedTask != null && activeData.containsKey(selectedTask)) {
      centerTopText = selectedTask!.toUpperCase();
      if (centerTopText.length > 12) centerTopText = "${centerTopText.substring(0, 10)}..";
      centerBottomText = "${activeData[selectedTask]!.toInt()}m";
      centerColor = taskColors[selectedTask] ?? JweTheme.accentCyan;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 4, // Gaps
            centerSpaceRadius: 40,
            sections: entries.map((e) {
              final isSelected = e.key == selectedTask;
              final color = taskColors[e.key] ?? JweTheme.accentCyan;
              
              return PieChartSectionData(
                color: color.withOpacity(isSelected ? 1.0 : 0.6),
                value: e.value,
                title: '',
                radius: isSelected ? 20 : 15,
                borderSide: BorderSide(color: JweTheme.bgBase, width: 2),
              );
            }).toList(),
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                if (event is FlTapUpEvent && pieTouchResponse?.touchedSection != null) {
                  final index = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                  if (index >= 0 && index < entries.length) {
                    final key = entries[index].key;
                    onTaskSelected?.call(selectedTask == key ? null : key);
                  }
                } else if (event is FlTapUpEvent && pieTouchResponse?.touchedSection == null) {
                   onTaskSelected?.call(null);
                }
              },
            ),
          ),
        ),
        // Inner Ring Detail
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              centerTopText,
              style: const TextStyle(
                fontSize: 10, 
                color: JweTheme.textMuted, 
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5
              )
            ),
            Text(
              centerBottomText,
              style: GoogleFonts.rajdhani(
                fontSize: 20, 
                color: centerColor, 
                fontWeight: FontWeight.bold
              )
            ),
          ],
        )
      ],
    );
  }
}