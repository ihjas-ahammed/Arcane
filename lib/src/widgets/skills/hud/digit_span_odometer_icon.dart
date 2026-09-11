import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tac_colors.dart';

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
