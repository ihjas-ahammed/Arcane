import 'package:flutter/material.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';

/// "Fullscreen launcher" switch: hides the status and navigation bars on the launcher.
/// Used in app Settings and in the launcher settings sheet; styled from the ambient [Theme].
class LauncherFullscreenSetting extends StatelessWidget {
  const LauncherFullscreenSetting({super.key});

  @override
  Widget build(BuildContext context) {
    if (!LauncherNative.isSupported) return const SizedBox.shrink();
    final service = LauncherService.instance;
    final muted = Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.75);
    return ValueListenableBuilder<bool>(
      valueListenable: service.fullscreen,
      builder: (_, on, __) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: on,
        onChanged: service.setFullscreen,
        title: const Text('Fullscreen launcher', style: TextStyle(fontSize: 14)),
        subtitle: Text(
          'Hide the status and navigation bars on the home screen. Swipe from an edge to show them briefly.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ),
    );
  }
}
