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

/// Launcher state: installed apps (+ pinned shortcuts, web links, other profiles), the dock,
/// home and shelf app areas, folders, hosted widgets, icon pack + per-app icon choices, hidden
/// apps and launch statistics. Everything is persisted and restored instantly at boot, then
/// refreshed from the package manager in the background.
class LauncherService {
  LauncherService._();
  static LauncherService _instance = LauncherService._();
  static LauncherService get instance => _instance;

  @visibleForTesting
  static void resetForTest() {
    _instance = LauncherService._();
  }

  static const _kApps = 'launcher_v4_apps';
  static const _kDock = 'launcher_v4_dock';
  static const _kHome = 'launcher_v4_home';
  static const _kHomePages = 'launcher_v4_home_pages';
  static const _kShelf = 'launcher_v4_shelf';
  static const _kDrawerFolders = 'launcher_v4_drawer_folders';
  static const _kFolders = 'launcher_v4_folders';
  static const _kWeb = 'launcher_v4_web';
  static const _kWidgets = 'launcher_v4_widgets';
  static const _kIconPack = 'launcher_v4_icon_pack';
  static const _kOverrides = 'launcher_v4_icon_overrides';
  static const _kHidden = 'launcher_v4_hidden';
  static const _kStats = 'launcher_v4_stats';
  static const _kFullscreen = 'launcher_v4_fullscreen';
  static const _kNotes = 'arcane_launcher_quick_notes';
  static const _kCountryCode = 'launcher_v4_country_code';

  VoidCallback? onLauncherChanged;
  void _notifyChanged() => onLauncherChanged?.call();

  static const int maxDockSlots = 6;
  static const int maxHomeItems = 40;

  /// All launchable entries, sorted by label. Arcane is always present.
  final ValueNotifier<List<LauncherApp>> apps = ValueNotifier<List<LauncherApp>>(const [LauncherApp.arcane]);

  /// Dock keys (apps or `folder:` keys), left → right.
  final ValueNotifier<List<String>> dock = ValueNotifier<List<String>>(const []);

  /// App/folder keys placed on the home page, in grid order.
  final ValueNotifier<List<String>> home = ValueNotifier<List<String>>(const []);

  /// App/folder keys partitioned per home page: [page0_keys, page1_keys, ...].
  final ValueNotifier<List<List<String>>> homePages = ValueNotifier<List<List<String>>>([const []]);

  /// Active home page index (0-indexed, where 0 is the primary home screen).
  final ValueNotifier<int> activeHomePage = ValueNotifier<int>(0);

  /// App/folder keys on the Arcane widgets page's quick-app shelf.
  final ValueNotifier<List<String>> shelf = ValueNotifier<List<String>>(const []);

  /// Folder keys shown at the top of the app drawer.
  final ValueNotifier<List<String>> drawerFolders = ValueNotifier<List<String>>(const []);

  final ValueNotifier<Map<String, LauncherFolder>> folders = ValueNotifier<Map<String, LauncherFolder>>(const {});

  /// Android AppWidgets on the home screen, top → bottom.
  final ValueNotifier<List<LauncherWidgetEntry>> widgets = ValueNotifier<List<LauncherWidgetEntry>>(const []);

  final ValueNotifier<Set<String>> hidden = ValueNotifier<Set<String>>(const {});

  /// Active icon pack package (null = original icons).
  final ValueNotifier<String?> iconPack = ValueNotifier<String?>(null);

  /// Bumped whenever icon resolution changes (pack switched, override set, pack map loaded).
  final ValueNotifier<int> iconsRevision = ValueNotifier<int>(0);

  /// Hide the status and navigation bars while the launcher surface is showing (on by default).
  final ValueNotifier<bool> fullscreen = ValueNotifier<bool>(true);

  /// Default international country code without '+' (defaults to '91' for India, user configurable).
  final ValueNotifier<String> defaultCountryCode = ValueNotifier<String>('91');

  /// Whether Android lets Arcane read pinned shortcuts (only as the default home app).
  final ValueNotifier<bool> shortcutsAvailable = ValueNotifier<bool>(false);

  Map<String, LauncherIconOverride> _overrides = {};
  Map<String, String> _packMap = const {};
  final Map<String, List<int>> _stats = {}; // key → [launchCount, lastLaunchedMillis]
  Map<String, LauncherApp> _byKey = {LauncherApp.arcane.key: LauncherApp.arcane};
  List<LauncherApp> _systemApps = const [];
  List<LauncherApp> _shortcuts = const [];
  List<LauncherApp> _webLinks = const [];
  String _quickNotes = '';
  String get quickNotes => _quickNotes;

  void setQuickNotes(String notes) {
    _quickNotes = notes;
    unawaited(_prefs?.setString(_kNotes, notes));
    _notifyChanged();
  }

  SharedPreferences? _prefs;
  Future<void>? _initFuture;
  Timer? _statsSave;
  bool _dockConfigured = false;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    await (_initFuture ??= _init());
    _isInitialized = true;
  }

  Future<void> _init() async {
    final prefs = _prefs = await SharedPreferences.getInstance();

    final cached = _decodeList(prefs.getString(_kApps)).map(LauncherApp.fromJson).toList();
    _systemApps = cached.where((a) => a.kind != LauncherAppKind.web).toList();
    _shortcuts = const [];
    _webLinks = _decodeList(prefs.getString(_kWeb)).map(LauncherApp.fromJson).toList();
    _quickNotes = prefs.getString(_kNotes) ?? '';
    _rebuildApps();

    final savedDock = prefs.getStringList(_kDock);
    if (savedDock != null && savedDock.isNotEmpty) {
      _dockConfigured = true;
      dock.value = List.unmodifiable(savedDock);
    } else {
      dock.value = [LauncherApp.arcane.key];
    }

    final rawHomePages = prefs.getString(_kHomePages);
    List<List<String>> loadedPages = [];
    if (rawHomePages != null && rawHomePages.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawHomePages);
        if (decoded is List) {
          loadedPages = decoded
              .whereType<List>()
              .map((p) => p.map((k) => '$k').toList())
              .toList();
        }
      } catch (_) {}
    }
    if (loadedPages.isEmpty) {
      final legacyHome = prefs.getStringList(_kHome) ?? const <String>[];
      loadedPages = [legacyHome];
    }
    homePages.value = List<List<String>>.unmodifiable(
      loadedPages.map((p) => List<String>.unmodifiable(p)),
    );
    home.value = List.unmodifiable(homePages.value.expand((p) => p).toSet().toList());

    shelf.value = List.unmodifiable(prefs.getStringList(_kShelf) ?? const <String>[]);
    drawerFolders.value = List.unmodifiable(prefs.getStringList(_kDrawerFolders) ?? const <String>[]);
    folders.value = Map.unmodifiable({
      for (final f in _decodeList(prefs.getString(_kFolders)).map(LauncherFolder.fromJson))
        if (f.id.isNotEmpty) f.key: f,
    });

    widgets.value = List.unmodifiable(_decodeList(prefs.getString(_kWidgets)).map(LauncherWidgetEntry.fromJson));
    hidden.value = Set.unmodifiable(prefs.getStringList(_kHidden) ?? const <String>[]);
    iconPack.value = prefs.getString(_kIconPack);
    fullscreen.value = prefs.getBool(_kFullscreen) ?? true;
    final savedCode = prefs.getString(_kCountryCode);
    if (savedCode != null && savedCode.trim().isNotEmpty) {
      defaultCountryCode.value = savedCode.replaceAll(RegExp(r'\D'), '');
    }

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
    LauncherNative.shortcutPinned.addListener(_onShortcutPinned);

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

  void _rebuildApps() {
    final byKey = <String, LauncherApp>{};
    for (final a in [..._systemApps, ..._shortcuts, ..._webLinks]) {
      if (a.kind == LauncherAppKind.app && a.package.isEmpty) continue;
      byKey[a.key] = a;
    }
    if (!byKey.values.any((a) => a.isArcane)) byKey[LauncherApp.arcane.key] = LauncherApp.arcane;
    final sorted = byKey.values.toList()
      ..sort((a, b) => a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase()));
    _byKey = byKey;
    apps.value = List.unmodifiable(sorted);
  }

  LauncherApp? appForKey(String key) => _byKey[key];

  LauncherFolder? folderForKey(String key) => folders.value[key];

  /// True for keys that currently resolve to something launchable or openable.
  bool isValidKey(String key) => LauncherFolder.isFolderKey(key) ? folders.value.containsKey(key) : _byKey.containsKey(key);

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

  void _onShortcutPinned() {
    final m = LauncherNative.shortcutPinned.value;
    if (m == null) return;
    final sc = LauncherApp.shortcut(
      package: m['package'] as String? ?? '',
      id: m['id'] as String? ?? '',
      label: m['label'] as String? ?? '',
      user: (m['user'] as num?)?.toInt() ?? -1,
    );
    _shortcuts = [..._shortcuts.where((s) => s.key != sc.key), sc];
    _rebuildApps();
    // Like any launcher: a freshly installed web app / shortcut lands on the home screen.
    addToArea(LauncherArea.home, sc.key);
    unawaited(refreshApps());
  }

  Future<void> refreshApps() async {
    if (!LauncherNative.isSupported) return;
    final results = await Future.wait([
      LauncherNative.getApps(),
      LauncherNative.getPinnedShortcuts(),
      LauncherNative.shortcutsAvailable(),
    ]);
    final raw = results[0] as List<Map<String, dynamic>>;
    final pinned = results[1] as List<Map<String, dynamic>>;
    shortcutsAvailable.value = results[2] as bool;
    if (raw.isEmpty) return;

    _systemApps = raw.map(LauncherApp.fromJson).where((a) => a.package.isNotEmpty).toList();
    _shortcuts = [
      for (final m in pinned)
        if (m['enabled'] != false)
          LauncherApp.shortcut(
            package: m['package'] as String? ?? '',
            id: m['id'] as String? ?? '',
            label: m['label'] as String? ?? '',
            user: (m['user'] as num?)?.toInt() ?? -1,
          ),
    ];
    _rebuildApps();
    unawaited(_prefs?.setString(_kApps, jsonEncode([..._systemApps, ..._shortcuts].map((a) => a.toJson()).toList())));

    if (!_dockConfigured) await _buildDefaultDock();
    _pruneMissing();
  }

  /// Whether a folder should auto-dissolve after a prune pass: only when it actually lost
  /// items this pass (an uninstall) and that leaves it with fewer than 2. A folder the user
  /// deliberately created with a single app — not yet grown, but untouched by this pass —
  /// is left alone, instead of vanishing on the next app refresh.
  @visibleForTesting
  static bool shouldDissolveAfterPrune({required int itemsBefore, required int itemsAfter}) =>
      itemsAfter < 2 && itemsAfter != itemsBefore;

  /// Drops uninstalled apps from every area and folder (folders left with < 2 items by an
  /// uninstall dissolve; see [shouldDissolveAfterPrune]).
  void _pruneMissing() {
    final nextFolders = <String, LauncherFolder>{};
    final dissolve = <String>{};
    for (final f in folders.value.values) {
      final kept = f.items.where(_byKey.containsKey).toList();
      nextFolders[f.key] = f.copyWith(items: kept);
      if (shouldDissolveAfterPrune(itemsBefore: f.items.length, itemsAfter: kept.length)) {
        dissolve.add(f.key);
      }
    }
    folders.value = Map.unmodifiable(nextFolders);
    for (final area in LauncherArea.values) {
      if (area == LauncherArea.home) continue;
      final list = areaList(area).value;
      final kept = list.where(isValidKey).toList();
      if (kept.length != list.length) _saveArea(area, kept);
    }
    final nextHomePages = <List<String>>[];
    for (final page in homePages.value) {
      nextHomePages.add(page.where(isValidKey).toList());
    }
    saveHomePages(nextHomePages);
    for (final key in dissolve) {
      _dissolveFolder(key);
    }
    _saveFolders();
  }

  Future<void> _buildDefaultDock() async {
    final roles = await LauncherNative.getDefaultApps();
    LauncherApp? byPackage(String? pkg) {
      if (pkg == null) return null;
      for (final a in apps.value) {
        if (a.package == pkg && a.kind == LauncherAppKind.app && !a.isOtherProfile) return a;
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
    _saveArea(LauncherArea.dock, slots);
  }

  // ── Areas (dock / home / shelf / drawer folders) ────────────

  ValueNotifier<List<String>> areaList(LauncherArea area) => switch (area) {
        LauncherArea.dock => dock,
        LauncherArea.home => home,
        LauncherArea.shelf => shelf,
        LauncherArea.drawer => drawerFolders,
      };

  int _areaCapacity(LauncherArea area) => switch (area) {
        LauncherArea.dock => maxDockSlots,
        LauncherArea.home => maxHomeItems,
        LauncherArea.shelf => 24,
        LauncherArea.drawer => 30,
      };

  int get homePageCount => homePages.value.length;

  List<String> getPageItems(int page) =>
      (page >= 0 && page < homePages.value.length) ? homePages.value[page] : const [];

  List<LauncherWidgetEntry> widgetsForPage(int page) =>
      widgets.value.where((w) => w.page == page).toList();

  void saveHomePages(List<List<String>> pages) {
    final cleanPages = pages.isEmpty ? [const <String>[]] : pages;
    homePages.value = List<List<String>>.unmodifiable(
      cleanPages.map((p) => List<String>.unmodifiable(p.take(maxHomeItems))),
    );
    home.value = List.unmodifiable(cleanPages.expand((p) => p).toSet().toList());
    unawaited(_prefs?.setString(_kHomePages, jsonEncode(homePages.value)));
    unawaited(_prefs?.setStringList(_kHome, home.value));
    _notifyChanged();
  }

  int addHomePage() {
    final current = homePages.value.map((p) => List<String>.from(p)).toList();
    current.add(<String>[]);
    saveHomePages(current);
    return current.length - 1;
  }

  void removeHomePage(int page) {
    if (page <= 0 || page >= homePages.value.length) return;
    final current = homePages.value.map((p) => List<String>.from(p)).toList();
    final removedItems = current.removeAt(page);
    final targetPage = (page - 1).clamp(0, current.length - 1);
    if (removedItems.isNotEmpty && current.isNotEmpty) {
      for (final item in removedItems) {
        if (!current[targetPage].contains(item) && current[targetPage].length < maxHomeItems) {
          current[targetPage].add(item);
        }
      }
    }
    final nextWidgets = widgets.value.map((w) {
      if (w.page == page) {
        return w.copyWith(page: (page - 1).clamp(0, current.length - 1));
      } else if (w.page > page) {
        return w.copyWith(page: w.page - 1);
      }
      return w;
    }).toList();
    widgets.value = List.unmodifiable(nextWidgets);
    unawaited(_prefs?.setString(_kWidgets, jsonEncode(nextWidgets.map((w) => w.toJson()).toList())));
    saveHomePages(current);
  }

  void pruneEmptyTrailingPages() {
    final current = homePages.value.map((p) => List<String>.from(p)).toList();
    var changed = false;
    while (current.length > 1) {
      final lastIdx = current.length - 1;
      final hasWidgets = widgets.value.any((w) => w.page == lastIdx);
      if (current.last.isEmpty && !hasWidgets) {
        current.removeLast();
        changed = true;
      } else {
        break;
      }
    }
    if (changed) {
      saveHomePages(current);
    }
  }

  bool addToPage(int page, String key, {int? index}) {
    final current = homePages.value.map((p) => List<String>.from(p)).toList();
    while (current.length <= page) {
      current.add(<String>[]);
    }
    for (final p in current) {
      p.remove(key);
    }
    if (current[page].length >= maxHomeItems) return false;
    final at = (index ?? current[page].length).clamp(0, current[page].length);
    current[page].insert(at, key);
    saveHomePages(current);
    return true;
  }

  void removeFromPage(int page, String key) {
    if (page < 0 || page >= homePages.value.length) return;
    final current = homePages.value.map((p) => List<String>.from(p)).toList();
    if (current[page].remove(key)) {
      saveHomePages(current);
    }
  }

  void dropOntoPage(int page, String targetKey, String dragged, {LauncherArea? from}) {
    if (targetKey == dragged) return;
    final pageItems = getPageItems(page);
    final idx = pageItems.indexOf(targetKey);
    if (idx < 0) return;

    if (LauncherFolder.isFolderKey(dragged)) {
      if (from != null && from != LauncherArea.home) removeFromArea(from, dragged);
      addToPage(page, dragged, index: idx);
      return;
    }
    if (from != null && from != LauncherArea.home) removeFromArea(from, dragged);
    if (LauncherFolder.isFolderKey(targetKey)) {
      addToFolder(targetKey, dragged);
      if (from == LauncherArea.home) removeFromArea(LauncherArea.home, dragged);
      return;
    }

    final current = homePages.value.map((p) => List<String>.from(p)).toList();
    while (current.length <= page) {
      current.add(<String>[]);
    }
    current[page].remove(dragged);
    final targetIdx = current[page].indexOf(targetKey);
    if (targetIdx < 0) return;

    final targetApp = appForKey(targetKey);
    final draggedApp = appForKey(dragged);
    final folder = _createFolder(
      [targetKey, dragged],
      name: _suggestFolderName(targetApp, draggedApp),
    );
    current[page][targetIdx] = folder.key;
    for (var i = 0; i < current.length; i++) {
      if (i != page) current[i].remove(dragged);
    }
    saveHomePages(current);
  }

  void _saveArea(LauncherArea area, List<String> keys) {
    final notifier = areaList(area);
    notifier.value = List.unmodifiable(keys.take(_areaCapacity(area)));
    final prefKey = switch (area) {
      LauncherArea.dock => _kDock,
      LauncherArea.home => _kHome,
      LauncherArea.shelf => _kShelf,
      LauncherArea.drawer => _kDrawerFolders,
    };
    if (area == LauncherArea.dock) _dockConfigured = true;
    if (area == LauncherArea.home) {
      final current = homePages.value.map((p) => List<String>.from(p)).toList();
      if (current.isEmpty) {
        current.add(List<String>.from(notifier.value));
      } else {
        current[0] = List<String>.from(notifier.value);
      }
      saveHomePages(current);
      return;
    }
    unawaited(_prefs?.setStringList(prefKey, notifier.value));
    _notifyChanged();
  }

  bool isAreaFull(LauncherArea area) => areaList(area).value.length >= _areaCapacity(area);

  /// Adds [key] to [area] (at [index], default end). Already there → moved to [index].
  bool addToArea(LauncherArea area, String key, {int? index, int? page}) {
    if (area == LauncherArea.home) {
      return addToPage(page ?? activeHomePage.value, key, index: index);
    }
    final list = List<String>.from(areaList(area).value);
    final existing = list.indexOf(key);
    if (existing >= 0) list.removeAt(existing);
    if (existing < 0 && list.length >= _areaCapacity(area)) return false;
    final at = (index ?? list.length).clamp(0, list.length);
    list.insert(at, key);
    _saveArea(area, list);
    return true;
  }

  void removeFromArea(LauncherArea area, String key) {
    if (area == LauncherArea.home) {
      final current = homePages.value.map((p) => List<String>.from(p)).toList();
      var removed = false;
      for (final page in current) {
        if (page.remove(key)) removed = true;
      }
      if (removed) {
        saveHomePages(current);
      }
      return;
    }
    final list = areaList(area).value;
    if (!list.contains(key)) return;
    _saveArea(area, list.where((k) => k != key).toList());
  }

  /// Dock compatibility helpers used by the dock editor.
  void setDockSlot(int index, String key) {
    final next = List<String>.from(dock.value);
    final existing = next.indexOf(key);
    if (index < next.length) {
      if (existing >= 0 && existing != index) next[existing] = next[index];
      next[index] = key;
    } else if (existing < 0) {
      next.add(key);
    }
    _saveArea(LauncherArea.dock, next);
  }

  void removeDockSlot(int index) {
    if (index < 0 || index >= dock.value.length) return;
    _saveArea(LauncherArea.dock, List<String>.from(dock.value)..removeAt(index));
  }

  void moveDockSlot(int from, int to) {
    final next = List<String>.from(dock.value);
    if (from < 0 || from >= next.length) return;
    final item = next.removeAt(from);
    next.insert(to.clamp(0, next.length), item);
    _saveArea(LauncherArea.dock, next);
  }

  /// Drag-and-drop: [dragged] dropped onto [targetKey] in [area].
  /// Folder target → added to it. App target → both become a new folder in the target's place.
  /// A move from another area (not the drawer, which copies) removes it from its origin.
  void dropOnto(LauncherArea area, String targetKey, String dragged, {LauncherArea? from, int? page}) {
    if (targetKey == dragged) return;
    if (area == LauncherArea.home) {
      dropOntoPage(page ?? activeHomePage.value, targetKey, dragged, from: from);
      return;
    }
    if (LauncherFolder.isFolderKey(dragged)) {
      // Folders don't nest: treat as a reorder next to the target.
      final idx = areaList(area).value.indexOf(targetKey);
      if (from != null && from != area) removeFromArea(from, dragged);
      addToArea(area, dragged, index: idx < 0 ? null : idx);
      return;
    }
    if (from != null && from != area) removeFromArea(from, dragged);
    if (LauncherFolder.isFolderKey(targetKey)) {
      addToFolder(targetKey, dragged);
      if (from == area) removeFromArea(area, dragged);
      return;
    }
    final list = List<String>.from(areaList(area).value)..remove(dragged);
    final idx = list.indexOf(targetKey);
    if (idx < 0) return;
    final targetApp = appForKey(targetKey);
    final draggedApp = appForKey(dragged);
    final folder = _createFolder(
      [targetKey, dragged],
      name: _suggestFolderName(targetApp, draggedApp),
    );
    list[idx] = folder.key;
    _saveArea(area, list);
  }

  // ── Folders ─────────────────────────────────────────────────

  void _saveFolders() {
    unawaited(_prefs?.setString(_kFolders, jsonEncode(folders.value.values.map((f) => f.toJson()).toList())));
    _notifyChanged();
  }

  LauncherFolder _createFolder(List<String> items, {String name = 'Folder'}) {
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final folder = LauncherFolder(id: id, name: name, items: List.unmodifiable(items));
    folders.value = Map.unmodifiable({...folders.value, folder.key: folder});
    _saveFolders();
    return folder;
  }

  /// New empty-named folder holding [items], placed in [area].
  LauncherFolder createFolderIn(LauncherArea area, List<String> items, {required String name}) {
    final folder = _createFolder(items, name: name);
    addToArea(area, folder.key);
    return folder;
  }

  static String _suggestFolderName(LauncherApp? a, LauncherApp? b) {
    final pa = a?.package.toLowerCase() ?? '';
    final pb = b?.package.toLowerCase() ?? '';
    bool both(bool Function(String) test) => test(pa) && test(pb);
    if (both((p) => p.contains('google'))) return 'Google';
    if (both((p) => p.contains('game') || p.contains('play.games'))) return 'Games';
    if (a?.kind == LauncherAppKind.shortcut || a?.kind == LauncherAppKind.web) return 'Web';
    return 'Folder';
  }

  void addToFolder(String folderKey, String appKey) {
    final f = folders.value[folderKey];
    if (f == null || f.items.contains(appKey) || LauncherFolder.isFolderKey(appKey)) return;
    folders.value = Map.unmodifiable({...folders.value, folderKey: f.copyWith(items: [...f.items, appKey])});
    _saveFolders();
  }

  void renameFolder(String folderKey, String name) {
    final f = folders.value[folderKey];
    if (f == null) return;
    final clean = name.trim().isEmpty ? 'Folder' : name.trim();
    folders.value = Map.unmodifiable({...folders.value, folderKey: f.copyWith(name: clean)});
    _saveFolders();
  }

  void reorderFolder(String folderKey, int from, int to) {
    final f = folders.value[folderKey];
    if (f == null || from < 0 || from >= f.items.length) return;
    final items = List<String>.from(f.items);
    final item = items.removeAt(from);
    items.insert(to.clamp(0, items.length), item);
    folders.value = Map.unmodifiable({...folders.value, folderKey: f.copyWith(items: items)});
    _saveFolders();
  }

  /// Removes [appKey] from the folder. [placeIn] puts it into that area instead of dropping it.
  void removeFromFolder(String folderKey, String appKey, {LauncherArea? placeIn}) {
    final f = folders.value[folderKey];
    if (f == null) return;
    final items = f.items.where((k) => k != appKey).toList();
    folders.value = Map.unmodifiable({...folders.value, folderKey: f.copyWith(items: items)});
    if (placeIn != null) addToArea(placeIn, appKey);
    if (items.length < 2) {
      _dissolveFolder(folderKey);
    }
    _saveFolders();
  }

  /// Replaces the folder with its last item (if any) wherever it's placed, then deletes it.
  void _dissolveFolder(String folderKey) {
    final f = folders.value[folderKey];
    final remaining = f?.items.firstOrNull;
    for (final area in LauncherArea.values) {
      final list = List<String>.from(areaList(area).value);
      final i = list.indexOf(folderKey);
      if (i < 0) continue;
      if (remaining != null && area != LauncherArea.drawer && !list.contains(remaining)) {
        list[i] = remaining;
      } else {
        list.removeAt(i);
      }
      _saveArea(area, list);
    }
    folders.value = Map.unmodifiable({...folders.value}..remove(folderKey));
    _saveFolders();
  }

  /// Deletes a folder; its apps stay installed (and in the drawer).
  void deleteFolder(String folderKey) {
    final f = folders.value[folderKey];
    if (f == null) return;
    for (final area in LauncherArea.values) {
      removeFromArea(area, folderKey);
    }
    folders.value = Map.unmodifiable({...folders.value}..remove(folderKey));
    _saveFolders();
  }

  /// Keys of apps that live inside drawer folders (hidden from the drawer's A–Z list).
  Set<String> get appsInDrawerFolders => {
        for (final fk in drawerFolders.value) ...?folders.value[fk]?.items,
      };

  // ── Web links ───────────────────────────────────────────────

  void addWebLink(String url, String label) {
    var clean = url.trim();
    if (clean.isEmpty) return;
    if (!clean.contains('://')) clean = 'https://$clean';
    final link = LauncherApp.web(url: clean, label: label.trim().isEmpty ? Uri.tryParse(clean)?.host ?? clean : label.trim());
    _webLinks = [..._webLinks.where((w) => w.key != link.key), link];
    unawaited(_prefs?.setString(_kWeb, jsonEncode(_webLinks.map((w) => w.toJson()).toList())));
    _rebuildApps();
    addToArea(LauncherArea.home, link.key);
    _notifyChanged();
  }

  void removeWebLink(String key) {
    _webLinks = _webLinks.where((w) => w.key != key).toList();
    unawaited(_prefs?.setString(_kWeb, jsonEncode(_webLinks.map((w) => w.toJson()).toList())));
    _rebuildApps();
    _pruneMissing();
    _notifyChanged();
  }

  /// Unpins a pinned shortcut (Chrome web app) from Arcane.
  Future<void> removeShortcut(LauncherApp sc) async {
    await LauncherNative.unpinShortcut(sc.package, sc.shortcutId ?? '', user: sc.user);
    _shortcuts = _shortcuts.where((s) => s.key != sc.key).toList();
    _rebuildApps();
    _pruneMissing();
  }

  // ── Hidden apps ─────────────────────────────────────────────

  void setHidden(String appKey, bool hide) {
    final next = Set<String>.from(hidden.value);
    hide ? next.add(appKey) : next.remove(appKey);
    hidden.value = Set.unmodifiable(next);
    unawaited(_prefs?.setStringList(_kHidden, next.toList()));
    _notifyChanged();
  }

  // ── Icons ───────────────────────────────────────────────────

  LauncherIconOverride? overrideFor(String appKey) => _overrides[appKey];

  /// Resolution order: explicit choice → active icon pack → the entry's original icon.
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
    if (pack != null && app.kind == LauncherAppKind.app) {
      final drawable = _packMap[app.componentKey];
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
    _notifyChanged();
  }

  Future<void> setFullscreen(bool value) async {
    fullscreen.value = value;
    await (_prefs ?? await SharedPreferences.getInstance()).setBool(_kFullscreen, value);
    _notifyChanged();
  }

  Future<void> setDefaultCountryCode(String code) async {
    final clean = code.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return;
    defaultCountryCode.value = clean;
    await (_prefs ?? await SharedPreferences.getInstance()).setString(_kCountryCode, clean);
    _notifyChanged();
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
    _notifyChanged();
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

  void moveWidgetToPage(LauncherWidgetEntry entry, int targetPage) {
    if (targetPage < 0) return;
    while (homePages.value.length <= targetPage) {
      addHomePage();
    }
    _saveWidgets([
      for (final w in widgets.value)
        if (w.id == entry.id) w.copyWith(page: targetPage) else w,
    ]);
  }

  void _saveWidgets(List<LauncherWidgetEntry> list) {
    widgets.value = List.unmodifiable(list);
    unawaited(_prefs?.setString(_kWidgets, jsonEncode(list.map((w) => w.toJson()).toList())));
    _notifyChanged();
  }

  // ── Launching & usage ───────────────────────────────────────

  Future<bool> launch(LauncherApp app) {
    _recordLaunch(app.key);
    return switch (app.kind) {
      LauncherAppKind.app => LauncherNative.launchApp(app.package, app.activity, user: app.user),
      LauncherAppKind.shortcut => LauncherNative.launchShortcut(app.package, app.shortcutId ?? '', user: app.user),
      LauncherAppKind.web => LauncherNative.openUrl(app.url ?? ''),
    };
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

  /// Full serializable map of launcher configuration and state for cloud sync and backups.
  Map<String, dynamic> getStateMap() {
    if (!_isInitialized) {
      // Uninitialized: return empty map so sync_mixin never wipes cloud state with blank arrays!
      return const {};
    }
    return {
      'dock': dock.value,
      'home': home.value,
      'shelf': shelf.value,
      'drawerFolders': drawerFolders.value,
      'folders': folders.value.values.map((f) => f.toJson()).toList(),
      'widgets': widgets.value.map((w) => w.toJson()).toList(),
      'hidden': hidden.value.toList(),
      'iconPack': iconPack.value,
      'fullscreen': fullscreen.value,
      'overrides': {for (final e in _overrides.entries) e.key: e.value.toJson()},
      'webLinks': _webLinks.map((w) => w.toJson()).toList(),
      'quickNotes': _quickNotes,
      'stats': _stats,
    };
  }

  /// Restores launcher configuration and state from a cloud or backup map.
  /// If [forceReplace] is false, empty arrays in [map] will NEVER overwrite non-empty local preferences.
  Future<void> loadFromMap(Map<String, dynamic> map, {bool forceReplace = false}) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();

    if (map['dock'] is List) {
      final list = (map['dock'] as List).whereType<String>().toList();
      if (list.isNotEmpty || forceReplace) {
        dock.value = List.unmodifiable(list.isNotEmpty ? list : [LauncherApp.arcane.key]);
        await prefs.setStringList(_kDock, dock.value);
      }
    }
    if (map['home'] is List) {
      final list = (map['home'] as List).whereType<String>().toList();
      if (list.isNotEmpty || forceReplace) {
        home.value = List.unmodifiable(list);
        await prefs.setStringList(_kHome, list);
      }
    }
    if (map['shelf'] is List) {
      final list = (map['shelf'] as List).whereType<String>().toList();
      if (list.isNotEmpty || forceReplace) {
        shelf.value = List.unmodifiable(list);
        await prefs.setStringList(_kShelf, list);
      }
    }
    if (map['drawerFolders'] is List) {
      final list = (map['drawerFolders'] as List).whereType<String>().toList();
      if (list.isNotEmpty || forceReplace) {
        drawerFolders.value = List.unmodifiable(list);
        await prefs.setStringList(_kDrawerFolders, list);
      }
    }
    if (map['folders'] is List) {
      final rawFolders = (map['folders'] as List)
          .whereType<Map>()
          .map((m) => LauncherFolder.fromJson(Map<String, dynamic>.from(m)))
          .where((f) => f.id.isNotEmpty)
          .toList();
      if (rawFolders.isNotEmpty || forceReplace) {
        folders.value = Map.unmodifiable({
          for (final f in rawFolders) f.key: f,
        });
        await prefs.setString(_kFolders, jsonEncode(rawFolders.map((f) => f.toJson()).toList()));
      }
    }
    if (map['widgets'] is List) {
      final rawWidgets = (map['widgets'] as List)
          .whereType<Map>()
          .map((m) => LauncherWidgetEntry.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (rawWidgets.isNotEmpty || forceReplace) {
        widgets.value = List.unmodifiable(rawWidgets);
        await prefs.setString(_kWidgets, jsonEncode(rawWidgets.map((w) => w.toJson()).toList()));
      }
    }
    if (map['hidden'] is List) {
      final list = (map['hidden'] as List).whereType<String>().toSet();
      if (list.isNotEmpty || forceReplace) {
        hidden.value = Set.unmodifiable(list);
        await prefs.setStringList(_kHidden, list.toList());
      }
    }
    if (map.containsKey('iconPack')) {
      final pack = map['iconPack'] as String?;
      if (pack != null || forceReplace) {
        iconPack.value = pack;
        if (pack == null) {
          await prefs.remove(_kIconPack);
        } else {
          await prefs.setString(_kIconPack, pack);
          unawaited(_loadPackMap(pack));
        }
      }
    }
    if (map.containsKey('fullscreen') && map['fullscreen'] is bool) {
      final val = map['fullscreen'] as bool;
      fullscreen.value = val;
      await prefs.setBool(_kFullscreen, val);
    }
    if (map['overrides'] is Map) {
      final rawOverrides = map['overrides'] as Map;
      if (rawOverrides.isNotEmpty || forceReplace) {
        _overrides = {};
        for (final e in rawOverrides.entries) {
          if (e.value is Map) {
            final o = LauncherIconOverride.fromJson(Map<String, dynamic>.from(e.value as Map));
            if (o != null) _overrides[e.key.toString()] = o;
          }
        }
        await prefs.setString(
          _kOverrides,
          jsonEncode({for (final e in _overrides.entries) e.key: e.value.toJson()}),
        );
        iconsRevision.value++;
      }
    }
    if (map['webLinks'] is List) {
      final list = (map['webLinks'] as List)
          .whereType<Map>()
          .map((m) => LauncherApp.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (list.isNotEmpty || forceReplace) {
        _webLinks = list;
        await prefs.setString(_kWeb, jsonEncode(list.map((w) => w.toJson()).toList()));
        _rebuildApps();
      }
    }
    if (map.containsKey('quickNotes') && map['quickNotes'] is String) {
      final notes = map['quickNotes'] as String;
      if (notes.isNotEmpty || forceReplace) {
        _quickNotes = notes;
        await prefs.setString(_kNotes, _quickNotes);
      }
    }
    if (map['stats'] is Map) {
      final rawStats = map['stats'] as Map;
      if (rawStats.isNotEmpty || forceReplace) {
        rawStats.forEach((k, v) {
          if (v is List && v.length == 2) {
            _stats[k.toString()] = [(v[0] as num).toInt(), (v[1] as num).toInt()];
          }
        });
        await prefs.setString(_kStats, jsonEncode(_stats));
      }
    }
  }

  /// Non-destructively merges launcher settings from an older backup or JSON file.
  /// Preserves all current icons, dock items, and widgets, adding any missing ones.
  Future<void> mergeFromMap(Map<String, dynamic> map) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();

    if (map['dock'] is List) {
      final incoming = (map['dock'] as List).whereType<String>().toList();
      if ((dock.value.isEmpty || (dock.value.length == 1 && dock.value.first == LauncherApp.arcane.key)) && incoming.isNotEmpty) {
        dock.value = List.unmodifiable(incoming);
        await prefs.setStringList(_kDock, incoming);
      } else if (incoming.isNotEmpty) {
        final merged = List<String>.from(dock.value);
        for (final k in incoming) {
          if (!merged.contains(k)) merged.add(k);
        }
        dock.value = List.unmodifiable(merged);
        await prefs.setStringList(_kDock, merged);
      }
    }

    if (map['home'] is List) {
      final incoming = (map['home'] as List).whereType<String>().toList();
      if (home.value.isEmpty && incoming.isNotEmpty) {
        home.value = List.unmodifiable(incoming);
        await prefs.setStringList(_kHome, incoming);
      } else if (incoming.isNotEmpty) {
        final merged = List<String>.from(home.value);
        for (final k in incoming) {
          if (!merged.contains(k)) merged.add(k);
        }
        home.value = List.unmodifiable(merged);
        await prefs.setStringList(_kHome, merged);
      }
    }

    if (map['shelf'] is List) {
      final incoming = (map['shelf'] as List).whereType<String>().toList();
      if (shelf.value.isEmpty && incoming.isNotEmpty) {
        shelf.value = List.unmodifiable(incoming);
        await prefs.setStringList(_kShelf, incoming);
      } else if (incoming.isNotEmpty) {
        final merged = List<String>.from(shelf.value);
        for (final k in incoming) {
          if (!merged.contains(k)) merged.add(k);
        }
        shelf.value = List.unmodifiable(merged);
        await prefs.setStringList(_kShelf, merged);
      }
    }

    if (map['drawerFolders'] is List) {
      final incoming = (map['drawerFolders'] as List).whereType<String>().toList();
      if (drawerFolders.value.isEmpty && incoming.isNotEmpty) {
        drawerFolders.value = List.unmodifiable(incoming);
        await prefs.setStringList(_kDrawerFolders, incoming);
      } else if (incoming.isNotEmpty) {
        final merged = List<String>.from(drawerFolders.value);
        for (final k in incoming) {
          if (!merged.contains(k)) merged.add(k);
        }
        drawerFolders.value = List.unmodifiable(merged);
        await prefs.setStringList(_kDrawerFolders, merged);
      }
    }

    if (map['folders'] is List) {
      final incoming = (map['folders'] as List)
          .whereType<Map>()
          .map((m) => LauncherFolder.fromJson(Map<String, dynamic>.from(m)))
          .where((f) => f.id.isNotEmpty)
          .toList();
      if (incoming.isNotEmpty) {
        final mergedMap = Map<String, LauncherFolder>.from(folders.value);
        for (final f in incoming) {
          if (!mergedMap.containsKey(f.key)) {
            mergedMap[f.key] = f;
          } else {
            final existing = mergedMap[f.key]!;
            final combinedItems = List<String>.from(existing.items);
            for (final it in f.items) {
              if (!combinedItems.contains(it)) combinedItems.add(it);
            }
            mergedMap[f.key] = existing.copyWith(items: combinedItems);
          }
        }
        folders.value = Map.unmodifiable(mergedMap);
        await prefs.setString(_kFolders, jsonEncode(mergedMap.values.map((f) => f.toJson()).toList()));
      }
    }

    if (map['widgets'] is List) {
      final incoming = (map['widgets'] as List)
          .whereType<Map>()
          .map((m) => LauncherWidgetEntry.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (incoming.isNotEmpty) {
        if (widgets.value.isEmpty) {
          widgets.value = List.unmodifiable(incoming);
          await prefs.setString(_kWidgets, jsonEncode(incoming.map((w) => w.toJson()).toList()));
        } else {
          final existingIds = widgets.value.map((w) => w.id).toSet();
          final combined = List<LauncherWidgetEntry>.from(widgets.value);
          for (final w in incoming) {
            if (!existingIds.contains(w.id)) {
              combined.add(w);
              existingIds.add(w.id);
            }
          }
          widgets.value = List.unmodifiable(combined);
          await prefs.setString(_kWidgets, jsonEncode(combined.map((w) => w.toJson()).toList()));
        }
      }
    }

    if (map['hidden'] is List) {
      final incoming = (map['hidden'] as List).whereType<String>().toSet();
      if (incoming.isNotEmpty) {
        final combined = {...hidden.value, ...incoming};
        hidden.value = Set.unmodifiable(combined);
        await prefs.setStringList(_kHidden, combined.toList());
      }
    }

    if (map['iconPack'] is String && iconPack.value == null) {
      final pack = map['iconPack'] as String;
      iconPack.value = pack;
      await prefs.setString(_kIconPack, pack);
      unawaited(_loadPackMap(pack));
    }

    if (map['overrides'] is Map) {
      final rawOverrides = map['overrides'] as Map;
      bool changed = false;
      for (final e in rawOverrides.entries) {
        if (e.value is Map && !_overrides.containsKey(e.key.toString())) {
          final o = LauncherIconOverride.fromJson(Map<String, dynamic>.from(e.value as Map));
          if (o != null) {
            _overrides[e.key.toString()] = o;
            changed = true;
          }
        }
      }
      if (changed) {
        await prefs.setString(
          _kOverrides,
          jsonEncode({for (final e in _overrides.entries) e.key: e.value.toJson()}),
        );
        iconsRevision.value++;
      }
    }

    if (map['webLinks'] is List) {
      final incoming = (map['webLinks'] as List)
          .whereType<Map>()
          .map((m) => LauncherApp.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (incoming.isNotEmpty) {
        final existingUrls = _webLinks.map((w) => w.url).toSet();
        final combined = List<LauncherApp>.from(_webLinks);
        for (final w in incoming) {
          if (!existingUrls.contains(w.url)) {
            combined.add(w);
            existingUrls.add(w.url);
          }
        }
        _webLinks = combined;
        await prefs.setString(_kWeb, jsonEncode(combined.map((w) => w.toJson()).toList()));
        _rebuildApps();
      }
    }

    if (map['quickNotes'] is String) {
      final incomingNotes = map['quickNotes'] as String;
      if (_quickNotes.trim().isEmpty && incomingNotes.trim().isNotEmpty) {
        _quickNotes = incomingNotes;
        await prefs.setString(_kNotes, incomingNotes);
      }
    }
  }
}
