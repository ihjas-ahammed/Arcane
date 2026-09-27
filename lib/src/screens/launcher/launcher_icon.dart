import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:path_provider/path_provider.dart';

/// Loads real app / icon-pack icons as [MemoryImage]s.
///
/// - One [ValueNotifier] per icon, so a finished load repaints only the tiles that show it
/// - Requests made in the same frame are batched into a single platform-channel call
/// - PNGs are cached on disk, so after the first boot icons appear without touching PackageManager
/// - The same [MemoryImage] instance is reused, so Flutter's ImageCache decodes each icon once
class LauncherIconCache {
  LauncherIconCache._() {
    LauncherService.instance.iconInvalidations.addListener(_onInvalidate);
  }
  static final LauncherIconCache instance = LauncherIconCache._();

  /// Pixel size icons are rendered at natively (covers 56dp at ~3x density).
  static const int renderSize = 168;

  final Map<String, ValueNotifier<ImageProvider?>> _slots = {};
  final Set<String> _requested = {};
  final Set<String> _pendingApps = {};
  final Map<String, Set<String>> _pendingPack = {};
  bool _flushScheduled = false;
  Directory? _dir;
  Future<Directory?>? _dirFuture;

  static String _appSlot(String appKey) => 'a|$appKey';
  static String _packSlot(String pack, String drawable) => 'p|$pack|$drawable';

  ValueListenable<ImageProvider?> appIcon(String appKey) => _slot(_appSlot(appKey), () {
        _pendingApps.add(appKey);
      });

  ValueListenable<ImageProvider?> packIcon(String pack, String drawable) => _slot(_packSlot(pack, drawable), () {
        (_pendingPack[pack] ??= <String>{}).add(drawable);
      });

  ValueNotifier<ImageProvider?> _slot(String id, VoidCallback enqueue) {
    final slot = _slots.putIfAbsent(id, () => ValueNotifier<ImageProvider?>(null));
    if (_requested.add(id) && LauncherNative.isSupported) {
      enqueue();
      _scheduleFlush();
    }
    return slot;
  }

  void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    // A microtask lets a whole grid of tiles register before one batched call goes out.
    scheduleMicrotask(() {
      _flushScheduled = false;
      unawaited(_flush());
    });
  }

  Future<Directory?> _cacheDir() => _dirFuture ??= () async {
        try {
          final base = await getApplicationSupportDirectory();
          final dir = Directory('${base.path}/launcher_icons');
          await dir.create(recursive: true);
          return _dir = dir;
        } catch (_) {
          return null;
        }
      }();

  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  File? _appFile(String appKey) {
    final dir = _dir;
    if (dir == null) return null;
    final slash = appKey.indexOf('/');
    final pkg = slash < 0 ? appKey : appKey.substring(0, slash);
    return File('${dir.path}/app/${_safe(pkg)}/${_safe(appKey)}.png');
  }

  File? _packFile(String pack, String drawable) {
    final dir = _dir;
    if (dir == null) return null;
    return File('${dir.path}/pack/${_safe(pack)}/${_safe(drawable)}.png');
  }

  Future<void> _flush() async {
    await _cacheDir();
    final apps = _pendingApps.toList();
    _pendingApps.clear();
    final packs = Map<String, Set<String>>.from(_pendingPack);
    _pendingPack.clear();

    // 1. Disk hits.
    final missingApps = <String>[];
    for (final key in apps) {
      final bytes = await _readFile(_appFile(key));
      if (bytes != null) {
        _publish(_appSlot(key), bytes);
      } else {
        missingApps.add(key);
      }
    }
    final missingPack = <String, List<String>>{};
    for (final e in packs.entries) {
      for (final d in e.value) {
        final bytes = await _readFile(_packFile(e.key, d));
        if (bytes != null) {
          _publish(_packSlot(e.key, d), bytes);
        } else {
          (missingPack[e.key] ??= <String>[]).add(d);
        }
      }
    }

    // 2. Native rendering, in chunks so the first screenful lands quickly.
    const chunk = 24;
    for (var i = 0; i < missingApps.length; i += chunk) {
      final part = missingApps.sublist(i, (i + chunk).clamp(0, missingApps.length));
      final items = <Map<String, String>>[];
      for (final key in part) {
        final slash = key.indexOf('/');
        if (slash <= 0) continue;
        items.add({'key': key, 'package': key.substring(0, slash), 'activity': key.substring(slash + 1)});
      }
      final result = await LauncherNative.getAppIcons(items, size: renderSize);
      for (final key in part) {
        final bytes = result[key];
        if (bytes != null && bytes.isNotEmpty) {
          _publish(_appSlot(key), bytes);
          unawaited(_writeFile(_appFile(key), bytes));
        }
      }
    }
    for (final e in missingPack.entries) {
      for (var i = 0; i < e.value.length; i += chunk) {
        final part = e.value.sublist(i, (i + chunk).clamp(0, e.value.length));
        final result = await LauncherNative.getIconPackIcons(e.key, part, size: renderSize);
        for (final d in part) {
          final bytes = result[d];
          if (bytes != null && bytes.isNotEmpty) {
            _publish(_packSlot(e.key, d), bytes);
            unawaited(_writeFile(_packFile(e.key, d), bytes));
          }
        }
      }
    }
  }

  void _publish(String id, Uint8List bytes) {
    _slots[id]?.value = MemoryImage(bytes);
  }

  static Future<Uint8List?> _readFile(File? f) async {
    if (f == null) return null;
    try {
      if (await f.exists()) return await f.readAsBytes();
    } catch (_) {}
    return null;
  }

  static Future<void> _writeFile(File? f, Uint8List bytes) async {
    if (f == null) return;
    try {
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes, flush: false);
    } catch (_) {}
  }

  /// A package was installed / updated / removed: drop its cached icons and reload visible ones.
  void _onInvalidate() {
    final pkg = LauncherService.instance.iconInvalidations.value;
    if (pkg == null || pkg.isEmpty || !LauncherNative.isSupported) return;
    unawaited(() async {
      final dir = _dir;
      if (dir != null) {
        try {
          await Directory('${dir.path}/app/${_safe(pkg)}').delete(recursive: true);
        } catch (_) {}
      }
      final prefix = _appSlot('$pkg/');
      final stale = _slots.keys.where((k) => k.startsWith(prefix)).toList();
      for (final id in stale) {
        _pendingApps.add(id.substring(2));
      }
      if (stale.isNotEmpty) _scheduleFlush();
    }());
  }
}

/// Square app icon honoring the user's icon choice, icon pack, and the app's original icon.
class LauncherAppIcon extends StatelessWidget {
  final LauncherApp app;
  final double size;

  const LauncherAppIcon({super.key, required this.app, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: LauncherService.instance.iconsRevision,
        builder: (context, _, __) {
          final spec = LauncherService.instance.iconFor(app);
          return LauncherIconView(
            spec: spec,
            size: size,
            fallback: app.fallbackGlyph,
            // A pack drawable that fails to load falls back to the app's real icon.
            fallbackAppKey: spec.appKey == null && spec.glyph == null ? app.key : null,
          );
        },
      ),
    );
  }
}

/// Renders a resolved [LauncherIconSpec]. Also used by the icon picker previews.
class LauncherIconView extends StatelessWidget {
  final LauncherIconSpec spec;
  final double size;
  final IconData fallback;
  final String? fallbackAppKey;

  const LauncherIconView({
    super.key,
    required this.spec,
    required this.size,
    required this.fallback,
    this.fallbackAppKey,
  });

  @override
  Widget build(BuildContext context) {
    if (spec.glyph != null) {
      return _GlyphTile(icon: launcherGlyphs[spec.glyph] ?? fallback, size: size);
    }
    final cache = LauncherIconCache.instance;
    final listenable =
        spec.appKey != null ? cache.appIcon(spec.appKey!) : cache.packIcon(spec.pack!, spec.drawable!);
    return ValueListenableBuilder<ImageProvider?>(
      valueListenable: listenable,
      builder: (context, image, _) {
        if (image == null) {
          if (fallbackAppKey != null) {
            return LauncherIconView(spec: LauncherIconSpec.app(fallbackAppKey!), size: size, fallback: fallback);
          }
          return _GlyphTile(icon: fallback, size: size, loading: LauncherNative.isSupported);
        }
        return Image(
          image: image,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _GlyphTile(icon: fallback, size: size),
        );
      },
    );
  }
}

class _GlyphTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool loading;

  const _GlyphTile({required this.icon, required this.size, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: LauncherTheme.panel2,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: LauncherTheme.line),
      ),
      alignment: Alignment.center,
      child: loading
          ? null
          : Icon(icon, size: size * 0.5, color: LauncherTheme.text.withValues(alpha: 0.85)),
    );
  }
}
