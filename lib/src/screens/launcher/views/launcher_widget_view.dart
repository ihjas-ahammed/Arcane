import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/views/launcher_command_deck.dart';
import 'package:missions/src/screens/launcher/views/launcher_notification_journal.dart';
import 'package:missions/src/screens/launcher/views/launcher_sheets.dart';
import 'package:missions/src/screens/settings/homescreen_widgets_preview_screen.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/homescreen_widgets.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/theme/valorant_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _WidgetTab { all, protocols, hud, notifications }

/// Arcane widgets page (left of the launcher home): live Arcane cards, tactical HUD with
/// real system controls, persistent notes, and the entry point for Android home widgets.
class LauncherWidgetView extends StatefulWidget {
  final VoidCallback onOpenArcane;

  const LauncherWidgetView({super.key, required this.onOpenArcane});

  @override
  State<LauncherWidgetView> createState() => _LauncherWidgetViewState();
}

class _LauncherWidgetViewState extends State<LauncherWidgetView> with WidgetsBindingObserver {
  Timer? _clockTimer;

  /// Only the clock text listens to this, so the per-second tick never rebuilds the page.
  final ValueNotifier<DateTime> _clock = ValueNotifier<DateTime>(DateTime.now());

  _WidgetTab _activeTab = _WidgetTab.all;
  bool _isSyncing = false;

  /// Real device state from LauncherNative.getSystemStatus.
  Map<String, bool> _system = const {};

  // Tactical Notes Controller & Persistence
  final TextEditingController _notesController = TextEditingController();
  static const String _notesPrefKey = 'arcane_launcher_quick_notes';
  Timer? _notesSave;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startClockTimer();
    _loadNotes();
    _refreshSystem();
  }

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _clock.value = DateTime.now();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Wi-Fi / Bluetooth / location are changed in system panels; re-read on return.
    if (state == AppLifecycleState.resumed) {
      _startClockTimer();
      _refreshSystem();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _clockTimer?.cancel();
      _clockTimer = null;
    }
  }

  Future<void> _refreshSystem() async {
    final status = await LauncherNative.getSystemStatus();
    if (mounted) setState(() => _system = status);
  }

  Future<void> _loadNotes() async {
    try {
      final saved = LauncherService.instance.quickNotes;
      if (saved.isNotEmpty && mounted) {
        _notesController.text = saved;
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final pSaved = prefs.getString(_notesPrefKey);
      if (pSaved != null && mounted) {
        _notesController.text = pSaved;
        LauncherService.instance.setQuickNotes(pSaved);
      }
    } catch (_) {}
  }

  void _saveNotes(String val) {
    // Debounced: one write after typing pauses instead of one per keystroke.
    _notesSave?.cancel();
    _notesSave = Timer(const Duration(milliseconds: 600), () {
      LauncherService.instance.setQuickNotes(val);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _clock.dispose();
    _notesSave?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _syncAllWidgets(AppProvider provider) async {
    setState(() => _isSyncing = true);
    await WidgetsStudioSync.pushAllToAndroid(provider, context: context);
    if (mounted) setState(() => _isSyncing = false);
  }

  void _openStudio() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HomescreenWidgetsPreviewScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = LauncherTheme.isLight;
    final provider = Provider.of<AppProvider>(context);

    return SafeArea(
      top: false,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              max(MediaQuery.viewPaddingOf(context).top, 28.0) + 6.0,
              16,
              12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ARCANE DECK',
                        style: LauncherTheme.rajdhani(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                          color: LauncherTheme.text,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'COMMANDS · QUICK APPS · LIVE WIDGETS',
                        style: LauncherTheme.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: LauncherTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Studio Shortcut
                IconButton(
                  onPressed: _openStudio,
                  icon: Icon(MdiIcons.tuneVerticalVariant, color: LauncherTheme.text, size: 20),
                  tooltip: 'Open Widgets Studio',
                ),
                // Sync to Android OS Button
                ElevatedButton.icon(
                  onPressed: _isSyncing ? null : () => _syncAllWidgets(provider),
                  icon: _isSyncing
                      ? SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isLight ? Colors.black : Colors.white,
                          ),
                        )
                      : Icon(Icons.sync, size: 14, color: isLight ? Colors.black : Colors.white),
                  label: Text(
                    'SYNC',
                    style: LauncherTheme.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isLight ? Colors.black : Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LauncherTheme.red,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),

          // ── Category Selector Tabs ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildTabChip('ALL', _WidgetTab.all),
                  const SizedBox(width: 8),
                  _buildTabChip('PROTOCOLS', _WidgetTab.protocols),
                  const SizedBox(width: 8),
                  _buildTabChip('TACTICAL HUD', _WidgetTab.hud),
                  const SizedBox(width: 8),
                  _buildTabChip(
                    'NOTIFICATIONS',
                    _WidgetTab.notifications,
                    badgeCount: provider.getNotificationsForDate(helper.getTodayDateString()).length,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Scrollable Widget Feed ──────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              physics: const BouncingScrollPhysics(),
              children: [
                // 0. Command deck: pulse, one-tap actions, drag-and-drop quick apps
                if (_activeTab == _WidgetTab.all) LauncherCommandDeck(onOpenArcane: widget.onOpenArcane),

                // 1. Arcane Protocols (Original Widgets)
                if (_activeTab == _WidgetTab.all || _activeTab == _WidgetTab.protocols) ...[
                  _buildSectionHeader('ARCANE PROTOCOLS', 'OPERATIONAL AGENTS & DASHBOARDS'),
                  const SizedBox(height: 10),
                  _buildTaskHeroCard(provider),
                  const SizedBox(height: 14),
                  _buildDayPlanCard(provider),
                  const SizedBox(height: 14),
                  _buildTodayGoalsCard(provider),
                  const SizedBox(height: 14),
                  _buildFinanceCard(provider),
                  const SizedBox(height: 14),
                  _buildJournalCard(provider),
                  const SizedBox(height: 14),
                  _buildBusRouteCard(provider),
                  const SizedBox(height: 20),
                ],

                // 2. Tactical HUD Widgets
                if (_activeTab == _WidgetTab.all || _activeTab == _WidgetTab.hud) ...[
                  _buildSectionHeader('TACTICAL HUD', 'LIVE TELEMETRY & SYSTEM CONTROLS'),
                  const SizedBox(height: 10),
                  _buildTacticalClockAndFocus(provider),
                  const SizedBox(height: 14),
                  _buildSystemMatrix(provider),
                  const SizedBox(height: 14),
                  _buildQuickNotesWidget(),
                  const SizedBox(height: 20),
                ],

                // 3. Communications Deck (Summary under ALL)
                if (_activeTab == _WidgetTab.all) ...[
                  _buildSectionHeader('COMMUNICATIONS JOURNAL', 'TELEMETRY & LOGGED NOTIFICATIONS'),
                  const SizedBox(height: 10),
                  LauncherNotificationDeckCard(
                    onOpenNotificationsTab: () => setState(() => _activeTab = _WidgetTab.notifications),
                  ),
                  const SizedBox(height: 20),
                ],

                // 4. Notifications Journal Tab View
                if (_activeTab == _WidgetTab.notifications) ...[
                  _buildSectionHeader('NOTIFICATIONS JOURNAL', 'MISSION COMMUNICATIONS TELEMETRY'),
                  const SizedBox(height: 10),
                  LauncherNotificationJournal(onOpenArcane: widget.onOpenArcane),
                  const SizedBox(height: 20),
                ],

                // 5. Android home-screen widgets (hosted on the launcher home page)
                if (_activeTab == _WidgetTab.all) ...[
                  _buildSectionHeader('ANDROID WIDGETS', 'ANY INSTALLED APP WIDGET, ON YOUR HOME PAGE'),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => showWidgetPicker(context),
                    child: ClipPath(
                      clipper: const Chamfer4CornerClipper(chamfer: 8),
                      child: CustomPaint(
                        foregroundPainter: TacticalCardBorderPainter(
                          themeColor: LauncherTheme.red,
                          chamfer: 8,
                          bracketSize: 8,
                          leftBarWidth: 2.5,
                          borderColor: LauncherTheme.redSoft,
                        ),
                        child: Container(
                          height: 46,
                          color: LauncherTheme.panel,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(MdiIcons.plus, color: LauncherTheme.red, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'ADD ANDROID WIDGET',
                                style: LauncherTheme.rajdhani(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: LauncherTheme.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, _WidgetTab tab, {int? badgeCount}) {
    final isSelected = _activeTab == tab;
    final isLight = LauncherTheme.isLight;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      child: ClipPath(
        clipper: const Chamfer4CornerClipper(chamfer: 6),
        child: CustomPaint(
          foregroundPainter: TacticalCardBorderPainter(
            themeColor: isSelected ? LauncherTheme.red : LauncherTheme.line,
            chamfer: 6,
            bracketSize: 6,
            leftBarWidth: isSelected ? 2.0 : 0.0,
            borderColor: isSelected ? LauncherTheme.red : LauncherTheme.line,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: isSelected
                ? LauncherTheme.red
                : (isLight ? const Color(0xFFE8E2D6) : const Color(0xFF13161C)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: LauncherTheme.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: isSelected
                        ? (isLight ? Colors.black : Colors.white)
                        : LauncherTheme.text,
                  ),
                ),
                if (badgeCount != null && badgeCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isLight ? Colors.black : Colors.white)
                          : LauncherTheme.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (isLight ? Colors.white : Colors.black)
                            : (isLight ? Colors.black : Colors.white),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          color: LauncherTheme.red,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: LauncherTheme.rajdhani(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
            color: LauncherTheme.text,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '// $subtitle',
          style: LauncherTheme.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            color: LauncherTheme.muted,
          ),
        ),
      ],
    );
  }

  // ── Original Widget 1: Task Hero ──────────────────────────────
  Widget _buildTaskHeroCard(AppProvider provider) {
    final live = WidgetsStudioResolvers.resolveLiveTask(provider);

    return _buildResponsiveWidgetFrame(
      title: 'TASK HERO // 4x2 ACTIVE DIRECTIVE',
      badge: live.isRunning ? 'ENGAGED' : (live.hasTask ? 'STANDBY' : 'EMPTY'),
      badgeColor: live.isRunning ? const Color(0xFF10B981) : LauncherTheme.red,
      onTap: widget.onOpenArcane,
      onPin: () => WidgetsStudioSync.pinWidget(
        context,
        HomeWidgetService.instance.requestPinTask,
        'Active Task Widget',
      ),
      child: RunningTaskHomeWidget(
        hasTask: live.hasTask,
        title: live.title,
        subtitle: live.subtitle,
        isRunning: live.isRunning,
        isCheckpoint: live.isCheckpoint,
        accumulatedSeconds: live.accumulatedSeconds,
        progress: live.progress,
        capacity: live.capacity,
        multitaskTasks: live.multitaskTasks,
        onPrimaryAction: () {
          if (!live.hasTask) {
            widget.onOpenArcane();
            return;
          }
          // Find running subtask and toggle timer
          final running = provider.activeTimers.entries
              .where((e) => e.value.isRunning && e.value.type == 'subtask')
              .firstOrNull;
          if (running != null) {
            provider.timerActions.pauseTimer(running.key);
          } else {
            // Find active or first available subtask to engage
            final today = helper.getTodayDateString();
            final plan = provider.taskActions.getDayPlan(today);
            if (plan.isNotEmpty) {
              final parts = plan.first.split('|');
              if (parts.length >= 2) {
                provider.timerActions.startTimer(
                  parts[1],
                  'subtask',
                  parts[0],
                );
              }
            }
          }
        },
        onSecondaryAction: () {
          widget.onOpenArcane();
        },
        onFinishAction: () {
          widget.onOpenArcane();
        },
      ),
    );
  }

  // ── Original Widget 2: Day Plan ───────────────────────────────
  Widget _buildDayPlanCard(AppProvider provider) {
    final today = helper.getTodayDateString();
    final livePlanTasks = TaskCalculations.resolveTopFiveDayPlanTasks(
      mainTasks: provider.mainTasks,
      plan: provider.taskActions.getDayPlan(today),
    );
    final liveTask = WidgetsStudioResolvers.resolveLiveTask(provider);
    final capacity = liveTask.capacity.isNotEmpty
        ? liveTask.capacity
        : (livePlanTasks.isNotEmpty ? '${livePlanTasks.length} ITEMS' : 'NO MISSIONS');

    return _buildResponsiveWidgetFrame(
      title: 'DAY PLAN // 4x2 TODAY TIMELINE',
      badge: '${livePlanTasks.length} MISSIONS',
      badgeColor: JweTheme.accentCyan,
      onTap: widget.onOpenArcane,
      onPin: () => WidgetsStudioSync.pinWidget(
        context,
        HomeWidgetService.instance.requestPinDayPlan,
        'Day Plan Widget',
      ),
      child: DayPlanHomeWidget(
        tasks: livePlanTasks,
        capacity: capacity,
        progress: liveTask.progress,
      ),
    );
  }

  // ── Today's Goals Widget ──────────────────────────────────────
  Widget _buildTodayGoalsCard(AppProvider provider) {
    final live = WidgetsStudioResolvers.resolveLiveGoals(provider);
    final isWeekly = live.scope == GoalScope.weekly;

    return _buildResponsiveWidgetFrame(
      title: isWeekly
          ? 'WEEKLY GOALS // 4x2 DIRECTIVES'
          : 'TODAY\'S GOALS // 4x2 DAILY DIRECTIVES',
      badge: '${live.completedCount}/${live.totalCount} DONE',
      badgeColor: JweTheme.accentAmber,
      onTap: widget.onOpenArcane,
      onPin: () => HomeWidgetService.instance.requestPinGoals(),
      child: TodayGoalsHomeWidget(
        goals: live.goals,
        progress: live.progress,
        earnedXp: live.earnedXp,
        totalXp: live.totalXp,
        scope: live.scope,
        onGoalTap: (g) => provider.toggleGoalCheck(g.id),
        onOpenArcane: widget.onOpenArcane,
      ),
    );
  }

  // ── Original Widget 3: Finance ────────────────────────────────
  Widget _buildFinanceCard(AppProvider provider) {
    final live = WidgetsStudioResolvers.resolveLiveFinance(provider);

    return _buildResponsiveWidgetFrame(
      title: 'FINANCE // 4x2 MONTHLY OVERVIEW',
      badge: '₹${live.balance.toInt()}',
      badgeColor: JweTheme.accentAmber,
      onTap: widget.onOpenArcane,
      onPin: () => WidgetsStudioSync.pinWidget(
        context,
        HomeWidgetService.instance.requestPinFinance,
        'Finance Widget',
      ),
      child: FinanceHomeWidget(
        balance: live.balance,
        todaySpend: live.todaySpend,
        monthSpend: live.monthSpend,
        budgetPct: live.budgetPct,
      ),
    );
  }

  // ── Original Widget 4: Journal ────────────────────────────────
  Widget _buildJournalCard(AppProvider provider) {
    final live = WidgetsStudioResolvers.resolveLiveJournal(provider);

    return _buildResponsiveWidgetFrame(
      title: 'JOURNAL // 4x2 REFLECTION TRACKER',
      badge: '${live.count} LOGS',
      badgeColor: JweTheme.accentTeal,
      onTap: widget.onOpenArcane,
      onPin: () => WidgetsStudioSync.pinWidget(
        context,
        HomeWidgetService.instance.requestPinJournal,
        'Journal Widget',
      ),
      child: JournalHomeWidget(
        count: live.count,
        wake: live.wake,
        morn: live.morn,
        aft: live.aft,
        eve: live.eve,
        night: live.night,
      ),
    );
  }

  // ── Original Widget 5: Bus Route ──────────────────────────────
  Widget _buildBusRouteCard(AppProvider provider) {
    final live = WidgetsStudioResolvers.resolveLiveBus(provider);

    return _buildResponsiveWidgetFrame(
      title: 'TRANSIT // 4x2 BUS TIMETABLE',
      badge: live.nextTime.isNotEmpty ? live.nextTime : 'STANDBY',
      badgeColor: JweTheme.accentCyan,
      onTap: widget.onOpenArcane,
      onPin: () => WidgetsStudioSync.pinWidget(
        context,
        HomeWidgetService.instance.requestPinBus,
        'Bus Transit Widget',
      ),
      child: BusHomeWidget(
        origin: live.origin,
        destination: live.destination,
        nextTime: live.nextTime,
        nextSubStop: live.nextSubStop,
        isOnBus: live.isOnBus,
        speedKmh: live.speedKmh,
        minutesRemaining: live.minutesRemaining,
      ),
    );
  }

  // ── Tactical HUD: Clock & Focus ───────────────────────────────
  Widget _buildTacticalClockAndFocus(AppProvider provider) {
    final live = WidgetsStudioResolvers.resolveLiveTask(provider);
    final isLight = LauncherTheme.isLight;
    final focusPct = (live.progress * 100).clamp(0, 100).toInt();

    final tealAccent = isLight ? const Color(0xFF009668) : ValorantColors.teal;

    return Row(
      children: [
        // Cyber Clock HUD
        Expanded(
          flex: 3,
          child: ClipPath(
            clipper: const Chamfer4CornerClipper(chamfer: 10),
            child: CustomPaint(
              foregroundPainter: TacticalCardBorderPainter(
                themeColor: LauncherTheme.red,
                chamfer: 10,
                bracketSize: 10,
                leftBarWidth: 3.0,
                borderColor: LauncherTheme.line,
              ),
              child: Container(
                height: 120,
                padding: const EdgeInsets.all(14),
                color: LauncherTheme.panel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TACTICAL TIME',
                          style: LauncherTheme.rajdhani(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: LauncherTheme.muted,
                          ),
                        ),
                        Icon(MdiIcons.radar, size: 14, color: LauncherTheme.red),
                      ],
                    ),
                    ValueListenableBuilder<DateTime>(
                      valueListenable: _clock,
                      builder: (_, now, __) => Text(
                        DateFormat('HH:mm:ss').format(now),
                        style: LauncherTheme.rajdhani(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: LauncherTheme.text,
                          height: 1.0,
                        ),
                      ),
                    ),
                    ValueListenableBuilder<DateTime>(
                      valueListenable: _clock,
                      builder: (_, now, __) => Text(
                        DateFormat('EEE, d MMM yyyy').format(now).toUpperCase(),
                        style: LauncherTheme.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: LauncherTheme.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Focus Gauge HUD
        Expanded(
          flex: 2,
          child: ClipPath(
            clipper: const Chamfer4CornerClipper(chamfer: 10),
            child: CustomPaint(
              foregroundPainter: TacticalCardBorderPainter(
                themeColor: tealAccent,
                chamfer: 10,
                bracketSize: 10,
                leftBarWidth: 3.0,
                borderColor: LauncherTheme.line,
              ),
              child: Container(
                height: 120,
                padding: const EdgeInsets.all(12),
                color: LauncherTheme.panel,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 58,
                          height: 58,
                          child: CircularProgressIndicator(
                            value: live.progress.clamp(0.05, 1.0),
                            strokeWidth: 5,
                            backgroundColor: isLight ? const Color(0xFFD8D2C5) : const Color(0xFF22262E),
                            valueColor: AlwaysStoppedAnimation<Color>(tealAccent),
                          ),
                        ),
                        Text(
                          '$focusPct%',
                          style: GoogleFonts.teko(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: tealAccent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'FOCUS EFFICIENCY',
                      style: LauncherTheme.rajdhani(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: LauncherTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tactical HUD: System Controls & Theme Switch ──────────────
  Widget _buildSystemMatrix(AppProvider provider) {
    final isLight = LauncherTheme.isLight;

    return ClipPath(
      clipper: const Chamfer4CornerClipper(chamfer: 10),
      child: CustomPaint(
        foregroundPainter: TacticalCardBorderPainter(
          themeColor: JweTheme.accentCyan,
          chamfer: 10,
          bracketSize: 12,
          leftBarWidth: 3.0,
          borderColor: LauncherTheme.line,
        ),
        child: Container(
          color: LauncherTheme.panel,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SYSTEM TELEMETRY MATRIX',
                    style: LauncherTheme.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: LauncherTheme.muted,
                    ),
                  ),
                  Text(
                    isLight ? 'LIGHT MODE' : 'CYBER DARK',
                    style: LauncherTheme.rajdhani(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: LauncherTheme.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSystemMatrixToggle(
                    icon: MdiIcons.wifi,
                    label: 'WiFi',
                    isOn: _system['wifi'] ?? false,
                    onTap: () => LauncherNative.openSystemPanel('wifi'),
                  ),
                  _buildSystemMatrixToggle(
                    icon: MdiIcons.bluetooth,
                    label: 'Bluetooth',
                    isOn: _system['bluetooth'] ?? false,
                    onTap: () => LauncherNative.openSystemPanel('bluetooth'),
                  ),
                  _buildSystemMatrixToggle(
                    icon: MdiIcons.airplane,
                    label: 'Airplane',
                    isOn: _system['airplane'] ?? false,
                    onTap: () => LauncherNative.openSystemPanel('airplane'),
                  ),
                  _buildSystemMatrixToggle(
                    icon: isLight ? MdiIcons.weatherSunny : MdiIcons.moonWaningCrescent,
                    label: 'Theme',
                    isOn: !isLight,
                    onTap: () {
                      final newMode = isLight ? 'dark' : 'light';
                      provider.setSettings(provider.settings..themeMode = newMode);
                    },
                  ),
                  _buildSystemMatrixToggle(
                    icon: MdiIcons.flashlight,
                    label: 'Torch',
                    isOn: _system['torch'] ?? false,
                    onTap: () async {
                      final on = !(_system['torch'] ?? false);
                      if (await LauncherNative.setTorch(on) && mounted) {
                        setState(() => _system = {..._system, 'torch': on});
                      }
                    },
                  ),
                  _buildSystemMatrixToggle(
                    icon: MdiIcons.crosshairsGps,
                    label: 'GPS',
                    isOn: _system['location'] ?? false,
                    onTap: () => LauncherNative.openSystemPanel('location'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMatrixToggle({
    required IconData icon,
    required String label,
    required bool isOn,
    required VoidCallback onTap,
  }) {
    final isLight = LauncherTheme.isLight;
    final activeTeal = isLight ? const Color(0xFF009668) : ValorantColors.teal;
    final toggleColor = isOn ? activeTeal : LauncherTheme.line;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipPath(
            clipper: const Chamfer4CornerClipper(chamfer: 6),
            child: CustomPaint(
              foregroundPainter: TacticalCardBorderPainter(
                themeColor: toggleColor,
                chamfer: 6,
                bracketSize: 4,
                leftBarWidth: 0,
                borderColor: toggleColor,
              ),
              child: Container(
                width: 44,
                height: 44,
                color: isOn
                    ? activeTeal.withValues(alpha: isLight ? 0.2 : 0.25)
                    : (isLight ? const Color(0xFFE2DDD2) : const Color(0xFF1A1D24)),
                child: Icon(
                  icon,
                  size: 20,
                  color: isOn ? activeTeal : LauncherTheme.text,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: LauncherTheme.rajdhani(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: isOn ? activeTeal : LauncherTheme.muted,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tactical HUD: Persistent Quick Notes ──────────────────────
  Widget _buildQuickNotesWidget() {
    return ClipPath(
      clipper: const Chamfer4CornerClipper(chamfer: 10),
      child: CustomPaint(
        foregroundPainter: TacticalCardBorderPainter(
          themeColor: JweTheme.accentAmber,
          chamfer: 10,
          bracketSize: 12,
          leftBarWidth: 3.0,
          borderColor: LauncherTheme.line,
        ),
        child: Container(
          color: LauncherTheme.panel,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TACTICAL SCRATCHPAD // PERSISTENT NOTES',
                    style: LauncherTheme.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: LauncherTheme.muted,
                    ),
                  ),
                  Icon(MdiIcons.noteEditOutline, size: 16, color: LauncherTheme.red),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 3,
                onChanged: _saveNotes,
                style: LauncherTheme.rajdhani(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                  color: LauncherTheme.text,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter mission notes, tactical directives, or immediate objectives...',
                  hintStyle: LauncherTheme.rajdhani(
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: LauncherTheme.muted.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: LauncherTheme.isLight ? const Color(0xFFF3EFE7) : const Color(0xFF090A0E),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widget Library: 2-Column Grid ─────────────────────────────
  // ── Frame Container for Android Widgets ────────────────────────
  Widget _buildResponsiveWidgetFrame({
    required String title,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
    required VoidCallback onPin,
    required Widget child,
  }) {
    return ClipPath(
      clipper: const Chamfer4CornerClipper(chamfer: 10),
      child: CustomPaint(
        foregroundPainter: TacticalCardBorderPainter(
          themeColor: badgeColor,
          chamfer: 10,
          bracketSize: 12,
          leftBarWidth: 3.0,
          borderColor: LauncherTheme.line,
        ),
        child: Container(
          color: LauncherTheme.panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Widget Card Titlebar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 4, height: 10, color: badgeColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: LauncherTheme.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: LauncherTheme.muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ClipPath(
                      clipper: const Chamfer4CornerClipper(chamfer: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        color: badgeColor.withValues(alpha: 0.15),
                        child: Text(
                          badge,
                          style: GoogleFonts.rajdhani(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(MdiIcons.pinOutline, size: 16, color: LauncherTheme.muted),
                      tooltip: 'Pin to Android Home',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onPin,
                    ),
                  ],
                ),
              ),

              // Scaled Widget Canvas
              InkWell(
                onTap: onTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  alignment: Alignment.center,
                  child: ClipPath(
                    clipper: const Chamfer4CornerClipper(chamfer: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
