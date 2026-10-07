import 'package:flutter/material.dart';

/// Width classes used across the app, so every screen adapts at the same points.
///
///  * compact  < 600   phone: bottom nav, single column
///  * medium   600-1000 small window / tablet: side rail, single column
///  * expanded 1000-1400 desktop: side rail, wider content, multi-column grids
///  * large    >= 1400 big monitor: labelled rail, widest content
enum ScreenClass { compact, medium, expanded, large }

class Responsive {
  Responsive._();

  /// From this width the bottom navigation is replaced by the side rail.
  static const double railBreakpoint = 720;

  /// From this width the rail shows its labels beside the icons.
  static const double extendedRailBreakpoint = 1200;

  static bool hasRailWidth(double width) => width >= railBreakpoint;
  static bool hasRail(BuildContext context) => hasRailWidth(MediaQuery.sizeOf(context).width);
  static bool extendedRail(BuildContext context) => MediaQuery.sizeOf(context).width >= extendedRailBreakpoint;

  static ScreenClass classOf(double width) {
    if (width < 600) return ScreenClass.compact;
    if (width < 1000) return ScreenClass.medium;
    if (width < 1400) return ScreenClass.expanded;
    return ScreenClass.large;
  }

  static ScreenClass of(BuildContext context) => classOf(MediaQuery.sizeOf(context).width);

  /// How many columns of at least [minTileWidth] fit in [width] (clamped to [min]..[max]).
  static int columnsFor(double width, {double minTileWidth = 220, int min = 1, int max = 6}) =>
      (width / minTileWidth).floor().clamp(min, max);
}

/// Centers [child] and caps its width, so lists and forms stay readable on wide windows.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({super.key, required this.child, this.maxWidth = 1100, this.alignment = Alignment.topCenter});

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}
