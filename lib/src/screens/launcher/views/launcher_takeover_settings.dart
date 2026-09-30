import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/services/assistant_routing_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// "Open Arcane over the default launcher" switch + Anti-Kill & MIUI background protection shield.
/// Ensures persistent home app status on MIUI / HyperOS, manages floating NORA HUD, and inspects
/// diagnostic crash logs.
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
  bool _ignoringBattery = false;
  List<String> _crashLogs = const [];
  bool _loaded = false;

  // Floating Nora settings
  bool _floatingNoraEnabled = true;
  bool _watchFloatingEnabled = true;

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
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await LauncherNative.getMiuiShieldStatus();
    final logs = await LauncherNative.getCrashLog();
    final noraStatus = await AssistantRoutingService.instance.getNoraBubbleStatus();

    if (!mounted) return;
    setState(() {
      _isDefault = s['isDefault'] == true;
      _enabled = s['takeoverEnabled'] == true;
      _serviceEnabled = s['serviceEnabled'] == true;
      _ignoringBattery = s['ignoringBattery'] == true;
      _isMiui = s['isMiui'] == true;
      _crashLogs = logs;
      _floatingNoraEnabled = noraStatus['enabled'] == true;
      _watchFloatingEnabled = noraStatus['watchFloating'] == true;
      _loaded = true;
    });
  }

  Future<void> _toggleTakeover(bool value) async {
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
            'It only watches which app comes to the front — never personal data.',
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

  void _showRecentsLockGuide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: JweTheme.accentAmber, size: 22),
            const SizedBox(width: 8),
            const Flexible(
              child: Text('Lock Arcane in Recents'),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'On MIUI / HyperOS and aggressive battery-saver ROMs, apps can be terminated randomly unless locked in task memory:\n',
              style: TextStyle(fontSize: 13),
            ),
            Text('1. Open your Recent Apps screen (swipe up from bottom & hold, or press Recents button).', style: TextStyle(fontSize: 12.5)),
            SizedBox(height: 6),
            Text('2. Press and hold on the Arcane window card.', style: TextStyle(fontSize: 12.5)),
            SizedBox(height: 6),
            Text('3. Tap the 🔒 Padlock icon to lock Arcane in memory.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Once locked, MIUI will never kill Arcane or reset your default home launcher!', style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('GOT IT')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!LauncherNative.isSupported) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isLight = JweTheme.isLight;
    final muted = isLight ? JweTheme.textMuted : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75);
    final ok = Colors.green;
    final warn = isLight ? JweTheme.accentAmber : theme.colorScheme.error;
    final accent = isLight ? JweTheme.accentCyan : theme.colorScheme.primary;

    Widget step({required bool done, required String label, required String action, required VoidCallback onTap}) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(done ? MdiIcons.checkCircle : MdiIcons.alertCircleOutline, color: done ? ok : warn, size: 20),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: TextButton(onPressed: onTap, child: Text(action)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 1. Default Launcher Persistence ─────────────────────────
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(_isDefault ? Icons.home : Icons.home_outlined, color: _isDefault ? ok : warn, size: 22),
          title: const Text('Default Home Launcher', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: Text(
            _isDefault ? 'Arcane is currently set as your default home app.' : 'Set Arcane as persistent default home app.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          trailing: TextButton(
            onPressed: () async {
              await LauncherNative.requestDefaultLauncher();
              _refresh();
            },
            child: Text(_isDefault ? 'RECHECK' : 'SET DEFAULT'),
          ),
        ),

        // ── 2. Takeover mode (for MIUI / HyperOS forced home) ─────────
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: _loaded ? _toggleTakeover : null,
          title: const Text('Open Arcane over default launcher', style: TextStyle(fontSize: 13.5)),
          subtitle: Text(
            _isDefault
                ? 'Arcane is default. Takeover provides zero-delay swap if MIUI reverts home.'
                : 'Instantly opens Arcane over stock home screen (essential for MIUI / HyperOS).',
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
        ),

        // ── 3. Anti-Kill Checklist ─────────────────────────────────
        step(
          done: _serviceEnabled,
          label: _serviceEnabled ? 'Accessibility service active' : 'Enable "Arcane Launcher" accessibility service',
          action: _serviceEnabled ? 'MANAGE' : 'ENABLE',
          onTap: LauncherNative.openAccessibilitySettings,
        ),
        step(
          done: _ignoringBattery,
          label: _ignoringBattery ? 'Battery optimization ignored' : 'Exempt Arcane from battery saver kills',
          action: _ignoringBattery ? 'EXEMPTED' : 'EXEMPT',
          onTap: () async {
            await LauncherNative.requestIgnoreBatteryOptimizations();
            _refresh();
          },
        ),
        if (_isMiui) ...[
          step(
            done: false,
            label: 'MIUI: allow Autostart (keeps Arcane running)',
            action: 'OPEN',
            onTap: () => LauncherNative.openMiuiPermissions('autostart'),
          ),
          step(
            done: false,
            label: 'MIUI: allow "Display pop-up windows in background"',
            action: 'OPEN',
            onTap: () => LauncherNative.openMiuiPermissions('permissions'),
          ),
        ],
        step(
          done: false,
          label: 'Lock Arcane in Recent Apps (stops random kills)',
          action: 'GUIDE',
          onTap: _showRecentsLockGuide,
        ),

        const Divider(height: 24),

        // ── 4. Floating NORA HUD Controls ──────────────────────────
        const Text(
          'FLOATING NORA ASSISTANT',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.14),
        ),
        const SizedBox(height: 6),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _floatingNoraEnabled,
          onChanged: (val) async {
            await AssistantRoutingService.instance.setNoraBubbleEnabled(val);
            setState(() => _floatingNoraEnabled = val);
          },
          title: const Text('Floating NORA Overlay', style: TextStyle(fontSize: 13.5)),
          subtitle: Text(
            'Displays a tactical floating NORA HUD orb that docks against the screen edge.',
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _watchFloatingEnabled,
          onChanged: (val) async {
            await AssistantRoutingService.instance.setNoraWatchFloating(val);
            setState(() => _watchFloatingEnabled = val);
          },
          title: const Text('Use Floating HUD for Watch Voice', style: TextStyle(fontSize: 13.5)),
          subtitle: Text(
            'When voice is triggered from smartwatch or Bluetooth, opens floating NORA with auto-mic instead of full app takeover.',
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => AssistantRoutingService.instance.summonFloatingNora(),
            icon: const Icon(Icons.mic, size: 16),
            label: const Text('TEST FLOATING NORA NOW', style: TextStyle(fontSize: 11.5)),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.5)),
            ),
          ),
        ),

        const Divider(height: 24),

        // ── 5. System Error & Crash Log Inspector ───────────────────
        Row(
          children: [
            Icon(
              _crashLogs.isEmpty ? Icons.shield_outlined : Icons.bug_report_outlined,
              color: _crashLogs.isEmpty ? ok : warn,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _crashLogs.isEmpty ? 'SYSTEM INTEGRITY CLEAN' : 'SHUTDOWN / CRASH LOGS DETECTED (${_crashLogs.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _crashLogs.isEmpty ? ok : warn,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_crashLogs.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await LauncherNative.clearCrashLog();
                  _refresh();
                },
                child: const Text('CLEAR LOGS', style: TextStyle(fontSize: 11, color: Colors.red)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (_crashLogs.isEmpty)
          Text(
            'No unexpected background kills or unhandled crashes detected. Background shields are operating normally.',
            style: TextStyle(fontSize: 11.5, color: muted),
          )
        else
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isLight ? JweTheme.panel2 : JweTheme.bgDeep,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: warn.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _crashLogs.last,
                  style: const TextStyle(fontSize: 10, fontFamily: 'RobotoMono'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _crashLogs.join('\n\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Crash logs copied to clipboard.')),
                    );
                  },
                  child: Text('TAP TO COPY FULL ERROR LOG', style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
