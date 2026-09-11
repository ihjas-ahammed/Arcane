import 'package:flutter/material.dart';

/// 4-corner chamfer clipper matching HTML tactical mission protocol cards
class Chamfer4CornerClipper extends CustomClipper<Path> {
  final double chamfer;
  const Chamfer4CornerClipper({this.chamfer = 10.0});

  @override
  Path getClip(Size size) {
    final c = chamfer;
    final w = size.width;
    final h = size.height;
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
  bool shouldReclip(covariant Chamfer4CornerClipper oldClipper) =>
      oldClipper.chamfer != chamfer;
}
