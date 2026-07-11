import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';

class ColorSelectorDialog extends StatelessWidget {
  final Color selectedColor;
  final Function(Color) onColorSelected;

  const ColorSelectorDialog({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  static  List<Color> palette = [
    AppTheme.fhAccentTealFixed,
    AppTheme.fhAccentRed,
    AppTheme.fhAccentPurple,
    AppTheme.fhAccentOrange,
    AppTheme.fhAccentGold,
    AppTheme.fhAccentGreen,
    ArcPalette.sky, // Blue
    ArcPalette.sunflower, // Sun Flower
    ArcPalette.softRed, // Soft Red
    ArcPalette.softPurple, // Soft Purple
    ArcPalette.softTeal, // Soft Teal
    ArcPalette.softOrange, // Soft Orange
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("AGENT COLOR"),
      content: SizedBox(
        width: 300,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: palette.length,
          itemBuilder: (context, index) {
            final color = palette[index];
            final bool isSelected = color.value == selectedColor.value;

            return GestureDetector(
              onTap: () {
                onColorSelected(color);
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(
                    color: isSelected ? AppTheme.fhTextPrimary : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}