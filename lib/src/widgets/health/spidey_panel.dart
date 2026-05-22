import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/spidey_theme.dart';

/// Spider-Man styled panel: red strip + gradient header, cut-corner card.
class SpideyPanel extends StatelessWidget {
  final String? title;
  final Widget child;
  final Color accentColor;

  const SpideyPanel({
    super.key,
    this.title,
    required this.child,
    this.accentColor = SpideyTheme.spideyRed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: SpideyTheme.bgPanel,
        border: Border.all(color: SpideyTheme.border),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipPath(
        clipper: _CutCornerClipper(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Container(
                height: 38,
                decoration: const BoxDecoration(
                  gradient: SpideyTheme.panelGradient,
                  border: Border(
                    bottom: BorderSide(color: SpideyTheme.border),
                  ),
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: double.infinity, color: SpideyTheme.spideyRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title!.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          color: SpideyTheme.textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accentColor,
                        boxShadow: [
                          BoxShadow(color: accentColor.withOpacity(0.7), blurRadius: 6),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Padding(padding: const EdgeInsets.all(14), child: child),
          ],
        ),
      ),
    );
  }
}

class _CutCornerClipper extends CustomClipper<Path> {
  static const double _cut = 12.0;
  @override
  Path getClip(Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - _cut)
      ..lineTo(size.width - _cut, size.height)
      ..lineTo(0, size.height)
      ..close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
