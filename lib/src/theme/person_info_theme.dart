import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Theme constants mapped precisely to the requested HTML/CSS variables
/// for the Person Profile Dossier screens.
/// Light mode maps onto the shared warm-paper system.
class PersonInfoTheme {
  static Color get spideyRed => JweTheme.isLight ? const Color(0xFFB91C1C) : const Color(0xFFd02b3e);
  static Color get spideyCyan => JweTheme.isLight ? const Color(0xFF0E7490) : const Color(0xFF00f0ff);
  static Color get spideyCyanDim => JweTheme.isLight ? const Color(0xFF155E75) : const Color(0xFF006b72);
  static Color get bgDark => JweTheme.isLight ? const Color(0xFFF5F2EC) : const Color(0xFF08111a);
  static Color get bgPanel => JweTheme.isLight ? const Color(0xFFFCFBF8) : const Color(0xFF0b1623);
  static Color get textWhite => JweTheme.isLight ? const Color(0xFF211D18) : const Color(0xFFe6e6e6);
  static Color get textGrey => JweTheme.isLight ? const Color(0xFF4A443C) : const Color(0xFF8a9ba8);
  static Color get headerGradientStart => JweTheme.isLight ? const Color(0xFFE9E4DB) : const Color(0xFF162433);
}
