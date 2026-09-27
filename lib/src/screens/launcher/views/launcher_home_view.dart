import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/launcher/launcher_icon.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/views/launcher_app_widget.dart';
import 'package:missions/src/screens/launcher/views/launcher_sheets.dart';
import 'package:missions/src/screens/settings/widgets_studio/widgets_studio.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:provider/provider.dart';

/// Home page: clock + Arcane status, the user's Android widgets, search pill and dock.
/// The real system status/navigation bars sit above/below it (edge-to-edge).
class LauncherHomeView extends StatelessWidget {
  final ValueChanged<LauncherApp> onLaunch;
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenArcane;
  final VoidCallback onOpenWidgetsPage;

  const LauncherHomeView({
    super.key,
    required this.onLaunch,
    required this.onOpenDrawer,
    required this.onOpenSearch,
    required this.onOpenArcane,
    required this.onOpenWidgetsPage,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HomeClock(),
                const SizedBox(height: 10),
                _ArcaneGlanceChip(onTap: onOpenArcane),
              ],
            ),
          ),
          const Expanded(child: _HomeWidgets()),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
            child: _SearchPill(onTap: onOpenSearch, onDrawer: onOpenDrawer),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: _Dock(onLaunch: onLaunch),
          ),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: LauncherTheme.isLight ? 0.08 : 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
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
    );
  }
}

class _HomeWidgets extends StatelessWidget {
  const _HomeWidgets();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<LauncherWidgetEntry>>(
      valueListenable: LauncherService.instance.widgets,
      builder: (context, entries, _) {
        if (entries.isEmpty) {
          return Center(
            child: Text(
              'LONG-PRESS TO ADD WIDGETS',
              style: LauncherTheme.rajdhani(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: LauncherTheme.muted.withValues(alpha: 0.6),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: entries.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LauncherAppWidget(key: ValueKey(entries[i].id), entry: entries[i]),
          ),
        );
      },
    );
  }
}

class _SearchPill extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onDrawer;

  const _SearchPill({required this.onTap, required this.onDrawer});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LauncherTheme.dockButtonBg,
      shape: StadiumBorder(side: BorderSide(color: LauncherTheme.dockBorder)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
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
                      Icon(MdiIcons.magnify, size: 20, color: LauncherTheme.muted),
                      const SizedBox(width: 10),
                      Text(
                        'Search apps & web',
                        style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600, color: LauncherTheme.muted),
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
    );
  }
}

class _Dock extends StatelessWidget {
  final ValueChanged<LauncherApp> onLaunch;

  const _Dock({required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([service.dock, service.apps]),
      builder: (context, _) {
        final slots = [
          for (final key in service.dock.value)
            if (service.appForKey(key) case final app?) app,
        ];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => showDockEditor(context),
          child: SizedBox(
            height: 64,
            child: slots.isEmpty
                ? Center(
                    child: TextButton.icon(
                      onPressed: () => showDockEditor(context),
                      icon: Icon(MdiIcons.plus, size: 18, color: LauncherTheme.red),
                      label: Text('ADD DOCK APPS',
                          style: LauncherTheme.rajdhani(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: LauncherTheme.red)),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < slots.length; i++)
                        _DockIcon(
                          app: slots[i],
                          onTap: () => onLaunch(slots[i]),
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            showDockSlotSheet(context, index: i, app: slots[i]);
                          },
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _DockIcon extends StatelessWidget {
  final LauncherApp app;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DockIcon({required this.app, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: app.displayLabel,
      button: true,
      child: InkResponse(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: 32,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: LauncherAppIcon(app: app, size: 52),
        ),
      ),
    );
  }
}
