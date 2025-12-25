import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class VirtuePieChart extends StatefulWidget {
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
  State<VirtuePieChart> createState() => _VirtuePieChartState();
}

class _VirtuePieChartState extends State<VirtuePieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.logs.isEmpty) {
      return const Center(
        child: Text(
          "No virtue data logged today.",
          style: TextStyle(
              color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic),
        ),
      );
    }

    // Aggregate totals
    Map<String, int> totals = {};
    for (var log in widget.logs) {
      log.xpGained.forEach((key, value) {
        totals[key] = (totals[key] ?? 0) + value;
      });
    }

    // Filter out zero values
    totals.removeWhere((key, value) => value <= 0);

    if (totals.isEmpty) {
      return const Center(
        child: Text(
          "No XP gained yet.",
          style: TextStyle(
              color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic),
        ),
      );
    }

    final int totalXpOfDay = totals.values.fold(0, (sum, item) => sum + item);
    final entries = totals.entries.toList();

    // Determine what text to show in the center
    // Priority: Hovered -> Selected -> Total
    int highlightIndex = _touchedIndex;
    if (highlightIndex == -1 && widget.selectedVirtue != null) {
      highlightIndex =
          entries.indexWhere((e) => e.key == widget.selectedVirtue);
    }

    String centerTopText = "TOTAL";
    String centerBottomText = "$totalXpOfDay XP";
    Color centerColor = AppTheme.fhTextPrimary;

    if (highlightIndex != -1 && highlightIndex < entries.length) {
      final entry = entries[highlightIndex];
      centerTopText = entry.key.toUpperCase();
      centerBottomText = "+${entry.value} XP";
      centerColor = _getVirtueColor(entry.key);
    }

    return LayoutBuilder(builder: (context, constraints) {
      // Responsive sizing
      final double chartRadius = constraints.maxWidth < 350 ? 45.0 : 55.0;
      final double centerRadius = constraints.maxWidth < 300 ? 55.0 : 65.0;

      final List<PieChartSectionData> sections =
          List.generate(entries.length, (i) {
        final entry = entries[i];
        final isHovered = i == _touchedIndex;
        final isSelected = entry.key == widget.selectedVirtue;
        final showActive = isHovered || (isSelected && _touchedIndex == -1);

        final color = _getVirtueColor(entry.key);

        // Pop out effect
        final double radius = showActive ? chartRadius + 8 : chartRadius;

        return PieChartSectionData(
          color: color.withValues(alpha: showActive ? 1.0 : 0.8),
          value: entry.value.toDouble(),
          title: '', // Hiding title on the chart itself for cleanliness
          radius: radius,
          // Add a border to sections for better separation
          badgeWidget: showActive ? _buildBadge(entry.key, color) : null,
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
                        if (widget.selectedVirtue != null) {
                          widget.onVirtueSelected?.call(null);
                        }
                        return;
                      }

                      final index =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                      _touchedIndex = index;

                      if (index >= 0 && index < entries.length) {
                        final key = entries[index].key;
                        if (widget.selectedVirtue != key) {
                          widget.onVirtueSelected?.call(key);
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
            // Center Info Display
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

  // Optional badge that appears outside the circle on hover
  Widget _buildBadge(String text, Color color) {
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

  Color _getVirtueColor(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom':
        return Colors.blueAccent;
      case 'courage':
        return AppTheme.fhAccentRed;
      case 'humanity':
        return const Color(0xFFE91E63);
      case 'justice':
        return AppTheme.fhAccentGold;
      case 'temperance':
        return AppTheme.fhAccentTeal;
      case 'transcendence':
        return AppTheme.fhAccentPurple;
      case 'discipline': // Added this one just in case
        return Colors.indigoAccent;
      case 'curiosity':
        return Colors.tealAccent;
      default:
        return Colors.grey;
    }
  }
}
