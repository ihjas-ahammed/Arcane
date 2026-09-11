import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

// --- Tactical Color Constants (Dynamic Light & Dark Theme Support) ---
class TacColors {
  static Color get bgDark => JweTheme.isLight ? const Color(0xFFEDE8E0) : const Color(0xFF05070A);
  static Color get panelBase => JweTheme.isLight ? const Color(0xFFFAF8F5) : const Color(0xFF0A0E16);
  static Color get cardBgStart => JweTheme.isLight ? const Color(0xFFFCFBF9) : const Color(0xFF0E1420);
  static Color get cardBgEnd => JweTheme.isLight ? const Color(0xFFF3EFE7) : const Color(0xFF0A0E17);
  static Color get cardSurface => JweTheme.isLight ? const Color(0xFFFFFFFF) : const Color(0xFF101724);
  static Color get borderOuter => JweTheme.isLight ? const Color(0xFFD4CDC0) : const Color(0xFF1D293D);
  static Color get borderInner => JweTheme.isLight ? const Color(0xFFC7BFAF) : const Color(0xFF24344A);
  static Color get borderHighlight => JweTheme.isLight ? const Color(0xFFB5AC9B) : const Color(0xFF334661);
  static Color get primaryRed => JweTheme.isLight ? const Color(0xFFC91D32) : const Color(0xFFFF4655);
  static Color get primaryRedGlow => JweTheme.isLight ? const Color(0x33C91D32) : const Color(0x73FF4655);
  static Color get redDark => JweTheme.isLight ? const Color(0xFF991B1B) : const Color(0xFF8C1A24);
  static Color get accentTeal => JweTheme.isLight ? const Color(0xFF047857) : const Color(0xFF00E5BE);
  static Color get accentTealDark => JweTheme.isLight ? const Color(0xFF065F46) : const Color(0xFF0A7362);
  static Color get accentDraw => JweTheme.isLight ? const Color(0xFF94A3B8) : const Color(0xFF384656);
  static Color get textMain => JweTheme.isLight ? const Color(0xFF1E242F) : const Color(0xFFFFFFFF);
  static Color get textMuted => JweTheme.isLight ? const Color(0xFF64748B) : const Color(0xFF728297);
  static Color get textDim => JweTheme.isLight ? const Color(0xFF94A3B8) : const Color(0xFF435164);
  static Color get gridLine => JweTheme.isLight ? const Color(0xFFE2DCD2) : const Color(0xFF172230);
  static Color get notchColor => JweTheme.isLight ? const Color(0xFFB8B0A2) : const Color(0xFF2B3B52);
  static Color get heroBgEnd => JweTheme.isLight ? const Color(0xFFF0EBE3) : const Color(0xFF0D131E);
  static Color get iconBgStart => JweTheme.isLight ? const Color(0xFFF5F0E8) : const Color(0xFF121927);
  static Color get iconBgEnd => JweTheme.isLight ? const Color(0xFFE8E2D8) : const Color(0xFF070A10);
  static Color get iconBorder => JweTheme.isLight ? const Color(0xFFD0C8BB) : const Color(0xFF1E2C3F);
  static Color get trackBg => JweTheme.isLight ? const Color(0xFFDFD8CC) : const Color(0xFF141B27);
  static Color get trackBorder => JweTheme.isLight ? const Color(0xFFCBC3B4) : const Color(0xFF1E2838);
  static Color get statTileBg => JweTheme.isLight ? const Color(0xFFF9F7F4) : const Color(0xFF0B1019);
  static Color get statTileBorder => JweTheme.isLight ? const Color(0xFFDDD6CA) : const Color(0xFF1B2637);
  static Color get tableHeaderBorder => JweTheme.isLight ? const Color(0xFFDDD6CA) : const Color(0xFF16202D);
  static Color get tableRowBorder => JweTheme.isLight ? const Color(0xFFECE7DF) : const Color(0xFF0F1520);
}
