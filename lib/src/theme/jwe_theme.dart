import 'package:flutter/material.dart';

/// Operator HUD design tokens.
/// Original tactical-AI aesthetic: amber primary on midnight, hairline brackets, mono telemetry.
class JweTheme {
  static bool isLight = false;

  // Backing fields for dynamic overrides from selected tasks
  static Color? _accentAmber;
  static Color? _amberDim;
  static Color? _amberSoft;
  static Color? _amberGlow;
  static Color? _lineAmber;

  // Intercept and calibrate assigned colors to fit an elegant light mode
  // palette. Keeps each hue's identity (no crush-to-black): saturation is
  // preserved and lightness lands in a darker, high-contrast band, with yellows/limes
  // pushed darker since they need it to pass contrast on paper surfaces.
  static Color calibrate(Color c) {
    if (!isLight) return c;
    final hsl = HSLColor.fromColor(c);
    final double sat = hsl.saturation.clamp(0.55, 0.85);
    final bool yellowish = hsl.hue >= 38 && hsl.hue < 95;
    final double light = yellowish
        ? hsl.lightness.clamp(0.20, 0.30)
        : hsl.lightness.clamp(0.24, 0.36);
    return hsl.withSaturation(sat).withLightness(light).toColor();
  }

  // ── Backgrounds ─────────────────────────────────────────────
  // Light mode is warm tactical paper/stone (not cold slate / blinding pure white):
  // warm neutrals reduce eye strain over long sessions, provide rich tactile depth,
  // and make elevated cards distinctly pop against the canvas.
  static Color get bgDeep => isLight ? const Color(0xFFE2DDD2) : const Color(0xFF04060E); // warm stone inset
  static Color get bgBase => isLight ? const Color(0xFFEDE8E0) : const Color(0xFF070B18); // warm tactical paper
  static Color get bgCanvas => isLight ? const Color(0xFFEDE8E0) : const Color(0xFF070B18); // warm canvas
  static Color get panel => isLight ? const Color(0xFFFAF8F5) : const Color(0xFF0D1426); // elevated card surface
  static Color get panel2 => isLight ? const Color(0xFFF3EFE7) : const Color(0xFF101A30); // warm panel alt
  static Color get elev => isLight ? const Color(0xFFDFD9CE) : const Color(0xFF142039); // warm elevated

  // ── Accents ─────────────────────────────────────────────────
  static Color get accentAmber => calibrate(_accentAmber ?? (isLight ? const Color(0xFF026AA2) : const Color(0xFF00AEFF)));
  static set accentAmber(Color val) => _accentAmber = val;

  static Color get amberDim => calibrate(_amberDim ?? (isLight ? const Color(0xFF075985) : const Color(0xFF0082BF)));
  static set amberDim(Color val) => _amberDim = val;

  static Color get amberSoft => _amberSoft ?? (isLight ? const Color(0x18026AA2) : const Color(0x2400AEFF));
  static set amberSoft(Color val) {
    if (isLight) {
      _amberSoft = calibrate(val).withValues(alpha: 0.14);
    } else {
      _amberSoft = val;
    }
  }

  static Color get amberGlow => _amberGlow ?? (isLight ? const Color(0x33026AA2) : const Color(0x8C00AEFF));
  static set amberGlow(Color val) {
    if (isLight) {
      _amberGlow = calibrate(val).withValues(alpha: 0.25);
    } else {
      _amberGlow = val;
    }
  }

  static Color get accentCyan => isLight ? const Color(0xFF0F766E) : const Color(0xFF5FE1D8); // Secondary HUD (teal)
  static Color get cyanDim => isLight ? const Color(0xFF115E59) : const Color(0xFF2A8D88);
  static Color get cyanSoft => isLight ? const Color(0x190F766E) : const Color(0x1A5FE1D8);

  static Color get accentTeal => isLight ? const Color(0xFF047857) : const Color(0xFF4AF3C2); // forest emerald
  static Color get accentRed => isLight ? const Color(0xFFBE123C) : const Color(0xFFFF5470); // elegant rose-crimson
  static Color get accentWarn => isLight ? const Color(0xFFB45309) : const Color(0xFFFFB547); // rich bronze-amber

  // ── Text ────────────────────────────────────────────────────
  // Warm off-black hierarchy (pure #000 on paper is harsh).
  static Color get textWhite => isLight ? const Color(0xFF211D18) : const Color(0xFFEAECF3); // warm off-black
  static Color get textMid => isLight ? const Color(0xFF4A443C) : const Color(0xFFA8B3C7); // warm gray-700
  static Color get textMuted => isLight ? const Color(0xFF7A7266) : const Color(0xFF5E6C87); // warm gray-500

  // ── Lines ───────────────────────────────────────────────────
  static Color get border => isLight ? const Color(0xFFD4CDC0) : const Color(0xFF1B2A38); // warm border
  static Color get line => isLight ? const Color(0x220F766E) : const Color(0x215FE1D8);
  static Color get lineAmber => _lineAmber ?? (isLight ? const Color(0x33026AA2) : const Color(0x4D00AEFF));
  static set lineAmber(Color val) {
    if (isLight) {
      _lineAmber = calibrate(val).withValues(alpha: 0.25);
    } else {
      _lineAmber = val;
    }
  }

  static Color get lineSoft => isLight ? const Color(0x14000000) : const Color(0x0FFFFFFF);

  // ── Contrast helpers ────────────────────────────────────────
  /// Foreground for text/icons sitting on an accent-colored fill.
  /// Light-mode accents are calibrated dark (white reads best);
  /// dark-mode accents are bright (black reads best).
  static Color get onAccent => isLight ? Colors.white : Colors.black;

  /// Brightness-aware ColorScheme for date/time pickers so they stay
  /// readable in both modes (dark scheme on light surfaces renders
  /// white-on-white otherwise).
  static ColorScheme pickerScheme({Color? accent, Color? surface}) {
    final Color a = accent ?? accentAmber;
    return isLight
        ? ColorScheme.light(
            primary: a,
            onPrimary: Colors.white,
            surface: surface ?? panel,
            onSurface: textWhite,
          )
        : ColorScheme.dark(
            primary: a,
            onPrimary: Colors.black,
            surface: surface ?? bgBase,
            onSurface: textWhite,
          );
  }

  // ── Fonts ───────────────────────────────────────────────────
  // Bundled families for static styling. HUD primitives use GoogleFonts
  // (saira / inter / jetBrainsMono) for the Operator HUD identity.
  static const String fontDisplay = 'RobotoCondensed';
  static const String fontBody = 'OpenSans';
}

// Keep a stub of JweDynamicColor for test compatibility
class JweDynamicColor extends Color {
  final Color darkColor;
  final Color lightColor;
  const JweDynamicColor(this.darkColor, this.lightColor) : super(0);
  @override
  int get value => JweTheme.isLight ? lightColor.value : darkColor.value;
}
