import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';

/// A real Android AppWidget hosted through the `arcane/appwidget` platform view.
/// Long-press opens its menu (resize, reorder, reconfigure, remove).
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
                child: Text(entry.label.toUpperCase(),
                    style: LauncherTheme.rajdhani(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: LauncherTheme.muted)),
              ),
              item(MdiIcons.arrowExpandVertical, 'Taller', () => service.resizeWidget(entry, entry.height + 48)),
              item(MdiIcons.arrowCollapseVertical, 'Shorter', () => service.resizeWidget(entry, entry.height - 48)),
              item(MdiIcons.arrowUp, 'Move up', () => service.moveWidget(entry, -1)),
              item(MdiIcons.arrowDown, 'Move down', () => service.moveWidget(entry, 1)),
              item(MdiIcons.cogOutline, 'Widget settings', () => LauncherNative.reconfigureWidget(entry.id)),
              item(MdiIcons.deleteOutline, 'Remove', () => service.removeWidget(entry), color: LauncherTheme.red),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return GestureDetector(
      onLongPress: _showMenu,
      child: SizedBox(
        height: entry.height,
        child: switch (_available) {
          null => const SizedBox.shrink(),
          false => _Unavailable(entry: entry),
          true => LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.round();
                return AndroidView(
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
                );
              },
            ),
        },
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
      decoration: BoxDecoration(
        color: LauncherTheme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LauncherTheme.line),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MdiIcons.alertCircleOutline, size: 18, color: LauncherTheme.muted),
          const SizedBox(width: 8),
          Text('${entry.label} is no longer available',
              style: LauncherTheme.rajdhani(fontSize: 13, fontWeight: FontWeight.w600, color: LauncherTheme.muted)),
          TextButton(
            onPressed: () => LauncherService.instance.removeWidget(entry),
            child: Text('REMOVE', style: LauncherTheme.rajdhani(fontSize: 12, fontWeight: FontWeight.w700, color: LauncherTheme.red)),
          ),
        ],
      ),
    );
  }
}
