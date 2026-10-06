import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/views/launcher_items.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// A real Android AppWidget hosted through the `arcane/appwidget` platform view,
/// encased in a Valorant tactical chamfered HUD frame to adapt non-native Android
/// widgets to Arcane's visual language.
class LauncherAppWidget extends StatefulWidget {
  final LauncherWidgetEntry entry;

  const LauncherAppWidget({super.key, required this.entry});

  @override
  State<LauncherAppWidget> createState() => _LauncherAppWidgetState();
}

class _LauncherAppWidgetState extends State<LauncherAppWidget> with AutomaticKeepAliveClientMixin {
  /// Availability survives state re-creation, so a widget coming back into view renders
  /// immediately instead of flashing blank while the platform channel is queried again.
  static final Map<int, bool> _availabilityCache = {};

  @override
  bool get wantKeepAlive => true;

  bool? _available;
  double _travel = 0;
  bool _moved = false;

  @override
  void initState() {
    super.initState();
    _available = _availabilityCache[widget.entry.id];
    LauncherNative.getWidgetInfo(widget.entry.id).then((info) {
      _availabilityCache[widget.entry.id] = info != null;
      if (mounted && _available != (info != null)) setState(() => _available = info != null);
    });
  }

  @override
  void dispose() {
    if (LauncherActions.activeWidget.value?.entry.id == widget.entry.id) {
      LauncherActions.activeWidget.value = null;
    }
    super.dispose();
  }

  void _onDragStarted() {
    _travel = 0;
    _moved = false;
    HapticFeedback.heavyImpact();
    LauncherActions.activeWidget.value = LauncherWidgetDragData(
      entry: widget.entry,
      fromPage: widget.entry.page,
    );
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_moved) return;
    _travel += d.delta.distance;
    if (_travel > 14) {
      _moved = true;
    }
  }

  void _onDragEnd() {
    LauncherActions.activeWidget.value = null;
    LauncherActions.dragEnded?.call();
    if (!_moved && mounted) {
      _showMenu();
    }
  }

  void _showMenu() {
    HapticFeedback.mediumImpact();
    final service = LauncherService.instance;
    final entry = widget.entry;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LauncherTheme.panel,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        Widget item(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
              dense: true,
              leading: Icon(icon, color: color ?? LauncherTheme.text, size: 20),
              title: Text(label, style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Container(width: 4, height: 14, color: LauncherTheme.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.label.toUpperCase(),
                        style: LauncherTheme.rajdhani(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: LauncherTheme.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              item(MdiIcons.arrowExpandVertical, 'Taller', () => service.resizeWidget(entry, entry.height + 48)),
              item(MdiIcons.arrowCollapseVertical, 'Shorter', () => service.resizeWidget(entry, entry.height - 48)),
              item(MdiIcons.arrowUp, 'Move up', () => service.moveWidget(entry, -1)),
              item(MdiIcons.arrowDown, 'Move down', () => service.moveWidget(entry, 1)),
              if (service.homePageCount > 1)
                item(MdiIcons.pageNextOutline, 'Move to another page…', () => _showMoveWidgetPageSheet(context, entry)),
              item(MdiIcons.cogOutline, 'Widget settings', () => LauncherNative.reconfigureWidget(entry.id)),
              item(MdiIcons.deleteOutline, 'Remove', () => service.removeWidget(entry), color: LauncherTheme.red),
            ],
          ),
        );
      },
    );
  }

  void _showMoveWidgetPageSheet(BuildContext context, LauncherWidgetEntry entry) {
    final service = LauncherService.instance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LauncherTheme.panel,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final count = service.homePageCount;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('MOVE WIDGET TO PAGE',
                    style: LauncherTheme.rajdhani(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              ),
              for (var i = 0; i < count; i++)
                ListTile(
                  dense: true,
                  leading: Icon(i == 0 ? MdiIcons.homeOutline : MdiIcons.viewCarouselOutline, color: LauncherTheme.red),
                  title: Text(i == 0 ? 'Page 1 (Primary Home)' : 'Page ${i + 1}',
                      style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600)),
                  trailing: entry.page == i ? Icon(MdiIcons.check, color: LauncherTheme.red, size: 18) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    service.moveWidgetToPage(entry, i);
                  },
                ),
              ListTile(
                dense: true,
                leading: Icon(MdiIcons.plusBoxOutline, color: LauncherTheme.red),
                title: Text('New Page',
                    style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w700, color: LauncherTheme.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  final newIdx = service.addHomePage();
                  service.moveWidgetToPage(entry, newIdx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragFeedback(BuildContext context, LauncherWidgetEntry entry) {
    final width = MediaQuery.sizeOf(context).width - 24;
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: width,
        height: 64,
        child: ClipPath(
          clipper: const Chamfer4CornerClipper(chamfer: 8),
          child: Container(
            decoration: BoxDecoration(
              color: LauncherTheme.panel.withValues(alpha: 0.95),
              border: Border.all(color: LauncherTheme.red, width: 2),
              boxShadow: [
                BoxShadow(
                  color: LauncherTheme.red.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Container(width: 4, height: 24, color: LauncherTheme.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.label.toUpperCase(),
                        style: LauncherTheme.rajdhani(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: LauncherTheme.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '// DRAGGING WIDGET · DRAG TO EDGE TO FLIP PAGES',
                        style: LauncherTheme.rajdhani(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                          color: LauncherTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(MdiIcons.dragVertical, color: LauncherTheme.red, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final entry = widget.entry;
    final accent = LauncherTheme.red;
    final feedbackWidth = (MediaQuery.sizeOf(context).width - 24).clamp(240.0, 600.0);

    final cardContent = ClipPath(
      clipper: const Chamfer4CornerClipper(chamfer: 10.0),
      child: CustomPaint(
        foregroundPainter: TacticalCardBorderPainter(
          themeColor: accent,
          chamfer: 10.0,
          bracketSize: 12.0,
          leftBarWidth: 3.0,
          borderColor: LauncherTheme.line,
        ),
        child: Container(
          color: LauncherTheme.panel,
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Tactical Title Bar ──
              Container(
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                child: Row(
                  children: [
                    Icon(MdiIcons.dragHorizontal, size: 13, color: accent),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '// APP_WIDGET: ${entry.label.toUpperCase()}',
                        style: LauncherTheme.rajdhani(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: LauncherTheme.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _showMenu,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(MdiIcons.dotsVertical, size: 14, color: LauncherTheme.muted),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Hosted Widget Surface ──
              SizedBox(
                height: entry.height,
                child: switch (_available) {
                  null => const SizedBox.shrink(),
                  false => _Unavailable(entry: entry),
                  true => LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth.round();
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: AndroidView(
                            // Recreate the host view when its size changes so the provider gets the new size.
                            key: ValueKey('${entry.id}-$width-${entry.height.round()}'),
                            viewType: 'arcane/appwidget',
                            layoutDirection: Directionality.of(context),
                            creationParams: {'id': entry.id, 'width': width, 'height': entry.height.round()},
                            creationParamsCodec: const StandardMessageCodec(),
                            // Horizontal swipes still page the launcher; taps and in-widget scrolls go to the widget.
                            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                              Factory<VerticalDragGestureRecognizer>(VerticalDragGestureRecognizer.new),
                            },
                          ),
                        );
                      },
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );

    return LongPressDraggable<LauncherWidgetDragData>(
      data: LauncherWidgetDragData(entry: entry, fromPage: entry.page),
      delay: const Duration(milliseconds: 350),
      hapticFeedbackOnStart: true,
      dragAnchorStrategy: (draggable, context, point) => Offset(feedbackWidth / 2, 32),
      feedback: _buildDragFeedback(context, entry),
      childWhenDragging: Opacity(opacity: 0.25, child: cardContent),
      onDragStarted: _onDragStarted,
      onDragUpdate: _onDragUpdate,
      onDragEnd: (_) => _onDragEnd(),
      onDraggableCanceled: (_, __) => _onDragEnd(),
      child: cardContent,
    );
  }
}

class _Unavailable extends StatelessWidget {
  final LauncherWidgetEntry entry;

  const _Unavailable({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LauncherTheme.panel,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MdiIcons.alertCircleOutline, size: 16, color: LauncherTheme.red),
          const SizedBox(width: 8),
          Text(
            'FEED OFFLINE: ${entry.label.toUpperCase()}',
            style: LauncherTheme.rajdhani(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: LauncherTheme.muted),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => LauncherService.instance.removeWidget(entry),
            child: Text('DISMISS', style: LauncherTheme.rajdhani(fontSize: 11, fontWeight: FontWeight.w700, color: LauncherTheme.red)),
          ),
        ],
      ),
    );
  }
}
