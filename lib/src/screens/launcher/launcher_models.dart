import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

enum LauncherScreenType {
  home,
  space,
  grid,
  search,
  widget,
  drawer,
  arcane,
}

enum LauncherSpaceCategory {
  main,
  study,
  tools,
  all,
}

class LauncherAppItem {
  final String id;
  final String label;
  final String package;
  final String? intentAction;
  final IconData icon;
  final bool isHot;
  final bool isSystem;
  final LauncherSpaceCategory category;
  final bool isArcaneApp;
  final int launchCount;
  final int lastLaunchedMillis;

  const LauncherAppItem({
    required this.id,
    required this.label,
    required this.package,
    this.intentAction,
    required this.icon,
    this.isHot = false,
    this.isSystem = false,
    this.category = LauncherSpaceCategory.all,
    this.isArcaneApp = false,
    this.launchCount = 0,
    this.lastLaunchedMillis = 0,
  });

  LauncherAppItem copyWith({
    String? id,
    String? label,
    String? package,
    String? intentAction,
    IconData? icon,
    bool? isHot,
    bool? isSystem,
    LauncherSpaceCategory? category,
    bool? isArcaneApp,
    int? launchCount,
    int? lastLaunchedMillis,
  }) {
    return LauncherAppItem(
      id: id ?? this.id,
      label: label ?? this.label,
      package: package ?? this.package,
      intentAction: intentAction ?? this.intentAction,
      icon: icon ?? this.icon,
      isHot: isHot ?? this.isHot,
      isSystem: isSystem ?? this.isSystem,
      category: category ?? this.category,
      isArcaneApp: isArcaneApp ?? this.isArcaneApp,
      launchCount: launchCount ?? this.launchCount,
      lastLaunchedMillis: lastLaunchedMillis ?? this.lastLaunchedMillis,
    );
  }

  static String getIconKey(IconData icon) {
    if (icon == MdiIcons.phone) return 'phone';
    if (icon == MdiIcons.messageProcessingOutline) return 'messages';
    if (icon == MdiIcons.cameraOutline) return 'camera';
    if (icon == MdiIcons.clockOutline) return 'clock';
    if (icon == MdiIcons.imageOutline) return 'gallery';
    if (icon == MdiIcons.fileDocumentOutline) return 'notes';
    if (icon == MdiIcons.cogOutline) return 'settings';
    if (icon == MdiIcons.web) return 'browser';
    if (icon == MdiIcons.mapMarkerRadiusOutline) return 'maps';
    if (icon == MdiIcons.musicBoxOutline) return 'music';
    if (icon == MdiIcons.console) return 'terminal';
    if (icon == MdiIcons.folderOutline) return 'files';
    if (icon == MdiIcons.calculatorVariantOutline) return 'calculator';
    if (icon == MdiIcons.calendarMonthOutline) return 'calendar';
    if (icon == MdiIcons.accountBoxOutline) return 'contacts';
    if (icon == MdiIcons.weatherPartlyCloudy) return 'weather';
    if (icon == MdiIcons.shoppingOutline) return 'store';
    if (icon == MdiIcons.chatProcessingOutline) return 'discord';
    if (icon == MdiIcons.musicCircleOutline) return 'spotify';
    if (icon == MdiIcons.videoOutline) return 'youtube';
    if (icon == MdiIcons.sourceBranch) return 'github';
    if (icon == MdiIcons.pound) return 'slack';
    if (icon == MdiIcons.notebookOutline) return 'notion';
    if (icon == MdiIcons.bookOpenPageVariantOutline) return 'books';
    if (icon == MdiIcons.heartPulse) return 'fitness';
    if (icon == MdiIcons.targetAccount) return 'missions';
    return 'app';
  }

  static IconData getIconFromKey(String? key) {
    switch (key) {
      case 'phone': return MdiIcons.phone;
      case 'messages': return MdiIcons.messageProcessingOutline;
      case 'camera': return MdiIcons.cameraOutline;
      case 'clock': return MdiIcons.clockOutline;
      case 'gallery': return MdiIcons.imageOutline;
      case 'notes': return MdiIcons.fileDocumentOutline;
      case 'settings': return MdiIcons.cogOutline;
      case 'browser': return MdiIcons.web;
      case 'maps': return MdiIcons.mapMarkerRadiusOutline;
      case 'music': return MdiIcons.musicBoxOutline;
      case 'terminal': return MdiIcons.console;
      case 'files': return MdiIcons.folderOutline;
      case 'calculator': return MdiIcons.calculatorVariantOutline;
      case 'calendar': return MdiIcons.calendarMonthOutline;
      case 'contacts': return MdiIcons.accountBoxOutline;
      case 'weather': return MdiIcons.weatherPartlyCloudy;
      case 'store': return MdiIcons.shoppingOutline;
      case 'discord': return MdiIcons.chatProcessingOutline;
      case 'spotify': return MdiIcons.musicCircleOutline;
      case 'youtube': return MdiIcons.videoOutline;
      case 'github': return MdiIcons.sourceBranch;
      case 'slack': return MdiIcons.pound;
      case 'notion': return MdiIcons.notebookOutline;
      case 'books': return MdiIcons.bookOpenPageVariantOutline;
      case 'fitness': return MdiIcons.heartPulse;
      case 'missions': return MdiIcons.targetAccount;
      default: return MdiIcons.applicationOutline;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'package': package,
    'intentAction': intentAction,
    'iconKey': getIconKey(icon),
    'isHot': isHot,
    'isSystem': isSystem,
    'category': category.name,
    'isArcaneApp': isArcaneApp,
    'launchCount': launchCount,
    'lastLaunchedMillis': lastLaunchedMillis,
  };

  factory LauncherAppItem.fromJson(Map<String, dynamic> json) {
    final icon = getIconFromKey(json['iconKey'] as String?);
    LauncherSpaceCategory cat = LauncherSpaceCategory.all;
    if (json['category'] != null) {
      try {
        cat = LauncherSpaceCategory.values.byName(json['category'] as String);
      } catch (_) {}
    }
    return LauncherAppItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      package: json['package'] as String? ?? '',
      intentAction: json['intentAction'] as String?,
      icon: icon,
      isHot: json['isHot'] as bool? ?? false,
      isSystem: json['isSystem'] as bool? ?? false,
      category: cat,
      isArcaneApp: json['isArcaneApp'] as bool? ?? false,
      launchCount: json['launchCount'] as int? ?? 0,
      lastLaunchedMillis: json['lastLaunchedMillis'] as int? ?? 0,
    );
  }

  /// Default catalogue of apps for web prototyping and device fallback.
  static List<LauncherAppItem> get defaultApps => [
        LauncherAppItem(
          id: 'missions',
          label: 'ARCANE',
          package: 'me.ihjas.missions',
          icon: MdiIcons.targetAccount,
          isHot: true,
          category: LauncherSpaceCategory.main,
          isArcaneApp: true,
        ),
        LauncherAppItem(
          id: 'phone',
          label: 'Phone',
          package: 'com.google.android.dialer',
          intentAction: 'phone',
          icon: MdiIcons.phone,
          category: LauncherSpaceCategory.main,
          isSystem: true,
        ),
        LauncherAppItem(
          id: 'messages',
          label: 'Messages',
          package: 'com.google.android.apps.messaging',
          intentAction: 'messages',
          icon: MdiIcons.messageProcessingOutline,
          category: LauncherSpaceCategory.main,
          isSystem: true,
        ),
        LauncherAppItem(
          id: 'camera',
          label: 'Camera',
          package: 'com.google.android.GoogleCamera',
          intentAction: 'camera',
          icon: MdiIcons.cameraOutline,
          category: LauncherSpaceCategory.main,
          isSystem: true,
        ),
        LauncherAppItem(
          id: 'clock',
          label: 'Clock',
          package: 'com.google.android.deskclock',
          intentAction: 'clock',
          icon: MdiIcons.clockOutline,
          category: LauncherSpaceCategory.tools,
          isSystem: true,
        ),
        LauncherAppItem(
          id: 'gallery',
          label: 'Gallery',
          package: 'com.google.android.apps.photos',
          intentAction: 'gallery',
          icon: MdiIcons.imageOutline,
          category: LauncherSpaceCategory.main,
          isSystem: true,
        ),
        LauncherAppItem(
          id: 'notes',
          label: 'Notes',
          package: 'com.google.android.keep',
          icon: MdiIcons.fileDocumentOutline,
          category: LauncherSpaceCategory.study,
        ),
        LauncherAppItem(
          id: 'settings',
          label: 'Settings',
          package: 'com.android.settings',
          intentAction: 'settings',
          icon: MdiIcons.cogOutline,
          category: LauncherSpaceCategory.tools,
          isSystem: true,
        ),
        LauncherAppItem(
          id: 'browser',
          label: 'Browser',
          package: 'com.android.chrome',
          icon: MdiIcons.web,
          category: LauncherSpaceCategory.main,
        ),
        LauncherAppItem(
          id: 'maps',
          label: 'Maps',
          package: 'com.google.android.apps.maps',
          icon: MdiIcons.mapMarkerRadiusOutline,
          category: LauncherSpaceCategory.main,
        ),
        LauncherAppItem(
          id: 'music',
          label: 'Music',
          package: 'com.google.android.apps.youtube.music',
          icon: MdiIcons.musicBoxOutline,
          category: LauncherSpaceCategory.main,
        ),
        LauncherAppItem(
          id: 'terminal',
          label: 'Terminal',
          package: 'com.termux',
          icon: MdiIcons.console,
          category: LauncherSpaceCategory.tools,
        ),
        LauncherAppItem(
          id: 'files',
          label: 'Files',
          package: 'com.google.android.apps.nbu.files',
          icon: MdiIcons.folderOutline,
          category: LauncherSpaceCategory.tools,
        ),
        LauncherAppItem(
          id: 'calculator',
          label: 'Calculator',
          package: 'com.google.android.calculator',
          icon: MdiIcons.calculatorVariantOutline,
          category: LauncherSpaceCategory.tools,
        ),
        LauncherAppItem(
          id: 'calendar',
          label: 'Calendar',
          package: 'com.google.android.calendar',
          icon: MdiIcons.calendarMonthOutline,
          category: LauncherSpaceCategory.study,
        ),
        LauncherAppItem(
          id: 'contacts',
          label: 'Contacts',
          package: 'com.google.android.contacts',
          icon: MdiIcons.accountBoxOutline,
          category: LauncherSpaceCategory.main,
        ),
        LauncherAppItem(
          id: 'weather',
          label: 'Weather',
          package: 'com.google.android.apps.weather',
          icon: MdiIcons.weatherPartlyCloudy,
          category: LauncherSpaceCategory.tools,
        ),
        LauncherAppItem(
          id: 'store',
          label: 'Play Store',
          package: 'com.android.vending',
          icon: MdiIcons.shoppingOutline,
          category: LauncherSpaceCategory.main,
        ),
        LauncherAppItem(
          id: 'discord',
          label: 'Discord',
          package: 'com.discord',
          icon: MdiIcons.chatProcessingOutline,
          category: LauncherSpaceCategory.main,
        ),
        LauncherAppItem(
          id: 'spotify',
          label: 'Spotify',
          package: 'com.spotify.music',
          icon: MdiIcons.musicCircleOutline,
          category: LauncherSpaceCategory.main,
        ),
        LauncherAppItem(
          id: 'youtube',
          label: 'YouTube',
          package: 'com.google.android.youtube',
          icon: MdiIcons.videoOutline,
          category: LauncherSpaceCategory.main,
        ),
        LauncherAppItem(
          id: 'github',
          label: 'GitHub',
          package: 'com.github.android',
          icon: MdiIcons.sourceBranch,
          category: LauncherSpaceCategory.study,
        ),
        LauncherAppItem(
          id: 'slack',
          label: 'Slack',
          package: 'com.Slack',
          icon: MdiIcons.pound,
          category: LauncherSpaceCategory.study,
        ),
        LauncherAppItem(
          id: 'notion',
          label: 'Notion',
          package: 'notion.id',
          icon: MdiIcons.notebookOutline,
          category: LauncherSpaceCategory.study,
        ),
        LauncherAppItem(
          id: 'books',
          label: 'Books',
          package: 'com.google.android.apps.books',
          icon: MdiIcons.bookOpenPageVariantOutline,
          category: LauncherSpaceCategory.study,
        ),
        LauncherAppItem(
          id: 'fitness',
          label: 'Fitness',
          package: 'com.google.android.apps.fitness',
          icon: MdiIcons.heartPulse,
          category: LauncherSpaceCategory.study,
        ),
        LauncherAppItem(
          id: 'drive',
          label: 'Drive',
          package: 'com.google.android.apps.docs',
          icon: MdiIcons.cloudOutline,
          category: LauncherSpaceCategory.study,
        ),
        LauncherAppItem(
          id: 'gmail',
          label: 'Gmail',
          package: 'com.google.android.gm',
          icon: MdiIcons.emailOutline,
          category: LauncherSpaceCategory.main,
        ),
      ];
}

class LauncherSpaceItem {
  final String id;
  final String title;
  final int appCount;
  final IconData icon;
  final LauncherSpaceCategory category;
  final bool isDefault;

  const LauncherSpaceItem({
    required this.id,
    required this.title,
    required this.appCount,
    required this.icon,
    required this.category,
    this.isDefault = false,
  });

  static List<LauncherSpaceItem> get defaultSpaces => [
        LauncherSpaceItem(
          id: 'main',
          title: 'MAIN',
          appCount: 12,
          icon: MdiIcons.grid,
          category: LauncherSpaceCategory.main,
          isDefault: true,
        ),
        LauncherSpaceItem(
          id: 'study',
          title: 'STUDY',
          appCount: 8,
          icon: MdiIcons.folderOutline,
          category: LauncherSpaceCategory.study,
        ),
        LauncherSpaceItem(
          id: 'tools',
          title: 'TOOLS',
          appCount: 10,
          icon: MdiIcons.cogOutline,
          category: LauncherSpaceCategory.tools,
        ),
      ];
}
