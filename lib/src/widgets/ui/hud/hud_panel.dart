import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'hud_types.dart';
import 'hud_cut_clipper.dart';
import 'hud_brackets.dart';

class HudPanel extends StatelessWidget {
  final Widget child;
  final HudClip clip;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool brackets;
  final bool allBrackets;
  final Color? background;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? width;
  final double? height;

  const HudPanel({
    super.key,
    required this.child,
    this.clip = HudClip.br,
    this.accent,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.brackets = true,
    this.allBrackets = false,
    this.background,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ClipPath(
      clipper: HudCutClipper(clip: clip),
      child: Container(
        width: width ?? double.infinity,
        height: height,
        color: background ?? JweTheme.panel,
        padding: padding,
        child: child,
      ),
    );

    if (brackets) {
      content = Stack(children: [
        content,
        Positioned.fill(child: HudBrackets(color: accent, all: allBrackets)),
      ]);
    }

    final wrapped = Container(margin: margin, child: content);

    if (onTap == null && onLongPress == null) return wrapped;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: wrapped,
    );
  }
}
