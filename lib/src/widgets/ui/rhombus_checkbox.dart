// lib/src/widgets/ui/rhombus_checkbox.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'dart:math' as math;
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

enum CheckboxSize { small, medium }

class RhombusCheckbox extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool?>? onChanged;
  final bool disabled;
  final CheckboxSize size;

  const RhombusCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    this.disabled = false,
    this.size = CheckboxSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final double dimension =
        size == CheckboxSize.small ? 18.0 : 22.0; // Overall tap target
    final double iconSize = size == CheckboxSize.small ? 12.0 : 14.0;
    final double visualDimension =
        size == CheckboxSize.small ? 15.0 : 18.0; // Visual size of rhombus
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    Color bgColor = checked
        ? (gameProvider.getSelectedTask()?.taskColor ??
            AppTheme.fhAccentTealFixed)
        : AppTheme.fhBgMedium;
    Color borderColor = disabled
        ? (checked
            ? (gameProvider.getSelectedTask()?.taskColor ??
                    AppTheme.fhAccentTealFixed)
                .withOpacity(0.5)
            : AppTheme.fhBorderColor.withOpacity(0.5))
        : (checked
            ? (gameProvider.getSelectedTask()?.taskColor ??
                AppTheme.fhAccentTealFixed)
            : AppTheme.fhBorderColor);

    if (disabled && checked) {
      bgColor = (gameProvider.getSelectedTask()?.taskColor ??
              AppTheme.fhAccentTealFixed)
          .withOpacity(0.6);
    } else if (disabled && !checked) {
      bgColor = AppTheme.fhBgLight.withOpacity(0.4);
    }

    return InkWell(
      onTap: disabled ? null : () => onChanged?.call(!checked),
      borderRadius: BorderRadius.circular(
          dimension / 4), // Make tap effect slightly rounded
      child: SizedBox(
        width: dimension,
        height: dimension,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: math.pi / 4, // 45 degrees
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: visualDimension *
                    0.9, // Make it slightly smaller than container for padding
                width: visualDimension * 0.9,
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(
                    color: borderColor,
                    width: 1.5, // Slightly thicker border
                  ),
                  // No boxShadow for flatter screenshot-like style
                  // borderRadius: BorderRadius.circular(2), // Optional: slight rounding of corners
                ),
              ),
            ),
            if (checked)
              Icon(
                MdiIcons.checkBold, // Using MDI check for a bolder look
                size: iconSize,
                color: disabled
                    ? AppTheme.fhTextSecondary.withOpacity(0.7)
                    : AppTheme.fhBgDark, // Dark check on light teal
              ),
          ],
        ),
      ),
    );
  }
}
