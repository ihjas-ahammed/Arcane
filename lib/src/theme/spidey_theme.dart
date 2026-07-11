import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Spider-Man (Insomniac) UI palette — crimson + cyan on deep midnight blue.
/// Light mode maps onto the shared warm-paper system.
class SpideyTheme {
  // Backgrounds
  static Color get bgDeep => JweTheme.isLight ? const Color(0xFFECE8E1) : const Color(0xFF03070D); // warm stone
  static Color get bgBase => JweTheme.isLight ? const Color(0xFFF5F2EC) : const Color(0xFF08111A); // warm paper
  static Color get bgPanel => JweTheme.isLight ? const Color(0xFFFCFBF8) : const Color(0xFF0B1623); // warm card
  static Color get bgElevated => JweTheme.isLight ? const Color(0xFFE9E4DB) : const Color(0xFF132030); // warm elevated
  static Color get headerGradientStart => JweTheme.isLight ? const Color(0xFFE9E4DB) : const Color(0xFF162433);

  // Accents
  static Color get spideyRed => JweTheme.isLight ? const Color(0xFF991B1B) : const Color(0xFFD02B3E); // red-800
  static Color get spideyRedBright => JweTheme.isLight ? const Color(0xFFB91C1C) : const Color(0xFFFF3D55); // red-700
  static Color get spideyCyan => JweTheme.isLight ? const Color(0xFF0E7490) : const Color(0xFF00F0FF); // cyan-700 (dark, highly readable)
  static Color get spideyCyanDim => JweTheme.isLight ? const Color(0xFF155E75) : const Color(0xFF006B72); // cyan-800
  static Color get spideyGold => JweTheme.isLight ? const Color(0xFFB45309) : const Color(0xFFE9B53A); // amber-700

  // Text — warm off-black hierarchy in light mode
  static Color get textWhite => JweTheme.isLight ? const Color(0xFF211D18) : const Color(0xFFE6E6E6); // warm off-black
  static Color get textGrey => JweTheme.isLight ? const Color(0xFF4A443C) : const Color(0xFF8A9BA8); // warm gray-700
  static Color get textMuted => JweTheme.isLight ? const Color(0xFF837B70) : const Color(0xFF536273); // warm gray-500

  // Lines
  static Color get border => JweTheme.isLight ? const Color(0xFFDDD6CA) : const Color(0xFF1F2F40); // warm border
  static Color get borderSoft => JweTheme.isLight ? const Color(0xFFEFEBE3) : const Color(0xFF152030); // warm border soft

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
      JweTheme.isLight ? const Color(0xFFF5F2EC) : const Color(0xFF132030),
      JweTheme.isLight ? const Color(0xFFECE8E1) : const Color(0xFF000000)
    ],
    radius: 1.0,
  );
}
