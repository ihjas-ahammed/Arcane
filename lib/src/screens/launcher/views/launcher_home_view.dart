import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/views/launcher_app_widget.dart';
import 'package:missions/src/screens/launcher/views/launcher_items.dart';
import 'package:missions/src/screens/launcher/views/launcher_sheets.dart';
import 'package:missions/src/screens/settings/widgets_studio/widgets_studio.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:provider/provider.dart';

/// Home page: clock + Arcane status, the user's Android widgets, search pill and dock.
/// The real system status/navigation bars sit above/below it (edge-to-edge).
class LauncherHomeView extends StatelessWidget {
  final int pageIndex;
  final bool isPrimary;
  final ValueChanged<LauncherApp> onLaunch;
  final VoidCallback onOpenArcane;

  const LauncherHomeView({
    super.key,
    this.pageIndex = 0,
    this.isPrimary = true,
    required this.onLaunch,
    required this.onOpenArcane,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPrimary)
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                max(MediaQuery.viewPaddingOf(context).top, 28.0) + 6.0,
                24,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HomeClock(),
                  const SizedBox(height: 10),
                  _ArcaneGlanceChip(onTap: onOpenArcane),
                ],
              ),
            )
          else
            SizedBox(height: max(MediaQuery.viewPaddingOf(context).top, 28.0) + 12.0),
          Expanded(child: _HomeSpace(pageIndex: pageIndex)),
        ],
      ),
    );
  }
}

/// Minute-accurate clock that only rebuilds itself, once per minute.
class _HomeClock extends StatefulWidget {
  const _HomeClock();

  @override
  State<_HomeClock> createState() => _HomeClockState();
}

class _HomeClockState extends State<_HomeClock> with WidgetsBindingObserver {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _timer = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers drift while the process is frozen in the background; resync on return.
    if (state == AppLifecycleState.resumed) {
      setState(() => _now = DateTime.now());
      _schedule();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              DateFormat(use24h ? 'HH:mm' : 'h:mm').format(_now),
              style: LauncherTheme.rajdhani(fontSize: 60, fontWeight: FontWeight.w500, letterSpacing: 1, height: 1.0),
            ),
            if (!use24h) ...[
              const SizedBox(width: 6),
              Text(
                DateFormat('a').format(_now),
                style: LauncherTheme.rajdhani(fontSize: 20, fontWeight: FontWeight.w600, color: LauncherTheme.muted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, d MMMM').format(_now).toUpperCase(),
          style: LauncherTheme.rajdhani(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
            color: LauncherTheme.muted,
          ),
        ),
      ],
    );
  }
}

/// Live Arcane status. Selects only the few fields it shows, so unrelated provider
/// updates never rebuild the home screen.
class _ArcaneGlanceChip extends StatelessWidget {
  final VoidCallback onTap;

  const _ArcaneGlanceChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (kind, title, planCount) = context.select<AppProvider, (int, String, int)>((p) {
      final live = WidgetsStudioResolvers.resolveLiveTask(p);
      if (live.isRunning) return (0, live.title, 0);
      if (live.hasTask) return (1, live.title, 0);
      return (2, '', p.taskActions.getDayPlan(helper.getTodayDateString()).length);
    });

    final String label;
    final IconData icon;
    final Color color;
    switch (kind) {
      case 0:
        label = 'ENGAGED // $title';
        icon = MdiIcons.targetAccount;
        color = LauncherTheme.red;
        break;
      case 1:
        label = 'STANDBY // $title';
        icon = MdiIcons.clockCheckOutline;
        color = JweTheme.accentAmber;
        break;
      default:
        label = planCount > 0 ? 'PLAN // $planCount MISSIONS TODAY' : 'ARCANE // ALL SYSTEMS NOMINAL';
        icon = planCount > 0 ? MdiIcons.calendarClock : MdiIcons.shieldCheckOutline;
        color = JweTheme.accentCyan;
    }

    return InkWell(
      onTap: onTap,
      child: ClipPath(
        clipper: const Chamfer4CornerClipper(chamfer: 6),
        child: CustomPaint(
          foregroundPainter: TacticalCardBorderPainter(
            themeColor: color,
            chamfer: 6,
            bracketSize: 6,
            leftBarWidth: 2.0,
            borderColor: color.withValues(alpha: 0.35),
          ),
          child: Container(
            color: color.withValues(alpha: LauncherTheme.isLight ? 0.08 : 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LauncherTheme.rajdhani(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Home page body: the user's placed apps/folders (drag targets) above their Android widgets.
class _HomeSpace extends StatelessWidget {
  final int pageIndex;

  const _HomeSpace({this.pageIndex = 0});

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    return LauncherAreaDropZone(
      area: LauncherArea.home,
      pageIndex: pageIndex,
      child: ListenableBuilder(
        listenable: Listenable.merge([service.widgets, service.homePages, LauncherActions.active, LauncherActions.activeWidget]),
        builder: (context, _) {
          final entries = service.widgetsForPage(pageIndex);
          final pageItems = service.getPageItems(pageIndex);
          final hasApps = pageItems.isNotEmpty;
          if (entries.isEmpty && !hasApps) {
            return Center(
              child: _BottomWidgetDropTarget(
                pageIndex: pageIndex,
                targetIndex: 0,
                isEmpty: true,
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 170 + MediaQuery.viewPaddingOf(context).bottom),
            itemCount: entries.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) {
                return hasApps
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: LauncherAreaGrid(area: LauncherArea.home, iconSize: 52, pageIndex: pageIndex),
                      )
                    : const SizedBox.shrink();
              }
              if (i == entries.length + 1) {
                return _BottomWidgetDropTarget(
                  pageIndex: pageIndex,
                  targetIndex: entries.length,
                  isEmpty: false,
                );
              }
              final entry = entries[i - 1];
              return _WidgetReorderSlot(
                key: ValueKey(entry.id),
                entry: entry,
                index: i - 1,
                pageIndex: pageIndex,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LauncherAppWidget(key: ValueKey(entry.id), entry: entry),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WidgetReorderSlot extends StatefulWidget {
  final LauncherWidgetEntry entry;
  final int index;
  final int pageIndex;
  final Widget child;

  const _WidgetReorderSlot({
    super.key,
    required this.entry,
    required this.index,
    required this.pageIndex,
    required this.child,
  });

  @override
  State<_WidgetReorderSlot> createState() => _WidgetReorderSlotState();
}

class _WidgetReorderSlotState extends State<_WidgetReorderSlot> {
  int _hoverPosition = 0; // -1: top, 1: bottom, 0: none

  @override
  Widget build(BuildContext context) {
    return DragTarget<LauncherWidgetDragData>(
      onWillAcceptWithDetails: (details) => true,
      onMove: (details) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final local = renderBox.globalToLocal(details.offset);
        final isTop = local.dy < (renderBox.size.height / 2);
        final pos = isTop ? -1 : 1;
        if (pos != _hoverPosition) {
          setState(() => _hoverPosition = pos);
        }
      },
      onLeave: (_) {
        if (_hoverPosition != 0) setState(() => _hoverPosition = 0);
      },
      onAcceptWithDetails: (details) {
        final pos = _hoverPosition;
        setState(() => _hoverPosition = 0);
        HapticFeedback.mediumImpact();
        final targetIdx = pos <= 0 ? widget.index : widget.index + 1;
        LauncherService.instance.reorderWidget(
          details.data.entry,
          targetIdx,
          targetPage: widget.pageIndex,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_hoverPosition == -1) _buildInsertionIndicator(isTop: true),
            widget.child,
            if (_hoverPosition == 1) _buildInsertionIndicator(isTop: false),
          ],
        );
      },
    );
  }

  Widget _buildInsertionIndicator({required bool isTop}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 4, color: LauncherTheme.red),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 2,
              color: LauncherTheme.red,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isTop ? 'INSERT ABOVE' : 'INSERT BELOW',
            style: LauncherTheme.rajdhani(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: LauncherTheme.red,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 2,
              color: LauncherTheme.red,
            ),
          ),
          const SizedBox(width: 4),
          Container(width: 8, height: 4, color: LauncherTheme.red),
        ],
      ),
    );
  }
}

class _BottomWidgetDropTarget extends StatefulWidget {
  final int pageIndex;
  final int targetIndex;
  final bool isEmpty;

  const _BottomWidgetDropTarget({
    required this.pageIndex,
    required this.targetIndex,
    this.isEmpty = false,
  });

  @override
  State<_BottomWidgetDropTarget> createState() => _BottomWidgetDropTargetState();
}

class _BottomWidgetDropTargetState extends State<_BottomWidgetDropTarget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<LauncherWidgetDragData>(
      onWillAcceptWithDetails: (details) => true,
      onMove: (_) {
        if (!_isHovered) setState(() => _isHovered = true);
      },
      onLeave: (_) {
        if (_isHovered) setState(() => _isHovered = false);
      },
      onAcceptWithDetails: (details) {
        setState(() => _isHovered = false);
        HapticFeedback.mediumImpact();
        LauncherService.instance.reorderWidget(
          details.data.entry,
          widget.targetIndex,
          targetPage: widget.pageIndex,
        );
      },
      builder: (context, candidates, _) {
        final isDragging = LauncherActions.activeWidget.value != null;
        if (!isDragging && !widget.isEmpty) {
          return const SizedBox(height: 24);
        }
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: widget.isEmpty ? 120 : (_isHovered ? 56 : 40),
          decoration: BoxDecoration(
            border: Border.all(
              color: _isHovered
                  ? LauncherTheme.red
                  : (isDragging ? LauncherTheme.red.withValues(alpha: 0.35) : Colors.transparent),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignCenter,
            ),
            borderRadius: BorderRadius.circular(6),
            color: _isHovered
                ? LauncherTheme.red.withValues(alpha: 0.12)
                : (isDragging ? LauncherTheme.red.withValues(alpha: 0.04) : Colors.transparent),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isDragging) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(MdiIcons.arrowDownBoldBoxOutline, size: 16, color: _isHovered ? LauncherTheme.red : LauncherTheme.muted),
                    const SizedBox(width: 8),
                    Text(
                      widget.isEmpty
                          ? (widget.pageIndex == 0 ? 'DROP WIDGET HERE ON HOME' : 'DROP WIDGET ON PAGE ${widget.pageIndex + 1}')
                          : 'DROP WIDGET AT BOTTOM OF PAGE',
                      style: LauncherTheme.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: _isHovered ? LauncherTheme.red : LauncherTheme.muted,
                      ),
                    ),
                  ],
                ),
              ] else if (widget.isEmpty) ...[
                Text(
                  widget.pageIndex == 0
                      ? 'LONG-PRESS TO ADD WIDGETS · DRAG APPS HERE'
                      : 'PAGE ${widget.pageIndex + 1} · DRAG APPS HERE',
                  style: LauncherTheme.rajdhani(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: LauncherTheme.muted.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class LauncherSearchPill extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onDrawer;

  const LauncherSearchPill({super.key, required this.onTap, required this.onDrawer});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const Chamfer4CornerClipper(chamfer: 8),
      child: CustomPaint(
        foregroundPainter: TacticalCardBorderPainter(
          themeColor: LauncherTheme.red,
          chamfer: 8,
          bracketSize: 8,
          leftBarWidth: 0,
          borderColor: LauncherTheme.dockBorder,
        ),
        child: Container(
          color: LauncherTheme.dockButtonBg,
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(MdiIcons.magnify, size: 20, color: LauncherTheme.red),
                        const SizedBox(width: 10),
                        Text(
                          'SEARCH APPS & WEB',
                          style: LauncherTheme.rajdhani(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: LauncherTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onDrawer,
                tooltip: 'All apps',
                icon: Icon(MdiIcons.dotsGrid, size: 20, color: LauncherTheme.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LauncherDock extends StatelessWidget {
  final ValueChanged<LauncherApp> onLaunch;

  const LauncherDock({super.key, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    return LauncherAreaDropZone(
      area: LauncherArea.dock,
      child: ListenableBuilder(
        listenable: Listenable.merge([service.dock, service.apps, service.folders]),
        builder: (context, _) {
          final keys = service.dock.value.where(service.isValidKey).toList();
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => showDockEditor(context),
            child: SizedBox(
              height: 66,
              child: keys.isEmpty
                  ? Center(
                      child: TextButton.icon(
                        onPressed: () => showDockEditor(context),
                        icon: Icon(MdiIcons.plus, size: 18, color: LauncherTheme.red),
                        label: Text('ADD DOCK APPS',
                            style: LauncherTheme.rajdhani(
                                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: LauncherTheme.red)),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final key in keys)
                          LauncherDropSlot(
                            area: LauncherArea.dock,
                            itemKey: key,
                            child: LauncherDraggableItem(
                              itemKey: key,
                              from: LauncherArea.dock,
                              onTap: () => LauncherActions.open(context, key),
                              onMenu: () {
                                HapticFeedback.mediumImpact();
                                showPlacedItemSheet(context, area: LauncherArea.dock, itemKey: key);
                              },
                              child: Semantics(
                                button: true,
                                label: service.appForKey(key)?.displayLabel ?? service.folderForKey(key)?.name,
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: LauncherItemTile(itemKey: key, iconSize: 52, showLabel: false),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class LauncherPageIndicator extends StatelessWidget {
  final PageController controller;
  final int pageCount;

  const LauncherPageIndicator({
    super.key,
    required this.controller,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final double rawPage = controller.hasClients ? (controller.page ?? 1.0) : 1.0;
        final double homePagePos = (rawPage - 1.0).clamp(0.0, (pageCount - 1).toDouble());
        final int activeIndex = homePagePos.round().clamp(0, pageCount - 1);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pageCount, (i) {
            final isCurrent = i == activeIndex;
            return GestureDetector(
              onTap: () {
                if (controller.hasClients) {
                  controller.animateToPage(
                    1 + i,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: isCurrent ? 18 : 6,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? LauncherTheme.red
                        : (LauncherTheme.isLight
                            ? Colors.black.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.28)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
