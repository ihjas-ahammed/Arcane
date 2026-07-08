import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Spider-Man (Insomniac) UI palette — crimson + cyan on deep midnight blue.
class SpideyTheme {
  // Backgrounds
  static Color get bgDeep => JweTheme.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF03070D); // slate-200
  static Color get bgBase => JweTheme.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF08111A); // slate-100
  static Color get bgPanel => JweTheme.isLight ? const Color(0xFFFFFFFF) : const Color(0xFF0B1623); // white card
  static Color get bgElevated => JweTheme.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF132030); // slate-200
  static Color get headerGradientStart => JweTheme.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF162433);

  // Accents
  static Color get spideyRed => JweTheme.isLight ? const Color(0xFF991B1B) : const Color(0xFFD02B3E); // red-800
  static Color get spideyRedBright => JweTheme.isLight ? const Color(0xFFB91C1C) : const Color(0xFFFF3D55); // red-700
  static Color get spideyCyan => JweTheme.isLight ? const Color(0xFF0E7490) : const Color(0xFF00F0FF); // cyan-700 (dark, highly readable)
  static Color get spideyCyanDim => JweTheme.isLight ? const Color(0xFF155E75) : const Color(0xFF006B72); // cyan-800
  static Color get spideyGold => JweTheme.isLight ? const Color(0xFFB45309) : const Color(0xFFE9B53A); // amber-700

  // Text
  static Color get textWhite => JweTheme.isLight ? const Color(0xFF000000) : const Color(0xFFE6E6E6); // pure black
  static Color get textGrey => JweTheme.isLight ? const Color(0xFF111827) : const Color(0xFF8A9BA8); // dark gray-900
  static Color get textMuted => JweTheme.isLight ? const Color(0xFF4B5563) : const Color(0xFF536273); // slate-700/gray-600

  // Lines
  static Color get border => JweTheme.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1F2F40); // slate-200
  static Color get borderSoft => JweTheme.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF152030); // slate-50

  static const String fontDisplay = 'RobotoCondensed';
  static const String fontBody = 'OpenSans';

  static LinearGradient get panelGradient => LinearGradient(
    colors: [headerGradientStart, bgPanel],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static RadialGradient get backdropGradient => RadialGradient(
    center: Alignment.center,
    colors: [
      JweTheme.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF132030),
      JweTheme.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF000000)
    ],
    radius: 1.0,
  );
}
