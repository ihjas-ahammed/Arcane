import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_swipe_detector.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';

class LauncherGridView extends StatefulWidget {
  final List<LauncherAppItem> apps;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenDrawer;
  final Function(LauncherAppItem app) onLaunchApp;
  final VoidCallback onHome;

  const LauncherGridView({
    super.key,
    required this.apps,
    required this.onOpenSearch,
    required this.onOpenDrawer,
    required this.onLaunchApp,
    required this.onHome,
  });

  @override
  State<LauncherGridView> createState() => _LauncherGridViewState();
}

class _LauncherGridViewState extends State<LauncherGridView> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = LauncherTheme.isLight;
    final timeStr = DateFormat('h:mm').format(_now);
    final amPm = DateFormat('a').format(_now);

    // Limit to 16 apps for the home grid view
    final gridApps = widget.apps.take(16).toList();

    return LauncherSwipeDetector(
      behavior: HitTestBehavior.opaque,
      onSwipeUp: widget.onOpenDrawer,
      onSwipeDown: widget.onHome,
      onSwipeRight: widget.onHome,
      child: Column(
        children: [
          // ── Grid Top: Big Time & Round Search Button ────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 16, 26, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      timeStr,
                      style: LauncherTheme.rajdhani(
                        fontSize: 50,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                        color: LauncherTheme.text,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      amPm,
                      style: LauncherTheme.rajdhani(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: LauncherTheme.text,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: widget.onOpenSearch,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: LauncherTheme.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: LauncherTheme.line),
                    ),
                    child: Center(
                      child: Icon(
                        MdiIcons.magnify,
                        size: 22,
                        color: LauncherTheme.text,
                      ),
                    ),
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
                itemCount: gridApps.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  final app = gridApps[index];
                  return _buildAppTile(app);
                },
              ),
            ),
          ),

          // ── Dots Indicator ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
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

          // ── Swipe Up Prompt ─────────────────────────────────────
          InkWell(
            onTap: widget.onOpenDrawer,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    MdiIcons.chevronDoubleUp,
                    size: 26,
                    color: LauncherTheme.red,
                    shadows: [
                      Shadow(color: LauncherTheme.red, blurRadius: 8),
                    ],
                  ),
                  Text(
                    'SWIPE UP',
                    style: LauncherTheme.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                      color: LauncherTheme.red.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Home Indicator ───────────────────────────────────────
          GestureDetector(
            onTap: widget.onHome,
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

  Widget _buildAppTile(LauncherAppItem app) {
    if (app.isHot) {
      // Hot Glowing Red App Tile (Arcane / Missions)
      return Tooltip(
        message: app.label,
        child: InkWell(
          onTap: () => widget.onLaunchApp(app),
          borderRadius: BorderRadius.circular(14),
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
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                app.icon,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: app.label,
      child: InkWell(
        onTap: () => widget.onLaunchApp(app),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: LauncherTheme.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LauncherTheme.line),
          ),
          child: Center(
            child: Icon(
              app.icon,
              size: 26,
              color: LauncherTheme.text.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}
