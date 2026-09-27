import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_icon.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/views/launcher_items.dart';
import 'package:missions/src/screens/launcher/views/launcher_sheets.dart';

/// All-apps drawer with search on top. Pull down at the top of the list to close.
class LauncherDrawerView extends StatefulWidget {
  final ValueChanged<LauncherApp> onLaunch;
  final VoidCallback onClose;

  /// Finger moved down by `delta` px while closing by drag.
  final ValueChanged<double> onDragClose;

  /// Drag released with downward `velocity` (px/s).
  final ValueChanged<double> onDragCloseEnd;

  const LauncherDrawerView({
    super.key,
    required this.onLaunch,
    required this.onClose,
    required this.onDragClose,
    required this.onDragCloseEnd,
  });

  @override
  State<LauncherDrawerView> createState() => LauncherDrawerViewState();
}

class LauncherDrawerViewState extends State<LauncherDrawerView> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  bool _dragClosing = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQuery);
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _lastQuery = '';
  void _onQuery() {
    if (_query.text == _lastQuery) return;
    _lastQuery = _query.text;
    setState(() {});
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void focusSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void reset() {
    _focus.unfocus();
    if (_query.text.isNotEmpty) _query.clear();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _submit(List<LauncherApp> results) {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    if (results.isNotEmpty) {
      widget.onLaunch(results.first);
    } else {
      LauncherNative.openWebSearch(q);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n is OverscrollNotification && n.overscroll < 0 && n.dragDetails != null) {
      if (!_dragClosing) {
        _dragClosing = true;
        _focus.unfocus();
      }
      widget.onDragClose(n.dragDetails!.delta.dy);
    } else if (_dragClosing && n is ScrollUpdateNotification && n.dragDetails != null) {
      widget.onDragClose(n.dragDetails!.delta.dy);
    } else if (_dragClosing && n is ScrollEndNotification) {
      _dragClosing = false;
      widget.onDragCloseEnd(n.dragDetails?.primaryVelocity ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final columns = (media.size.width / 86).floor().clamp(4, 6);
    final service = LauncherService.instance;

    return Material(
      color: LauncherTheme.bg.withValues(alpha: 0.97),
      child: Padding(
        padding: EdgeInsets.only(top: media.padding.top, bottom: media.viewInsets.bottom),
        child: Column(
          children: [
            // Handle + search. Dragging here closes the drawer too.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (d) => widget.onDragClose(d.primaryDelta ?? 0),
              onVerticalDragEnd: (d) => widget.onDragCloseEnd(d.primaryVelocity ?? 0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: LauncherTheme.line, borderRadius: BorderRadius.circular(2)),
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildSearchField()),
                        IconButton(
                          tooltip: 'Launcher settings',
                          onPressed: () => showLauncherSettings(context),
                          icon: Icon(MdiIcons.tuneVariant, color: LauncherTheme.text, size: 22),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([service.apps, service.hidden, service.drawerFolders, service.folders]),
                builder: (context, _) {
                  final q = _query.text.trim();
                  final hidden = service.hidden.value;
                  final inFolders = service.appsInDrawerFolders;
                  final folderKeys = q.isEmpty ? service.drawerFolders.value.where(service.isValidKey).toList() : const <String>[];
                  final List<LauncherApp> apps = q.isEmpty
                      ? service.apps.value.where((a) => !hidden.contains(a.key) && !inFolders.contains(a.key)).toList()
                      : service.search(q);
                  final suggestions = q.isEmpty ? service.suggestions(limit: columns) : const <LauncherApp>[];

                  return NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: CustomScrollView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        if (suggestions.isNotEmpty) ...[
                          _sectionLabel('SUGGESTED'),
                          _grid(suggestions, columns),
                          SliverToBoxAdapter(
                            child: Divider(color: LauncherTheme.line, height: 20, indent: 16, endIndent: 16),
                          ),
                        ],
                        if (folderKeys.isNotEmpty) _folderGrid(folderKeys, columns),
                        if (q.isNotEmpty) _sectionLabel(apps.isEmpty ? 'NO APPS FOUND' : 'APPS'),
                        _grid(apps, columns),
                        if (q.isNotEmpty) SliverToBoxAdapter(child: _webSearchTile(q)),
                        SliverPadding(padding: EdgeInsets.only(bottom: media.padding.bottom + 16)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _query,
      focusNode: _focus,
      textInputAction: TextInputAction.go,
      onSubmitted: (_) => _submit(LauncherService.instance.search(_query.text)),
      style: LauncherTheme.rajdhani(fontSize: 16, fontWeight: FontWeight.w600),
      cursorColor: LauncherTheme.red,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: LauncherTheme.panel2,
        hintText: 'Search apps',
        hintStyle: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600, color: LauncherTheme.muted),
        prefixIcon: Icon(MdiIcons.magnify, color: LauncherTheme.muted, size: 20),
        suffixIcon: _query.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(MdiIcons.close, size: 18, color: LauncherTheme.muted),
                onPressed: _query.clear,
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: LauncherTheme.line)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: LauncherTheme.line)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: LauncherTheme.redSoft)),
      ),
    );
  }

  Widget _sectionLabel(String text) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Text(text,
              style: LauncherTheme.rajdhani(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2, color: LauncherTheme.muted)),
        ),
      );

  Widget _grid(List<LauncherApp> apps, int columns) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 92,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => LauncherDraggableItem(
            itemKey: apps[i].key,
            from: null,
            onTap: () => widget.onLaunch(apps[i]),
            onMenu: () {
              _focus.unfocus();
              showAppActionsSheet(context, apps[i]);
            },
            child: _AppTile(app: apps[i]),
          ),
          childCount: apps.length,
        ),
      ),
    );
  }

  Widget _folderGrid(List<String> keys, int columns) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: 92),
        delegate: SliverChildBuilderDelegate(
          (context, i) => LauncherDropSlot(
            area: LauncherArea.drawer,
            itemKey: keys[i],
            child: LauncherDraggableItem(
              itemKey: keys[i],
              from: LauncherArea.drawer,
              onTap: () => LauncherActions.open(context, keys[i]),
              onMenu: () => showPlacedItemSheet(context, area: LauncherArea.drawer, itemKey: keys[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: LauncherItemTile(itemKey: keys[i], iconSize: 50),
              ),
            ),
          ),
          childCount: keys.length,
        ),
      ),
    );
  }

  Widget _webSearchTile(String q) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: LauncherTheme.line)),
        tileColor: LauncherTheme.panel,
        leading: Icon(MdiIcons.web, color: LauncherTheme.red),
        title: Text('Search the web for "$q"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600)),
        onTap: () => LauncherNative.openWebSearch(q),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final LauncherApp app;

  const _AppTile({required this.app});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LauncherAppIcon(app: app, size: 50),
          const SizedBox(height: 6),
          Text(
            app.displayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: LauncherTheme.rajdhani(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.2, height: 1.1),
          ),
        ],
      ),
    );
  }
}
