import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_swipe_detector.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';

class LauncherDrawerView extends StatelessWidget {
  final List<LauncherAppItem> apps;
  final Function(LauncherAppItem app) onLaunchApp;
  final VoidCallback onClose;
  final VoidCallback onHome;

  const LauncherDrawerView({
    super.key,
    required this.apps,
    required this.onLaunchApp,
    required this.onClose,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = LauncherTheme.isLight;

    return LauncherSwipeDetector(
      behavior: HitTestBehavior.opaque,
      onSwipeDown: onClose,
      child: Column(
        children: [
          // ── Drawer Handle Bar ────────────────────────────────────
          InkWell(
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: LauncherTheme.text.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    MdiIcons.chevronDown,
                    color: LauncherTheme.text.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Drawer Head: ALL APPS & Total Count ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 6, 26, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'ALL APPS',
                  style: LauncherTheme.rajdhani(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                    color: LauncherTheme.text,
                  ),
                ),
                Text(
                  '${apps.length} APPS',
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

          // ── 4-Column Apps Grid ──────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: apps.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.88,
                ),
                itemBuilder: (context, index) {
                  final app = apps[index];
                  return _buildDrawerAppItem(app);
                },
              ),
            ),
          ),

          // ── Dots Indicator ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: LauncherTheme.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: LauncherTheme.red,
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isLight ? const Color(0xFFC8BFB2) : const Color(0xFF353944),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isLight ? const Color(0xFFC8BFB2) : const Color(0xFF353944),
                    shape: BoxShape.circle,
                  ),
                ),
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

  Widget _buildDrawerAppItem(LauncherAppItem app) {
    if (app.isHot) {
      return InkWell(
        onTap: () => onLaunchApp(app),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF3B4E), Color(0xFFC4101F)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFF6B78), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x80FF2B3F),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(app.icon, size: 28, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              app.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: LauncherTheme.rajdhani(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: LauncherTheme.text,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => onLaunchApp(app),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: LauncherTheme.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LauncherTheme.line),
              ),
              child: Center(
                child: Icon(
                  app.icon,
                  size: 24,
                  color: LauncherTheme.text.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            app.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: LauncherTheme.rajdhani(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: LauncherTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}
