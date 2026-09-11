import 'package:flutter/material.dart';

class HexButtonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    
    // Polygon: 10% 0, 90% 0, 100% 50%, 90% 100%, 10% 100%, 0% 50%
    final cutX = w * 0.1;
    final halfY = h * 0.5;

    path.moveTo(cutX, 0);
    path.lineTo(w - cutX, 0);
    path.lineTo(w, halfY);
    path.lineTo(w - cutX, h);
    path.lineTo(cutX, h);
    path.lineTo(0, halfY);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
