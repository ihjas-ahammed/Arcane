import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
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

class _LauncherAppWidgetState extends State<LauncherAppWidget> {
  bool? _available;

  @override
  void initState() {
    super.initState();
    LauncherNative.getWidgetInfo(widget.entry.id).then((info) {
      if (mounted) setState(() => _available = info != null);
    });
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

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final accent = LauncherTheme.red;

    return GestureDetector(
      onLongPress: _showMenu,
      child: ClipPath(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                  child: Row(
                    children: [
                      Container(width: 4, height: 10, color: accent),
                      const SizedBox(width: 6),
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
      ),
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
