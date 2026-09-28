import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';

/// "Floating task button" switch: an AssistiveTouch-style bubble over every app, shown while a task
/// is running. Tap halts it, double-tap checks the current checkpoint and adds the next one on the
/// same level, long-press opens a quick menu, drag moves it. It is drawn by the "Arcane Launcher"
/// accessibility service, so it only shows while that service is on.
class LauncherTaskBubbleSettings extends StatefulWidget {
  const LauncherTaskBubbleSettings({super.key});

  @override
  State<LauncherTaskBubbleSettings> createState() => _LauncherTaskBubbleSettingsState();
}

class _LauncherTaskBubbleSettingsState extends State<LauncherTaskBubbleSettings> with WidgetsBindingObserver {
  bool _enabled = true;
  bool _serviceEnabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user flips the accessibility switch in system settings; re-read on return.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await LauncherNative.getTaskBubbleStatus();
    if (!mounted) return;
    setState(() {
      _enabled = s['enabled'] != false;
      _serviceEnabled = s['serviceEnabled'] == true;
      _loaded = true;
    });
  }

  Future<void> _toggle(bool value) async {
    await LauncherNative.setTaskBubbleEnabled(value);
    if (!mounted) return;
    setState(() => _enabled = value);
    if (value && !_serviceEnabled) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable "Arcane Launcher"'),
          content: const Text(
            'The floating task button is drawn by Arcane\'s accessibility service.\n\n'
            'In the next screen open "Arcane Launcher" (under Downloaded / Installed apps) and turn it on. '
            'It never reads screen content or what you type.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('LATER')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OPEN SETTINGS')),
          ],
        ),
      );
      if (go == true) await LauncherNative.openAccessibilitySettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!LauncherNative.isSupported) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: _loaded ? _toggle : null,
          title: const Text('Floating task button', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            'A draggable bubble over every app while a task is running. Tap to halt it; '
            'double-tap to check off the current checkpoint and add the next one; long-press for more.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
        if (_loaded && _enabled && !_serviceEnabled)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(MdiIcons.alertCircleOutline, color: theme.colorScheme.error, size: 20),
            title: const Text('Turn on "Arcane Launcher" accessibility service', style: TextStyle(fontSize: 13.5)),
            trailing: TextButton(onPressed: LauncherNative.openAccessibilitySettings, child: const Text('ENABLE')),
          ),
      ],
    );
  }
}
