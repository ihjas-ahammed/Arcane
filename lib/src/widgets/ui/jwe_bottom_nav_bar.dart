import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Operator HUD bottom nav — icon + label, top amber hairline,
/// glowing 28×2 indicator over active tab.
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

  static const _tabs = <_TabSpec>[
    _TabSpec(label: 'MISSIONS', icon: 'target'),
    _TabSpec(label: 'SCHEDULE', icon: 'calendar'),
    _TabSpec(label: 'BIO',      icon: 'pulse'),
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
    }
    return MdiIcons.circle;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF208101C),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: JweTheme.lineSoft, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top hairline gradient accent
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  JweTheme.lineAmber,
                  Colors.transparent,
                ]),
              ),
            ),
            SafeArea(
              top: false,
              child: SizedBox(
                height: 60,
                child: Row(children: List.generate(_tabs.length, (i) {
                  final t = _tabs[i];
                  final on = i == selectedIndex;
                  final color = on ? JweTheme.accentAmber : JweTheme.textMuted;
                  return Expanded(
                    child: InkWell(
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
                              width: 28,
                              height: 2,
                              decoration: BoxDecoration(
                                color: JweTheme.accentAmber,
                                boxShadow: [
                                  BoxShadow(
                                    color: JweTheme.accentAmber.withValues(alpha: 0.55),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_icon(t.icon), size: 20, color: color),
                                const SizedBox(height: 6),
                                Text(
                                  t.label,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9,
                                    height: 1.0,
                                    color: color,
                                    letterSpacing: 1.6,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final String icon;
  const _TabSpec({required this.label, required this.icon});
}
