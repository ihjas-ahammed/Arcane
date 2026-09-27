import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where [LauncherService.iconFor] says an app's icon should come from.
@immutable
class LauncherIconSpec {
  /// Original icon of this app key (`package/activity`).
  final String? appKey;

  /// Icon-pack drawable.
  final String? pack;
  final String? drawable;

  /// Built-in glyph key.
  final String? glyph;

  const LauncherIconSpec.app(String this.appKey)
      : pack = null,
        drawable = null,
        glyph = null;
  const LauncherIconSpec.pack(String this.pack, String this.drawable)
      : appKey = null,
        glyph = null;
  const LauncherIconSpec.glyph(String this.glyph)
      : appKey = null,
        pack = null,
        drawable = null;

  @override
  bool operator ==(Object other) =>
      other is LauncherIconSpec &&
      other.appKey == appKey &&
      other.pack == pack &&
      other.drawable == drawable &&
      other.glyph == glyph;

  @override
  int get hashCode => Object.hash(appKey, pack, drawable, glyph);
}

/// Launcher state: installed apps, dock, hosted widgets, icon pack + per-app icon choices,
/// hidden apps and launch statistics. Everything is persisted and restored instantly at boot,
/// then refreshed from the package manager in the background.
class LauncherService {
  LauncherService._();
  static final LauncherService instance = LauncherService._();

  static const _kApps = 'launcher_v4_apps';
  static const _kDock = 'launcher_v4_dock';
  static const _kWidgets = 'launcher_v4_widgets';
  static const _kIconPack = 'launcher_v4_icon_pack';
  static const _kOverrides = 'launcher_v4_icon_overrides';
  static const _kHidden = 'launcher_v4_hidden';
  static const _kStats = 'launcher_v4_stats';

  static const int maxDockSlots = 6;

  /// All launchable apps, sorted by label. Arcane is always present.
  final ValueNotifier<List<LauncherApp>> apps = ValueNotifier<List<LauncherApp>>(const [LauncherApp.arcane]);

  /// Dock app keys, left → right.
  final ValueNotifier<List<String>> dock = ValueNotifier<List<String>>(const []);

  /// Android AppWidgets on the home screen, top → bottom.
  final ValueNotifier<List<LauncherWidgetEntry>> widgets = ValueNotifier<List<LauncherWidgetEntry>>(const []);

  final ValueNotifier<Set<String>> hidden = ValueNotifier<Set<String>>(const {});

  /// Active icon pack package (null = original icons).
  final ValueNotifier<String?> iconPack = ValueNotifier<String?>(null);

  /// Bumped whenever icon resolution changes (pack switched, override set, pack map loaded).
  final ValueNotifier<int> iconsRevision = ValueNotifier<int>(0);

  Map<String, LauncherIconOverride> _overrides = {};
  Map<String, String> _packMap = const {};
  final Map<String, List<int>> _stats = {}; // key → [launchCount, lastLaunchedMillis]
  Map<String, LauncherApp> _byKey = {LauncherApp.arcane.key: LauncherApp.arcane};
  SharedPreferences? _prefs;
  Future<void>? _initFuture;
  Timer? _statsSave;
  bool _dockConfigured = false;

  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    final prefs = _prefs = await SharedPreferences.getInstance();

    _setApps(_decodeList(prefs.getString(_kApps)).map(LauncherApp.fromJson).toList());

    final savedDock = prefs.getStringList(_kDock);
    if (savedDock != null) {
      _dockConfigured = true;
      dock.value = List.unmodifiable(savedDock);
    } else {
      dock.value = [LauncherApp.arcane.key];
    }

    widgets.value = List.unmodifiable(_decodeList(prefs.getString(_kWidgets)).map(LauncherWidgetEntry.fromJson));
    hidden.value = Set.unmodifiable(prefs.getStringList(_kHidden) ?? const <String>[]);
    iconPack.value = prefs.getString(_kIconPack);

    final rawOverrides = _decodeMap(prefs.getString(_kOverrides));
    _overrides = {};
    for (final e in rawOverrides.entries) {
      final v = e.value;
      if (v is! Map) continue;
      final o = LauncherIconOverride.fromJson(Map<String, dynamic>.from(v));
      if (o != null) _overrides[e.key] = o;
    }

    _decodeMap(prefs.getString(_kStats)).forEach((k, v) {
      if (v is List && v.length == 2) _stats[k] = [(v[0] as num).toInt(), (v[1] as num).toInt()];
    });

    LauncherNative.attach();
    LauncherNative.packagesChanged.addListener(_onPackagesChanged);
    LauncherNative.widgetPinned.addListener(_onWidgetPinned);

    // Background refreshes; the cached state above is already on screen.
    unawaited(refreshApps());
    if (iconPack.value != null) unawaited(_loadPackMap(iconPack.value!));
  }

  static List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {}
    return const [];
  }

  static Map<String, dynamic> _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
  }

  void _setApps(List<LauncherApp> list) {
    final byKey = <String, LauncherApp>{for (final a in list) if (a.package.isNotEmpty) a.key: a};
    if (!byKey.values.any((a) => a.isArcane)) byKey[LauncherApp.arcane.key] = LauncherApp.arcane;
    final sorted = byKey.values.toList()
      ..sort((a, b) => a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase()));
    _byKey = byKey;
    apps.value = List.unmodifiable(sorted);
  }

  LauncherApp? appForKey(String key) => _byKey[key];

  LauncherApp get arcaneApp => apps.value.firstWhere((a) => a.isArcane, orElse: () => LauncherApp.arcane);

  // ── App discovery ───────────────────────────────────────────

  final ValueNotifier<String?> iconInvalidations = ValueNotifier<String?>(null);

  void _onPackagesChanged() {
    final pkg = LauncherNative.packagesChanged.value;
    if (pkg == null) return;
    iconInvalidations.value = null;
    iconInvalidations.value = pkg;
    unawaited(refreshApps());
  }

  Future<void> refreshApps() async {
    if (!LauncherNative.isSupported) return;
    final raw = await LauncherNative.getApps();
    if (raw.isEmpty) return;
    final list = raw.map(LauncherApp.fromJson).where((a) => a.package.isNotEmpty).toList();
    _setApps(list);
    unawaited(_prefs?.setString(_kApps, jsonEncode(list.map((a) => a.toJson()).toList())));

    // Drop dock slots / hidden entries whose app was uninstalled.
    final validDock = dock.value.where(_byKey.containsKey).toList();
    if (!_dockConfigured) {
      await _buildDefaultDock();
    } else if (validDock.length != dock.value.length) {
      _saveDock(validDock);
    }
  }

  Future<void> _buildDefaultDock() async {
    final roles = await LauncherNative.getDefaultApps();
    LauncherApp? byPackage(String? pkg) {
      if (pkg == null) return null;
      for (final a in apps.value) {
        if (a.package == pkg) return a;
      }
      return null;
    }

    final slots = <String>[];
    void add(LauncherApp? a) {
      if (a != null && !slots.contains(a.key)) slots.add(a.key);
    }

    add(byPackage(roles['phone']));
    add(byPackage(roles['messages']));
    add(arcaneApp);
    add(byPackage(roles['browser']));
    add(byPackage(roles['camera']));
    _saveDock(slots);
  }

  // ── Dock ────────────────────────────────────────────────────

  void _saveDock(List<String> keys) {
    _dockConfigured = true;
    dock.value = List.unmodifiable(keys.take(maxDockSlots));
    unawaited(_prefs?.setStringList(_kDock, dock.value));
  }

  void setDockSlot(int index, String appKey) {
    final next = List<String>.from(dock.value);
    final existing = next.indexOf(appKey);
    if (index < next.length) {
      if (existing >= 0 && existing != index) next[existing] = next[index];
      next[index] = appKey;
    } else if (existing < 0) {
      next.add(appKey);
    }
    _saveDock(next);
  }

  void removeDockSlot(int index) {
    if (index < 0 || index >= dock.value.length) return;
    _saveDock(List<String>.from(dock.value)..removeAt(index));
  }

  void moveDockSlot(int from, int to) {
    final next = List<String>.from(dock.value);
    if (from < 0 || from >= next.length) return;
    final item = next.removeAt(from);
    next.insert(to.clamp(0, next.length), item);
    _saveDock(next);
  }

  // ── Hidden apps ─────────────────────────────────────────────

  void setHidden(String appKey, bool hide) {
    final next = Set<String>.from(hidden.value);
    hide ? next.add(appKey) : next.remove(appKey);
    hidden.value = Set.unmodifiable(next);
    unawaited(_prefs?.setStringList(_kHidden, next.toList()));
  }

  // ── Icons ───────────────────────────────────────────────────

  LauncherIconOverride? overrideFor(String appKey) => _overrides[appKey];

  /// Resolution order: explicit choice → active icon pack → the app's original icon.
  LauncherIconSpec iconFor(LauncherApp app) {
    final o = _overrides[app.key];
    if (o != null) {
      switch (o.source) {
        case LauncherIconSource.pack:
          return LauncherIconSpec.pack(o.pack!, o.drawable!);
        case LauncherIconSource.app:
          return LauncherIconSpec.app(o.appKey!);
        case LauncherIconSource.glyph:
          return LauncherIconSpec.glyph(o.glyph!);
      }
    }
    final pack = iconPack.value;
    if (pack != null) {
      final drawable = _packMap[app.key];
      if (drawable != null) return LauncherIconSpec.pack(pack, drawable);
    }
    return LauncherIconSpec.app(app.key);
  }

  void setIconOverride(String appKey, LauncherIconOverride? override) {
    if (override == null) {
      _overrides.remove(appKey);
    } else {
      _overrides[appKey] = override;
    }
    iconsRevision.value++;
    unawaited(_prefs?.setString(
      _kOverrides,
      jsonEncode({for (final e in _overrides.entries) e.key: e.value.toJson()}),
    ));
  }

  Future<void> setIconPack(String? pack) async {
    iconPack.value = pack;
    _packMap = const {};
    iconsRevision.value++;
    if (pack == null) {
      await _prefs?.remove(_kIconPack);
    } else {
      await _prefs?.setString(_kIconPack, pack);
      await _loadPackMap(pack);
    }
  }

  Future<void> _loadPackMap(String pack) async {
    final (map, _) = await LauncherNative.getIconPack(pack);
    if (iconPack.value != pack) return;
    _packMap = map;
    iconsRevision.value++;
  }

  // ── Widgets ─────────────────────────────────────────────────

  /// Runs the Android bind/configure flow for [provider] and places the widget on the home screen.
  Future<LauncherWidgetEntry?> addWidget(Map<String, dynamic> provider) async {
    final result = await LauncherNative.addWidget(provider['provider'] as String);
    if (result == null) return null;
    return _placeWidget(result);
  }

  void _onWidgetPinned() {
    final result = LauncherNative.widgetPinned.value;
    if (result != null) _placeWidget(result);
  }

  LauncherWidgetEntry _placeWidget(Map<String, dynamic> result) {
    final id = (result['id'] as num).toInt();
    for (final w in widgets.value) {
      if (w.id == id) return w;
    }
    final minHeight = (result['minHeight'] as num?)?.toDouble() ?? 110;
    final entry = LauncherWidgetEntry(
      id: id,
      provider: result['provider'] as String? ?? '',
      label: result['label'] as String? ?? '',
      height: minHeight.clamp(72, 420).toDouble(),
    );
    _saveWidgets([...widgets.value, entry]);
    return entry;
  }

  void removeWidget(LauncherWidgetEntry entry) {
    unawaited(LauncherNative.removeWidget(entry.id));
    _saveWidgets(widgets.value.where((w) => w.id != entry.id).toList());
  }

  void resizeWidget(LauncherWidgetEntry entry, double height) {
    _saveWidgets([for (final w in widgets.value) w.id == entry.id ? w.copyWith(height: height.clamp(72, 560).toDouble()) : w]);
  }

  void moveWidget(LauncherWidgetEntry entry, int delta) {
    final list = List<LauncherWidgetEntry>.from(widgets.value);
    final i = list.indexWhere((w) => w.id == entry.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= list.length) return;
    list.insert(j, list.removeAt(i));
    _saveWidgets(list);
  }

  void _saveWidgets(List<LauncherWidgetEntry> list) {
    widgets.value = List.unmodifiable(list);
    unawaited(_prefs?.setString(_kWidgets, jsonEncode(list.map((w) => w.toJson()).toList())));
  }

  // ── Launching & usage ───────────────────────────────────────

  Future<bool> launch(LauncherApp app) {
    _recordLaunch(app.key);
    return LauncherNative.launchApp(app.package, app.activity);
  }

  void _recordLaunch(String key) {
    final s = _stats[key] ?? [0, 0];
    _stats[key] = [s[0] + 1, DateTime.now().millisecondsSinceEpoch];
    _statsSave?.cancel();
    _statsSave = Timer(const Duration(seconds: 2), () {
      unawaited(_prefs?.setString(_kStats, jsonEncode(_stats)));
    });
  }

  void recordArcaneOpen() => _recordLaunch(arcaneApp.key);

  /// Frequently + recently used apps (frecency), excluding hidden ones.
  List<LauncherApp> suggestions({int limit = 5}) {
    if (_stats.isEmpty) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    double score(List<int> s) {
      final ageHours = (now - s[1]) / 3600000.0;
      return s[0] / (1 + ageHours / 24);
    }

    final hiddenKeys = hidden.value;
    final ranked = _stats.entries.where((e) => _byKey.containsKey(e.key) && !hiddenKeys.contains(e.key)).toList()
      ..sort((a, b) => score(b.value).compareTo(score(a.value)));
    return ranked.take(limit).map((e) => _byKey[e.key]!).toList();
  }

  /// Label search: prefix matches first, then word-start, then substring.
  List<LauncherApp> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    int rank(LauncherApp a) {
      final l = a.displayLabel.toLowerCase();
      if (l.startsWith(q)) return 0;
      if (l.contains(' $q')) return 1;
      if (l.contains(q)) return 2;
      if (a.package.toLowerCase().contains(q)) return 3;
      return 9;
    }

    final hits = <(int, LauncherApp)>[];
    for (final a in apps.value) {
      final r = rank(a);
      if (r < 9) hits.add((r, a));
    }
    hits.sort((x, y) => x.$1 != y.$1 ? x.$1.compareTo(y.$1) : x.$2.displayLabel.compareTo(y.$2.displayLabel));
    return hits.map((h) => h.$2).toList();
  }
}
