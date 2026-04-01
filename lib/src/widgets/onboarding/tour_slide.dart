import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/ui/jwe_panel.dart';
import 'package:google_fonts/google_fonts.dart';

class TourSlide extends StatelessWidget {
  final String title;
  final String subtitle;
  final String content;
  final Widget visual;
  final Color accentColor;

  const TourSlide({
    super.key,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.visual,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(
            subtitle,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: JweTheme.textWhite,
              fontWeight: FontWeight.w900,
              fontSize: 36,
              height: 1.0,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          JwePanel(
            accentColor: accentColor,
            child: visual,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accentColor, width: 3)),
              color: JweTheme.panel.withOpacity(0.5),
            ),
            child: Text(
              content,
              style: const TextStyle(
                color: JweTheme.textWhite,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}