import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_icon.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/views/launcher_items.dart';
import 'package:missions/src/screens/launcher/views/launcher_takeover_settings.dart';

// ── Shared chrome ─────────────────────────────────────────────

Future<T?> _sheet<T>(BuildContext context, WidgetBuilder builder, {bool tall = false}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: tall,
    showDragHandle: true,
    backgroundColor: LauncherTheme.panel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(child: builder(ctx)),
  );
}

Widget _title(String text, {String? subtitle}) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.toUpperCase(),
              style: LauncherTheme.rajdhani(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.8)),
          if (subtitle != null)
            Text(subtitle,
                style: LauncherTheme.rajdhani(fontSize: 12.5, fontWeight: FontWeight.w500, color: LauncherTheme.muted)),
        ],
      ),
    );

Widget _action(BuildContext ctx, IconData icon, String label, VoidCallback onTap, {Color? color, String? subtitle}) {
  return ListTile(
    dense: true,
    leading: Icon(icon, size: 21, color: color ?? LauncherTheme.text),
    title: Text(label, style: LauncherTheme.rajdhani(fontSize: 15.5, fontWeight: FontWeight.w600, color: color)),
    subtitle: subtitle == null
        ? null
        : Text(subtitle, style: LauncherTheme.rajdhani(fontSize: 12, color: LauncherTheme.muted)),
    onTap: () {
      Navigator.pop(ctx);
      onTap();
    },
  );
}

InputDecoration _searchDecoration(String hint) => InputDecoration(
      isDense: true,
      filled: true,
      fillColor: LauncherTheme.panel2,
      hintText: hint,
      hintStyle: LauncherTheme.rajdhani(fontSize: 14, color: LauncherTheme.muted),
      prefixIcon: Icon(MdiIcons.magnify, size: 18, color: LauncherTheme.muted),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: LauncherTheme.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: LauncherTheme.line)),
    );

// ── Home long-press menu ──────────────────────────────────────

void showLauncherHomeMenu(BuildContext context, {required VoidCallback onOpenArcaneWidgets}) {
  _sheet<void>(context, (ctx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _action(ctx, MdiIcons.appsBox, 'Add apps to home', () async {
          final picked = await pickApp(context, title: 'Add to home screen');
          if (picked != null) LauncherService.instance.addToArea(LauncherArea.home, picked.key);
        }),
        _action(ctx, MdiIcons.webPlus, 'Add web app', () => showAddWebApp(context)),
        _action(ctx, MdiIcons.widgetsOutline, 'Add widget', () => showWidgetPicker(context)),
        _action(ctx, MdiIcons.dockBottom, 'Edit dock', () => showDockEditor(context)),
        _action(ctx, MdiIcons.paletteSwatchOutline, 'Icon pack', () => showIconPackPicker(context)),
        _action(ctx, MdiIcons.targetAccount, 'Arcane widgets', onOpenArcaneWidgets),
        _action(ctx, MdiIcons.tuneVariant, 'Launcher settings', () => showLauncherSettings(context)),
      ],
    );
  });
}

// ── Launcher settings ─────────────────────────────────────────

void showLauncherSettings(BuildContext context) {
  _sheet<void>(context, (ctx) => _LauncherSettings(host: context));
}

class _LauncherSettings extends StatefulWidget {
  /// Context that outlives this sheet; follow-up sheets open from it after this one closes.
  final BuildContext host;

  const _LauncherSettings({required this.host});

  @override
  State<_LauncherSettings> createState() => _LauncherSettingsState();
}

class _LauncherSettingsState extends State<_LauncherSettings> {
  bool? _isDefault;

  @override
  void initState() {
    super.initState();
    LauncherNative.isDefaultLauncher().then((v) {
      if (mounted) setState(() => _isDefault = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    final host = widget.host;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _title('Launcher'),
        _action(
          context,
          _isDefault == true ? MdiIcons.checkDecagram : MdiIcons.homeImportOutline,
          _isDefault == true ? 'Arcane is your home app' : 'Set Arcane as home app',
          LauncherNative.openHomeSettings,
          color: _isDefault == true ? null : LauncherTheme.red,
          subtitle: 'Opens Android default-apps settings',
        ),
        if (_isDefault != true)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LauncherTakeoverSettings(),
          ),
        ValueListenableBuilder<String?>(
          valueListenable: service.iconPack,
          builder: (_, pack, __) => _action(
            context,
            MdiIcons.paletteSwatchOutline,
            'Icon pack',
            () => showIconPackPicker(host),
            subtitle: pack ?? 'Original app icons',
          ),
        ),
        _action(context, MdiIcons.dockBottom, 'Edit dock', () => showDockEditor(host)),
        _action(context, MdiIcons.widgetsOutline, 'Add widget', () => showWidgetPicker(host)),
        _action(context, MdiIcons.webPlus, 'Add web app', () => showAddWebApp(host),
            subtitle: 'Any site as an app icon (opens its installed web app if present)'),
        ValueListenableBuilder<bool>(
          valueListenable: service.shortcutsAvailable,
          builder: (_, ok, __) => ok
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(
                    'Chrome web apps installed as home-screen shortcuts can only be read by the default home app. '
                    'Installed web apps (WebAPKs) already show in the drawer; add others with "Add web app".',
                    style: LauncherTheme.rajdhani(fontSize: 12, color: LauncherTheme.muted),
                  ),
                ),
        ),
        ValueListenableBuilder<Set<String>>(
          valueListenable: service.hidden,
          builder: (_, hidden, __) => _action(
            context,
            MdiIcons.eyeOffOutline,
            'Hidden apps',
            () => showHiddenApps(host),
            subtitle: hidden.isEmpty ? 'None' : '${hidden.length} hidden',
          ),
        ),
      ],
    );
  }
}

// ── App actions (drawer long-press) ───────────────────────────

void showAppActionsSheet(BuildContext context, LauncherApp app) {
  final service = LauncherService.instance;
  final inDock = service.dock.value.contains(app.key);
  final onHome = service.home.value.contains(app.key);
  final isHidden = service.hidden.value.contains(app.key);
  _sheet<void>(context, (ctx) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: LauncherAppIcon(app: app, size: 40),
            title: Text(app.displayLabel, style: LauncherTheme.rajdhani(fontSize: 17, fontWeight: FontWeight.w700)),
            subtitle: Text(
              switch (app.kind) {
                LauncherAppKind.app => app.isOtherProfile ? '${app.package} · other profile' : app.package,
                LauncherAppKind.shortcut => 'Shortcut · ${app.package}',
                LauncherAppKind.web => app.url ?? '',
              },
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LauncherTheme.rajdhani(fontSize: 12, color: LauncherTheme.muted),
            ),
          ),
          if (app.kind == LauncherAppKind.app && !app.isArcane) _AppShortcutsRow(app: app, host: context),
          if (!onHome)
            _action(ctx, MdiIcons.homePlusOutline, 'Add to home screen', () {
              if (!service.addToArea(LauncherArea.home, app.key)) _toast(context, 'Home screen is full.');
            }),
          if (inDock)
            _action(ctx, MdiIcons.dockBottom, 'Remove from dock', () => service.removeFromArea(LauncherArea.dock, app.key))
          else if (!service.isAreaFull(LauncherArea.dock))
            _action(ctx, MdiIcons.dockBottom, 'Add to dock', () => service.addToArea(LauncherArea.dock, app.key)),
          _action(ctx, MdiIcons.folderPlusOutline, 'Add to folder…', () => showAddToFolder(context, app)),
          _action(ctx, MdiIcons.imageEditOutline, 'Change icon', () => showIconPicker(context, app)),
          _action(ctx, isHidden ? MdiIcons.eyeOutline : MdiIcons.eyeOffOutline, isHidden ? 'Unhide' : 'Hide from drawer',
              () => service.setHidden(app.key, !isHidden)),
          if (app.kind == LauncherAppKind.app && !app.isArcane)
            _action(ctx, MdiIcons.informationOutline, 'App info', () => LauncherNative.appInfo(app.package)),
          if (app.kind == LauncherAppKind.app && !app.isArcane && !app.isSystem && !app.isOtherProfile)
            _action(ctx, MdiIcons.deleteOutline, 'Uninstall', () => LauncherNative.uninstall(app.package),
                color: LauncherTheme.red),
          if (app.kind == LauncherAppKind.shortcut)
            _action(ctx, MdiIcons.deleteOutline, 'Remove shortcut', () => service.removeShortcut(app), color: LauncherTheme.red),
          if (app.kind == LauncherAppKind.web)
            _action(ctx, MdiIcons.deleteOutline, 'Remove web app', () => service.removeWebLink(app.key), color: LauncherTheme.red),
        ],
      ),
    );
  });
}

void _toast(BuildContext context, String msg) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));

/// The app's own shortcuts (Pixel-style long-press actions). Only available as default home.
class _AppShortcutsRow extends StatelessWidget {
  final LauncherApp app;
  final BuildContext host;

  const _AppShortcutsRow({required this.app, required this.host});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LauncherNative.getAppShortcuts(app.package, user: app.user),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final m in list)
              ListTile(
                dense: true,
                leading: Icon(MdiIcons.arrowTopRightThin, size: 20, color: LauncherTheme.red),
                title: Text('${m['label']}', style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  LauncherNative.launchShortcut(app.package, '${m['id']}', user: app.user);
                },
              ),
            Divider(color: LauncherTheme.line, height: 8),
          ],
        );
      },
    );
  }
}

/// Pick a folder for [app]: any existing folder, or a new one on home / in the drawer.
void showAddToFolder(BuildContext context, LauncherApp app) {
  final service = LauncherService.instance;
  _sheet<void>(context, (ctx) {
    final folders = service.folders.value.values.toList();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _title('Add ${app.displayLabel} to folder'),
          for (final f in folders)
            ListTile(
              dense: true,
              leading: LauncherFolderIconSmall(folder: f),
              title: Text(f.name, style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: Text('${f.items.length} apps', style: LauncherTheme.rajdhani(fontSize: 12, color: LauncherTheme.muted)),
              onTap: () {
                Navigator.pop(ctx);
                service.addToFolder(f.key, app.key);
              },
            ),
          _action(ctx, MdiIcons.folderPlusOutline, 'New folder on home screen', () async {
            final name = await _askName(context);
            if (name != null) service.createFolderIn(LauncherArea.home, [app.key], name: name);
          }),
          _action(ctx, MdiIcons.folderPlusOutline, 'New folder in app drawer', () async {
            final name = await _askName(context);
            if (name != null) service.createFolderIn(LauncherArea.drawer, [app.key], name: name);
          }),
        ],
      ),
    );
  });
}

Future<String?> _askName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Folder name'),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Social')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim().isEmpty ? 'Folder' : controller.text.trim()), child: const Text('CREATE')),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Menu for an item placed on home / shelf / dock (long-press without dragging).
void showPlacedItemSheet(BuildContext context, {required LauncherArea area, required String itemKey}) {
  final service = LauncherService.instance;
  final app = service.appForKey(itemKey);
  if (app != null && area == LauncherArea.dock) {
    showDockSlotSheet(context, index: service.dock.value.indexOf(itemKey), app: app);
    return;
  }
  final areaName = switch (area) {
    LauncherArea.dock => 'dock',
    LauncherArea.home => 'home screen',
    LauncherArea.shelf => 'quick apps',
    LauncherArea.drawer => 'drawer',
  };
  _sheet<void>(context, (ctx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: LauncherItemTileSmall(itemKey: itemKey),
          title: Text(
            app?.displayLabel ?? service.folderForKey(itemKey)?.name ?? '',
            style: LauncherTheme.rajdhani(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          subtitle: Text('Drag to move · drop on an app to make a folder',
              style: LauncherTheme.rajdhani(fontSize: 12, color: LauncherTheme.muted)),
        ),
        if (app != null) _action(ctx, MdiIcons.dotsHorizontal, 'App options', () => showAppActionsSheet(context, app)),
        if (app == null) _action(ctx, MdiIcons.folderOpenOutline, 'Open folder', () => LauncherActions.open(context, itemKey)),
        _action(ctx, MdiIcons.closeCircleOutline, 'Remove from $areaName', () => service.removeFromArea(area, itemKey),
            color: LauncherTheme.red),
      ],
    );
  });
}

void showHiddenApps(BuildContext context) {
  final service = LauncherService.instance;
  _sheet<void>(context, tall: true, (ctx) {
    return SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.6,
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: service.hidden,
        builder: (_, hidden, __) {
          final apps = service.apps.value.where((a) => hidden.contains(a.key)).toList();
          return Column(
            children: [
              _title('Hidden apps', subtitle: 'Hidden apps stay searchable'),
              Expanded(
                child: apps.isEmpty
                    ? Center(child: Text('No hidden apps', style: LauncherTheme.rajdhani(color: LauncherTheme.muted)))
                    : ListView.builder(
                        itemCount: apps.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: LauncherAppIcon(app: apps[i], size: 36),
                          title: Text(apps[i].displayLabel, style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600)),
                          trailing: TextButton(
                            onPressed: () => service.setHidden(apps[i].key, false),
                            child: Text('UNHIDE', style: LauncherTheme.rajdhani(fontWeight: FontWeight.w700, color: LauncherTheme.red)),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  });
}

// ── Dock ──────────────────────────────────────────────────────

void showDockSlotSheet(BuildContext context, {required int index, required LauncherApp app}) {
  final service = LauncherService.instance;
  _sheet<void>(context, (ctx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: LauncherAppIcon(app: app, size: 40),
          title: Text(app.displayLabel, style: LauncherTheme.rajdhani(fontSize: 17, fontWeight: FontWeight.w700)),
          subtitle: Text('Dock slot ${index + 1}', style: LauncherTheme.rajdhani(fontSize: 12, color: LauncherTheme.muted)),
        ),
        _action(ctx, MdiIcons.swapHorizontal, 'Replace app', () async {
          final picked = await pickApp(context, title: 'Dock slot ${index + 1}');
          if (picked != null) service.setDockSlot(index, picked.key);
        }),
        _action(ctx, MdiIcons.imageEditOutline, 'Change icon', () => showIconPicker(context, app)),
        _action(ctx, MdiIcons.dockBottom, 'Edit whole dock', () => showDockEditor(context)),
        if (!app.isArcane) _action(ctx, MdiIcons.informationOutline, 'App info', () => LauncherNative.appInfo(app.package)),
        _action(ctx, MdiIcons.closeCircleOutline, 'Remove from dock', () => service.removeDockSlot(index),
            color: LauncherTheme.red),
      ],
    );
  });
}

void showDockEditor(BuildContext context) {
  _sheet<void>(context, tall: true, (ctx) => const _DockEditor());
}

class _DockEditor extends StatelessWidget {
  const _DockEditor();

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([service.dock, service.folders]),
      builder: (context, _) {
        final keys = service.dock.value.where(service.isValidKey).toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _title('Dock', subtitle: 'Drag to reorder · tap to change · drop apps onto dock icons for folders'),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: keys.length,
                // ignore: deprecated_member_use
                onReorder: (from, to) => service.moveDockSlot(from, to > from ? to - 1 : to),
                itemBuilder: (context, i) {
                  final key = keys[i];
                  final app = service.appForKey(key);
                  final folder = service.folderForKey(key);
                  return ListTile(
                    key: ValueKey(key),
                    leading: InkWell(
                      onTap: () => app != null ? showIconPicker(context, app) : LauncherActions.open(context, key),
                      borderRadius: BorderRadius.circular(12),
                      child: LauncherItemTileSmall(itemKey: key),
                    ),
                    title: Text(app?.displayLabel ?? '${folder?.name ?? 'Folder'} (folder)',
                        style: LauncherTheme.rajdhani(fontSize: 15.5, fontWeight: FontWeight.w600)),
                    onTap: () async {
                      final picked = await pickApp(context, title: 'Dock slot ${i + 1}');
                      if (picked != null) service.setDockSlot(i, picked.key);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Remove',
                          icon: Icon(MdiIcons.closeCircleOutline, color: LauncherTheme.muted, size: 20),
                          onPressed: () => service.removeDockSlot(i),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(MdiIcons.dragHorizontalVariant, color: LauncherTheme.muted),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (keys.length < LauncherService.maxDockSlots)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: BorderSide(color: LauncherTheme.redSoft),
                  ),
                  onPressed: () async {
                    final picked = await pickApp(context, title: 'Add to dock');
                    if (picked != null) service.addToArea(LauncherArea.dock, picked.key);
                  },
                  icon: Icon(MdiIcons.plus, color: LauncherTheme.red),
                  label: Text('ADD APP',
                      style: LauncherTheme.rajdhani(fontWeight: FontWeight.w700, letterSpacing: 1.5, color: LauncherTheme.red)),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Small leading icon for list rows (app or folder).
class LauncherItemTileSmall extends StatelessWidget {
  final String itemKey;

  const LauncherItemTileSmall({super.key, required this.itemKey});

  @override
  Widget build(BuildContext context) => LauncherItemTile(itemKey: itemKey, iconSize: 40, showLabel: false);
}

class LauncherFolderIconSmall extends StatelessWidget {
  final LauncherFolder folder;

  const LauncherFolderIconSmall({super.key, required this.folder});

  @override
  Widget build(BuildContext context) => LauncherFolderIcon(folder: folder, size: 36);
}

// ── App picker ────────────────────────────────────────────────

Future<LauncherApp?> pickApp(BuildContext context, {required String title}) {
  return _sheet<LauncherApp>(context, tall: true, (ctx) => _AppPicker(title: title));
}

class _AppPicker extends StatefulWidget {
  final String title;

  const _AppPicker({required this.title});

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    final apps = _q.isEmpty ? service.apps.value : service.search(_q);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          _title(widget.title),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: _searchDecoration('Search apps'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: apps.length,
              itemExtent: 56,
              itemBuilder: (_, i) => ListTile(
                leading: LauncherAppIcon(app: apps[i], size: 36),
                title: Text(apps[i].displayLabel, style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, apps[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Icon picker ───────────────────────────────────────────────

void showIconPicker(BuildContext context, LauncherApp app) {
  _sheet<void>(context, tall: true, (ctx) => _IconPicker(app: app));
}

class _IconPicker extends StatefulWidget {
  final LauncherApp app;

  const _IconPicker({required this.app});

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  List<Map<String, String>> _packs = const [];
  String? _pack;
  Map<String, String> _packMap = const {};
  List<String> _drawables = const [];
  bool _loadingPack = false;
  String _q = '';

  @override
  void initState() {
    super.initState();
    LauncherNative.getIconPacks().then((packs) {
      if (!mounted) return;
      setState(() => _packs = packs);
      final active = LauncherService.instance.iconPack.value;
      final initial = packs.any((p) => p['package'] == active) ? active : (packs.isNotEmpty ? packs.first['package'] : null);
      if (initial != null) _selectPack(initial);
    });
  }

  Future<void> _selectPack(String pack) async {
    setState(() {
      _pack = pack;
      _loadingPack = true;
      _drawables = const [];
    });
    final (map, drawables) = await LauncherNative.getIconPack(pack);
    if (!mounted || _pack != pack) return;
    setState(() {
      _packMap = map;
      _drawables = drawables;
      _loadingPack = false;
    });
  }

  void _choose(LauncherIconOverride? o) {
    LauncherService.instance.setIconOverride(widget.app.key, o);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            ListTile(
              leading: LauncherAppIcon(app: widget.app, size: 44),
              title: Text('Icon for ${widget.app.displayLabel}',
                  style: LauncherTheme.rajdhani(fontSize: 16, fontWeight: FontWeight.w700)),
              trailing: TextButton(
                onPressed: () => _choose(null),
                child: Text('RESET', style: LauncherTheme.rajdhani(fontWeight: FontWeight.w700, color: LauncherTheme.red)),
              ),
            ),
            TabBar(
              labelColor: LauncherTheme.red,
              unselectedLabelColor: LauncherTheme.muted,
              indicatorColor: LauncherTheme.red,
              labelStyle: LauncherTheme.rajdhani(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2),
              tabs: const [Tab(text: 'APP ICONS'), Tab(text: 'ICON PACK'), Tab(text: 'GLYPHS')],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600),
                decoration: _searchDecoration('Filter'),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [_appIconsTab(), _packTab(), _glyphTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconGrid({required int count, required IndexedWidgetBuilder builder}) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 72,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: builder,
    );
  }

  /// Original icons of every installed app — including this app's own (first).
  Widget _appIconsTab() {
    final service = LauncherService.instance;
    final others = service.apps.value
        .where((a) => a.key != widget.app.key)
        .where((a) => _q.isEmpty || a.displayLabel.toLowerCase().contains(_q))
        .toList();
    final apps = [widget.app, ...others];
    return _iconGrid(
      count: apps.length,
      builder: (_, i) => Tooltip(
        message: i == 0 ? 'Original icon' : apps[i].displayLabel,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _choose(LauncherIconOverride.app(apps[i].key)),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: i == 0
                ? BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: LauncherTheme.redSoft))
                : null,
            child: LauncherIconView(
              spec: LauncherIconSpec.app(apps[i].key),
              size: 48,
              fallback: apps[i].fallbackGlyph,
            ),
          ),
        ),
      ),
    );
  }

  Widget _packTab() {
    if (_packs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No icon packs installed.\nInstall any ADW / Nova-compatible icon pack from the Play Store.',
            textAlign: TextAlign.center,
            style: LauncherTheme.rajdhani(fontSize: 14, color: LauncherTheme.muted),
          ),
        ),
      );
    }
    final pack = _pack;
    final matched = pack == null ? null : _packMap[widget.app.key];
    final names = _drawables.where((d) => _q.isEmpty || d.toLowerCase().contains(_q)).toList();
    if (matched != null && _q.isEmpty) {
      names
        ..remove(matched)
        ..insert(0, matched);
    }
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final p in _packs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p['label'] ?? p['package']!, style: LauncherTheme.rajdhani(fontSize: 13, fontWeight: FontWeight.w600)),
                    selected: p['package'] == pack,
                    selectedColor: LauncherTheme.redDim,
                    onSelected: (_) => _selectPack(p['package']!),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loadingPack
              ? Center(child: CircularProgressIndicator(color: LauncherTheme.red, strokeWidth: 2))
              : pack == null
                  ? const SizedBox.shrink()
                  : _iconGrid(
                      count: names.length,
                      builder: (_, i) => InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _choose(LauncherIconOverride.pack(pack, names[i])),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: names[i] == matched
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(12), border: Border.all(color: LauncherTheme.redSoft))
                              : null,
                          child: LauncherIconView(
                            spec: LauncherIconSpec.pack(pack, names[i]),
                            size: 48,
                            fallback: MdiIcons.imageOffOutline,
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _glyphTab() {
    final keys = launcherGlyphs.keys.where((k) => _q.isEmpty || k.contains(_q)).toList();
    return _iconGrid(
      count: keys.length,
      builder: (_, i) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _choose(LauncherIconOverride.glyph(keys[i])),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: LauncherIconView(spec: LauncherIconSpec.glyph(keys[i]), size: 48, fallback: MdiIcons.applicationOutline),
        ),
      ),
    );
  }
}

// ── Icon pack chooser ─────────────────────────────────────────

void showIconPackPicker(BuildContext context) {
  _sheet<void>(context, (ctx) => const _IconPackPicker());
}

class _IconPackPicker extends StatelessWidget {
  const _IconPackPicker();

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    return FutureBuilder<List<Map<String, String>>>(
      future: LauncherNative.getIconPacks(),
      builder: (context, snap) {
        final packs = snap.data ?? const <Map<String, String>>[];
        return ValueListenableBuilder<String?>(
          valueListenable: service.iconPack,
          builder: (context, active, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _title('Icon pack', subtitle: 'Applies to every app without a custom icon'),
              _PackTile(label: 'Original app icons', selected: active == null, onTap: () => service.setIconPack(null)),
              if (snap.connectionState != ConnectionState.done)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: LauncherTheme.red, strokeWidth: 2),
                )
              else if (packs.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Text('No icon packs installed (any ADW / Nova-compatible pack works).',
                      style: LauncherTheme.rajdhani(fontSize: 13, color: LauncherTheme.muted)),
                ),
              for (final p in packs)
                _PackTile(
                  label: p['label'] ?? p['package']!,
                  selected: active == p['package'],
                  onTap: () => service.setIconPack(p['package']),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PackTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PackTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(
        selected ? MdiIcons.checkboxMarkedCircle : MdiIcons.checkboxBlankCircleOutline,
        color: selected ? LauncherTheme.red : LauncherTheme.muted,
        size: 22,
      ),
      title: Text(label, style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Android widget picker ─────────────────────────────────────

void showWidgetPicker(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  _sheet<Map<String, dynamic>>(context, tall: true, (ctx) => const _WidgetPicker()).then((provider) async {
    if (provider == null) return;
    final entry = await LauncherService.instance.addWidget(provider);
    if (entry == null) {
      messenger?.showSnackBar(const SnackBar(content: Text('Widget was not added')));
    }
  });
}

class _WidgetPicker extends StatefulWidget {
  const _WidgetPicker();

  @override
  State<_WidgetPicker> createState() => _WidgetPickerState();
}

class _WidgetPickerState extends State<_WidgetPicker> {
  late final Future<List<Map<String, dynamic>>> _providers = LauncherNative.getWidgetProviders();
  final Map<String, Future<Uint8List?>> _previews = {};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          _title('Widgets'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: _searchDecoration('Search widgets'),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _providers,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(child: CircularProgressIndicator(color: LauncherTheme.red, strokeWidth: 2));
                }
                final all = snap.data ?? const [];
                final items = all.where((p) {
                  if (_q.isEmpty) return true;
                  return '${p['label']} ${p['appLabel']}'.toLowerCase().contains(_q);
                }).toList();
                if (items.isEmpty) {
                  return Center(child: Text('No widgets found', style: LauncherTheme.rajdhani(color: LauncherTheme.muted)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final p = items[i];
                    final provider = p['provider'] as String;
                    final showHeader = i == 0 || items[i - 1]['appLabel'] != p['appLabel'];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                            child: Text('${p['appLabel']}'.toUpperCase(),
                                style: LauncherTheme.rajdhani(
                                    fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: LauncherTheme.muted)),
                          ),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(context, p),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: LauncherTheme.panel2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: LauncherTheme.line),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 96,
                                  height: 72,
                                  child: FutureBuilder<Uint8List?>(
                                    future: _previews[provider] ??= LauncherNative.getWidgetPreview(provider),
                                    builder: (_, img) => img.data == null
                                        ? Icon(MdiIcons.widgetsOutline, color: LauncherTheme.muted)
                                        : Image.memory(img.data!, fit: BoxFit.contain, cacheWidth: 288, gaplessPlayback: true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${p['label']}',
                                          style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w700)),
                                      Text('${p['minWidth']} × ${p['minHeight']} dp',
                                          style: LauncherTheme.rajdhani(fontSize: 12, color: LauncherTheme.muted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Web apps ──────────────────────────────────────────────────

void showAddWebApp(BuildContext context) {
  final url = TextEditingController();
  final name = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add web app'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: url,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Address', hintText: 'e.g. web.whatsapp.com'),
          ),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name (optional)')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        FilledButton(
          onPressed: () {
            if (url.text.trim().isEmpty) return;
            LauncherService.instance.addWebLink(url.text, name.text);
            Navigator.pop(ctx);
          },
          child: const Text('ADD'),
        ),
      ],
    ),
  ).whenComplete(() {
    url.dispose();
    name.dispose();
  });
}
