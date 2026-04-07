import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class JweBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final Color activeColor;

  const JweBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: JweTheme.panel,
        border: Border(
          top: BorderSide(color: activeColor.withOpacity(0.5), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, -2),
          )
        ]
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        selectedItemColor: activeColor,
        unselectedItemColor: JweTheme.textMuted,
        selectedLabelStyle: GoogleFonts.rajdhani(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          fontSize: 11,
        ),
        unselectedLabelStyle: GoogleFonts.rajdhani(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontSize: 10,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        currentIndex: selectedIndex,
        onTap: onItemTapped,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Padding(padding: const EdgeInsets.only(bottom: 2), child: Icon(MdiIcons.targetAccount, size: 22)), label: 'MISSIONS'),
          BottomNavigationBarItem(icon: Padding(padding: const EdgeInsets.only(bottom: 2), child: Icon(MdiIcons.calendarClock, size: 22)), label: 'SCHEDULE'),
          BottomNavigationBarItem(icon: Padding(padding: const EdgeInsets.only(bottom: 2), child: Icon(MdiIcons.heartPulse, size: 22)), label: 'BIOMETRICS'),
          BottomNavigationBarItem(icon: Padding(padding: const EdgeInsets.only(bottom: 2), child: Icon(MdiIcons.notebookOutline, size: 22)), label: 'ANALYTICS'),
          BottomNavigationBarItem(icon: Padding(padding: const EdgeInsets.only(bottom: 2), child: Icon(MdiIcons.walletOutline, size: 22)), label: 'WALLET'),
        ],
      ),
    );
  }
}