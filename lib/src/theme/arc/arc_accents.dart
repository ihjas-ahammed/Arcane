import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Accent tokens — semantic colors beyond the JweTheme core, plus the soft
/// tone fills the HUD primitives used to hardcode.
/// Light values are darkened for >=4.5:1 contrast on the warm-paper surfaces
/// while keeping each hue's identity (no hue swaps).
class ArcAccents {
  static bool get _l => JweTheme.isLight;

  // ── Core (delegates) ───────────────────────────────────────
  static Color get primary => JweTheme.accentAmber;
  static Color get secondary => JweTheme.accentCyan;
  static Color get success => JweTheme.accentTeal;
  static Color get danger => JweTheme.accentRed;
  static Color get warning => JweTheme.accentWarn;

  // ── Extended accents ───────────────────────────────────────
  /// Nora / therapy purple (was 0xFF8A2BE2).
  static Color get violet => _l ? const Color(0xFF6D28D9) : const Color(0xFF8A2BE2);

  /// Brighter purple accent used in review screens (was 0xFFB07BFF).
  static Color get violetBright => _l ? const Color(0xFF7C3AED) : const Color(0xFFB07BFF);

  /// Indigo (bus/transit cards, was 0xFF3F51B5).
  static Color get indigo => _l ? const Color(0xFF3949AB) : const Color(0xFF3F51B5);

  /// Neon cyan of the dossier/NFS aesthetic (was 0xFF00F0FF).
  static Color get neonCyan => _l ? const Color(0xFF0E7490) : const Color(0xFF00F0FF);

  /// Neon pink "running" state (was 0xFFFF0055).
  static Color get neonPink => _l ? const Color(0xFFBE185D) : const Color(0xFFFF0055);

  // ── Timer ring family (circular_time_progress) ─────────────
  /// Completed ring green (was 0xFF3BFEB9).
  static Color get ringGreen => _l ? const Color(0xFF047857) : const Color(0xFF3BFEB9);

  /// Bright sweep green (was 0xFF4FFFA8).
  static Color get ringGreenBright => _l ? const Color(0xFF059669) : const Color(0xFF4FFFA8);

  /// Gradient partner green (was 0xFF7AFFBD).
  static Color get ringGreenSoft => _l ? const Color(0xFF10B981) : const Color(0xFF7AFFBD);

  /// Tick spikes around the ring (was 0xFF445561).
  static Color get ringSpikes => _l ? const Color(0xFFC9C2B6) : const Color(0xFF445561);

  /// Inactive ring track (was 0xFF5D727D).
  static Color get ringInactive => _l ? const Color(0xFFB3AA9C) : const Color(0xFF5D727D);

  // ── Soft tone fills (10% chips/tracks used by HUD widgets) ──
  static Color get tealSoft => _l ? const Color(0x1A047857) : const Color(0x1A4AF3C2);
  static Color get redSoft => _l ? const Color(0x1ABE123C) : const Color(0x1AFF5470);
  static Color get neutralSoft => _l ? const Color(0x143D362E) : const Color(0x1AA8B3C7);
}
