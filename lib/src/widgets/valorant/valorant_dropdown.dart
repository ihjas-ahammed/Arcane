import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';

class ValorantDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const ValorantDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.fhTextSecondary,
            fontFamily: AppTheme.fontDisplay,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark.withOpacity(0.5),
            border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Container(width: 4, height: 48, color: AppTheme.fhAccentTeal),
              Expanded(
                child: ButtonTheme(
                  alignedDropdown: true,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<T>(
                      value: value,
                      items: items,
                      onChanged: onChanged,
                      style: const TextStyle(
                        color: AppTheme.fhTextPrimary,
                        fontFamily: AppTheme.fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.w600
                      ),
                      dropdownColor: AppTheme.fhBgDark,
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.fhTextSecondary),
                      isExpanded: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}