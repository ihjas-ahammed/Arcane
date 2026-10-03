import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_icon.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/views/launcher_sheets.dart';

/// Payload of an app/folder being dragged. [from] null = dragged out of the app drawer (copy).
@immutable
class LauncherDragData {
  final String key;
  final LauncherArea? from;

  const LauncherDragData(this.key, this.from);
}

/// Hooks the launcher screen installs so deeply nested tiles can launch apps and react to drags.
class LauncherActions {
  LauncherActions._();

  static ValueChanged<LauncherApp>? launch;

  /// A drag actually started moving (the drawer closes to reveal home, drop zones appear).
  static ValueChanged<LauncherDragData>? dragMoved;
  static VoidCallback? dragEnded;

  /// The drag in progress, for drop-zone chrome.
  static final ValueNotifier<LauncherDragData?> active = ValueNotifier<LauncherDragData?>(null);

  static void open(BuildContext context, String key) {
    if (LauncherFolder.isFolderKey(key)) {
      showLauncherFolder(context, key);
      return;
    }
    final app = LauncherService.instance.appForKey(key);
    if (app != null) launch?.call(app);
  }
}

/// Icon (+ optional label) for an app or folder key.
class LauncherItemTile extends StatelessWidget {
  final String itemKey;
  final double iconSize;
  final bool showLabel;

  const LauncherItemTile({super.key, required this.itemKey, this.iconSize = 50, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    final String label;
    final Widget icon;
    if (LauncherFolder.isFolderKey(itemKey)) {
      final folder = service.folderForKey(itemKey);
      label = folder?.name ?? 'Folder';
      icon = LauncherFolderIcon(folder: folder, size: iconSize);
    } else {
      final app = service.appForKey(itemKey);
      if (app == null) return SizedBox(width: iconSize, height: iconSize);
      label = app.displayLabel;
      icon = LauncherAppIcon(app: app, size: iconSize);
    }
    if (!showLabel) return icon;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: LauncherTheme.rajdhani(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.2, height: 1.1),
        ),
      ],
    );
  }
}

/// Folder glyph: a tile with a 2×2 preview of its first apps.
class LauncherFolderIcon extends StatelessWidget {
  final LauncherFolder? folder;
  final double size;

  const LauncherFolderIcon({super.key, required this.folder, required this.size});

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    final previews = [
      for (final k in folder?.items ?? const <String>[])
        if (service.appForKey(k) case final app?) app,
    ].take(4).toList();
    final pad = size * 0.12;
    final cell = (size - pad * 2 - 3) / 2;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: LauncherTheme.panel2.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: LauncherTheme.redSoft.withValues(alpha: 0.5)),
      ),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: [
          for (final app in previews) LauncherAppIcon(app: app, size: cell),
          if (previews.isEmpty) Icon(MdiIcons.folderOutline, size: cell * 1.4, color: LauncherTheme.muted),
        ],
      ),
    );
  }
}

/// Long-press to drag; a long-press released without moving opens [onMenu] instead.
class LauncherDraggableItem extends StatefulWidget {
  final String itemKey;
  final LauncherArea? from;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final double feedbackSize;

  const LauncherDraggableItem({
    super.key,
    required this.itemKey,
    required this.from,
    required this.child,
    required this.onTap,
    required this.onMenu,
    this.feedbackSize = 58,
  });

  @override
  State<LauncherDraggableItem> createState() => _LauncherDraggableItemState();
}

class _LauncherDraggableItemState extends State<LauncherDraggableItem> {
  double _travel = 0;
  bool _moved = false;

  void _end() {
    final moved = _moved;
    _moved = false;
    _travel = 0;
    LauncherActions.active.value = null;
    LauncherActions.dragEnded?.call();
    if (!moved) widget.onMenu();
  }

  @override
  Widget build(BuildContext context) {
    final data = LauncherDragData(widget.itemKey, widget.from);
    final size = widget.feedbackSize;
    return LongPressDraggable<LauncherDragData>(
      data: data,
      delay: const Duration(milliseconds: 380),
      hapticFeedbackOnStart: true,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Transform.translate(
        offset: Offset(-size / 2, -size / 2),
        child: Material(
          type: MaterialType.transparency,
          child: Transform.scale(
            scale: 1.12,
            child: LauncherItemTile(itemKey: widget.itemKey, iconSize: size, showLabel: false),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: widget.child),
      onDragStarted: () {
        _travel = 0;
        _moved = false;
        LauncherActions.active.value = data;
      },
      onDragUpdate: (d) {
        if (_moved) return;
        _travel += d.delta.distance;
        if (_travel > 14) {
          _moved = true;
          LauncherActions.dragMoved?.call(data);
        }
      },
      onDragEnd: (_) => _end(),
      onDraggableCanceled: (_, __) {
        // onDragEnd also fires; nothing extra to do.
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: widget.child,
      ),
    );
  }
}

/// A placed item that accepts drops: centre → merge into a folder, edges → insert before/after.
class LauncherDropSlot extends StatefulWidget {
  final LauncherArea area;
  final String itemKey;
  final Widget child;
  final int? pageIndex;

  const LauncherDropSlot({
    super.key,
    required this.area,
    required this.itemKey,
    required this.child,
    this.pageIndex,
  });

  @override
  State<LauncherDropSlot> createState() => _LauncherDropSlotState();
}

class _LauncherDropSlotState extends State<LauncherDropSlot> {
  /// -1 insert before, 0 merge, 1 insert after.
  int _zone = 0;

  int _zoneFor(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0;
    final dx = box.globalToLocal(global).dx / box.size.width;
    if (dx < 0.22) return -1;
    if (dx > 0.78) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    return DragTarget<LauncherDragData>(
      onWillAcceptWithDetails: (d) => d.data.key != widget.itemKey,
      onMove: (d) {
        final z = _zoneFor(d.offset);
        if (z != _zone) setState(() => _zone = z);
      },
      onAcceptWithDetails: (d) {
        HapticFeedback.selectionClick();
        final zone = _zoneFor(d.offset);
        final dragged = d.data.key;
        final from = d.data.from;
        final folderTarget = LauncherFolder.isFolderKey(widget.itemKey);
        if (zone == 0 && !LauncherFolder.isFolderKey(dragged) && (folderTarget || widget.area != LauncherArea.drawer)) {
          service.dropOnto(widget.area, widget.itemKey, dragged, from: from, page: widget.pageIndex);
          return;
        }
        final list = widget.area == LauncherArea.home
            ? service.getPageItems(widget.pageIndex ?? service.activeHomePage.value)
            : service.areaList(widget.area).value;
        var index = list.indexOf(widget.itemKey);
        if (index < 0) return;
        if (zone == 1) index++;
        if (from == widget.area && list.indexOf(dragged) < index) index--;
        // Add to the target first (capacity-checked) before removing from the source, so a
        // drop that doesn't fit (e.g. a full dock) leaves the item where it was instead of
        // deleting it from its origin with nowhere to land.
        if (!service.addToArea(widget.area, dragged, index: index, page: widget.pageIndex)) {
          _full(context);
          return;
        }
        if (from != null && from != widget.area) service.removeFromArea(from, dragged);
      },
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: hovering && _zone == 0 ? LauncherTheme.redDim : Colors.transparent,
            border: Border(
              left: BorderSide(color: hovering && _zone == -1 ? LauncherTheme.red : Colors.transparent, width: 3),
              right: BorderSide(color: hovering && _zone == 1 ? LauncherTheme.red : Colors.transparent, width: 3),
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

void _full(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(content: Text('No room there. Remove something first, or drop onto an app to make a folder.')),
  );
}

/// Background drop target for a whole area: drops that miss every item append to the end.
class LauncherAreaDropZone extends StatelessWidget {
  final LauncherArea area;
  final Widget child;
  final int? pageIndex;

  const LauncherAreaDropZone({
    super.key,
    required this.area,
    required this.child,
    this.pageIndex,
  });

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    return DragTarget<LauncherDragData>(
      onWillAcceptWithDetails: (d) => area != LauncherArea.drawer,
      onAcceptWithDetails: (d) {
        final from = d.data.from;
        if (from == area && area != LauncherArea.home) {
          service.addToArea(area, d.data.key);
          return;
        }
        if (!service.addToArea(area, d.data.key, page: pageIndex)) {
          _full(context);
          return;
        }
        if (from != null) service.removeFromArea(from, d.data.key);
      },
      builder: (context, candidates, _) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: candidates.isNotEmpty ? LauncherTheme.redSoft : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A grid of placed items (home page / widgets-page shelf) with drag, drop and folders.
class LauncherAreaGrid extends StatelessWidget {
  final LauncherArea area;
  final double iconSize;
  final int? pageIndex;

  const LauncherAreaGrid({
    super.key,
    required this.area,
    this.iconSize = 50,
    this.pageIndex,
  });

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    final listNotifier = area == LauncherArea.home ? service.homePages : service.areaList(area);
    return ListenableBuilder(
      listenable: Listenable.merge([listNotifier, service.folders, service.apps]),
      builder: (context, _) {
        final rawKeys = area == LauncherArea.home
            ? service.getPageItems(pageIndex ?? service.activeHomePage.value)
            : service.areaList(area).value;
        final keys = rawKeys.where(service.isValidKey).toList();
        final columns = (MediaQuery.sizeOf(context).width / 86).floor().clamp(4, 6);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: 92),
          itemCount: keys.length,
          itemBuilder: (context, i) {
            final key = keys[i];
            return LauncherDropSlot(
              area: area,
              itemKey: key,
              pageIndex: pageIndex,
              child: LauncherDraggableItem(
                itemKey: key,
                from: area,
                onTap: () => LauncherActions.open(context, key),
                onMenu: () => showPlacedItemSheet(context, area: area, itemKey: key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: LauncherItemTile(itemKey: key, iconSize: iconSize),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Folder view ───────────────────────────────────────────────

void showLauncherFolder(BuildContext context, String folderKey) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _FolderDialog(folderKey: folderKey, host: context),
  );
}

class _FolderDialog extends StatefulWidget {
  final String folderKey;
  final BuildContext host;

  const _FolderDialog({required this.folderKey, required this.host});

  @override
  State<_FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<_FolderDialog> {
  late final TextEditingController _name =
      TextEditingController(text: LauncherService.instance.folderForKey(widget.folderKey)?.name ?? 'Folder');

  @override
  void dispose() {
    LauncherService.instance.renameFolder(widget.folderKey, _name.text);
    _name.dispose();
    super.dispose();
  }

  /// Where an app taken out of this folder goes: the area the folder itself lives in.
  LauncherArea _folderArea() {
    final service = LauncherService.instance;
    for (final a in LauncherArea.values) {
      if (service.areaList(a).value.contains(widget.folderKey)) return a == LauncherArea.drawer ? LauncherArea.home : a;
    }
    return LauncherArea.home;
  }

  void _itemMenu(String appKey) {
    final service = LauncherService.instance;
    final app = service.appForKey(appKey);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: LauncherTheme.panel,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: Icon(MdiIcons.folderMoveOutline, color: LauncherTheme.text),
              title: Text('Move out of folder', style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                final area = _folderArea();
                service.removeFromFolder(widget.folderKey, appKey, placeIn: service.isAreaFull(area) ? null : area);
                if (service.folderForKey(widget.folderKey) == null && mounted) Navigator.pop(context);
                setState(() {});
              },
            ),
            ListTile(
              dense: true,
              leading: Icon(MdiIcons.closeCircleOutline, color: LauncherTheme.red),
              title: Text('Remove from folder',
                  style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600, color: LauncherTheme.red)),
              onTap: () {
                Navigator.pop(ctx);
                service.removeFromFolder(widget.folderKey, appKey);
                if (service.folderForKey(widget.folderKey) == null && mounted) Navigator.pop(context);
                setState(() {});
              },
            ),
            if (app != null)
              ListTile(
                dense: true,
                leading: Icon(MdiIcons.dotsHorizontal, color: LauncherTheme.text),
                title: Text('App options', style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  showAppActionsSheet(widget.host, app);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    return ValueListenableBuilder<Map<String, LauncherFolder>>(
      valueListenable: service.folders,
      builder: (context, folders, _) {
        final folder = folders[widget.folderKey];
        final items = folder?.items.where((k) => service.appForKey(k) != null).toList() ?? const <String>[];
        return Dialog(
          backgroundColor: LauncherTheme.panel,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: LauncherTheme.line),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _name,
                        textAlign: TextAlign.center,
                        style: LauncherTheme.rajdhani(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                        onSubmitted: (v) => service.renameFolder(widget.folderKey, v),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete folder',
                      icon: Icon(MdiIcons.folderRemoveOutline, color: LauncherTheme.muted, size: 20),
                      onPressed: () {
                        service.deleteFolder(widget.folderKey);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisExtent: 90),
                    itemCount: items.length,
                    itemBuilder: (context, i) => InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(context);
                        LauncherActions.open(widget.host, items[i]);
                      },
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        _itemMenu(items[i]);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                        child: LauncherItemTile(itemKey: items[i], iconSize: 48),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await pickApp(context, title: 'Add to ${folder?.name ?? 'folder'}');
                    if (picked != null) service.addToFolder(widget.folderKey, picked.key);
                  },
                  icon: Icon(MdiIcons.plus, size: 18, color: LauncherTheme.red),
                  label: Text('ADD APP',
                      style: LauncherTheme.rajdhani(fontWeight: FontWeight.w700, letterSpacing: 1.4, color: LauncherTheme.red)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
