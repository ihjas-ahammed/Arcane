import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

/// 8-Corner Chamfer Polygon Clipper
class TacticalChamferClipper extends CustomClipper<Path> {
  final double cut;
  const TacticalChamferClipper({this.cut = 8.0});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final c = math.min(cut, math.min(w / 4, h / 4));

    final path = Path()
      ..moveTo(c, 0)
      ..lineTo(w - c, 0)
      ..lineTo(w, c)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(c, h)
      ..lineTo(0, h - c)
      ..lineTo(0, c)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant TacticalChamferClipper oldClipper) => oldClipper.cut != cut;
}

/// Tactical HUD Card with Chamfered Edges, 1px border, and top center notch
class TacticalChamferCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double cut;
  final Color? borderColor;
  final Color? bgStart;
  final Color? bgEnd;
  final bool showNotch;

  const TacticalChamferCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
    this.onLongPress,
    this.cut = 8.0,
    this.borderColor,
    this.bgStart,
    this.bgEnd,
    this.showNotch = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: CustomPaint(
        painter: _ChamferCardPainter(
          cut: cut,
          borderColor: borderColor ?? TacColors.borderOuter,
          bgStart: bgStart ?? TacColors.cardBgStart,
          bgEnd: bgEnd ?? TacColors.cardBgEnd,
          showNotch: showNotch,
        ),
        child: ClipPath(
          clipper: TacticalChamferClipper(cut: cut),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              splashColor: TacColors.primaryRed.withValues(alpha: 0.15),
              highlightColor: TacColors.primaryRed.withValues(alpha: 0.08),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChamferCardPainter extends CustomPainter {
  final double cut;
  final Color borderColor;
  final Color bgStart;
  final Color bgEnd;
  final bool showNotch;

  _ChamferCardPainter({
    required this.cut,
    required this.borderColor,
    required this.bgStart,
    required this.bgEnd,
    required this.showNotch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = math.min(cut, math.min(w / 4, h / 4));

    final path = Path()
      ..moveTo(c, 0)
      ..lineTo(w - c, 0)
      ..lineTo(w, c)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(c, h)
      ..lineTo(0, h - c)
      ..lineTo(0, c)
      ..close();

    // Background Gradient Fill
    final paintFill = Paint()
      ..shader = LinearGradient(
        colors: [bgStart, bgEnd],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paintFill);

    // Border
    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, paintBorder);

    // Top center notch
    if (showNotch && w > 80) {
      final notchPaint = Paint()
        ..color = TacColors.notchColor
        ..strokeWidth = 1.5;
      final centerX = w / 2;
      canvas.drawLine(Offset(centerX - 20, 0), Offset(centerX + 20, 0), notchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChamferCardPainter oldDelegate) => true;
}

/// Tactical Hero Card with Radial Glow and Red L-Brackets at Top-Left & Bottom-Right
class TacticalHeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  const TacticalHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? TacColors.primaryRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: TacColors.cardBgEnd,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TacColors.borderOuter, width: 1),
        gradient: RadialGradient(
          center: const Alignment(0.7, 0.0),
          radius: 1.2,
          colors: [
            effectiveAccent.withValues(alpha: JweTheme.isLight ? 0.10 : 0.14),
            TacColors.heroBgEnd,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Top-Left Red L-Bracket
          Positioned(
            top: -1,
            left: -1,
            child: CustomPaint(
              size: const Size(12, 12),
              painter: _CornerBracketPainter(color: effectiveAccent, isTopLeft: true),
            ),
          ),
          // Bottom-Right Red L-Bracket
          Positioned(
            bottom: -1,
            right: -1,
            child: CustomPaint(
              size: const Size(12, 12),
              painter: _CornerBracketPainter(color: effectiveAccent, isTopLeft: false),
            ),
          ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final bool isTopLeft;
  _CornerBracketPainter({required this.color, required this.isTopLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTopLeft) {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) => true;
}

/// Tactical Icon Container with 4 Corner Red L-Brackets (Matching HTML tech-icon-container)
class TacticalIconBox extends StatelessWidget {
  final Widget icon;
  final double size;
  final Color? accent;

  const TacticalIconBox({
    super.key,
    required this.icon,
    this.size = 58,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? TacColors.primaryRed;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TacColors.iconBorder, width: 1),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [TacColors.iconBgStart, TacColors.iconBgEnd],
        ),
      ),
      child: Stack(
        children: [
          // 4 Corner L-Brackets
          Positioned(top: -1, left: -1, child: _buildBracket(true, true, effectiveAccent)),
          Positioned(top: -1, right: -1, child: _buildBracket(true, false, effectiveAccent)),
          Positioned(bottom: -1, left: -1, child: _buildBracket(false, true, effectiveAccent)),
          Positioned(bottom: -1, right: -1, child: _buildBracket(false, false, effectiveAccent)),
          Center(child: icon),
        ],
      ),
    );
  }

  Widget _buildBracket(bool isTop, bool isLeft, Color color) {
    return CustomPaint(
      size: const Size(5, 5),
      painter: _FourCornerPainter(color: color, isTop: isTop, isLeft: isLeft),
    );
  }
}

class _FourCornerPainter extends CustomPainter {
  final Color color;
  final bool isTop;
  final bool isLeft;

  _FourCornerPainter({required this.color, required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FourCornerPainter old) => true;
}

/// Tactical Segmented / Glowing Progress Bar (Matching HTML hud-bar-track & hud-bar-fill)
class TacticalProgressBar extends StatelessWidget {
  final double progress;
  final double width;
  final double height;
  final Color? accent;

  const TacticalProgressBar({
    super.key,
    required this.progress,
    this.width = double.infinity,
    this.height = 4.0,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final effectiveAccent = accent ?? TacColors.primaryRed;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: TacColors.trackBg,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: TacColors.trackBorder, width: 1),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: clamped,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [
                JweTheme.isLight ? const Color(0xFFA51325) : const Color(0xFFE62035),
                effectiveAccent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: effectiveAccent.withValues(alpha: JweTheme.isLight ? 0.35 : 0.55),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Valorant SVG Crest (Red & White triangles)
class ValorantLogoBadge extends StatelessWidget {
  final double width;
  final double height;
  final Color? primaryColor;

  const ValorantLogoBadge({
    super.key,
    this.width = 22,
    this.height = 18,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _ValorantLogoPainter(primaryColor: primaryColor ?? TacColors.primaryRed),
    );
  }
}

class _ValorantLogoPainter extends CustomPainter {
  final Color primaryColor;
  _ValorantLogoPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 100.0;
    final scaleY = size.height / 80.0;

    // Left red polygon: M40 0 L0 80 L20 80 L50 20 Z
    final leftPath = Path()
      ..moveTo(40 * scaleX, 0)
      ..lineTo(0, 80 * scaleY)
      ..lineTo(20 * scaleX, 80 * scaleY)
      ..lineTo(50 * scaleX, 20 * scaleY)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = primaryColor..style = PaintingStyle.fill);

    // Right white / dark polygon: M60 0 L100 80 L80 80 L50 20 Z
    final rightPath = Path()
      ..moveTo(60 * scaleX, 0)
      ..lineTo(100 * scaleX, 80 * scaleY)
      ..lineTo(80 * scaleX, 80 * scaleY)
      ..lineTo(50 * scaleX, 20 * scaleY)
      ..close();
    canvas.drawPath(
      rightPath,
      Paint()
        ..color = JweTheme.isLight ? const Color(0xFF1E242F) : Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ValorantLogoPainter old) => true;
}

/// Valorant Tiered Chevron Insignia (3 layered chevrons)
class ValorantChevronInsignia extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;

  const ValorantChevronInsignia({
    super.key,
    this.width = 19,
    this.height = 23,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _ChevronInsigniaPainter(color: color ?? TacColors.primaryRed),
    );
  }
}

class _ChevronInsigniaPainter extends CustomPainter {
  final Color color;
  _ChevronInsigniaPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24.0;
    final sy = size.height / 28.0;

    // Top chevron (0.35 opacity): M12 2 L22 10 L12 18 L2 10 Z
    final p1 = Path()
      ..moveTo(12 * sx, 2 * sy)
      ..lineTo(22 * sx, 10 * sy)
      ..lineTo(12 * sx, 18 * sy)
      ..lineTo(2 * sx, 10 * sy)
      ..close();
    canvas.drawPath(p1, Paint()..color = color.withValues(alpha: 0.35)..style = PaintingStyle.fill);

    // Mid chevron (0.75 opacity): M12 7 L20 13 L12 19 L4 13 Z
    final p2 = Path()
      ..moveTo(12 * sx, 7 * sy)
      ..lineTo(20 * sx, 13 * sy)
      ..lineTo(12 * sx, 19 * sy)
      ..lineTo(4 * sx, 13 * sy)
      ..close();
    canvas.drawPath(p2, Paint()..color = color.withValues(alpha: 0.75)..style = PaintingStyle.fill);

    // Bottom chevron (1.0 opacity): M12 12 L18 16 L12 20 L6 16 Z
    final p3 = Path()
      ..moveTo(12 * sx, 12 * sy)
      ..lineTo(18 * sx, 16 * sy)
      ..lineTo(12 * sx, 20 * sy)
      ..lineTo(6 * sx, 16 * sy)
      ..close();
    canvas.drawPath(p3, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _ChevronInsigniaPainter old) => true;
}

/// Custom Silhouette Painters from the HTML
class ChessKnightSilhouette extends StatelessWidget {
  final double size;
  final Color? color;
  const ChessKnightSilhouette({super.key, this.size = 30, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SvgPathPainter(
        pathString: 'M19 22H5v-2h14v2M17.5 10.5c.3 0 .5-.2.5-.5a3.5 3.5 0 0 0-4.6-3.3c-.6-.7-1.4-1.2-2.4-1.2h-.5c-.3-1.4-1.2-2.7-2.6-3.2-.3-.1-.6.1-.6.4v.3c0 .8-.5 1.5-1.2 1.8-.7.3-1.1 1-1.1 1.7v1c0 1.1.9 2 2 2h.5l-1.5 2.5c-.3.5-.5 1.1-.5 1.7v3.3c0 .8.7 1.5 1.5 1.5h7c.8 0 1.5-.7 1.5-1.5v-2c0-.8-.7-1.5-1.5-1.5h-.5l1.5-2.5c.3-.5.9-.8 1.5-.8h.4z',
        color: color ?? TacColors.primaryRed,
        viewBoxSize: 24,
      ),
    );
  }
}

class DigitSpanOdometerIcon extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;
  const DigitSpanOdometerIcon({super.key, this.width = 34, this.height = 28, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? TacColors.primaryRed;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: TacColors.iconBgEnd,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: TacColors.iconBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: Center(child: Text('7', style: GoogleFonts.chakraPetch(color: effectiveColor, fontSize: 13, fontWeight: FontWeight.bold)))),
          Container(width: 1, height: height, color: TacColors.borderOuter),
          Expanded(child: Center(child: Text('2', style: GoogleFonts.chakraPetch(color: effectiveColor, fontSize: 13, fontWeight: FontWeight.bold)))),
          Container(width: 1, height: height, color: TacColors.borderOuter),
          Expanded(child: Center(child: Text('9', style: GoogleFonts.chakraPetch(color: effectiveColor, fontSize: 13, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }
}

class PushUpSilhouetteIcon extends StatelessWidget {
  final double size;
  final Color? color;
  const PushUpSilhouetteIcon({super.key, this.size = 32, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PushUpPainter(color: color ?? TacColors.primaryRed),
    );
  }
}

class _PushUpPainter extends CustomPainter {
  final Color color;
  _PushUpPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 32.0;
    final sy = size.height / 32.0;

    final paintHead = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(27 * sx, 11 * sy), 2.5 * sx, paintHead);

    final pathBody = Path()
      ..moveTo(25 * sx, 14.5 * sy)
      ..lineTo(16.5 * sx, 19 * sy)
      ..lineTo(7.5 * sx, 17.5 * sy)
      ..lineTo(3 * sx, 21.5 * sy)
      ..lineTo(4.5 * sx, 23 * sy)
      ..lineTo(8 * sx, 20 * sy)
      ..lineTo(16 * sx, 21.5 * sy)
      ..lineTo(24.5 * sx, 16.5 * sy)
      ..lineTo(26 * sx, 21 * sy)
      ..lineTo(28 * sx, 20.5 * sy)
      ..lineTo(26 * sx, 14.5 * sy)
      ..close();
    canvas.drawPath(pathBody, paintHead);

    final paintFloor = Paint()
      ..color = TacColors.borderOuter
      ..strokeWidth = 1.5 * sy;
    canvas.drawLine(Offset(2 * sx, 26 * sy), Offset(30 * sx, 26 * sy), paintFloor);
  }

  @override
  bool shouldRepaint(covariant _PushUpPainter old) => true;
}

class PullUpRigSilhouetteIcon extends StatelessWidget {
  final double size;
  final Color? color;
  const PullUpRigSilhouetteIcon({super.key, this.size = 32, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PullUpPainter(color: color ?? TacColors.primaryRed),
    );
  }
}

class _PullUpPainter extends CustomPainter {
  final Color color;
  _PullUpPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 32.0;
    final sy = size.height / 32.0;

    // Top Bar: (4,8) to (28,8)
    final barPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0 * sy
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(4 * sx, 8 * sy), Offset(28 * sx, 8 * sy), barPaint);

    // Left and Right Rig Legs
    final legPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5 * sx;
    canvas.drawLine(Offset(6 * sx, 8 * sy), Offset(6 * sx, 28 * sy), legPaint);
    canvas.drawLine(Offset(26 * sx, 8 * sy), Offset(26 * sx, 28 * sy), legPaint);

    // Head circle at (16, 14)
    canvas.drawCircle(Offset(16 * sx, 14 * sy), 2.2 * sx, Paint()..color = color..style = PaintingStyle.fill);

    // Body strokes
    final bodyPaint = Paint()
      ..color = color
      ..strokeWidth = 1.8 * sx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final bodyPath = Path()
      ..moveTo(11 * sx, 9.5 * sy)
      ..lineTo(14 * sx, 14 * sy)
      ..lineTo(14 * sx, 20 * sy)
      ..lineTo(13 * sx, 25 * sy)
      ..lineTo(15 * sx, 25 * sy)
      ..lineTo(16 * sx, 20.5 * sy)
      ..lineTo(17 * sx, 25 * sy)
      ..lineTo(19 * sx, 25 * sy)
      ..lineTo(18 * sx, 20 * sy)
      ..lineTo(18 * sx, 14 * sy)
      ..lineTo(21 * sx, 9.5 * sy);
    canvas.drawPath(bodyPath, bodyPaint);
  }

  @override
  bool shouldRepaint(covariant _PullUpPainter old) => true;
}

class _SvgPathPainter extends CustomPainter {
  final String pathString;
  final Color color;
  final double viewBoxSize;

  _SvgPathPainter({required this.pathString, required this.color, required this.viewBoxSize});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / viewBoxSize;
    final sy = size.height / viewBoxSize;

    final path = Path()
      ..moveTo(19 * sx, 22 * sy)
      ..lineTo(5 * sx, 22 * sy)
      ..lineTo(5 * sx, 20 * sy)
      ..lineTo(19 * sx, 20 * sy)
      ..close()
      ..moveTo(17.5 * sx, 10.5 * sy)
      ..cubicTo(17.8 * sx, 10.5 * sy, 18 * sx, 10.3 * sy, 18 * sx, 10 * sy)
      ..cubicTo(18 * sx, 8 * sy, 15.5 * sx, 6.7 * sy, 13.4 * sx, 6.7 * sy)
      ..cubicTo(12.8 * sx, 6 * sy, 12 * sx, 5.5 * sy, 11 * sx, 5.5 * sy)
      ..lineTo(10.5 * sx, 5.5 * sy)
      ..cubicTo(10.2 * sx, 4.1 * sy, 9.3 * sx, 2.8 * sy, 7.9 * sx, 2.3 * sy)
      ..lineTo(7.5 * sx, 2.5 * sy)
      ..cubicTo(7.5 * sx, 3.3 * sy, 7 * sx, 4 * sy, 6.3 * sx, 4.3 * sy)
      ..lineTo(5.5 * sx, 6 * sy)
      ..lineTo(7.5 * sx, 8 * sy)
      ..lineTo(6 * sx, 10.5 * sy)
      ..lineTo(5.5 * sx, 12.2 * sy)
      ..lineTo(5.5 * sx, 15.5 * sy)
      ..cubicTo(5.5 * sx, 16.3 * sy, 6.2 * sx, 17 * sy, 7 * sx, 17 * sy)
      ..lineTo(14 * sx, 17 * sy)
      ..cubicTo(14.8 * sx, 17 * sy, 15.5 * sx, 16.3 * sy, 15.5 * sx, 15.5 * sy)
      ..lineTo(15.5 * sx, 13.5 * sy)
      ..cubicTo(15.5 * sx, 12.7 * sy, 14.8 * sx, 12 * sy, 14 * sx, 12 * sy)
      ..lineTo(15.5 * sx, 9.5 * sy)
      ..close();

    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _SvgPathPainter old) => true;
}
