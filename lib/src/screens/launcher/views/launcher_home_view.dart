import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/launcher/launcher_swipe_detector.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/launcher_wallpaper_painter.dart';
import 'package:missions/src/screens/settings/widgets_studio/widgets_studio.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:provider/provider.dart';

class LauncherHomeView extends StatefulWidget {
  final VoidCallback onOpenSpace;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenWidget;
  final VoidCallback onOpenDrawer;
  final VoidCallback onSwipeUpToArcane;
  final Function(String action) onAction;

  const LauncherHomeView({
    super.key,
    required this.onOpenSpace,
    required this.onOpenSearch,
    required this.onOpenWidget,
    required this.onOpenDrawer,
    required this.onSwipeUpToArcane,
    required this.onAction,
  });

  @override
  State<LauncherHomeView> createState() => _LauncherHomeViewState();
}

class _LauncherHomeViewState extends State<LauncherHomeView> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = LauncherTheme.isLight;
    final timeStr = DateFormat('h:mm').format(_now);
    final amPm = DateFormat('a').format(_now);
    final dateStr = DateFormat('EEEE, d MMMM').format(_now).toUpperCase();

    return LauncherSwipeDetector(
      behavior: HitTestBehavior.opaque,
      onSwipeUp: widget.onSwipeUpToArcane,
      onSwipeDown: widget.onOpenSearch,
      onSwipeRight: widget.onOpenWidget,
      onSwipeLeft: widget.onOpenSpace,
      child: Column(
        children: [
          // ── Status Bar ──────────────────────────────────────────
          _buildStatusBar(context),

          // ── Home Top: Clock, Date, At-A-Glance & Mini Widget ───
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 12, 26, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            timeStr,
                            style: LauncherTheme.rajdhani(
                              fontSize: 56,
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
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: LauncherTheme.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dateStr,
                        style: LauncherTheme.rajdhani(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.8,
                          color: LauncherTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // At-A-Glance Tactical Smart Chip
                      _buildAtAGlanceChip(context),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Mini Widget (Interactive Live Telemetry Box)
                GestureDetector(
                  onTap: widget.onOpenWidget,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFFF3EFE7) : const Color(0xFF0B0C10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLight ? const Color(0xFFD8D2C5) : const Color(0xFF2A2E37),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: LauncherTheme.red.withValues(alpha: 0.12),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Grid Lines Background
                        CustomPaint(
                          size: const Size(76, 76),
                          painter: _GridTexturePainter(isLight: isLight),
                        ),
                        // Red Glowing Indicator Dot
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: LauncherTheme.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: LauncherTheme.red,
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                MdiIcons.widgetsOutline,
                                size: 24,
                                color: LauncherTheme.text.withValues(alpha: 0.85),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'WIDGETS',
                                style: LauncherTheme.rajdhani(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: LauncherTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Cyber Mountain Wallpaper Area ───────────────────────
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: LauncherWallpaperPainter(isLight: isLight),
                  ),
                ),
                // Swipe Up Prompt Banner in Wallpaper Center Bottom
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: InkWell(
                    onTap: widget.onSwipeUpToArcane,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          MdiIcons.chevronDoubleUp,
                          size: 26,
                          color: LauncherTheme.red,
                          shadows: [
                            Shadow(color: LauncherTheme.red, blurRadius: 10),
                          ],
                        ),
                        Text(
                          'SWIPE UP FOR MISSIONS',
                          style: LauncherTheme.rajdhani(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.8,
                            color: LauncherTheme.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Dock Wrap ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isLight
                        ? const Color(0x14000000)
                        : const Color(0x0AFFFFFF),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDockButton(
                    icon: MdiIcons.phone,
                    label: 'Phone',
                    onTap: () => widget.onAction('phone'),
                  ),
                  _buildDockButton(
                    icon: MdiIcons.messageProcessingOutline,
                    label: 'Messages',
                    onTap: () => widget.onAction('messages'),
                  ),
                  _buildDockButton(
                    icon: MdiIcons.grid,
                    label: 'App Space',
                    onTap: widget.onOpenSpace,
                    highlight: true,
                  ),
                  _buildDockButton(
                    icon: MdiIcons.magnifyScan,
                    label: 'Search',
                    onTap: widget.onOpenSearch,
                  ),
                  _buildDockButton(
                    icon: MdiIcons.cameraOutline,
                    label: 'Camera',
                    onTap: () => widget.onAction('camera'),
                  ),
                ],
              ),
            ),
          ),

          // ── Home Indicator (Gesture Pill) ───────────────────────
          GestureDetector(
            onTap: widget.onSwipeUpToArcane,
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

  Widget _buildStatusBar(BuildContext context) {
    final timeStr = DateFormat('h:mm').format(_now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 12, 26, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            timeStr,
            style: LauncherTheme.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: LauncherTheme.text,
            ),
          ),
          Row(
            children: [
              Icon(MdiIcons.signalCellular3, size: 16, color: LauncherTheme.text),
              const SizedBox(width: 6),
              Icon(MdiIcons.wifi, size: 16, color: LauncherTheme.text),
              const SizedBox(width: 8),
              // Battery Indicator
              Container(
                width: 22,
                height: 11,
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  border: Border.all(color: LauncherTheme.text, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 13,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: LauncherTheme.text,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAtAGlanceChip(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final live = WidgetsStudioResolvers.resolveLiveTask(provider);

    String chipLabel;
    IconData chipIcon;
    Color chipColor;

    if (live.isRunning) {
      chipLabel = 'ENGAGED // ${live.title}';
      chipIcon = MdiIcons.targetAccount;
      chipColor = LauncherTheme.red;
    } else if (live.hasTask) {
      chipLabel = 'STANDBY // ${live.title}';
      chipIcon = MdiIcons.clockCheckOutline;
      chipColor = JweTheme.accentAmber;
    } else {
      final today = helper.getTodayDateString();
      final plan = provider.taskActions.getDayPlan(today);
      if (plan.isNotEmpty) {
        chipLabel = 'PLAN // ${plan.length} MISSIONS TODAY';
        chipIcon = MdiIcons.calendarClock;
        chipColor = JweTheme.accentCyan;
      } else {
        chipLabel = 'STANDBY // ALL SYSTEMS NOMINAL';
        chipIcon = MdiIcons.shieldCheckOutline;
        chipColor = JweTheme.accentCyan;
      }
    }

    return InkWell(
      onTap: widget.onOpenWidget,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: JweTheme.isLight ? 0.08 : 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: chipColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(chipIcon, size: 14, color: chipColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                chipLabel,
                style: LauncherTheme.rajdhani(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: chipColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    final isLight = LauncherTheme.isLight;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: highlight
                ? LauncherTheme.red.withValues(alpha: 0.12)
                : LauncherTheme.dockButtonBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlight ? LauncherTheme.red : LauncherTheme.dockBorder,
              width: highlight ? 1.5 : 1.0,
            ),
            boxShadow: highlight
                ? [
                    BoxShadow(
                      color: LauncherTheme.redDim,
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: highlight ? LauncherTheme.red : (isLight ? const Color(0xFF3C3730) : const Color(0xFFCFD3DB)),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridTexturePainter extends CustomPainter {
  final bool isLight;
  _GridTexturePainter({required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = isLight ? const Color(0xFFE2DDD2) : const Color(0xFF1A1D24)
      ..strokeWidth = 1.0;

    const step = 25.3;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridTexturePainter oldDelegate) =>
      oldDelegate.isLight != isLight;
}
