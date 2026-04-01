import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class JwePanel extends StatelessWidget {
  final String? title;
  final Widget child;
  final Color accentColor;

  const JwePanel({
    super.key,
    this.title,
    required this.child,
    this.accentColor = JweTheme.accentCyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: JweTheme.panel.withOpacity(0.85),
        border: Border.all(color: accentColor.withOpacity(0.3)),
        borderRadius: BorderRadius.zero, // Sharp holographic aesthetic
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: accentColor, width: 4),
                  bottom: BorderSide(color: accentColor.withOpacity(0.2)),
                ),
                gradient: LinearGradient(
                  colors:[accentColor.withOpacity(0.15), Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Text(
                title!.toUpperCase(),
                style: GoogleFonts.rajdhani(
                  color: JweTheme.textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ],
      ),
    );
  }
}