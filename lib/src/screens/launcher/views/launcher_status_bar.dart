import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/theme/valorant_theme.dart';

/// Fullscreen tactical status bar positioned at the top of the launcher.
/// Displays live battery gauge, charging state, network transport, and 4-step range bar.
class TacticalStatusBar extends StatefulWidget {
  const TacticalStatusBar({super.key});

  @override
  State<TacticalStatusBar> createState() => _TacticalStatusBarState();
}

class _TacticalStatusBarState extends State<TacticalStatusBar> with WidgetsBindingObserver {
  Timer? _pollTimer;
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
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _refreshTelemetry();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshTelemetry();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LauncherService.instance.fullscreen,
      builder: (context, isFullscreen, _) {
        if (!isFullscreen) return const SizedBox.shrink();

        final topInset = MediaQuery.paddingOf(context).top;
        final effectiveTop = topInset > 0 ? topInset + 2.0 : 8.0;
        final isLight = LauncherTheme.isLight;
        final activeTeal = isLight ? const Color(0xFF009668) : ValorantColors.teal;
        final redAlert = LauncherTheme.red;

        return Semantics(
          label: 'System Status: Battery $_batteryLevel%, $_networkType, Signal $_signalLevel of 4',
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, effectiveTop, 18, 4),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                LauncherNative.expandNotifications();
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _refreshTelemetry();
              },
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: [
                    // ── Left: Range & Network Telemetry ──
                    _buildRangeBar(activeTeal, redAlert),
                    const SizedBox(width: 8),
                    _buildNetworkBadge(activeTeal, redAlert),

                    const Spacer(),

                    // ── Right: Battery Telemetry ──
                    _buildBatteryTelemetry(activeTeal, redAlert),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRangeBar(Color activeColor, Color alertColor) {
    final barHeights = [4.0, 7.5, 11.0, 14.5];
    final isOffline = !_isOnline || _networkType == 'OFFLINE';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 2.0),
          Container(
            width: 3.0,
            height: barHeights[i],
            decoration: BoxDecoration(
              color: isOffline
                  ? LauncherTheme.muted.withValues(alpha: 0.25)
                  : (i < _signalLevel
                      ? activeColor
                      : LauncherTheme.muted.withValues(alpha: 0.25)),
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

    final IconData icon = isOffline
        ? MdiIcons.wifiOff
        : (isWifi ? MdiIcons.wifi : MdiIcons.signalCellular3);
    final Color color = isOffline ? alertColor : LauncherTheme.text;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: isOffline ? alertColor : activeColor),
        const SizedBox(width: 4),
        Text(
          _networkType,
          style: LauncherTheme.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: color,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryTelemetry(Color activeColor, Color alertColor) {
    final Color batColor = _batteryLevel > 30
        ? activeColor
        : (_batteryLevel >= 15 ? JweTheme.accentAmber : alertColor);

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
        const SizedBox(width: 6),
        Container(
          width: 24,
          height: 12,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2.5),
            border: Border.all(
              color: LauncherTheme.line,
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
          width: 2.0,
          height: 5.0,
          decoration: BoxDecoration(
            color: LauncherTheme.line,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(1.0)),
          ),
        ),
      ],
    );
  }
}
