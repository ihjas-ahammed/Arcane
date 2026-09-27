import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_swipe_detector.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';

class LauncherSpaceView extends StatelessWidget {
  final VoidCallback onBack;
  final Function(LauncherSpaceCategory category) onSelectSpace;
  final VoidCallback onAddSpace;
  final VoidCallback onHome;

  const LauncherSpaceView({
    super.key,
    required this.onBack,
    required this.onSelectSpace,
    required this.onAddSpace,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = LauncherTheme.isLight;
    final spaces = LauncherSpaceItem.defaultSpaces;

    return LauncherSwipeDetector(
      behavior: HitTestBehavior.opaque,
      onSwipeRight: onBack,
      onSwipeDown: onBack,
      child: Column(
      children: [
        // ── Header ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 22, 18),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: Icon(MdiIcons.arrowLeft, color: LauncherTheme.text, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: isLight ? const Color(0x12000000) : const Color(0x1FFFFFFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APP SPACE',
                    style: LauncherTheme.rajdhani(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                      color: LauncherTheme.text,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'ORGANISE YOUR SPACE',
                    style: LauncherTheme.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.8,
                      color: LauncherTheme.muted,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(MdiIcons.dotsVertical, color: LauncherTheme.muted, size: 22),
            ],
          ),
        ),

        // ── Spaces List ──────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final space in spaces) ...[
                _buildSpaceCard(space),
                const SizedBox(height: 14),
              ],

              // ADD SPACE Card
              InkWell(
                onTap: onAddSpace,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: LauncherTheme.red,
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                    color: LauncherTheme.redDim.withValues(alpha: 0.05),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(MdiIcons.plus, color: LauncherTheme.red, size: 26),
                      const SizedBox(height: 6),
                      Text(
                        'ADD SPACE',
                        style: LauncherTheme.rajdhani(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: LauncherTheme.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),

        // ── Home Indicator ───────────────────────────────────────
        GestureDetector(
          onTap: onHome,
          child: Container(
            width: 120,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: LauncherTheme.text.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildSpaceCard(LauncherSpaceItem space) {
    final isLight = LauncherTheme.isLight;
    final isOn = space.isDefault;

    return InkWell(
      onTap: () => onSelectSpace(space.category),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isOn
              ? (isLight ? const Color(0xFFFAF5EE) : const Color(0xFF14070A))
              : LauncherTheme.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOn ? LauncherTheme.red : LauncherTheme.line,
            width: isOn ? 1.5 : 1.0,
          ),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: LauncherTheme.redDim,
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isOn
                    ? LauncherTheme.red.withValues(alpha: 0.12)
                    : LauncherTheme.panel2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOn
                      ? LauncherTheme.red.withValues(alpha: 0.4)
                      : (isLight ? const Color(0xFFD8D2C5) : const Color(0xFF242832)),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  space.icon,
                  size: 26,
                  color: isOn ? LauncherTheme.red : LauncherTheme.text,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    space.title,
                    style: LauncherTheme.rajdhani(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: LauncherTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${space.appCount} APPS',
                    style: LauncherTheme.rajdhani(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                      color: LauncherTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              MdiIcons.chevronRight,
              color: isOn ? LauncherTheme.red : LauncherTheme.muted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
