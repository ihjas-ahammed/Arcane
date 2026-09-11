import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'package:missions/src/theme/person_info_theme.dart';

class CyberpunkTextField extends StatelessWidget {
  final TextEditingController controller;
  final int? maxLines;
  final TextInputType keyboardType;
  final String? hintText;

  const CyberpunkTextField({
    super.key,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ArcSurfaces.deepPanel,
        border: Border.all(color: ArcStrokes.steel),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.rajdhani(
          color: PersonInfoTheme.textWhite,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: PersonInfoTheme.textGrey, fontSize: 11),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}

class PersonSectionHeader extends StatelessWidget {
  final String text;

  const PersonSectionHeader({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 15.0),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: GoogleFonts.rajdhani(
              color: PersonInfoTheme.spideyCyan,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [PersonInfoTheme.spideyCyanDim, Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PersonFieldLabel extends StatelessWidget {
  final String label;

  const PersonFieldLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.rajdhani(
          color: PersonInfoTheme.textGrey,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
