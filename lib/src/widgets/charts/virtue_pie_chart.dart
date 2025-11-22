import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
      return Center(
        child: Text(
          "No XP gained yet.",
          style: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic),
        ),
      );
    }

    final int totalXpOfDay = totals.values.fold(0, (sum, item) => sum + item);
    final entries = totals.entries.toList();

    // Determine what text to show in the center
    String centerTopText = "TOTAL";
    String centerBottomText = "$totalXpOfDay XP";
    Color centerColor = AppTheme.fhTextPrimary;

    if (_touchedIndex != -1 && _touchedIndex < entries.length) {
      final entry = entries[_touchedIndex];
      centerTopText = entry.key.toUpperCase();
      centerBottomText = "+${entry.value} XP";
      centerColor = _getVirtueColor(entry.key);
    }

    return LayoutBuilder(builder: (context, constraints) {
      // Responsive sizing
      final double chartRadius = constraints.maxWidth < 350 ? 45.0 : 55.0;
      final double centerRadius = constraints.maxWidth < 300 ? 55.0 : 65.0;

      final List<PieChartSectionData> sections = List.generate(entries.length, (i) {
        final isTouched = i == _touchedIndex;
        final entry = entries[i];
        final color = _getVirtueColor(entry.key);
        
        // Pop out effect
        final double radius = isTouched ? chartRadius + 8 : chartRadius;
        
        return PieChartSectionData(
          color: color.withOpacity(isTouched ? 1.0 : 0.8),
          value: entry.value.toDouble(),
          title: '', // Hiding title on the chart itself for cleanliness
          radius: radius,
          // Add a border to sections for better separation
          badgeWidget: isTouched ? _buildBadge(entry.key, color) : null,
          badgePositionPercentageOffset: 1.4,
          borderSide: BorderSide(color: AppTheme.fhBgMedium, width: 2),
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
                        return;
                      }
                      _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
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
                  style: TextStyle(
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
                        color: centerColor.withOpacity(0.5),
                        blurRadius: 10,
                      )
                    ]
                  ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)]
      ),
      child:  Icon(MdiIcons.arrowDownBold, size: 12, color: color), 
      // Used an icon marker instead of text to avoid clutter, 
      // since text is now in the center.
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