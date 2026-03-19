import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class JweProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final String? label;

  const JweProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              label!,
              style: GoogleFonts.rajdhani(
                color: color.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
            borderRadius: BorderRadius.zero,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 4,
                  )
                ]
              ),
            ),
          ),
        ),
      ],
    );
  }
}