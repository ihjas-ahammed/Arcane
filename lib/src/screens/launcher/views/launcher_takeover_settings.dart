import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';

/// "Open Arcane over the default launcher" switch + setup steps, for ROMs (MIUI / HyperOS)
/// that won't let a third-party app be the default home app. Used in app Settings and in the
/// launcher settings sheet; styled from the ambient [Theme] so it fits both.
class LauncherTakeoverSettings extends StatefulWidget {
  const LauncherTakeoverSettings({super.key});

  @override
  State<LauncherTakeoverSettings> createState() => _LauncherTakeoverSettingsState();
}

class _LauncherTakeoverSettingsState extends State<LauncherTakeoverSettings> with WidgetsBindingObserver {
  bool _enabled = false;
  bool _serviceEnabled = false;
  bool _isDefault = false;
  bool _isMiui = false;
  List<String> _stock = const [];
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
    final s = await LauncherNative.getTakeoverStatus();
    if (!mounted) return;
    setState(() {
      _enabled = s['enabled'] == true;
      _serviceEnabled = s['serviceEnabled'] == true;
      _isDefault = s['isDefault'] == true;
      _isMiui = s['isMiui'] == true;
      _stock = (s['stockLaunchers'] as List? ?? const []).map((e) => '$e').toList();
      _loaded = true;
    });
  }

  Future<void> _toggle(bool value) async {
    await LauncherNative.setTakeoverEnabled(value);
    setState(() => _enabled = value);
    if (value && !_serviceEnabled && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable "Arcane Launcher"'),
          content: const Text(
            'Arcane needs its accessibility service to notice when the stock home screen opens, '
            'so it can open itself on top.\n\n'
            'In the next screen open "Arcane Launcher" (under Downloaded / Installed apps) and turn it on. '
            'It only watches which app comes to the front — never screen content or typing.',
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
    final ok = theme.colorScheme.primary;
    final warn = theme.colorScheme.error;

    Widget step({required bool done, required String label, required String action, required VoidCallback onTap}) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(done ? MdiIcons.checkCircle : MdiIcons.alertCircleOutline, color: done ? ok : warn, size: 20),
        title: Text(label, style: const TextStyle(fontSize: 13.5)),
        trailing: TextButton(onPressed: onTap, child: Text(action)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: _loaded ? _toggle : null,
          title: const Text('Open Arcane over default launcher', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            _isDefault
                ? 'Arcane is already your default home app — not needed.'
                : 'Every time the stock home screen${_stock.isEmpty ? '' : ' (${_stock.first})'} opens, Arcane opens on top. '
                    'For MIUI / HyperOS, which force their own launcher.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
        if (_enabled) ...[
          step(
            done: _serviceEnabled,
            label: _serviceEnabled ? 'Accessibility service on' : 'Turn on "Arcane Launcher" accessibility service',
            action: _serviceEnabled ? 'MANAGE' : 'ENABLE',
            onTap: LauncherNative.openAccessibilitySettings,
          ),
          if (_isMiui) ...[
            step(
              done: false,
              label: 'MIUI: allow Autostart (keeps the service alive)',
              action: 'OPEN',
              onTap: () => LauncherNative.openMiuiPermissions('autostart'),
            ),
            step(
              done: false,
              label: 'MIUI: allow "Display pop-up windows while running in background"',
              action: 'OPEN',
              onTap: () => LauncherNative.openMiuiPermissions('permissions'),
            ),
          ],
        ],
      ],
    );
  }
}
