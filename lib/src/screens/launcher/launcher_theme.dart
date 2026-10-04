import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';

class LauncherPalette {
  final String id;
  final String name;
  final Color accent;
  final Color? bgDark;
  final Color? bgLight;
  final Color? panelDark;
  final Color? panelLight;

  const LauncherPalette({
    required this.id,
    required this.name,
    required this.accent,
    this.bgDark,
    this.bgLight,
    this.panelDark,
    this.panelLight,
  });

  static List<LauncherPalette> get presets => LauncherTheme.palettes;
  static LauncherPalette byId(String id) =>
      LauncherTheme.palettes.firstWhere((p) => p.id == id, orElse: () => LauncherTheme.palettes.first);
}

/// Launcher theme tokens adapted to Dark mode (Cyber / Midnight / Red glow)
/// and Light mode (Warm tactical stone/paper / Calibrated crimson).
class LauncherTheme {
  static bool get isLight => JweTheme.isLight;

  static const List<LauncherPalette> palettes = [
    LauncherPalette(
      id: 'crimson',
      name: 'Crimson Protocol',
      accent: Color(0xFFFF2B3F),
      bgDark: Color(0xFF07080B),
      bgLight: Color(0xFFEDE8E0),
      panelDark: Color(0xFF0E1016),
      panelLight: Color(0xFFFAF8F5),
    ),
    LauncherPalette(
      id: 'amber',
      name: 'Tactical Amber',
      accent: Color(0xFFFFB300),
      bgDark: Color(0xFF0B0904),
      bgLight: Color(0xFFEFE9DC),
      panelDark: Color(0xFF16130A),
      panelLight: Color(0xFFFDFBF7),
    ),
    LauncherPalette(
      id: 'cyan',
      name: 'Cyber Cyan',
      accent: Color(0xFF00E5FF),
      bgDark: Color(0xFF04090C),
      bgLight: Color(0xFFE5ECEF),
      panelDark: Color(0xFF09141B),
      panelLight: Color(0xFFF6F9FA),
    ),
    LauncherPalette(
      id: 'matrix',
      name: 'Matrix Emerald',
      accent: Color(0xFF00E676),
      bgDark: Color(0xFF030A06),
      bgLight: Color(0xFFE5EFE7),
      panelDark: Color(0xFF08150D),
      panelLight: Color(0xFFF5FAF6),
    ),
    LauncherPalette(
      id: 'violet',
      name: 'Void Violet',
      accent: Color(0xFFB388FF),
      bgDark: Color(0xFF09060E),
      bgLight: Color(0xFFEAE5F0),
      panelDark: Color(0xFF130E1C),
      panelLight: Color(0xFFF9F7FB),
    ),
    LauncherPalette(
      id: 'cobalt',
      name: 'Cobalt Blue',
      accent: Color(0xFF2979FF),
      bgDark: Color(0xFF04070F),
      bgLight: Color(0xFFE5E9F2),
      panelDark: Color(0xFF0A0F1E),
      panelLight: Color(0xFFF6F8FC),
    ),
    LauncherPalette(
      id: 'orange',
      name: 'Neon Hazard',
      accent: Color(0xFFFF6D00),
      bgDark: Color(0xFF0C0803),
      bgLight: Color(0xFFEFE7DC),
      panelDark: Color(0xFF181007),
      panelLight: Color(0xFFFDF9F5),
    ),
    LauncherPalette(
      id: 'stealth',
      name: 'Stealth Slate',
      accent: Color(0xFFECEFF1),
      bgDark: Color(0xFF08090B),
      bgLight: Color(0xFFE8E9EA),
      panelDark: Color(0xFF121417),
      panelLight: Color(0xFFF7F8F9),
    ),
  ];

  static LauncherPalette get currentPalette {
    final id = LauncherService.instance.paletteId.value;
    return palettes.firstWhere((p) => p.id == id, orElse: () => palettes.first);
  }

  // ── Accent Colors ──────────────────────────────────────────
  static Color get accent {
    final custom = LauncherService.instance.customAccent.value;
    final base = custom ?? currentPalette.accent;
    return isLight ? JweTheme.calibrate(base) : base;
  }

  static Color get red => accent;

  static Color get redSoft => accent.withValues(alpha: 0.55);

  static Color get redDim => accent.withValues(alpha: 0.18);

  static Color get redGlow => accent.withValues(alpha: 0.35);

  // ── Surface & Canvas Colors ────────────────────────────────
  static Color get bg {
    final p = currentPalette;
    if (isLight) {
      return p.bgLight ?? const Color(0xFFEDE8E0);
    } else {
      return p.bgDark ?? const Color(0xFF050608);
    }
  }

  static Color get panel {
    final p = currentPalette;
    if (isLight) {
      return p.panelLight ?? const Color(0xFFFAF8F5);
    } else {
      return p.panelDark ?? const Color(0xFF0E1015);
    }
  }

  static Color get panel2 =>
      isLight ? const Color(0xFFF3EFE7) : const Color(0xFF13161C);

  static Color get line =>
      isLight ? const Color(0xFFD4CDC0) : const Color(0xFF1E222B);

  static Color get text =>
      isLight ? const Color(0xFF211D18) : const Color(0xFFE9ECF2);

  static Color get muted =>
      isLight ? const Color(0xFF7A7266) : const Color(0xFF8A909C);

  static Color get dockButtonBg =>
      isLight ? const Color(0xFFF0EBE1) : const Color(0xD914161C);

  static Color get dockBorder =>
      isLight ? const Color(0xFFDCD4C6) : const Color(0xFF232730);

  static Color get cardAddedBadge => accent;

  // ── Typography (Rajdhani) ──────────────────────────────────
  static TextStyle rajdhani({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    double letterSpacing = 0.5,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.rajdhani(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color ?? text,
      height: height,
    );
  }
}
