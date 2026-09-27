import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Package id of Arcane itself. Its drawer / dock entry opens the in-process Arcane UI.
const String kArcanePackage = 'me.ihjas.missions';

/// A launchable activity, as reported by Android's LauncherApps.
class LauncherApp {
  final String package;
  final String activity;
  final String label;
  final bool isSystem;
  final int installTime;

  const LauncherApp({
    required this.package,
    required this.activity,
    required this.label,
    this.isSystem = false,
    this.installTime = 0,
  });

  /// Stable identity: flattened component, same format icon packs use in appfilter.xml.
  String get key => '$package/$activity';

  bool get isArcane => package == kArcanePackage;

  String get displayLabel => isArcane ? 'Arcane' : label;

  Map<String, dynamic> toJson() => {
        'package': package,
        'activity': activity,
        'label': label,
        'isSystem': isSystem,
        'installTime': installTime,
      };

  factory LauncherApp.fromJson(Map<String, dynamic> json) => LauncherApp(
        package: json['package'] as String? ?? '',
        activity: json['activity'] as String? ?? '',
        label: json['label'] as String? ?? '',
        isSystem: json['isSystem'] as bool? ?? false,
        installTime: (json['installTime'] as num?)?.toInt() ?? 0,
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
    final p = package.toLowerCase();
    if (p.contains('dialer') || p.contains('phone') || p.contains('contacts')) return MdiIcons.phone;
    if (p.contains('messag') || p.contains('sms') || p.contains('mms')) return MdiIcons.messageProcessingOutline;
    if (p.contains('camera')) return MdiIcons.cameraOutline;
    if (p.contains('photo') || p.contains('gallery')) return MdiIcons.imageOutline;
    if (p.contains('clock')) return MdiIcons.clockOutline;
    if (p.contains('setting')) return MdiIcons.cogOutline;
    if (p.contains('music')) return MdiIcons.musicBoxOutline;
    if (p.contains('map')) return MdiIcons.mapMarkerRadiusOutline;
    if (p.contains('chrome') || p.contains('browser') || p.contains('firefox')) return MdiIcons.web;
    if (p.contains('mail') || p.contains('.gm')) return MdiIcons.emailOutline;
    if (p.contains('calc')) return MdiIcons.calculatorVariantOutline;
    if (p.contains('calendar')) return MdiIcons.calendarMonthOutline;
    if (p.contains('file')) return MdiIcons.folderOutline;
    return MdiIcons.applicationOutline;
  }
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
