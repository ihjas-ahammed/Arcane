import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/views/launcher_items.dart';
import 'package:missions/src/screens/settings/widgets_studio/widgets_studio.dart';
import 'package:missions/src/services/widget_action_router.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:provider/provider.dart';

/// Top of the Arcane widgets page: greeting, the day's pulse, one-tap command deck and the
/// drag-and-drop quick-apps shelf.
class LauncherCommandDeck extends StatelessWidget {
  final VoidCallback onOpenArcane;

  const LauncherCommandDeck({super.key, required this.onOpenArcane});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DailyPulse(onTap: onOpenArcane),
        const SizedBox(height: 12),
        const _CommandRow(),
        const SizedBox(height: 16),
        const _QuickShelf(),
        const SizedBox(height: 18),
      ],
    );
  }
}

/// Greeting + a ring showing how much of the day is gone next to the live mission state.
class _DailyPulse extends StatefulWidget {
  final VoidCallback onTap;

  const _DailyPulse({required this.onTap});

  @override
  State<_DailyPulse> createState() => _DailyPulseState();
}

class _DailyPulseState extends State<_DailyPulse> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // The ring moves ~0.07% a minute; once a minute is plenty.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final h = _now.hour;
    if (h < 5) return 'LATE WATCH';
    if (h < 12) return 'GOOD MORNING';
    if (h < 17) return 'GOOD AFTERNOON';
    if (h < 21) return 'GOOD EVENING';
    return 'NIGHT SHIFT';
  }

  @override
  Widget build(BuildContext context) {
    final (name, running, taskTitle, progress, planCount) =
        context.select<AppProvider, (String, bool, String, double, int)>((p) {
      final live = WidgetsStudioResolvers.resolveLiveTask(p);
      final raw = p.currentUser?.displayName?.trim() ?? '';
      return (
        raw.isEmpty ? 'OPERATOR' : raw.split(' ').first.toUpperCase(),
        live.isRunning,
        live.hasTask ? live.title : '',
        live.progress.clamp(0.0, 1.0).toDouble(),
        p.taskActions.getDayPlan(helper.getTodayDateString()).length,
      );
    });

    final minutes = _now.hour * 60 + _now.minute;
    final dayFrac = minutes / (24 * 60);
    final accent = running ? LauncherTheme.red : JweTheme.accentCyan;
    final left = 24 * 60 - minutes;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LauncherTheme.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: LauncherTheme.line),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              height: 74,
              child: CustomPaint(
                painter: _PulseRingPainter(
                  day: dayFrac,
                  mission: progress,
                  dayColor: LauncherTheme.muted.withValues(alpha: 0.55),
                  missionColor: accent,
                  track: LauncherTheme.line,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(dayFrac * 100).round()}%',
                          style: LauncherTheme.rajdhani(fontSize: 17, fontWeight: FontWeight.w700, height: 1)),
                      Text('OF DAY',
                          style: LauncherTheme.rajdhani(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: LauncherTheme.muted)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_greeting, $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LauncherTheme.rajdhani(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.6)),
                  const SizedBox(height: 4),
                  Text(
                    running
                        ? 'ENGAGED · $taskTitle'
                        : taskTitle.isNotEmpty
                            ? 'NEXT · $taskTitle'
                            : planCount > 0
                                ? '$planCount MISSIONS PLANNED TODAY'
                                : 'NO MISSIONS PLANNED — OPEN ARCANE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LauncherTheme.rajdhani(
                        fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: accent),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${left ~/ 60}H ${left % 60}M LEFT TODAY${progress > 0 ? ' · MISSION ${(progress * 100).round()}%' : ''}',
                    style: LauncherTheme.rajdhani(
                        fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: LauncherTheme.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  final double day;
  final double mission;
  final Color dayColor;
  final Color missionColor;
  final Color track;

  _PulseRingPainter({
    required this.day,
    required this.mission,
    required this.dayColor,
    required this.missionColor,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    void arc(double radius, double width, double frac, Color color) {
      final rect = Rect.fromCircle(center: c, radius: radius);
      canvas.drawArc(
          rect,
          0,
          math.pi * 2,
          false,
          Paint()
            ..color = track
            ..style = PaintingStyle.stroke
            ..strokeWidth = width);
      if (frac <= 0) return;
      canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2 * frac,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = width);
    }

    arc(r - 3, 5, mission, missionColor);
    arc(r - 11, 3, day, dayColor);
  }

  @override
  bool shouldRepaint(covariant _PulseRingPainter old) =>
      old.day != day || old.mission != mission || old.missionColor != missionColor || old.dayColor != dayColor;
}

/// One-tap Arcane actions, routed through the same handler as the Android home widgets.
class _CommandRow extends StatelessWidget {
  const _CommandRow();

  @override
  Widget build(BuildContext context) {
    final running = context.select<AppProvider, bool>((p) => WidgetsStudioResolvers.resolveLiveTask(p).isRunning);
    Widget cmd(IconData icon, String label, String action, {Color? color}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: LauncherTheme.panel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: (color ?? LauncherTheme.line).withValues(alpha: color == null ? 1 : 0.6)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  HapticFeedback.selectionClick();
                  WidgetActionRouter.instance.handle(action);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 21, color: color ?? LauncherTheme.text),
                      const SizedBox(height: 5),
                      Text(label,
                          maxLines: 1,
                          style: LauncherTheme.rajdhani(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: LauncherTheme.muted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    return Row(
      children: [
        cmd(running ? MdiIcons.pause : MdiIcons.play, running ? 'PAUSE' : 'FOCUS', 'task_toggle',
            color: running ? LauncherTheme.red : null),
        cmd(MdiIcons.notebookEditOutline, 'JOURNAL', 'journal_new'),
        cmd(MdiIcons.cashMinus, 'EXPENSE', 'finance_add_expense'),
        cmd(MdiIcons.robotHappyOutline, 'NORA', 'open_nora', color: JweTheme.accentCyan),
        cmd(MdiIcons.busClock, 'BUS', 'bus_open'),
      ],
    );
  }
}

/// Drag apps here from the drawer / home / dock for one-tap access next to your Arcane widgets.
class _QuickShelf extends StatelessWidget {
  const _QuickShelf();

  @override
  Widget build(BuildContext context) {
    final service = LauncherService.instance;
    return LauncherAreaDropZone(
      area: LauncherArea.shelf,
      child: ListenableBuilder(
        listenable: Listenable.merge([service.shelf, LauncherActions.active]),
        builder: (context, _) {
          final empty = service.shelf.value.isEmpty;
          final dragging = LauncherActions.active.value != null;
          return Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            decoration: BoxDecoration(
              color: LauncherTheme.panel.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: dragging ? LauncherTheme.redSoft : LauncherTheme.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 6),
                  child: Row(
                    children: [
                      Icon(MdiIcons.lightningBoltOutline, size: 14, color: LauncherTheme.red),
                      const SizedBox(width: 6),
                      Text('QUICK APPS',
                          style: LauncherTheme.rajdhani(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                              color: LauncherTheme.muted)),
                    ],
                  ),
                ),
                if (empty)
                  SizedBox(
                    height: 64,
                    child: Center(
                      child: Text(
                        dragging ? 'DROP TO PIN HERE' : 'LONG-PRESS ANY APP, THEN DRAG IT HERE',
                        style: LauncherTheme.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: dragging ? LauncherTheme.red : LauncherTheme.muted.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  )
                else
                  const LauncherAreaGrid(area: LauncherArea.shelf, iconSize: 46),
              ],
            ),
          );
        },
      ),
    );
  }
}
