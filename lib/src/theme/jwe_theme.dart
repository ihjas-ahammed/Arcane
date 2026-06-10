import 'package:flutter/material.dart';

/// Operator HUD design tokens.
/// Original tactical-AI aesthetic: amber primary on midnight, hairline brackets, mono telemetry.
class JweTheme {
  // ── Backgrounds ─────────────────────────────────────────────
  static const Color bgDeep = Color(0xFF04060E);
  static const Color bgBase = Color(0xFF070B18);
  static const Color bgCanvas = Color(0xFF070B18);
  static const Color panel = Color(0xFF0D1426);
  static const Color panel2 = Color(0xFF101A30);
  static const Color elev = Color(0xFF142039);

  // ── Accents ─────────────────────────────────────────────────
  static Color accentAmber = const Color(0xFF00AEFF); // Primary HUD (Sky Blue)
  static Color amberDim = const Color(0xFF0082BF);
  static Color amberSoft = const Color(0x2400AEFF); // ~14% alpha
  static Color amberGlow = const Color(0x8C00AEFF);

  static const Color accentCyan = Color(0xFF5FE1D8); // Secondary HUD
  static const Color cyanDim = Color(0xFF2A8D88);
  static const Color cyanSoft = Color(0x1A5FE1D8);

  static const Color accentTeal = Color(0xFF4AF3C2);
  static const Color accentRed = Color(0xFFFF5470); // Alert
  static const Color accentWarn = Color(0xFFFFB547);

  // ── Text ────────────────────────────────────────────────────
  static const Color textWhite = Color(0xFFEAECF3);
  static const Color textMid = Color(0xFFA8B3C7);
  static const Color textMuted = Color(0xFF5E6C87);

  // ── Lines ───────────────────────────────────────────────────
  static const Color border = Color(0xFF1B2A38); // legacy panel border
  static const Color line = Color(0x215FE1D8); // cyan hairline ~13%
  static Color lineAmber = const Color(0x4D00AEFF); // sky blue hairline ~30%
  static const Color lineSoft = Color(0x0FFFFFFF); // ~6%

  // ── Fonts ───────────────────────────────────────────────────
  // Bundled families for static styling. HUD primitives use GoogleFonts
  // (saira / inter / jetBrainsMono) for the Operator HUD identity.
  static const String fontDisplay = 'RobotoCondensed';
  static const String fontBody = 'OpenSans';
}
