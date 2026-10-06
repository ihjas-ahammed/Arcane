import 'package:flutter/material.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';

class PersonInfoHeader extends StatelessWidget {
  final int level;
  final String role;
  final String titleName;

  const PersonInfoHeader({
    super.key,
    required this.level,
    required this.role,
    required this.titleName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- Header Section ---
        Container(
          height: 70,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: ArcStrokes.steel),
            ),
          ),
          child: Row(
            children: [
              // Red Strip
              Container(
                width: 15,
                height: double.infinity,
                color: PersonInfoTheme.spideyRed,
              ),
              // Stats Area
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration:   BoxDecoration(
                    gradient: LinearGradient(
                      colors: [PersonInfoTheme.headerGradientStart, PersonInfoTheme.bgPanel],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Level Box
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "LVL",
                            style: GoogleFonts.rajdhani(
                              color: PersonInfoTheme.spideyCyan,
                              fontSize: 10,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "$level",
                            style: GoogleFonts.rajdhani(
                              color: PersonInfoTheme.spideyCyan,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                              shadows: [
                                Shadow(
                                  color: ArcEffects.cyanGlow(0.4),
                                  blurRadius: 5.0,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            role.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.rajdhani(
                              color: PersonInfoTheme.textWhite,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // --- Name Band ---
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 20, bottom: 10),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration:   BoxDecoration(
            color: ArcEffects.cyanGlow(0.05), // rgba(0, 240, 255, 0.05)
            border: Border(
              top: BorderSide(color: PersonInfoTheme.spideyCyanDim),
              bottom: BorderSide(color: PersonInfoTheme.spideyCyanDim),
            ),
          ),
          child: Text(
            titleName.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
              color: PersonInfoTheme.spideyCyan,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              shadows: [
                Shadow(
                  color: ArcEffects.cyanGlow(0.4),
                  blurRadius: 10.0,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}