// lib/src/widgets/ui/rhombus_checkbox.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
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
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    Color bgColor = checked
        ? (appProvider.getSelectedTask()?.taskColor ??
            AppTheme.fhAccentTealFixed)
        : AppTheme.fhBgMedium;
    Color borderColor = disabled
        ? (checked
            ? (appProvider.getSelectedTask()?.taskColor ??
                    AppTheme.fhAccentTealFixed)
                .withValues(alpha: 0.5)
            : AppTheme.fhBorderColor.withValues(alpha: 0.5))
        : (checked
            ? (appProvider.getSelectedTask()?.taskColor ??
                AppTheme.fhAccentTealFixed)
            : AppTheme.fhBorderColor);

    if (disabled && checked) {
      bgColor = (appProvider.getSelectedTask()?.taskColor ??
              AppTheme.fhAccentTealFixed)
          .withValues(alpha: 0.6);
    } else if (disabled && !checked) {
      bgColor = AppTheme.fhBgMedium.withValues(alpha: 0.4);
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
                ),
              ),
            ),
            if (checked)
              Icon(
                MdiIcons.checkBold,
                size: iconSize,
                color: disabled
                    ? AppTheme.fhTextSecondary.withValues(alpha: 0.7)
                    : AppTheme.fhBgDark,
              ),
          ],
        ),
      ),
    );
  }
}
