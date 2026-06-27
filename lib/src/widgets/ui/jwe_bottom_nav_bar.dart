import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Operator HUD bottom nav — icon + label, top amber hairline,
/// glassy backdrop filter, Nora circle in the center.
class JweBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final Color activeColor;
  final VoidCallback onNoraTapped;

  const JweBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.activeColor,
    required this.onNoraTapped,
  });

  static const _tabs = <_TabSpec>[
    _TabSpec(label: 'MISSIONS', icon: 'target'),
    _TabSpec(label: 'BIO',      icon: 'pulse'),
    _TabSpec(label: 'SCHEDULE', icon: 'calendar'),
    _TabSpec(label: 'PROJECTS', icon: 'projects'),
    _TabSpec(label: 'INTEL',    icon: 'note'),
    _TabSpec(label: 'WALLET',   icon: 'wallet'),
  ];

  IconData _icon(String key) {
    switch (key) {
      case 'target': return MdiIcons.targetAccount;
      case 'calendar': return MdiIcons.calendarClock;
      case 'pulse': return MdiIcons.heartPulse;
      case 'note': return MdiIcons.notebookOutline;
      case 'wallet': return MdiIcons.walletOutline;
      case 'projects': return MdiIcons.rocketLaunchOutline;
    }
    return MdiIcons.circle;
  }

  Widget _buildTab(int i) {
    final t = _tabs[i];
    final on = i == selectedIndex;
    final color = on ? JweTheme.accentAmber : JweTheme.textMuted;
    return InkWell(
      onTap: () => onItemTapped(i),
      splashColor: JweTheme.amberSoft,
      highlightColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Active indicator slab
          if (on)
            Container(
              width: 22,
              height: 2,
              decoration: BoxDecoration(
                color: JweTheme.accentAmber,
                boxShadow: [
                  BoxShadow(
                    color: JweTheme.accentAmber.withValues(alpha: 0.55),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icon(t.icon), size: 16, color: color),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    t.label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8,
                      height: 1.0,
                      color: color,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoraCircle(BuildContext context) {
    return GestureDetector(
      onTap: onNoraTapped,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.fhAccentPurple.withValues(alpha: 0.08), // Subtle purple base
                border: Border.all(
                  color: AppTheme.fhAccentPurple.withValues(alpha: 0.35), // Subtle purple border
                  width: 1.2,
                ),
              ),
              child: const Center(
                child: Icon(
                  MdiIcons.creation, // Sparkles icon
                  color: Colors.white, // Clean white
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: 64 + MediaQuery.of(context).padding.bottom, // Regular 64 height
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. The rectangular glassy bar (starts at Y=0, no top margin needed!)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0x8008101C), // Glassy 50% opacity
                    border: Border(top: BorderSide(color: JweTheme.lineSoft, width: 1)),
                  ),
                ),
              ),
            ),
          ),

          // 2. Top hairline gradient accent (horizontal straight line)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  JweTheme.lineAmber.withValues(alpha: 0.5),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // 3. The tabs row
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(child: _buildTab(0)), // MISSIONS
                    Expanded(child: _buildTab(1)), // BIO
                    Expanded(child: _buildTab(2)), // SCHEDULE
                    
                    const SizedBox(width: 52), // Gap for Nora circle
                    
                    Expanded(child: _buildTab(3)), // TOOLS
                    Expanded(child: _buildTab(4)), // INTEL
                    Expanded(child: _buildTab(5)), // WALLET
                  ],
                ),
              ),
            ),
          ),

          // 4. The inner Nora button (starts at Y=10, centered vertically inside the 64-height bar!)
          Positioned(
            top: 10,
            left: (screenWidth - 44) / 2,
            width: 44,
            height: 44,
            child: _buildNoraCircle(context),
          ),
        ],
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final String icon;
  const _TabSpec({required this.label, required this.icon});
}
