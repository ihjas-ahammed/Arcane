import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Stroke tokens — borders, hairlines, dividers, tracks.
class ArcStrokes {
  static bool get _l => JweTheme.isLight;

  // ── Core (delegates) ───────────────────────────────────────
  static Color get border => JweTheme.border;
  static Color get soft => JweTheme.lineSoft;

  /// Steel border used across the dossier screens (was 0xFF1F2F40).
  static Color get steel => _l ? const Color(0xFFD4CDC0) : const Color(0xFF1F2F40);

  /// Neutral 10% hairline for tracks, idle bars, dividers
  /// (was 0x1AA8B3C7 in dark).
  static Color get hairline => _l ? const Color(0x1A3D362E) : const Color(0x1AA8B3C7);

  /// 25% variant for chart guide dots (was 0x3FA8B3C7).
  static Color get hairlineStrong => _l ? const Color(0x3F3D362E) : const Color(0x3FA8B3C7);

  /// 5% variant for barely-there separators (was 0x0DFFFFFF).
  static Color get hairlineFaint => _l ? const Color(0x0D000000) : const Color(0x0DFFFFFF);
}
