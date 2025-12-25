import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TimePieChart extends StatefulWidget {
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
  State<TimePieChart> createState() => _TimePieChartState();
}

class _TimePieChartState extends State<TimePieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.taskData.isEmpty ||
        widget.taskData.values.fold(0.0, (a, b) => a + b) <= 0) {
      return const Center(
        child: Text(
          "No active mission time today.",
          style: TextStyle(
              color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic),
        ),
      );
    }

    // Filter zero values
    final Map<String, double> activeData = {};
    widget.taskData.forEach((k, v) {
      if (v > 0) activeData[k] = v;
    });

    if (activeData.isEmpty) {
      return const Center(
        child: Text(
          "No time logged today.",
          style: TextStyle(
              color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic),
        ),
      );
    }

    final double totalTime =
        activeData.values.fold(0, (sum, item) => sum + item);
    final entries = activeData.entries.toList();

    String centerTopText = "TOTAL TIME";
    String centerBottomText = "${totalTime.toInt()}m";
    Color centerColor = AppTheme.fhTextPrimary;

    // Determine what to show in center
    // Priority: Hovered -> Selected -> Total
    int highlightIndex = _touchedIndex;
    if (highlightIndex == -1 && widget.selectedTask != null) {
      highlightIndex = entries.indexWhere((e) => e.key == widget.selectedTask);
    }

    if (highlightIndex != -1 && highlightIndex < entries.length) {
      final entry = entries[highlightIndex];
      centerTopText = entry.key.toUpperCase();
      if (centerTopText.length > 10)
        centerTopText = "${centerTopText.substring(0, 8)}..";

      centerBottomText = "${entry.value.toInt()}m";
      centerColor = widget.taskColors[entry.key] ?? AppTheme.fhAccentTeal;
    }

    return LayoutBuilder(builder: (context, constraints) {
      final double chartRadius = constraints.maxWidth < 350 ? 45.0 : 55.0;
      final double centerRadius = constraints.maxWidth < 300 ? 55.0 : 65.0;

      final List<PieChartSectionData> sections =
          List.generate(entries.length, (i) {
        final entry = entries[i];
        final isHovered = i == _touchedIndex;
        final isSelected = entry.key == widget.selectedTask;
        final showActive = isHovered || (isSelected && _touchedIndex == -1);

        final color = widget.taskColors[entry.key] ?? AppTheme.fhAccentTeal;

        final double radius = showActive ? chartRadius + 8 : chartRadius;

        return PieChartSectionData(
          color: color.withValues(alpha: showActive ? 1.0 : 0.8),
          value: entry.value,
          title: '',
          radius: radius,
          badgeWidget: showActive ? _buildBadge(color) : null,
          badgePositionPercentageOffset: 1.4,
          borderSide: const BorderSide(color: AppTheme.fhBgMedium, width: 2),
        );
      });

      return SizedBox(
        height: 250,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        // Clear selection on hover exit / touch release
                        if (widget.selectedTask != null) {
                          widget.onTaskSelected?.call(null);
                        }
                        return;
                      }

                      final index =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                      _touchedIndex = index;

                      // Update selection on hover/touch
                      if (index >= 0 && index < entries.length) {
                        final key = entries[index].key;
                        if (widget.selectedTask != key) {
                          widget.onTaskSelected?.call(key);
                        }
                      }
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 0,
                centerSpaceRadius: centerRadius,
                sections: sections,
                startDegreeOffset: 270,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerTopText,
                  style: const TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontFamily: AppTheme.fontBody,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  centerBottomText,
                  style: TextStyle(
                      color: centerColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppTheme.fontDisplay,
                      shadows: [
                        Shadow(
                          color: centerColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                        )
                      ]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: AppTheme.fhBgDeepDark,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4)
          ]),
      child: Icon(MdiIcons.arrowDownBold, size: 12, color: color),
    );
  }
}
