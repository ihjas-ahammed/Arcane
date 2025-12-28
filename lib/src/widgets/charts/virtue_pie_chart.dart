import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class VirtuePieChart extends StatelessWidget {
  final List<ReflectionLog> logs;
  final String? selectedVirtue;
  final Function(String?)? onVirtueSelected;

  const VirtuePieChart({
    super.key,
    required this.logs,
    this.selectedVirtue,
    this.onVirtueSelected,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, int> totals = {};
    for (var log in logs) {
      log.xpGained.forEach((key, value) {
        totals[key] = (totals[key] ?? 0) + value;
      });
    }
    totals.removeWhere((key, value) => value <= 0);

    if (totals.isEmpty) {
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

    final int totalXp = totals.values.fold(0, (sum, item) => sum + item);
    final entries = totals.entries.toList();

    // Default Text
    String centerTopText = "TOTAL XP";
    String centerBottomText = "$totalXp";
    Color centerColor = AppTheme.fhTextPrimary;

    // Selected Text
    if (selectedVirtue != null && totals.containsKey(selectedVirtue)) {
      centerTopText = selectedVirtue!.toUpperCase();
      centerBottomText = "+${totals[selectedVirtue]}";
      centerColor = _getVirtueColor(selectedVirtue!);
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
                color: _getVirtueColor(e.key).withValues(alpha: isSelected ? 1.0 : 0.7),
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
              style: const TextStyle(fontSize: 10, color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)
            ),
            Text(
              centerBottomText, 
              style: TextStyle(fontSize: 20, color: centerColor, fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.bold)
            ),
          ],
        )
      ],
    );
  }

  Color _getVirtueColor(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom': return Colors.blueAccent;
      case 'courage': return AppTheme.fhAccentRed;
      case 'humanity': return const Color(0xFFE91E63);
      case 'justice': return AppTheme.fhAccentGold;
      case 'temperance': return AppTheme.fhAccentTeal;
      case 'transcendence': return AppTheme.fhAccentPurple;
      default: return Colors.grey;
    }
  }
}