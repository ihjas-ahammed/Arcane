import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Launcher theme tokens adapted to Dark mode (Cyber / Midnight / Red glow)
/// and Light mode (Warm tactical stone/paper / Calibrated crimson).
class LauncherTheme {
  static bool get isLight => JweTheme.isLight;

  // ── Accent Colors ──────────────────────────────────────────
  static Color get red =>
      isLight ? JweTheme.calibrate(const Color(0xFFFF2B3F)) : const Color(0xFFFF2B3F);

  static Color get redSoft => red.withValues(alpha: 0.55);

  static Color get redDim => red.withValues(alpha: 0.18);

  static Color get redGlow => red.withValues(alpha: 0.35);

  // ── Surface & Canvas Colors ────────────────────────────────
  static Color get bg =>
      isLight ? const Color(0xFFEDE8E0) : const Color(0xFF050608);

  static Color get panel =>
      isLight ? const Color(0xFFFAF8F5) : const Color(0xFF0E1015);

  static Color get panel2 =>
      isLight ? const Color(0xFFF3EFE7) : const Color(0xFF13161C);

  static Color get line =>
      isLight ? const Color(0xFFD4CDC0) : const Color(0xFF1E222B);

  static Color get text =>
      isLight ? const Color(0xFF211D18) : const Color(0xFFE9ECF2);

  static Color get muted =>
      isLight ? const Color(0xFF7A7266) : const Color(0xFF8A909C);

  static Color get dockButtonBg =>
      isLight ? const Color(0xFFF0EBE1) : const Color(0xD914161C);

  static Color get dockBorder =>
      isLight ? const Color(0xFFDCD4C6) : const Color(0xFF232730);

  static Color get cardAddedBadge =>
      isLight ? const Color(0xFFC81E30) : const Color(0xFFFF2B3F);

  // ── Typography (Rajdhani) ──────────────────────────────────
  static TextStyle rajdhani({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    double letterSpacing = 0.5,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.rajdhani(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color ?? text,
      height: height,
    );
  }
}
