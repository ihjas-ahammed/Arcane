import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One thing a device (or its companion app) told us. `data` keeps every field the native side
/// captured, so a later feature can mine it without a schema change.
class DeviceEvent {
  final DateTime time;
  final String source; // gatt | classic | watch-app | keepalive | scan
  final String device;
  final String kind;
  final Map<String, dynamic> data;

  const DeviceEvent({
    required this.time,
    required this.source,
    required this.device,
    required this.kind,
    required this.data,
  });

  factory DeviceEvent.fromMap(Map<dynamic, dynamic> m) => DeviceEvent(
        time: DateTime.fromMillisecondsSinceEpoch((m['ts'] as num?)?.toInt() ?? 0),
        source: '${m['source'] ?? ''}',
        device: '${m['device'] ?? ''}',
        kind: '${m['kind'] ?? ''}',
        data: m['data'] is Map ? Map<String, dynamic>.from(m['data'] as Map) : const {},
      );

  Map<String, dynamic> toJson() => {
        'ts': time.millisecondsSinceEpoch,
        'source': source,
        'device': device,
        'kind': kind,
        'data': data,
      };

  /// Short human line for the live log.
  String get summary {
    switch (kind) {
      case 'data':
        final parsed = data['parsed'];
        final label = data['name'] ?? data['char'];
        return '$label  ${parsed ?? data['text'] ?? data['hex']}${parsed != null ? '   (${data['hex']})' : ''}';
      case 'notification':
        return [data['title'], data['text'] ?? data['bigText']].where((e) => e != null && '$e'.isNotEmpty).join(' · ');
      case 'broadcast':
        final rest = Map<String, dynamic>.from(data)..remove('action');
        return '${data['action']}  ${rest.isEmpty ? '' : jsonEncode(rest)}';
      case 'services':
        final n = (data['services'] as List?)?.length ?? 0;
        return '$n GATT services discovered';
      default:
        return data.isEmpty ? kind : '$kind  ${jsonEncode(data)}';
    }
  }
}

/// Wrapper around the `arcane/devices` channel (DevicesBridge.kt). Android only.
class DevicesService extends ChangeNotifier {
  DevicesService._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'event' && call.arguments is Map) {
        final e = DeviceEvent.fromMap(call.arguments as Map);
        if (e.kind == 'scanResult') {
          _scan[e.device] = e;
        } else if (e.kind == 'scanStopped') {
          scanning = false;
        } else {
          events.insert(0, e);
          if (events.length > 800) events.removeRange(800, events.length);
          if (e.source == 'gatt' && (e.kind == 'connected' || e.kind == 'disconnected')) refreshBonded();
        }
        notifyListeners();
      }
      return null;
    });
  }

  static final DevicesService instance = DevicesService._();
  static const MethodChannel _channel = MethodChannel('arcane/devices');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  Map<String, dynamic> state = const {};
  List<Map<String, dynamic>> bonded = const [];
  final Map<String, DeviceEvent> _scan = {};
  final List<DeviceEvent> events = [];
  bool scanning = false;

  List<DeviceEvent> get scanResults {
    final l = _scan.values.toList()
      ..sort((a, b) => ((b.data['rssi'] as num?) ?? -999).compareTo((a.data['rssi'] as num?) ?? -999));
    return l;
  }

  Future<T?> _call<T>(String method, [Map<String, dynamic>? args]) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e) {
      debugPrint('[DevicesService] $method failed: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    final raw = await _call<Map<dynamic, dynamic>>('getState');
    if (raw != null) state = Map<String, dynamic>.from(raw);
    await refreshBonded();
    notifyListeners();
  }

  Future<void> refreshBonded() async {
    final raw = await _call<List<dynamic>>('getBonded');
    bonded = raw == null ? const [] : raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    notifyListeners();
  }

  Future<void> loadLog() async {
    final raw = await _call<List<dynamic>>('readLog', {'limit': 500});
    if (raw == null) return;
    final loaded = <DeviceEvent>[];
    for (final line in raw) {
      try {
        loaded.add(DeviceEvent.fromMap(jsonDecode('$line') as Map));
      } catch (_) {}
    }
    events
      ..clear()
      ..addAll(loaded.reversed);
    notifyListeners();
  }

  Future<void> clearLog() async {
    await _call<bool>('clearLog');
    events.clear();
    notifyListeners();
  }

  Future<bool> requestPermissions() async {
    final ok = await _call<bool>('requestPermissions') ?? false;
    await refresh();
    return ok;
  }

  Future<void> startScan() async {
    _scan.clear();
    scanning = await _call<bool>('startScan') ?? false;
    notifyListeners();
  }

  Future<void> stopScan() async {
    await _call<bool>('stopScan');
    scanning = false;
    notifyListeners();
  }

  Future<bool> connect(String address) async {
    final ok = await _call<bool>('connect', {'address': address}) ?? false;
    await refresh();
    return ok;
  }

  Future<void> disconnect(String address) async {
    await _call<bool>('disconnect', {'address': address});
    await refresh();
  }

  bool isConnected(String address) => ((state['connected'] as List?) ?? const []).contains(address);

  // ── Watch companion app ──
  Map<String, dynamic> get watch => state['watch'] is Map ? Map<String, dynamic>.from(state['watch'] as Map) : const {};

  Future<void> setWatchApp(String package) async {
    await _call<bool>('setWatchApp', {'package': package});
    await refresh();
  }

  Future<void> setKeepAlive(bool enabled) async {
    await _call<bool>('setKeepAlive', {'enabled': enabled});
    await refresh();
  }

  Future<bool> restartWatchApp() async => await _call<bool>('restartWatchApp') ?? false;
  Future<void> openListenerSettings() => _call<bool>('openListenerSettings');
  Future<void> openOverlaySettings() => _call<bool>('openOverlaySettings');
  Future<void> openBatterySettings() => _call<bool>('openBatterySettings');
  Future<void> openUsageAccess() => _call<bool>('openUsageAccess');
  Future<void> openAppSettings(String package) => _call<bool>('openAppSettings', {'package': package});

  /// The whole log as JSON lines, for sharing / pasting.
  String exportLog() => events.reversed.map((e) => jsonEncode(e.toJson())).join('\n');
}
