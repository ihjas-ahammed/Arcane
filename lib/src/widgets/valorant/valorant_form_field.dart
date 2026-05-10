import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';

class ValorantFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;

  const ValorantFormField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onSaved,
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
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onSaved: onSaved,
          style: const TextStyle(
            color: AppTheme.fhTextPrimary,
            fontFamily: AppTheme.fontBody,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.fhBgDark.withOpacity(0.5),
            contentPadding: const EdgeInsets.all(16),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppTheme.fhTextSecondary) : null,
            suffixIcon: suffixIcon,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppTheme.fhBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.5)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppTheme.fhAccentRed, width: 1.0),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppTheme.fhAccentRed),
            ),
            errorStyle: const TextStyle(
              color: AppTheme.fhAccentRed,
              fontFamily: AppTheme.fontBody,
              fontSize: 11
            ),
          ),
        ),
      ],
    );
  }
}