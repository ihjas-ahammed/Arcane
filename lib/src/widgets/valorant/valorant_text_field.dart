import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';

class ValorantTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final bool autofocus;

  const ValorantTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.autofocus = false,
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
              Container(width: 4, height: 48, color: AppTheme.fhBorderColor),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  autofocus: autofocus,
                  style: const TextStyle(
                    color: AppTheme.fhTextPrimary,
                    fontFamily: AppTheme.fontBody,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: AppTheme.fhTextSecondary.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    filled: false,
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