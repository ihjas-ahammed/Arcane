import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/services/devices_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Utilities › Devices: pair-and-listen to a smartwatch (or any Bluetooth device), log everything it
/// sends, and keep the watch's companion app running.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> with WidgetsBindingObserver {
  final DevicesService _svc = DevicesService.instance;
  String _deviceFilter = '';
  String _watchLabel = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _svc.addListener(_onChange);
    _init();
  }

  Future<void> _init() async {
    await _svc.refresh();
    await _svc.loadLog();
    await _resolveWatchLabel();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _svc.removeListener(_onChange);
    _svc.stopScan();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _svc.refresh();
  }

  Future<void> _resolveWatchLabel() async {
    final pkg = '${_svc.watch['package'] ?? ''}';
    if (pkg.isEmpty) return;
    final apps = await LauncherNative.getApps();
    final match = apps.where((a) => a['package'] == pkg).firstOrNull;
    if (mounted) setState(() => _watchLabel = (match?['label'] as String?) ?? pkg);
  }

  Future<void> _pickWatchApp() async {
    final apps = await LauncherNative.getApps();
    if (!mounted) return;
    final seen = <String>{};
    final list = apps.where((a) => seen.add('${a['package']}')).toList()
      ..sort((a, b) => '${a['label']}'.toLowerCase().compareTo('${b['label']}'.toLowerCase()));
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: JweTheme.panel,
      builder: (_) => _AppPickerSheet(apps: list),
    );
    if (picked == null) return;
    await _svc.setWatchApp(picked);
    await _resolveWatchLabel();
  }

  String _deviceName(String address) {
    for (final d in _svc.bonded) {
      if (d['address'] == address) return '${d['name']}';
    }
    return address;
  }

  @override
  Widget build(BuildContext context) {
    final s = _svc.state;
    final btOn = s['bluetoothOn'] == true;
    final permOk = s['connectPermission'] == true && s['scanPermission'] == true;
    final watch = _svc.watch;
    final hasWatch = '${watch['package'] ?? ''}'.isNotEmpty;
    final events = _deviceFilter.isEmpty ? _svc.events : _svc.events.where((e) => e.device == _deviceFilter).toList();

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        title: Text('DEVICES',
            style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: JweTheme.bgBase,
        iconTheme: IconThemeData(color: JweTheme.accentCyan),
      ),
      body: !DevicesService.isSupported
          ? Center(child: Text('Devices is only available on Android.', style: TextStyle(color: JweTheme.textMuted)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                // ── Status ──
                _section('BLUETOOTH'),
                _card(Column(children: [
                  _row(MdiIcons.bluetooth, 'Bluetooth', btOn ? 'ON' : 'OFF', btOn ? JweTheme.accentTeal : JweTheme.accentRed),
                  _row(MdiIcons.shieldKeyOutline, 'Permissions', permOk ? 'GRANTED' : 'NEEDED',
                      permOk ? JweTheme.accentTeal : JweTheme.accentAmber,
                      action: permOk ? null : ('GRANT', _svc.requestPermissions)),
                ])),

                // ── Watch app ──
                _section('WATCH APP'),
                _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _row(MdiIcons.watchVariant, 'Companion app', hasWatch ? (_watchLabel.isEmpty ? '${watch['package']}' : _watchLabel) : 'NOT SET',
                      hasWatch ? JweTheme.accentCyan : JweTheme.textMuted,
                      action: (hasWatch ? 'CHANGE' : 'SELECT', _pickWatchApp)),
                  if (hasWatch) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: JweTheme.accentTeal,
                      title: Text('Keep it running', style: GoogleFonts.chakraPetch(color: JweTheme.textWhite, fontSize: 13)),
                      subtitle: Text(
                        'If the app gets killed, Arcane starts it again. Arcane notices because the app\'s ongoing notification disappears.',
                        style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                      ),
                      value: watch['enabled'] == true,
                      onChanged: (v) => _svc.setKeepAlive(v),
                    ),
                    _row(MdiIcons.bellRingOutline, 'Notification access', s['listenerEnabled'] == true ? 'ON' : 'REQUIRED',
                        s['listenerEnabled'] == true ? JweTheme.accentTeal : JweTheme.accentAmber,
                        action: s['listenerEnabled'] == true ? null : ('ENABLE', _svc.openListenerSettings)),
                    _row(MdiIcons.layersOutline, 'Show over other apps', s['overlayAllowed'] == true ? 'ON' : 'RECOMMENDED',
                        s['overlayAllowed'] == true ? JweTheme.accentTeal : JweTheme.accentAmber,
                        action: s['overlayAllowed'] == true ? null : ('ALLOW', _svc.openOverlaySettings)),
                    _row(MdiIcons.history, 'Restarted by Arcane', '${watch['restarts'] ?? 0}x', JweTheme.textMid),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      _chip('RESTART NOW', MdiIcons.restart, () async {
                        final ok = await _svc.restartWatchApp();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Launching…' : 'Could not launch the app')));
                      }),
                      _chip('BATTERY SETTINGS', MdiIcons.batteryHeartVariant, _svc.openBatterySettings),
                      _chip('APP INFO', MdiIcons.informationOutline, () => _svc.openAppSettings('${watch['package']}')),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'Tip: also set the watch app to "No restrictions" / autostart in battery settings so the system does not kill it first. Detection needs the app to show a persistent notification while connected.',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5),
                    ),
                  ],
                ])),

                // ── Devices ──
                _section('PAIRED DEVICES'),
                if (_svc.bonded.isEmpty)
                  _card(Text(permOk ? 'No paired Bluetooth devices.' : 'Grant permissions to list paired devices.',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11)))
                else
                  for (final d in _svc.bonded) _deviceTile(d),

                _section('NEARBY (BLE SCAN)'),
                Row(children: [
                  _chip(_svc.scanning ? 'STOP SCAN' : 'SCAN 25s', _svc.scanning ? MdiIcons.stop : MdiIcons.radar,
                      () => _svc.scanning ? _svc.stopScan() : _svc.startScan()),
                  if (_svc.scanning) ...[
                    const SizedBox(width: 10),
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ]),
                const SizedBox(height: 6),
                for (final r in _svc.scanResults.take(40)) _scanTile(r),

                // ── Live log ──
                _section('LIVE DATA'),
                Row(children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: JweTheme.panel,
                        value: _deviceFilter,
                        items: [
                          DropdownMenuItem(value: '', child: Text('All sources (${_svc.events.length})', style: _mono(JweTheme.textWhite))),
                          for (final id in _svc.events.map((e) => e.device).where((d) => d.isNotEmpty).toSet())
                            DropdownMenuItem(value: id, child: Text(_deviceName(id), style: _mono(JweTheme.textWhite), overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => _deviceFilter = v ?? ''),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy log',
                    icon: Icon(MdiIcons.contentCopy, color: JweTheme.accentCyan, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _svc.exportLog()));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log copied (JSON lines)')));
                    },
                  ),
                  IconButton(
                    tooltip: 'Clear log',
                    icon: Icon(MdiIcons.deleteOutline, color: JweTheme.accentRed, size: 18),
                    onPressed: _svc.clearLog,
                  ),
                ]),
                if (events.isEmpty)
                  _card(Text('Nothing received yet. Connect a device above, or enable notification access and pick the watch app.',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11)))
                else
                  for (final e in events.take(200)) _eventTile(e),
              ],
            ),
    );
  }

  TextStyle _mono(Color c) => GoogleFonts.jetBrainsMono(color: c, fontSize: 11);

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(children: [
          Container(width: 3, height: 12, color: JweTheme.accentCyan),
          const SizedBox(width: 8),
          Text(t, style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.6)),
        ]),
      );

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: JweTheme.panel, border: Border.all(color: JweTheme.border)),
        child: child,
      );

  Widget _row(IconData icon, String label, String value, Color color, {(String, VoidCallback)? action}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: GoogleFonts.chakraPetch(color: JweTheme.textWhite, fontSize: 13))),
          Flexible(child: Text(value, overflow: TextOverflow.ellipsis, style: _mono(color))),
          if (action != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: action.$2,
              style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              child: Text(action.$1, style: _mono(JweTheme.accentCyan).copyWith(fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
      );

  Widget _chip(String label, IconData icon, VoidCallback onTap) => ActionChip(
        backgroundColor: JweTheme.panel,
        side: BorderSide(color: JweTheme.accentCyan.withValues(alpha: 0.5)),
        avatar: Icon(icon, size: 14, color: JweTheme.accentCyan),
        label: Text(label, style: _mono(JweTheme.accentCyan).copyWith(fontWeight: FontWeight.bold, fontSize: 10)),
        onPressed: onTap,
      );

  Widget _deviceTile(Map<String, dynamic> d) {
    final addr = '${d['address']}';
    final connected = _svc.isConnected(addr);
    final isLe = d['type'] == 'le' || d['type'] == 'dual';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: JweTheme.panel, border: Border.all(color: connected ? JweTheme.accentTeal : JweTheme.border)),
      child: Row(children: [
        Icon(d['majorClass'] == 1792 ? MdiIcons.watchVariant : MdiIcons.bluetooth, color: connected ? JweTheme.accentTeal : JweTheme.textMid),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d['name']}', style: GoogleFonts.chakraPetch(color: JweTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold)),
            Text('$addr · ${d['type']}${d['battery'] != null ? ' · ${d['battery']}%' : ''}', style: _mono(JweTheme.textMuted)),
          ]),
        ),
        if (isLe)
          TextButton(
            onPressed: () => connected ? _svc.disconnect(addr) : _svc.connect(addr),
            child: Text(connected ? 'DISCONNECT' : 'LISTEN', style: _mono(connected ? JweTheme.accentRed : JweTheme.accentCyan).copyWith(fontWeight: FontWeight.bold)),
          )
        else
          Text('classic\n(auto-logged)', textAlign: TextAlign.right, style: _mono(JweTheme.textMuted).copyWith(fontSize: 9)),
      ]),
    );
  }

  Widget _scanTile(DeviceEvent r) {
    final name = '${r.data['name'] ?? ''}';
    final addr = r.device;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(MdiIcons.bluetoothAudio, color: JweTheme.textMid, size: 18),
      title: Text(name.isEmpty ? '(unnamed)' : name, style: GoogleFonts.chakraPetch(color: JweTheme.textWhite, fontSize: 13)),
      subtitle: Text('$addr · ${r.data['rssi']} dBm${(r.data['manufacturer'] as Map?)?.isNotEmpty == true ? ' · ${(r.data['manufacturer'] as Map).keys.join(',')}' : ''}',
          style: _mono(JweTheme.textMuted).copyWith(fontSize: 10)),
      trailing: TextButton(
        onPressed: () => _svc.connect(addr),
        child: Text(_svc.isConnected(addr) ? 'CONNECTED' : 'LISTEN', style: _mono(JweTheme.accentCyan).copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _eventTile(DeviceEvent e) {
    final color = switch (e.source) {
      'gatt' => JweTheme.accentTeal,
      'classic' => JweTheme.accentCyan,
      'watch-app' => JweTheme.accentAmber,
      'keepalive' => JweTheme.accentRed,
      _ => JweTheme.textMid,
    };
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: e.toJson().toString()));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event copied')));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('HH:mm:ss').format(e.time), style: _mono(JweTheme.textMuted).copyWith(fontSize: 10)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            color: color.withValues(alpha: 0.18),
            child: Text(e.kind.toUpperCase(), style: _mono(color).copyWith(fontSize: 8.5, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_deviceFilter.isEmpty && e.device.isNotEmpty ? '${_deviceName(e.device)}: ' : ''}${e.summary}',
              style: _mono(JweTheme.textWhite).copyWith(fontSize: 10.5),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }
}

class _AppPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> apps;
  const _AppPickerSheet({required this.apps});

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final shown = widget.apps.where((a) => q.isEmpty || '${a['label']}'.toLowerCase().contains(q) || '${a['package']}'.toLowerCase().contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              style: TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                hintText: 'Search the watch app (Mi Fitness, Zepp, Wear OS…)',
                hintStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                prefixIcon: Icon(Icons.search, color: JweTheme.accentCyan),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (_, i) => ListTile(
                title: Text('${shown[i]['label']}', style: TextStyle(color: JweTheme.textWhite)),
                subtitle: Text('${shown[i]['package']}', style: TextStyle(color: JweTheme.textMuted, fontSize: 11)),
                onTap: () => Navigator.pop(context, '${shown[i]['package']}'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
