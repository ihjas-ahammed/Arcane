import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ValorantColors {
  static const Color black = Color(0xFF0F1923);      // Main Background
  static const Color darkGrey = Color(0xFF1F2937);   // Card Background
  static const Color red = Color(0xFFFF4655);        // Primary Accent (Kill/Alert)
  static const Color white = Color(0xFFECE8E1);      // Main Text
  static const Color teal = Color(0xFF00F59B);       // Secondary Accent (Abilities/Success)
  static const Color muted = Color(0xFF8B9BB4);      // Subtitles/Disabled
}

class ValorantTextStyles {
  static TextStyle get header => GoogleFonts.teko(
    color: ValorantColors.white,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: 2.0,
  );

  static TextStyle get subHeader => GoogleFonts.teko(
    color: ValorantColors.white,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
  );

  static TextStyle get body => GoogleFonts.roboto(
    color: ValorantColors.white.withOpacity(0.9),
    fontSize: 14,
    height: 1.5,
  );

  static TextStyle get label => GoogleFonts.roboto(
    color: ValorantColors.muted,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.0,
  );
}