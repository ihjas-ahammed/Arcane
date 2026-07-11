import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/theme/arc/arc_surfaces.dart';

/// Effect tokens — shadows, glows, sheens, gradients.
class ArcEffects {
  static bool get _l => JweTheme.isLight;

  /// Drop shadow color. Shadows stay black-based in both modes but are
  /// softened on light surfaces where heavy shadows read as dirt.
  static Color shadow(double alpha) =>
      Colors.black.withValues(alpha: _l ? alpha * 0.45 : alpha);

  /// Specular sheen over accent-colored fills (stays white-based: accents
  /// are dark in light mode, bright in dark mode — white reads in both).
  static Color sheen(double alpha) => Colors.white.withValues(alpha: alpha);

  /// Cyan glow of the dossier aesthetic (was 0x??00F0FF alphas).
  static Color cyanGlow(double alpha) =>
      (_l ? const Color(0xFF0E7490) : const Color(0xFF00F0FF))
          .withValues(alpha: _l ? alpha * 0.6 : alpha);

  /// Header gradient for dossier panels.
  static LinearGradient get dossierHeaderGradient => LinearGradient(
        colors: [
          _l ? const Color(0xFFE9E4DB) : const Color(0xFF162433),
          ArcSurfaces.panel,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  /// Full-screen radial backdrop (person detail).
  static RadialGradient get dossierBackdrop => RadialGradient(
        center: Alignment.center,
        colors: [
          _l ? const Color(0xFFF5F2EC) : const Color(0xFF132030),
          _l ? const Color(0xFFECE8E1) : const Color(0xFF000000),
        ],
        radius: 1.0,
      );
}
