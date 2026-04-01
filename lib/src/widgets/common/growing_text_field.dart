import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';

class GrowingTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minLines;

  const GrowingTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.minLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark.withValues(alpha: 0.5),
        border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.5)),
        // No rounded corners as per Valorant style preference in editor
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: null, // Allows unlimited growth
        keyboardType: TextInputType.multiline,
        style: const TextStyle(color: AppTheme.fhTextPrimary, height: 1.5, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.fhTextDisabled),
          contentPadding: EdgeInsets.zero,
          filled: false,
          isDense: true,
        ),
      ),
    );
  }
}