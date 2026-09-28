import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper around the `arcane/launcher` platform channel (see LauncherBridge.kt).
/// Every call degrades to a harmless default off-Android so web/desktop builds still run.
class LauncherNative {
  LauncherNative._();

  static const MethodChannel _channel = MethodChannel('arcane/launcher');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Fired when the user presses HOME while Arcane is the default launcher.
  static final ValueNotifier<int> homePressed = ValueNotifier<int>(0);

  /// Whether the latest [homePressed] came from the takeover service (skip all animation).
  static bool lastHomeInstant = false;

  /// Fired when the activity is re-entered from a non-home intent (app icon, widget deep link, assistant).
  static final ValueNotifier<int> openArcaneRequested = ValueNotifier<int>(0);

  /// Fired with the changed package name when apps are installed / removed / updated.
  static final ValueNotifier<String?> packagesChanged = ValueNotifier<String?>(null);

  /// A widget pinned via AppWidgetManager.requestPinAppWidget, already bound (`id`, `provider`, `label`, …).
  static final ValueNotifier<Map<String, dynamic>?> widgetPinned = ValueNotifier<Map<String, dynamic>?>(null);

  /// A shortcut pinned to Arcane (Chrome "Install app" / "Add to Home screen").
  static final ValueNotifier<Map<String, dynamic>?> shortcutPinned = ValueNotifier<Map<String, dynamic>?>(null);

  static bool _attached = false;

  static void attach() {
    if (_attached || !isSupported) return;
    _attached = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'homePressed':
          final args = call.arguments;
          lastHomeInstant = args is Map && args['instant'] == true;
          homePressed.value++;
          break;
        case 'openArcane':
          openArcaneRequested.value++;
          break;
        case 'shortcutPinned':
          if (call.arguments is Map) shortcutPinned.value = Map<String, dynamic>.from(call.arguments as Map);
          break;
        case 'widgetPinned':
          if (call.arguments is Map) widgetPinned.value = Map<String, dynamic>.from(call.arguments as Map);
          break;
        case 'packagesChanged':
          // Force a notification even when the same package changes twice in a row.
          packagesChanged.value = null;
          packagesChanged.value = (call.arguments as String?) ?? '';
          break;
      }
      return null;
    });
  }

  static Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e) {
      debugPrint('[LauncherNative] $method failed: $e');
      return null;
    }
  }

  static Future<String> launchMode() async => await _invoke<String>('getLaunchMode') ?? 'app';
  static Future<bool> isDefaultLauncher() async => await _invoke<bool>('isDefaultLauncher') ?? false;
  static Future<bool> openHomeSettings() async => await _invoke<bool>('openHomeSettings') ?? false;

  /// True when Arcane is the default home app, or the takeover mode is on and its service is running.
  static Future<bool> actsAsHome() async => await _invoke<bool>('actsAsHome') ?? false;

  // ── Takeover mode (MIUI / HyperOS: open over the stock launcher) ──
  static Future<Map<String, dynamic>> getTakeoverStatus() async {
    final raw = await _invoke<Map<dynamic, dynamic>>('getTakeoverStatus');
    return raw == null ? const {} : Map<String, dynamic>.from(raw);
  }

  static Future<void> setTakeoverEnabled(bool enabled) => _invoke<bool>('setTakeoverEnabled', {'enabled': enabled});
  // ── Floating task button (drawn by the same accessibility service) ──
  static Future<Map<String, dynamic>> getTaskBubbleStatus() async {
    final raw = await _invoke<Map<dynamic, dynamic>>('getTaskBubbleStatus');
    return raw == null ? const {} : Map<String, dynamic>.from(raw);
  }

  static Future<void> setTaskBubbleEnabled(bool enabled) => _invoke<bool>('setTaskBubbleEnabled', {'enabled': enabled});
  static Future<bool> openAccessibilitySettings() async => await _invoke<bool>('openAccessibilitySettings') ?? false;

  /// [page]: `autostart` or `permissions` (background pop-up windows).
  static Future<bool> openMiuiPermissions(String page) async =>
      await _invoke<bool>('openMiuiPermissions', {'page': page}) ?? false;

  static Future<List<Map<String, dynamic>>> getApps() async {
    final raw = await _invoke<List<dynamic>>('getApps');
    if (raw == null) return const [];
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  /// Role → package the system resolves for it (phone, messages, browser, camera, email).
  static Future<Map<String, String>> getDefaultApps() async {
    final raw = await _invoke<Map<dynamic, dynamic>>('getDefaultApps');
    if (raw == null) return const {};
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (v is String && v.isNotEmpty) out['$k'] = v;
    });
    return out;
  }

  /// [items]: `{key, kind, package, activity|shortcutId, user}` maps. Returns key → PNG bytes.
  static Future<Map<String, Uint8List?>> getAppIcons(List<Map<String, Object?>> items, {int size = 144}) async {
    final raw = await _invoke<Map<dynamic, dynamic>>('getAppIcons', {'items': items, 'size': size});
    if (raw == null) return const {};
    return raw.map((k, v) => MapEntry(k as String, v as Uint8List?));
  }

  static Future<bool> launchApp(String package, String? activity, {int user = -1}) async =>
      await _invoke<bool>('launchApp', {'package': package, 'activity': activity, 'user': user}) ?? false;

  // ── Shortcuts (Chrome web apps, pinned + per-app shortcuts) ──
  /// False unless Arcane is the default home app (Android only lets that app read shortcuts).
  static Future<bool> shortcutsAvailable() async => await _invoke<bool>('shortcutsAvailable') ?? false;

  static Future<List<Map<String, dynamic>>> getPinnedShortcuts() async {
    final raw = await _invoke<List<dynamic>>('getPinnedShortcuts');
    if (raw == null) return const [];
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  static Future<List<Map<String, dynamic>>> getAppShortcuts(String package, {int user = -1}) async {
    final raw = await _invoke<List<dynamic>>('getAppShortcuts', {'package': package, 'user': user});
    if (raw == null) return const [];
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  static Future<bool> launchShortcut(String package, String id, {int user = -1}) async =>
      await _invoke<bool>('launchShortcut', {'package': package, 'id': id, 'user': user}) ?? false;
  static Future<bool> unpinShortcut(String package, String id, {int user = -1}) async =>
      await _invoke<bool>('unpinShortcut', {'package': package, 'id': id, 'user': user}) ?? false;
  static Future<bool> openUrl(String url) async => await _invoke<bool>('openUrl', {'url': url}) ?? false;
  static Future<bool> appInfo(String package) async => await _invoke<bool>('appInfo', {'package': package}) ?? false;
  static Future<bool> uninstall(String package) async => await _invoke<bool>('uninstall', {'package': package}) ?? false;
  static Future<bool> expandNotifications() async => await _invoke<bool>('expandNotifications') ?? false;
  static Future<bool> expandQuickSettings() async => await _invoke<bool>('expandQuickSettings') ?? false;
  static Future<bool> openWebSearch(String query) async =>
      await _invoke<bool>('openWebSearch', {'query': query}) ?? false;

  // ── Icon packs ──────────────────────────────────────────────
  static Future<List<Map<String, String>>> getIconPacks() async {
    final raw = await _invoke<List<dynamic>>('getIconPacks');
    if (raw == null) return const [];
    return raw.whereType<Map>().map((m) => m.map((k, v) => MapEntry('$k', '$v'))).toList();
  }

  /// Returns `(componentMap, drawableNames)` where componentMap is `"pkg/activity" → drawable`.
  static Future<(Map<String, String>, List<String>)> getIconPack(String pack) async {
    final raw = await _invoke<Map<dynamic, dynamic>>('getIconPack', {'pack': pack});
    if (raw == null) return (const <String, String>{}, const <String>[]);
    final map = (raw['map'] as Map? ?? const {}).map((k, v) => MapEntry('$k', '$v'));
    final drawables = (raw['drawables'] as List? ?? const []).map((e) => '$e').toList();
    return (map, drawables);
  }

  static Future<Map<String, Uint8List?>> getIconPackIcons(String pack, List<String> names, {int size = 144}) async {
    final raw = await _invoke<Map<dynamic, dynamic>>('getIconPackIcons', {'pack': pack, 'names': names, 'size': size});
    if (raw == null) return const {};
    return raw.map((k, v) => MapEntry(k as String, v as Uint8List?));
  }

  // ── System quick controls ───────────────────────────────────
  static Future<Map<String, bool>> getSystemStatus() async {
    final raw = await _invoke<Map<dynamic, dynamic>>('getSystemStatus');
    if (raw == null) return const {};
    return raw.map((k, v) => MapEntry('$k', v == true));
  }

  static Future<bool> openSystemPanel(String panel) async =>
      await _invoke<bool>('openSystemPanel', {'panel': panel}) ?? false;
  static Future<bool> setTorch(bool on) async => await _invoke<bool>('setTorch', {'on': on}) ?? false;

  // ── AppWidgets ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getWidgetProviders() async {
    final raw = await _invoke<List<dynamic>>('getWidgetProviders');
    if (raw == null) return const [];
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  static Future<Uint8List?> getWidgetPreview(String provider, {int size = 360}) =>
      _invoke<Uint8List>('getWidgetPreview', {'provider': provider, 'size': size});

  /// Runs the full bind (+ permission prompt) and configure flow. Null when cancelled.
  static Future<Map<String, dynamic>?> addWidget(String provider) async {
    final raw = await _invoke<Map<dynamic, dynamic>>('addWidget', {'provider': provider});
    return raw == null ? null : Map<String, dynamic>.from(raw);
  }

  static Future<void> removeWidget(int id) => _invoke<bool>('removeWidget', {'id': id});

  static Future<Map<String, dynamic>?> getWidgetInfo(int id) async {
    final raw = await _invoke<Map<dynamic, dynamic>>('getWidgetInfo', {'id': id});
    return raw == null ? null : Map<String, dynamic>.from(raw);
  }

  static Future<bool> reconfigureWidget(int id) async =>
      await _invoke<bool>('reconfigureWidget', {'id': id}) ?? false;
}
