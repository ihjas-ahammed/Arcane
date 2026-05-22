import 'package:flutter/material.dart';

/// Spider-Man (Insomniac) UI palette — crimson + cyan on deep midnight blue.
class SpideyTheme {
  // Backgrounds
  static const Color bgDeep = Color(0xFF03070D);
  static const Color bgBase = Color(0xFF08111A);
  static const Color bgPanel = Color(0xFF0B1623);
  static const Color bgElevated = Color(0xFF132030);
  static const Color headerGradientStart = Color(0xFF162433);

  // Accents
  static const Color spideyRed = Color(0xFFD02B3E);
  static const Color spideyRedBright = Color(0xFFFF3D55);
  static const Color spideyCyan = Color(0xFF00F0FF);
  static const Color spideyCyanDim = Color(0xFF006B72);
  static const Color spideyGold = Color(0xFFE9B53A);

  // Text
  static const Color textWhite = Color(0xFFE6E6E6);
  static const Color textGrey = Color(0xFF8A9BA8);
  static const Color textMuted = Color(0xFF536273);

  // Lines
  static const Color border = Color(0xFF1F2F40);
  static const Color borderSoft = Color(0xFF152030);

  static const String fontDisplay = 'RobotoCondensed';
  static const String fontBody = 'OpenSans';

  static const LinearGradient panelGradient = LinearGradient(
    colors: [headerGradientStart, bgPanel],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const RadialGradient backdropGradient = RadialGradient(
    center: Alignment.center,
    colors: [Color(0xFF132030), Color(0xFF000000)],
    radius: 1.0,
  );
}
