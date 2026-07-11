import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Surface tokens — every background an element can sit on.
/// Core surfaces delegate to JweTheme (single source of truth); this file
/// adds the surfaces that widgets used to hardcode.
///
/// Light mode is a warm-paper system (research: warm off-whites reduce eye
/// strain vs pure/cold white; avoid pure black/white).
class ArcSurfaces {
  static bool get _l => JweTheme.isLight;

  // ── Core (delegates) ───────────────────────────────────────
  static Color get canvasDeep => JweTheme.bgDeep;
  static Color get canvas => JweTheme.bgBase;
  static Color get panel => JweTheme.panel;
  static Color get panelAlt => JweTheme.panel2;
  static Color get elevated => JweTheme.elev;

  // ── Deep navy panel family (person/people dossier screens) ─
  /// Deepest inset panel (was 0xFF07121C / 0xFF061019 / 0xFF06101A).
  static Color get deepPanel => _l ? const Color(0xFFF7F4EE) : const Color(0xFF07121C);

  /// Raised/selected variant (was 0xFF0D1E2F / 0xFF0E2133 / 0xFF0F2136).
  static Color get deepPanelRaised => _l ? const Color(0xFFE9E4DB) : const Color(0xFF0D1E2F);

  // ── Warm ember panels (habit/streak containers) ────────────
  /// Was 0xFF140C08 — near-black warm brown.
  static Color get emberPanelDeep => _l ? const Color(0xFFF6EBDC) : const Color(0xFF140C08);

  /// Was 0xFF261811 — glowing orange container base.
  static Color get emberPanel => _l ? const Color(0xFFF1E2CD) : const Color(0xFF261811);

  // ── Nora (violet AI room) backdrop ──────────────────────────
  static Color get noraDeep => _l ? const Color(0xFFEFECE7) : const Color(0xFF0F0C1B);
  static Color get noraDeeper => _l ? const Color(0xFFE4DFD6) : const Color(0xFF0A0812);

  // ── Inputs & code fields ────────────────────────────────────
  /// Filled input background sitting on a panel.
  static Color get inputFill => _l ? const Color(0xFFF1EDE5) : Colors.black.withValues(alpha: 0.3);

  /// Monospace/JSON editor background.
  static Color get codeField => _l ? const Color(0xFFF1EEE7) : Colors.black;

  /// Disabled chip/button fill (was 0xFF444444).
  static Color get disabledFill => _l ? const Color(0xFFD8D2C8) : const Color(0xFF444444);

  // ── Overlays ────────────────────────────────────────────────
  /// "Ink" overlay: subtle structure drawn over surfaces.
  /// White-based in dark mode, black-based in light mode — this is the
  /// overlay that must flip with the mode (grid lines, idle segments).
  static Color ink(double alpha) =>
      (_l ? Colors.black : Colors.white).withValues(alpha: alpha);

  /// Dimming scrim over content (stays dark in both modes).
  static Color dim(double alpha) =>
      Colors.black.withValues(alpha: _l ? alpha * 0.7 : alpha);

  /// Glassmorphic bar fill (bottom nav).
  static Color get glass => _l ? const Color(0xB3FCFBF8) : const Color(0x8008101C);
}
