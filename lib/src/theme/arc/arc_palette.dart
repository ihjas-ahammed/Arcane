import 'package:flutter/material.dart';

/// Fixed data palettes — user-selectable task colors and protocol theme
/// hues. These are data, not chrome: they identify user content, so they do
/// NOT flip with the mode. Light-mode legibility is handled at the point of
/// use by JweTheme.calibrate().
class ArcPalette {
  // Task color picker swatches (color_selector_dialog).
  static const Color sky = Color(0xFF5DADE2);
  static const Color sunflower = Color(0xFFF1C40F);
  static const Color softRed = Color(0xFFEC7063);
  static const Color softPurple = Color(0xFFA569BD);
  static const Color softTeal = Color(0xFF48C9B0);
  static const Color softOrange = Color(0xFFEB984E);

  // Protocol theme hues (shared by task drawer / details / protocol dialog).
  static const Color themeHealth = Color(0xFF58D68D);
  static const Color themeFinance = Color(0xFFF1C40F);
  static const Color themeCreative = Color(0xFFEC7063);
  static const Color themeExploration = Color(0xFF5DADE2);
  static const Color themeSocial = Color(0xFFE59866);
  static const Color themeNature = Color(0xFF2ECC71);
}
