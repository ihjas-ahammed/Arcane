import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'hud_types.dart';

class HudCutClipper extends CustomClipper<Path> {
  final HudClip clip;
  final double cut;
  HudCutClipper({this.clip = HudClip.br, this.cut = 12});

  @override
  Path getClip(Size s) {
    final p = Path();
    final c = math.min(cut, math.min(s.width, s.height) / 2);
    switch (clip) {
      case HudClip.none:
        p.addRect(Rect.fromLTWH(0, 0, s.width, s.height));
        break;
      case HudClip.br:
        p
          ..moveTo(0, 0)
          ..lineTo(s.width, 0)
          ..lineTo(s.width, s.height - c)
          ..lineTo(s.width - c, s.height)
          ..lineTo(0, s.height)
          ..close();
        break;
      case HudClip.tr:
        p
          ..moveTo(0, 0)
          ..lineTo(s.width - c, 0)
          ..lineTo(s.width, c)
          ..lineTo(s.width, s.height)
          ..lineTo(0, s.height)
          ..close();
        break;
      case HudClip.both:
        p
          ..moveTo(0, 0)
          ..lineTo(s.width - c, 0)
          ..lineTo(s.width, c)
          ..lineTo(s.width, s.height - c)
          ..lineTo(s.width - c, s.height)
          ..lineTo(c, s.height)
          ..lineTo(0, s.height - c)
          ..close();
        break;
    }
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => true;
}
