import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';

/// Fullscreen tactical status bar positioned at the top of the launcher (at the notch/cutout line).
/// Displays live clock, 4-step range bar, network transport, charging status, and battery gauge.
/// In dark theme, it renders in crisp white; in light theme, in dark tactical paper charcoal.
class TacticalStatusBar extends StatefulWidget {
  const TacticalStatusBar({super.key});

  @override
  State<TacticalStatusBar> createState() => _TacticalStatusBarState();
}

class _TacticalStatusBarState extends State<TacticalStatusBar> with WidgetsBindingObserver {
  Timer? _pollTimer;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  int _batteryLevel = 100;
  bool _isCharging = false;
  String _networkType = 'WIFI';
  int _signalLevel = 4;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTelemetry();
    _startClock();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _refreshTelemetry();
    });
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshTelemetry();
      setState(() => _now = DateTime.now());
    }
  }

  Future<void> _refreshTelemetry() async {
    try {
      final status = await LauncherNative.getBatteryAndNetworkStatus();
      if (!mounted || status.isEmpty) return;
      setState(() {
        _batteryLevel = (status['batteryLevel'] as num?)?.toInt() ?? 100;
        _isCharging = status['isCharging'] == true;
        _networkType = (status['networkType'] as String?) ?? 'WIFI';
        _signalLevel = (status['signalLevel'] as num?)?.toInt() ?? 4;
        _isOnline = status['isOnline'] == true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LauncherService.instance.fullscreen,
      builder: (context, isFullscreen, _) {
        if (!isFullscreen) return const SizedBox.shrink();

        final viewPaddingTop = MediaQuery.viewPaddingOf(context).top;
        final barHeight = max(viewPaddingTop, 28.0);
        final isLight = LauncherTheme.isLight;

        // Dark theme: crisp pure white. Light theme: dark tactical charcoal.
        final Color activeColor = isLight ? const Color(0xFF1B2028) : Colors.white;
        final Color inactiveColor = isLight
            ? const Color(0xFF1B2028).withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.28);
        final Color alertColor = LauncherTheme.red;

        final timeFormatted = DateFormat('HH:mm').format(_now);

        return Semantics(
          label: 'Status Bar: $timeFormatted, Battery $_batteryLevel%, $_networkType, Signal $_signalLevel of 4',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                LauncherNative.expandNotifications();
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _refreshTelemetry();
              },
              child: Container(
                height: barHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Left: Time & Network / Range Telemetry ──
                    Text(
                      timeFormatted,
                      style: LauncherTheme.rajdhani(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: activeColor,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildRangeBar(activeColor, inactiveColor, alertColor),
                    const SizedBox(width: 6),
                    _buildNetworkBadge(activeColor, alertColor),

                    // ── Center: Cutout / Notch Void ──
                    const Spacer(),

                    // ── Right: Battery Telemetry ──
                    _buildBatteryTelemetry(activeColor, inactiveColor, alertColor),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRangeBar(Color activeColor, Color inactiveColor, Color alertColor) {
    final barHeights = [4.0, 7.5, 11.0, 14.5];
    final isOffline = !_isOnline || _networkType == 'OFFLINE';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 2.0),
          Container(
            width: 2.5,
            height: barHeights[i],
            decoration: BoxDecoration(
              color: isOffline
                  ? inactiveColor
                  : (i < _signalLevel ? activeColor : inactiveColor),
              borderRadius: BorderRadius.circular(0.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNetworkBadge(Color activeColor, Color alertColor) {
    final isOffline = !_isOnline || _networkType == 'OFFLINE';
    final isWifi = _networkType == 'WIFI';
    final Color color = isOffline ? alertColor : activeColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isOffline) ...[
          Icon(MdiIcons.wifiOff, size: 12, color: color),
          const SizedBox(width: 3),
        ] else if (isWifi) ...[
          Icon(MdiIcons.wifi, size: 12, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          _networkType,
          style: LauncherTheme.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: color,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryTelemetry(Color activeColor, Color inactiveColor, Color alertColor) {
    final bool isCritical = _batteryLevel < 15 && !_isCharging;
    final Color batColor = isCritical ? alertColor : activeColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_isCharging) ...[
          Icon(MdiIcons.lightningBolt, size: 13, color: activeColor),
          const SizedBox(width: 2),
        ],
        Text(
          '$_batteryLevel%',
          style: LauncherTheme.rajdhani(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: batColor,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 22,
          height: 11,
          padding: const EdgeInsets.all(1.2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2.5),
            border: Border.all(
              color: batColor,
              width: 1.2,
            ),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (_batteryLevel / 100.0).clamp(0.06, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: batColor,
                  borderRadius: BorderRadius.circular(1.0),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: 1.5,
          height: 4.5,
          decoration: BoxDecoration(
            color: batColor,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(1.0)),
          ),
        ),
      ],
    );
  }
}
