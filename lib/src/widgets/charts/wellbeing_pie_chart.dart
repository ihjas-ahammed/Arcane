import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/wellbeing_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class WellbeingPieChart extends StatelessWidget {
  final List<ReflectionLog> logs;
  final String? selectedVirtue;
  final Function(String?)? onVirtueSelected;

  const WellbeingPieChart({
    super.key,
    required this.logs,
    this.selectedVirtue,
    this.onVirtueSelected,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, int> categoryTotals = {};
    
    for (var log in logs) {
      log.xpGained.forEach((key, value) {
        if (value > 0) {
           categoryTotals[key] = (categoryTotals[key] ?? 0) + value;
        }
      });
    }

    if (categoryTotals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.chartDonut, color: AppTheme.fhTextDisabled.withValues(alpha: 0.3), size: 32),
            const SizedBox(height: 8),
            Text("NO XP DATA", style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: AppTheme.fontDisplay, fontSize: 16)),
          ],
        ),
      );
    }

    final int totalXp = categoryTotals.values.fold(0, (sum, item) => sum + item);
    final entries = categoryTotals.entries.toList();

    // Default Text
    String centerTopText = "TOTAL XP";
    String centerBottomText = "$totalXp";
    Color centerColor = AppTheme.fhTextPrimary;

    // Selected Text
    if (selectedVirtue != null && categoryTotals.containsKey(selectedVirtue)) {
      centerTopText = selectedVirtue!.toUpperCase();
      if (centerTopText.contains(' ')) {
        centerTopText = centerTopText.replaceAll(' ', '\n');
      } else if (centerTopText.contains('-')) {
        centerTopText = centerTopText.replaceAll('-', '-\n');
      }
      centerBottomText = "+${categoryTotals[selectedVirtue]}";
      centerColor = WellbeingTheme.getColor(selectedVirtue!);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 4, 
            centerSpaceRadius: 40,
            sections: entries.map((e) {
              final isSelected = e.key == selectedVirtue;
              return PieChartSectionData(
                color: WellbeingTheme.getColor(e.key).withValues(alpha: isSelected ? 1.0 : 0.7),
                value: e.value.toDouble(),
                title: '',
                radius: isSelected ? 20 : 15,
                borderSide: BorderSide(color: AppTheme.fhBgDeepDark, width: 2), 
              );
            }).toList(),
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                if (event is FlTapUpEvent && pieTouchResponse?.touchedSection != null) {
                  final index = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                  if (index >= 0 && index < entries.length) {
                    final key = entries[index].key;
                    onVirtueSelected?.call(selectedVirtue == key ? null : key);
                  }
                } else if (event is FlTapUpEvent && pieTouchResponse?.touchedSection == null) {
                   onVirtueSelected?.call(null);
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
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)
            ),
            Text(
              centerBottomText, 
              style: TextStyle(fontSize: 18, color: centerColor, fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.bold)
            ),
          ],
        )
      ],
    );
  }
}