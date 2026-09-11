import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class SectionLabel extends StatelessWidget {
  final String label;
  final Color accentColor;
  final IconData icon;
  final Widget? trailing;

  const SectionLabel({
    super.key,
    required this.label,
    required this.accentColor,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: accentColor),
          const SizedBox(width: 8),
          Icon(icon, color: accentColor, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              color: JweTheme.textWhite,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
