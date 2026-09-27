import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Package id of Arcane itself. Its drawer / dock entry opens the in-process Arcane UI.
const String kArcanePackage = 'me.ihjas.missions';

/// What a launcher entry opens.
enum LauncherAppKind {
  /// A launchable activity (any profile).
  app,

  /// A pinned shortcut — Chrome web apps / "Add to Home screen" / pinned app shortcuts.
  shortcut,

  /// A web link saved in Arcane (opens in its installed web app or the browser).
  web,
}

/// A launchable entry: activity, pinned shortcut, or saved web link.
class LauncherApp {
  final String package;
  final String activity;
  final String label;
  final bool isSystem;
  final int installTime;

  /// Android user serial for other profiles (MIUI Dual Apps / work profile); -1 = own profile.
  final int user;
  final LauncherAppKind kind;
  final String? shortcutId;
  final String? url;

  const LauncherApp({
    required this.package,
    required this.activity,
    required this.label,
    this.isSystem = false,
    this.installTime = 0,
    this.user = -1,
    this.kind = LauncherAppKind.app,
    this.shortcutId,
    this.url,
  });

  const LauncherApp.shortcut({
    required this.package,
    required String id,
    required this.label,
    this.user = -1,
  })  : activity = '',
        isSystem = false,
        installTime = 0,
        kind = LauncherAppKind.shortcut,
        shortcutId = id,
        url = null;

  const LauncherApp.web({required String this.url, required this.label})
      : package = '',
        activity = '',
        isSystem = false,
        installTime = 0,
        user = -1,
        kind = LauncherAppKind.web,
        shortcutId = null;

  /// Stable identity. Own-profile apps keep the icon-pack `package/activity` format.
  String get key => switch (kind) {
        LauncherAppKind.app => user < 0 ? '$package/$activity' : '$package/$activity@$user',
        LauncherAppKind.shortcut => 'sc:$package/$shortcutId@$user',
        LauncherAppKind.web => 'web:$url',
      };

  /// Component key used for icon-pack matching (always the plain activity).
  String get componentKey => '$package/$activity';

  bool get isArcane => kind == LauncherAppKind.app && package == kArcanePackage && user < 0;
  bool get isOtherProfile => user >= 0;

  String get displayLabel => isArcane ? 'Arcane' : label;

  Map<String, dynamic> toJson() => {
        'package': package,
        'activity': activity,
        'label': label,
        'isSystem': isSystem,
        'installTime': installTime,
        'user': user,
        'kind': kind.name,
        if (shortcutId != null) 'shortcutId': shortcutId,
        if (url != null) 'url': url,
      };

  factory LauncherApp.fromJson(Map<String, dynamic> json) => LauncherApp(
        package: json['package'] as String? ?? '',
        activity: json['activity'] as String? ?? '',
        label: json['label'] as String? ?? '',
        isSystem: json['isSystem'] as bool? ?? false,
        installTime: (json['installTime'] as num?)?.toInt() ?? 0,
        user: (json['user'] as num?)?.toInt() ?? -1,
        kind: LauncherAppKind.values.asNameMap()[json['kind']] ?? LauncherAppKind.app,
        shortcutId: json['shortcutId'] as String?,
        url: json['url'] as String?,
      );

  /// Arcane's own entry, used before the package manager has answered (and off-Android).
  static const LauncherApp arcane = LauncherApp(
    package: kArcanePackage,
    activity: '$kArcanePackage.MainActivity',
    label: 'Arcane',
  );

  /// Glyph shown only while a real icon is loading or when the system has none.
  IconData get fallbackGlyph {
    if (isArcane) return MdiIcons.targetAccount;
    if (kind == LauncherAppKind.web) return MdiIcons.web;
    final p = package.toLowerCase();
    if (p.contains('dialer') || p.contains('phone') || p.contains('contacts')) return MdiIcons.phone;
    if (p.contains('messag') || p.contains('sms') || p.contains('mms')) return MdiIcons.messageProcessingOutline;
    if (p.contains('camera')) return MdiIcons.cameraOutline;
    if (p.contains('photo') || p.contains('gallery')) return MdiIcons.imageOutline;
    if (p.contains('clock')) return MdiIcons.clockOutline;
    if (p.contains('setting')) return MdiIcons.cogOutline;
    if (p.contains('music')) return MdiIcons.musicBoxOutline;
    if (p.contains('map')) return MdiIcons.mapMarkerRadiusOutline;
    if (p.contains('chrome') || p.contains('browser') || p.contains('firefox') || p.contains('webapk')) {
      return MdiIcons.web;
    }
    if (p.contains('mail') || p.contains('.gm')) return MdiIcons.emailOutline;
    if (p.contains('calc')) return MdiIcons.calculatorVariantOutline;
    if (p.contains('calendar')) return MdiIcons.calendarMonthOutline;
    if (p.contains('file')) return MdiIcons.folderOutline;
    return MdiIcons.applicationOutline;
  }
}

/// Places an app/folder can live. The drawer area only holds drawer folders.
enum LauncherArea { dock, home, shelf, drawer }

/// A user folder of launcher entries. Referenced from areas as `folder:<id>`.
class LauncherFolder {
  final String id;
  final String name;
  final List<String> items;

  const LauncherFolder({required this.id, required this.name, required this.items});

  static const String prefix = 'folder:';
  static bool isFolderKey(String key) => key.startsWith(prefix);

  String get key => '$prefix$id';

  LauncherFolder copyWith({String? name, List<String>? items}) =>
      LauncherFolder(id: id, name: name ?? this.name, items: items ?? this.items);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'items': items};

  factory LauncherFolder.fromJson(Map<String, dynamic> json) => LauncherFolder(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Folder',
        items: (json['items'] as List? ?? const []).map((e) => '$e').toList(),
      );
}

/// Where a user-chosen icon comes from.
enum LauncherIconSource { pack, app, glyph }

/// Per-app icon choice. `null` override = pack icon when an icon pack is active, else the app's original icon.
class LauncherIconOverride {
  final LauncherIconSource source;

  /// [LauncherIconSource.pack]: icon-pack package + drawable name.
  final String? pack;
  final String? drawable;

  /// [LauncherIconSource.app]: key of the app whose original icon is borrowed (the app's own key = original).
  final String? appKey;

  /// [LauncherIconSource.glyph]: key into [launcherGlyphs].
  final String? glyph;

  const LauncherIconOverride.pack(String this.pack, String this.drawable)
      : source = LauncherIconSource.pack,
        appKey = null,
        glyph = null;

  const LauncherIconOverride.app(String this.appKey)
      : source = LauncherIconSource.app,
        pack = null,
        drawable = null,
        glyph = null;

  const LauncherIconOverride.glyph(String this.glyph)
      : source = LauncherIconSource.glyph,
        pack = null,
        drawable = null,
        appKey = null;

  Map<String, dynamic> toJson() => {
        'source': source.name,
        if (pack != null) 'pack': pack,
        if (drawable != null) 'drawable': drawable,
        if (appKey != null) 'appKey': appKey,
        if (glyph != null) 'glyph': glyph,
      };

  static LauncherIconOverride? fromJson(Map<String, dynamic> json) {
    switch (json['source']) {
      case 'pack':
        final pack = json['pack'] as String?;
        final drawable = json['drawable'] as String?;
        return pack != null && drawable != null ? LauncherIconOverride.pack(pack, drawable) : null;
      case 'app':
        final key = json['appKey'] as String?;
        return key != null ? LauncherIconOverride.app(key) : null;
      case 'glyph':
        final glyph = json['glyph'] as String?;
        return glyph != null ? LauncherIconOverride.glyph(glyph) : null;
    }
    return null;
  }
}

/// Tactical glyphs selectable as custom icons.
final Map<String, IconData> launcherGlyphs = {
  'target': MdiIcons.targetAccount,
  'phone': MdiIcons.phone,
  'messages': MdiIcons.messageProcessingOutline,
  'camera': MdiIcons.cameraOutline,
  'web': MdiIcons.web,
  'mail': MdiIcons.emailOutline,
  'music': MdiIcons.musicBoxOutline,
  'map': MdiIcons.mapMarkerRadiusOutline,
  'image': MdiIcons.imageOutline,
  'clock': MdiIcons.clockOutline,
  'calendar': MdiIcons.calendarMonthOutline,
  'settings': MdiIcons.cogOutline,
  'terminal': MdiIcons.console,
  'folder': MdiIcons.folderOutline,
  'calculator': MdiIcons.calculatorVariantOutline,
  'notes': MdiIcons.notebookOutline,
  'chat': MdiIcons.chatProcessingOutline,
  'video': MdiIcons.videoOutline,
  'code': MdiIcons.sourceBranch,
  'book': MdiIcons.bookOpenPageVariantOutline,
  'fitness': MdiIcons.heartPulse,
  'wallet': MdiIcons.walletOutline,
  'shop': MdiIcons.shoppingOutline,
  'game': MdiIcons.gamepadVariantOutline,
  'shield': MdiIcons.shieldOutline,
  'star': MdiIcons.starOutline,
  'bolt': MdiIcons.flashOutline,
  'rocket': MdiIcons.rocketLaunchOutline,
};

/// An Android AppWidget placed on the home screen.
class LauncherWidgetEntry {
  final int id;
  final String provider;
  final String label;
  final double height;

  const LauncherWidgetEntry({
    required this.id,
    required this.provider,
    required this.label,
    required this.height,
  });

  LauncherWidgetEntry copyWith({double? height}) =>
      LauncherWidgetEntry(id: id, provider: provider, label: label, height: height ?? this.height);

  Map<String, dynamic> toJson() => {'id': id, 'provider': provider, 'label': label, 'height': height};

  factory LauncherWidgetEntry.fromJson(Map<String, dynamic> json) => LauncherWidgetEntry(
        id: (json['id'] as num).toInt(),
        provider: json['provider'] as String? ?? '',
        label: json['label'] as String? ?? '',
        height: (json['height'] as num?)?.toDouble() ?? 160,
      );
}
