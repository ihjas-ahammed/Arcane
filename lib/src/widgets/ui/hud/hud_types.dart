import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';

/// Typography helpers (use GoogleFonts so HUD identity is consistent
/// regardless of bundled assets).
class HudType {
  static TextStyle display({double size = 16, FontWeight weight = FontWeight.w700, Color? color, double letter = 0.4}) =>
      GoogleFonts.saira(fontSize: size, fontWeight: weight, color: color ?? JweTheme.textWhite, letterSpacing: letter, height: 1.15);

  static TextStyle body({double size = 13, FontWeight weight = FontWeight.w400, Color? color, double letter = 0.05}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color ?? JweTheme.textWhite, letterSpacing: letter, height: 1.4);

  static TextStyle mono({double size = 11, FontWeight weight = FontWeight.w500, Color? color, double letter = 1.2}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color ?? JweTheme.textMid, letterSpacing: letter);

  static TextStyle cap({Color? color, double size = 10}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: FontWeight.w600, color: color ?? JweTheme.textMuted, letterSpacing: 1.8);
}

/// Clip shape for cut-corner panels (Operator HUD signature).
enum HudClip { none, br, tr, both }

/// HUD color tone categories
enum HudTone { neutral, amber, cyan, teal, red }

Color hudToneFg(HudTone t) {
  switch (t) {
    case HudTone.amber: return JweTheme.accentAmber;
    case HudTone.cyan: return JweTheme.accentCyan;
    case HudTone.teal: return JweTheme.accentTeal;
    case HudTone.red: return JweTheme.accentRed;
    case HudTone.neutral: return JweTheme.textMid;
  }
}

Color hudToneBg(HudTone t) {
  switch (t) {
    case HudTone.amber: return JweTheme.amberSoft;
    case HudTone.cyan: return JweTheme.cyanSoft;
    case HudTone.teal: return ArcAccents.tealSoft;
    case HudTone.red: return ArcAccents.redSoft;
    case HudTone.neutral: return ArcStrokes.hairline;
  }
}
