import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/services/assistant_routing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central launcher service responsible for:
/// - Instant app list loading from persistent cache (Rootless Pixel Launcher / Launcher3 design)
/// - Background package manager discovery and cache invalidation
/// - Launch statistics & dynamic predicted / recent apps tracking
/// - System intent and package launching with platform fallback
class LauncherService {
  LauncherService._();
  static final LauncherService instance = LauncherService._();

  static const String _cacheKey = 'arcane_launcher_cached_apps_v3';

  List<LauncherAppItem> _apps = [];
  final Map<String, Uint8List?> _iconCache = {};
  bool _initialized = false;
  final ValueNotifier<List<LauncherAppItem>> appsNotifier = ValueNotifier<List<LauncherAppItem>>([]);

  List<LauncherAppItem> get apps => _apps;

  /// Initializes the launcher state.
  /// First immediately reads cached apps from SharedPreferences for instant 0ms boot,
  /// then triggers background synchronization with native package manager.
  Future<void> init() async {
    if (_initialized && _apps.isNotEmpty) return;
    _initialized = true;

    // 1. Instant cache restoration
    final cached = await _loadCachedApps();
    if (cached.isNotEmpty) {
      _apps = cached;
      appsNotifier.value = List.unmodifiable(_apps);
    } else {
      _apps = List<LauncherAppItem>.from(LauncherAppItem.defaultApps);
      appsNotifier.value = List.unmodifiable(_apps);
      await _saveCachedApps();
    }

    // 2. Background package synchronization
    _syncInstalledApps();
  }

  /// Loads cached app list from SharedPreferences
  Future<List<LauncherAppItem>> _loadCachedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final list = <LauncherAppItem>[];
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              list.add(LauncherAppItem.fromJson(item));
            }
          }
          if (list.isNotEmpty) {
            return list;
          }
        }
      }
    } catch (e) {
      debugPrint('[LauncherService] Failed reading cached apps: $e');
    }
    return const [];
  }

  /// Persists current app list with usage metrics to SharedPreferences
  Future<void> _saveCachedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _apps.map((a) => a.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[LauncherService] Failed saving cached apps: $e');
    }
  }

  /// Background sync with native Android Package Manager
  Future<void> _syncInstalledApps() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final installed = await AssistantRoutingService.instance.getAllInstalledApps();
      if (installed.isEmpty) return;

      final existingMap = <String, LauncherAppItem>{
        for (final a in _apps) a.package: a,
      };

      final updatedList = <LauncherAppItem>[];

      // Always ensure Arcane is the pinned primary hot app
      final arcaneApp = _apps.firstWhere(
        (a) => a.isArcaneApp,
        orElse: () => LauncherAppItem.defaultApps.first,
      );
      updatedList.add(arcaneApp);

      for (final app in installed) {
        if (!app.isLaunchable) continue;
        if (app.package == 'me.ihjas.missions') continue; // Handled by arcaneApp

        final label = app.label.trim().isEmpty ? app.package : app.label.trim();
        final lower = label.toLowerCase();
        final lowerPkg = app.package.toLowerCase();

        // Preserve previous launch telemetry if present
        final existing = existingMap[app.package];
        final launchCount = existing?.launchCount ?? 0;
        final lastLaunched = existing?.lastLaunchedMillis ?? 0;

        LauncherSpaceCategory cat = existing?.category ?? LauncherSpaceCategory.main;
        if (existing == null) {
          if (lower.contains('study') ||
              lower.contains('book') ||
              lower.contains('learn') ||
              lower.contains('notes') ||
              lower.contains('code') ||
              lower.contains('read') ||
              lower.contains('doc') ||
              lower.contains('slack') ||
              lower.contains('notion') ||
              lower.contains('github') ||
              lower.contains('calendar')) {
            cat = LauncherSpaceCategory.study;
          } else if (lower.contains('tool') ||
              lower.contains('calc') ||
              lower.contains('clock') ||
              lower.contains('setting') ||
              lower.contains('term') ||
              lower.contains('file') ||
              lower.contains('manager') ||
              lower.contains('weather') ||
              lower.contains('assistant')) {
            cat = LauncherSpaceCategory.tools;
          }
        }

        IconData icon = existing?.icon ?? MdiIcons.applicationOutline;
        if (existing == null) {
          if (lowerPkg.contains('dialer') || lowerPkg.contains('phone')) {
            icon = MdiIcons.phone;
          } else if (lowerPkg.contains('messaging') || lowerPkg.contains('sms')) {
            icon = MdiIcons.messageProcessingOutline;
          } else if (lowerPkg.contains('camera')) {
            icon = MdiIcons.cameraOutline;
          } else if (lowerPkg.contains('photo') || lowerPkg.contains('gallery')) {
            icon = MdiIcons.imageOutline;
          } else if (lowerPkg.contains('clock')) {
            icon = MdiIcons.clockOutline;
          } else if (lowerPkg.contains('setting')) {
            icon = MdiIcons.cogOutline;
          } else if (lowerPkg.contains('music')) {
            icon = MdiIcons.musicBoxOutline;
          } else if (lowerPkg.contains('map')) {
            icon = MdiIcons.mapMarkerRadiusOutline;
          } else if (lowerPkg.contains('chrome') || lowerPkg.contains('browser')) {
            icon = MdiIcons.web;
          } else if (lowerPkg.contains('mail')) {
            icon = MdiIcons.emailOutline;
          }
        }

        updatedList.add(LauncherAppItem(
          id: app.package,
          label: label,
          package: app.package,
          icon: icon,
          category: cat,
          isSystem: app.isSystem,
          launchCount: launchCount,
          lastLaunchedMillis: lastLaunched,
        ));
      }

      if (updatedList.length > 1) {
        _apps = updatedList;
        appsNotifier.value = List.unmodifiable(_apps);
        await _saveCachedApps();
      }
    } catch (e) {
      debugPrint('[LauncherService] Failed package synchronization: $e');
    }
  }

  /// Records an app launch to track frequency and recent usage (Rootless Pixel Launcher insight)
  Future<void> recordAppLaunch(LauncherAppItem app) async {
    final idx = _apps.indexWhere((a) => a.id == app.id || a.package == app.package);
    if (idx >= 0) {
      final existing = _apps[idx];
      final updated = existing.copyWith(
        launchCount: existing.launchCount + 1,
        lastLaunchedMillis: DateTime.now().millisecondsSinceEpoch,
      );
      _apps[idx] = updated;
      appsNotifier.value = List.unmodifiable(_apps);
      await _saveCachedApps();
    }
  }

  /// Retrieves the most recently and frequently launched apps
  List<LauncherAppItem> getRecentApps({int limit = 4}) {
    final launched = _apps.where((a) => a.lastLaunchedMillis > 0).toList();
    if (launched.isNotEmpty) {
      launched.sort((a, b) {
        final cmpTime = b.lastLaunchedMillis.compareTo(a.lastLaunchedMillis);
        if (cmpTime != 0) return cmpTime;
        return b.launchCount.compareTo(a.launchCount);
      });
      return launched.take(limit).toList();
    }

    // Default primary apps when no launches have occurred yet
    return _apps.where((a) => !a.isArcaneApp && (a.isHot || a.isSystem)).take(limit).toList();
  }

  /// Performs fast app query search
  List<LauncherAppItem> searchApps(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _apps;

    return _apps.where((app) {
      return app.label.toLowerCase().contains(q) ||
          app.package.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final aStarts = a.label.toLowerCase().startsWith(q);
        final bStarts = b.label.toLowerCase().startsWith(q);
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
  }

  /// Retrieves or caches the app icon
  Future<Uint8List?> getAppIcon(String package) async {
    if (kIsWeb) return null;
    if (_iconCache.containsKey(package)) {
      return _iconCache[package];
    }
    try {
      final bytes = await AssistantRoutingService.instance.getAppIcon(package);
      _iconCache[package] = bytes;
      return bytes;
    } catch (_) {
      _iconCache[package] = null;
      return null;
    }
  }

  /// Launches the requested app and records launch telemetry
  Future<bool> launchApp(LauncherAppItem app) async {
    await recordAppLaunch(app);

    if (!kIsWeb && Platform.isAndroid) {
      if (app.intentAction != null && app.intentAction!.isNotEmpty) {
        final success = await AssistantRoutingService.instance.launchIntentAction(app.intentAction!);
        if (success) return true;
      }
      if (app.package.isNotEmpty) {
        final success = await AssistantRoutingService.instance.launchPackage(app.package);
        if (success) return true;
      }
    }
    return false;
  }
}
