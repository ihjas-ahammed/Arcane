import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Content tokens — text and icon colors.
/// Delegates the core hierarchy to JweTheme and adds contrast helpers for
/// content sitting on accent fills and arbitrary swatches.
class ArcContent {
  // ── Hierarchy (delegates) ──────────────────────────────────
  static Color get primary => JweTheme.textWhite;
  static Color get secondary => JweTheme.textMid;
  static Color get muted => JweTheme.textMuted;

  /// Foreground for text/icons on an accent-colored fill.
  /// Dark-mode accents are bright (black reads best); light-mode accents
  /// are calibrated dark (white reads best).
  static Color get onAccent => JweTheme.onAccent;

  /// Foreground readable on an arbitrary swatch (user task colors).
  static Color onSwatch(Color swatch) =>
      ThemeData.estimateBrightnessForColor(swatch) == Brightness.dark
          ? Colors.white
          : Colors.black;

  /// Bright body text on the dossier (person) screens
  /// (was hardcoded 0xFFCCCCCC).
  static Color get dossierBody =>
      JweTheme.isLight ? const Color(0xFF3D3830) : const Color(0xFFCCCCCC);
}
