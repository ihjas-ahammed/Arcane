import 'package:flutter/material.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class PersonInfoHeader extends StatelessWidget {
  final int level;
  final int xp;
  final String role;
  final String titleName;

  const PersonInfoHeader({
    super.key,
    required this.level,
    required this.xp,
    required this.role,
    required this.titleName,
  });

  @override
  Widget build(BuildContext context) {
    // XP Bar Width Calculation (Mock logic: Assuming 3000 max XP for display scaling)
    final double xpProgress = (xp / 3000).clamp(0.0, 1.0);

    return Column(
      children: [
        // --- Header Section ---
        Container(
          height: 70,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF1f2f40)),
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
                  decoration: const BoxDecoration(
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
                                const Shadow(
                                  color: Color(0x6600f0ff),
                                  blurRadius: 5.0,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 15),
                      // XP Bar Container
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 6,
                              width: double.infinity,
                              color: const Color(0xFF1f2f40),
                              margin: const EdgeInsets.only(bottom: 5),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: xpProgress,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: PersonInfoTheme.spideyCyan,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x6600f0ff),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              "${role.toUpperCase()} / $xp XP",
                              style: GoogleFonts.rajdhani(
                                color: PersonInfoTheme.textWhite,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
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
          decoration: const BoxDecoration(
            color: Color(0x0D00f0ff), // rgba(0, 240, 255, 0.05)
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
                const Shadow(
                  color: Color(0x6600f0ff),
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