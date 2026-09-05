import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/homescreen_widgets.dart';

class HomescreenWidgetsPreviewScreen extends StatefulWidget {
  const HomescreenWidgetsPreviewScreen({super.key});

  @override
  State<HomescreenWidgetsPreviewScreen> createState() => _HomescreenWidgetsPreviewScreenState();
}

class _HomescreenWidgetsPreviewScreenState extends State<HomescreenWidgetsPreviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Toggle for overriding real-time data with custom test controls per tab
  bool _overrideBus = false;
  bool _overrideTask = false;
  bool _overrideFinance = false;
  bool _overrideJournal = false;

  // 1. Bus Widget Custom Test State
  String _busOrigin = "S.S College";
  String _busDest = "Edavannappara";
  String _busNextTime = "08:15 AM";
  String _busSubStop = "Cheekkode";
  bool _busIsOnBus = true;
  int _busSpeedKmh = 32;
  int _busMinsRemaining = 14;

  // 2. Task Widget Custom Test State
  String _taskTitle = "DESIGN NEURAL ARCHITECTURE";
  String _taskSubtitle = "OPERATIONAL PROTOCOL // DEEP WORK";
  String _taskCapacity = "2h40 / 4h30";
  double _taskProgress = 0.65;
  bool _taskIsRunning = true;
  final bool _taskIsCheckpoint = false;
  final int _taskAccumulatedSeconds = 1800;
  int _taskMultitaskCount = 1;

  // 3. Finance Widget Custom Test State
  double _financeBalance = 24500.0;
  double _financeSpentToday = 450.0;
  double _financeMonthSpend = 4200.0;
  int _financeBudgetPct = 42;

  // 4. Journal Widget Custom Test State
  int _journalCount = 3;
  bool _journalWake = true;
  bool _journalMorn = true;
  bool _journalAft = false;
  bool _journalEve = false;
  bool _journalNight = false;

  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── LIVE DATA RESOLVERS ───────────────────────────────────────────────────

  ({
    String origin,
    String destination,
    String nextTime,
    String nextSubStop,
    bool isOnBus,
    int speedKmh,
    int minutesRemaining,
  }) _resolveLiveBus(AppProvider provider) {
    final live = BusLocationService.instance.currentState;
    final settings = provider.settings;

    // 1. Resolve Stops & Routes (Custom or default)
    List<BusStop> stops = DefaultBusNetwork.stops;
    if (settings.customBusStopsJson != null && settings.customBusStopsJson!.isNotEmpty) {
      stops = settings.customBusStopsJson!.map((e) => BusStop.fromJson(e)).toList();
    }

    List<BusRoute> routes = DefaultBusNetwork.getRoutes();
    if (settings.customBusRoutesJson != null && settings.customBusRoutesJson!.isNotEmpty) {
      routes = settings.customBusRoutesJson!.map((e) => BusRoute.fromJson(e)).toList();
    }

    // 2. Resolve focused Origin and Destination
    String origin = 'S.S College';
    String destination = 'Edavannappara';

    if (live.activeRoute != null) {
      origin = live.activeRoute!.originId;
      destination = live.activeRoute!.destinationId;
      final origStop = stops.firstWhereOrNull((s) => s.id == origin || s.name.toLowerCase() == origin.toLowerCase());
      final destStop = stops.firstWhereOrNull((s) => s.id == destination || s.name.toLowerCase() == destination.toLowerCase());
      if (origStop != null) origin = origStop.name;
      if (destStop != null) destination = destStop.name;
    } else if (settings.lastSelectedBusOrigin != null && settings.lastSelectedBusDestination != null) {
      origin = settings.lastSelectedBusOrigin!;
      destination = settings.lastSelectedBusDestination!;
    }

    final normOrigin = origin.toLowerCase().trim();
    final normDest = destination.toLowerCase().trim();

    // 3. Find directional departures for this route
    List<String> departures = const [];

    // Check custom schedule map
    if (settings.customBusSchedules != null && settings.customBusSchedules!.isNotEmpty) {
      for (final k in settings.customBusSchedules!.keys) {
        if (k.toLowerCase().trim() == normOrigin) {
          for (final k2 in settings.customBusSchedules![k]!.keys) {
            if (k2.toLowerCase().trim() == normDest && settings.customBusSchedules![k]![k2]!.isNotEmpty) {
              departures = settings.customBusSchedules![k]![k2]!;
              break;
            }
          }
        }
      }
    }

    // Check loaded routes directionally
    if (departures.isEmpty) {
      final activeR = routes.firstWhereOrNull((r) {
        final rOrig = stops.firstWhereOrNull((s) => s.id.toLowerCase() == r.originId.toLowerCase())?.name ?? r.originId;
        final rDest = stops.firstWhereOrNull((s) => s.id.toLowerCase() == r.destinationId.toLowerCase())?.name ?? r.destinationId;
        if (rOrig.toLowerCase().trim() == normOrigin && rDest.toLowerCase().trim() == normDest) return true;
        if (r.name.contains('→')) {
          final parts = r.name.split('→');
          if (parts.length == 2 && parts[0].trim().toLowerCase() == normOrigin && parts[1].trim().toLowerCase() == normDest) return true;
        }
        return false;
      });
      if (activeR != null && activeR.departures.isNotEmpty) {
        departures = activeR.departures;
      }
    }

    if (departures.isEmpty) {
      final defaultMap = DefaultBusNetwork.getDefaultScheduleMap();
      for (final k in defaultMap.keys) {
        if (k.toLowerCase().trim() == normOrigin) {
          for (final k2 in defaultMap[k]!.keys) {
            if (k2.toLowerCase().trim() == normDest && defaultMap[k]![k2]!.isNotEmpty) {
              departures = defaultMap[k]![k2]!;
              break;
            }
          }
        }
      }
    }

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    String nextTime = '08:15 AM';
    int smallestDiff = 99999;

    for (final t in departures) {
      try {
        final parsed = DateFormat("hh:mm a").parse(t);
        final busMin = parsed.hour * 60 + parsed.minute;
        final diff = busMin - currentMinutes;
        if (diff >= 0 && diff < smallestDiff) {
          smallestDiff = diff;
          nextTime = t;
        }
      } catch (_) {}
    }

    if (smallestDiff == 99999 && departures.isNotEmpty) {
      nextTime = departures.first;
      try {
        final parsed = DateFormat("hh:mm a").parse(nextTime);
        final busMin = parsed.hour * 60 + parsed.minute;
        smallestDiff = (busMin + 24 * 60) - currentMinutes;
      } catch (_) {}
    }

    return (
      origin: DefaultBusNetwork.formatPlaceName(origin),
      destination: DefaultBusNetwork.formatPlaceName(destination),
      nextTime: nextTime,
      nextSubStop: live.nextSubStop?.name ?? '',
      isOnBus: live.isOnBus,
      speedKmh: live.speedKmh.round(),
      minutesRemaining: smallestDiff < 9999 ? smallestDiff : -1,
    );
  }

  ({
    bool hasTask,
    String title,
    String subtitle,
    bool isRunning,
    bool isCheckpoint,
    int accumulatedSeconds,
    double progress,
    String capacity,
    List<ResolvedDayPlanItem> multitaskTasks,
  }) _resolveLiveTask(AppProvider provider) {
    final today = helper.getTodayDateString();
    final plan = List<String>.from(provider.taskActions.getDayPlan(today));

    // 1. Running session always claims the headline
    final runningEntry = provider.activeTimers.entries
        .firstWhereOrNull((e) => e.value.isRunning && e.value.type == 'subtask');
    MainTask? m;
    SubTask? s;
    SubSubTask? cp;
    bool isRunning = false;

    if (runningEntry != null) {
      m = provider.mainTasks.firstWhereOrNull((t) => t.id == runningEntry.value.mainTaskId && !t.isDeleted);
      s = m?.subTasks.firstWhereOrNull((st) => st.id == runningEntry.key && !st.isDeleted);
      if (m != null && s != null && !s.completed) {
        isRunning = true;
        final inPlan = plan.firstWhereOrNull((p) {
          final parts = p.split('|');
          return parts.length >= 2 && parts[0] == m!.id && parts[1] == s!.id;
        });
        if (inPlan != null) {
          final parts = inPlan.split('|');
          if (parts.length == 3) {
            cp = s.findCheckpoint(parts[2]);
          }
        }
      }
    }

    // 2. Fallback to first day plan item
    if (s == null) {
      for (final qId in plan) {
        final parts = qId.split('|');
        if (parts.length < 2) continue;
        final candidateM = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
        final candidateS = candidateM?.subTasks.firstWhereOrNull((st) => st.id == parts[1] && !st.isDeleted && !st.completed);
        if (candidateM != null && candidateS != null) {
          m = candidateM;
          s = candidateS;
          if (parts.length == 3) {
            cp = s.findCheckpoint(parts[2]);
          }
          break;
        }
      }
    }

    final hasTask = s != null;
    final title = s != null ? s.name.toUpperCase() : "NO ACTIVE PROTOCOL";
    final subtitle = cp != null
        ? "CHECKPOINT // ${cp.name.toUpperCase()}"
        : (m != null ? "${m.name.toUpperCase()} // DIRECTIVE" : "STANDBY // DEPLOY MISSION");
    final accumulated = s != null ? s.currentTimeSpent : 0;
    final progress = s != null ? s.calculateProgress() : 0.0;
    final capacity = s != null && s.targetCount > 0 ? "${s.currentCount}/${s.targetCount}" : "";

    final planRows = provider.taskActions.getDayPlanRows(today);
    List<String> activeRowCompoundIds = [];
    if (s != null) {
      final activeSubId = s.id;
      for (final row in planRows) {
        if (row.any((id) {
          final parts = id.split('|');
          return parts.length >= 2 && parts[1] == activeSubId;
        })) {
          activeRowCompoundIds = row;
          break;
        }
      }
    }
    if (activeRowCompoundIds.isEmpty) {
      for (final row in planRows) {
        bool hasUncompleted = false;
        for (final id in row) {
          final parts = id.split('|');
          if (parts.length >= 2) {
            final candM = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
            final candS = candM?.subTasks.firstWhereOrNull((st) => st.id == parts[1] && !st.isDeleted);
            if (candS != null && !candS.completed) {
              if (parts.length == 3) {
                final candCp = candS.findCheckpoint(parts[2]);
                if (candCp != null && !candCp.completed) {
                  hasUncompleted = true;
                  break;
                }
              } else {
                hasUncompleted = true;
                break;
              }
            }
          }
        }
        if (hasUncompleted) {
          activeRowCompoundIds = row;
          break;
        }
      }
    }
    final multitaskTasks = TaskCalculations.resolveDayPlanItems(
      mainTasks: provider.mainTasks,
      compoundIds: activeRowCompoundIds,
      activeTimers: provider.activeTimers,
    );

    return (
      hasTask: hasTask,
      title: title,
      subtitle: subtitle,
      isRunning: isRunning,
      isCheckpoint: cp != null,
      accumulatedSeconds: accumulated,
      progress: progress,
      capacity: capacity,
      multitaskTasks: multitaskTasks,
    );
  }

  ({
    double balance,
    double todaySpend,
    double monthSpend,
    int budgetPct,
  }) _resolveLiveFinance(AppProvider provider) {
    final balance = provider.financeActions.currentBalance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final thirtyAgo = today.subtract(const Duration(days: 29));

    var todaySpend = 0.0;
    var monthSpend = 0.0;
    var expense30d = 0.0;

    for (final t in provider.transactions) {
      if (t.isIncome) continue;
      final ts = t.timestamp;
      if (ts.year == today.year && ts.month == today.month && ts.day == today.day) {
        todaySpend += t.amount;
      }
      if (!ts.isBefore(monthStart)) monthSpend += t.amount;
      if (!ts.isBefore(thirtyAgo)) expense30d += t.amount;
    }

    final avg30d = expense30d / 30.0;
    final monthBudget = avg30d * 30;
    final monthPct = monthBudget > 0 ? (monthSpend / monthBudget) * 100 : 0.0;
    final budgetPct = monthPct.clamp(0.0, 999.0).round();

    return (
      balance: balance,
      todaySpend: todaySpend,
      monthSpend: monthSpend,
      budgetPct: budgetPct,
    );
  }

  ({
    int count,
    bool wake,
    bool morn,
    bool aft,
    bool eve,
    bool night,
  }) _resolveLiveJournal(AppProvider provider) {
    final logs = provider.reflectionLogs;
    final now = DateTime.now();
    final todayLogs = logs.where((log) {
      return log.timestamp.year == now.year &&
          log.timestamp.month == now.month &&
          log.timestamp.day == now.day;
    }).toList();

    bool wake = false;
    bool morn = false;
    bool aft = false;
    bool eve = false;
    bool night = false;

    for (final log in todayLogs) {
      final h = log.timestamp.hour;
      if (h >= 0 && h < 8) {
        wake = true;
      } else if (h >= 8 && h < 12) {
        morn = true;
      } else if (h >= 12 && h < 16) {
        aft = true;
      } else if (h >= 16 && h < 19) {
        eve = true;
      } else if (h >= 19 && h <= 23) {
        night = true;
      }
    }

    if (night) {
      eve = true;
      aft = true;
      morn = true;
      wake = true;
    } else if (eve) {
      aft = true;
      morn = true;
      wake = true;
    } else if (aft) {
      morn = true;
      wake = true;
    } else if (morn) {
      wake = true;
    }

    return (
      count: todayLogs.length,
      wake: wake,
      morn: morn,
      aft: aft,
      eve: eve,
      night: night,
    );
  }

  // ── PIN ACTIONS ───────────────────────────────────────────────────────────

  Future<void> _pinWidget(Future<bool?> Function() pinFn, String widgetName) async {
    final ok = await pinFn();
    if (!mounted) return;
    if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Requested to add $widgetName to Android home screen.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pinning $widgetName to home screen is not supported on this device/launcher.')),
      );
    }
  }

  // ── SYNC ACTIONS ──────────────────────────────────────────────────────────

  Future<void> _pushBusToAndroid(AppProvider provider) async {
    setState(() => _isSyncing = true);
    final bus = _overrideBus ? (
      origin: _busOrigin,
      destination: _busDest,
      nextTime: _busNextTime,
      nextSubStop: _busSubStop,
      isOnBus: _busIsOnBus,
      speedKmh: _busSpeedKmh,
      minutesRemaining: _busMinsRemaining,
    ) : _resolveLiveBus(provider);

    await HomeWidgetService.instance.publishBus(
      origin: bus.origin,
      destination: bus.destination,
      nextTime: bus.nextTime,
      nextSubStop: bus.nextSubStop,
      isOnBus: bus.isOnBus,
      speedKmh: bus.speedKmh,
      minutesRemaining: bus.minutesRemaining,
    );
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus Widget synchronized with Android OS!')),
      );
    }
  }

  Future<void> _pushTaskToAndroid(AppProvider provider) async {
    setState(() => _isSyncing = true);
    final task = _overrideTask ? (
      hasTask: true,
      title: _taskTitle,
      subtitle: _taskSubtitle,
      isRunning: _taskIsRunning,
      isCheckpoint: _taskIsCheckpoint,
      accumulatedSeconds: _taskAccumulatedSeconds,
      progress: _taskProgress,
      capacity: _taskCapacity,
      multitaskTasks: _taskMultitaskCount > 1
          ? [
              ResolvedDayPlanItem(
                compoundId: 'test-1',
                name: _taskTitle,
                parentName: 'PRIMARY PROTOCOL',
                color: Colors.cyan,
                mainTaskId: 'm1',
                subTaskId: 's1',
                isRunning: _taskIsRunning,
                totalCheckpoints: 3,
                completedCheckpoints: 1,
                durationMinutes: 45,
              ),
              ResolvedDayPlanItem(
                compoundId: 'test-2',
                name: 'SYSTEM RECON & TELEMETRY',
                parentName: 'ARCANE CORE',
                color: Colors.amber,
                mainTaskId: 'm2',
                subTaskId: 's2',
                isRunning: false,
                totalCheckpoints: 0,
                completedCheckpoints: 0,
                durationMinutes: 30,
              ),
              if (_taskMultitaskCount >= 3)
                ResolvedDayPlanItem(
                  compoundId: 'test-3',
                  name: 'SECURITY AUDIT // SUITE',
                  parentName: 'CYBERPUNK OPS',
                  color: Colors.purple,
                  mainTaskId: 'm3',
                  subTaskId: 's3',
                  isRunning: false,
                  totalCheckpoints: 4,
                  completedCheckpoints: 2,
                  durationMinutes: 20,
                ),
            ]
          : const <ResolvedDayPlanItem>[],
    ) : _resolveLiveTask(provider);

    await HomeWidgetService.instance.publishTask(
      hasTask: task.hasTask,
      title: task.title,
      subtitle: task.subtitle,
      isRunning: task.isRunning,
      isCheckpoint: task.isCheckpoint,
      accumulatedSeconds: task.accumulatedSeconds,
      progress: task.progress,
      isPhoenix: false,
      capacity: task.capacity,
      multitaskTasks: task.multitaskTasks,
    );
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task Widget synchronized with Android OS!')),
      );
    }
  }

  Future<void> _pushFinanceToAndroid(AppProvider provider) async {
    setState(() => _isSyncing = true);
    final fin = _overrideFinance ? (
      balance: _financeBalance,
      todaySpend: _financeSpentToday,
      monthSpend: _financeMonthSpend,
      budgetPct: _financeBudgetPct,
    ) : _resolveLiveFinance(provider);

    await HomeWidgetService.instance.publishFinance(
      balance: fin.balance,
      todaySpend: fin.todaySpend,
      monthSpend: fin.monthSpend,
      budgetPct: fin.budgetPct,
    );
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finance Widget synchronized with Android OS!')),
      );
    }
  }

  Future<void> _pushJournalToAndroid(AppProvider provider) async {
    setState(() => _isSyncing = true);
    final jnl = _overrideJournal ? (
      count: _journalCount,
      wake: _journalWake,
      morn: _journalMorn,
      aft: _journalAft,
      eve: _journalEve,
      night: _journalNight,
    ) : _resolveLiveJournal(provider);

    await HomeWidgetService.instance.publishJournal(
      count: jnl.count,
      wake: jnl.wake,
      morn: jnl.morn,
      aft: jnl.aft,
      eve: jnl.eve,
      night: jnl.night,
    );
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal Widget synchronized with Android OS!')),
      );
    }
  }

  Future<void> _pushAllToAndroid(AppProvider provider) async {
    setState(() => _isSyncing = true);
    await _pushBusToAndroid(provider);
    await _pushTaskToAndroid(provider);
    await _pushFinanceToAndroid(provider);
    await _pushJournalToAndroid(provider);
    if (mounted) {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: JweTheme.bgBase,
      ),
      child: Scaffold(
        backgroundColor: JweTheme.bgBase,
        appBar: AppBar(
          backgroundColor: JweTheme.bgBase,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(MdiIcons.widgetsOutline, color: JweTheme.accentAmber, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'WIDGETS STUDIO',
                  style: GoogleFonts.rajdhani(
                    color: JweTheme.textWhite,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: _isSyncing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.sync, size: 16, color: Colors.black),
              label: const Text('SYNC ALL', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: _isSyncing ? null : () => _pushAllToAndroid(provider),
            ),
            const SizedBox(width: 12),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: JweTheme.accentAmber,
            labelColor: JweTheme.accentAmber,
            unselectedLabelColor: JweTheme.textMuted,
            labelStyle: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "BUS ROUTE"),
              Tab(text: "TASK HERO"),
              Tab(text: "FINANCE"),
              Tab(text: "JOURNAL"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildBusWidgetTab(provider),
            _buildTaskWidgetTab(provider),
            _buildFinanceWidgetTab(provider),
            _buildJournalWidgetTab(provider),
          ],
        ),
      ),
    );
  }

  // ── BUS WIDGET TAB ──────────────────────────────────────────────────────────
  Widget _buildBusWidgetTab(AppProvider provider) {
    final live = _resolveLiveBus(provider);
    final origin = _overrideBus ? _busOrigin : live.origin;
    final destination = _overrideBus ? _busDest : live.destination;
    final nextTime = _overrideBus ? _busNextTime : live.nextTime;
    final nextSubStop = _overrideBus ? _busSubStop : live.nextSubStop;
    final isOnBus = _overrideBus ? _busIsOnBus : live.isOnBus;
    final speed = _overrideBus ? _busSpeedKmh : live.speedKmh;
    final minsRemaining = _overrideBus ? _busMinsRemaining : live.minutesRemaining;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            isLive: !_overrideBus,
            child: Center(
              child: BusHomeWidget(
                origin: origin,
                destination: destination,
                nextTime: nextTime,
                nextSubStop: nextSubStop,
                isOnBus: isOnBus,
                speedKmh: speed,
                minutesRemaining: minsRemaining,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButtons(
            syncLabel: "SYNC BUS WIDGET",
            onSync: () => _pushBusToAndroid(provider),
            onPin: () => _pinWidget(HomeWidgetService.instance.requestPinBus, "Live Bus Widget"),
          ),
          const SizedBox(height: 20),
          _buildTestControlsAccordion(
            isOverriding: _overrideBus,
            onToggleOverride: (val) {
              setState(() {
                _overrideBus = val;
                if (val) {
                  _busOrigin = live.origin;
                  _busDest = live.destination;
                  _busNextTime = live.nextTime;
                  _busSubStop = live.nextSubStop;
                  _busIsOnBus = live.isOnBus;
                  _busSpeedKmh = live.speedKmh;
                  _busMinsRemaining = live.minutesRemaining;
                }
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: Text("Is On Bus (Transit Active)", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  subtitle: Text("Toggles live transit beacon & sub-stop ETA", style: TextStyle(color: JweTheme.textMuted, fontSize: 10)),
                  value: _busIsOnBus,
                  activeTrackColor: JweTheme.accentTeal,
                  onChanged: (val) => setState(() => _busIsOnBus = val),
                ),
                const SizedBox(height: 8),
                _buildTextField("Origin Stop", _busOrigin, (val) => setState(() => _busOrigin = val)),
                const SizedBox(height: 8),
                _buildTextField("Destination Stop", _busDest, (val) => setState(() => _busDest = val)),
                const SizedBox(height: 8),
                _buildTextField("Next Sub-Stop", _busSubStop, (val) => setState(() => _busSubStop = val)),
                const SizedBox(height: 8),
                _buildTextField("Next Bus Time", _busNextTime, (val) => setState(() => _busNextTime = val)),
                const SizedBox(height: 12),
                Text("Speed: $_busSpeedKmh km/h", style: TextStyle(color: JweTheme.textWhite, fontSize: 12)),
                Slider(
                  value: _busSpeedKmh.toDouble(),
                  min: 0,
                  max: 80,
                  divisions: 16,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _busSpeedKmh = v.round()),
                ),
                Text("Minutes Remaining: $_busMinsRemaining min", style: TextStyle(color: JweTheme.textWhite, fontSize: 12)),
                Slider(
                  value: _busMinsRemaining.toDouble(),
                  min: 1,
                  max: 60,
                  divisions: 59,
                  activeColor: JweTheme.accentAmber,
                  onChanged: (v) => setState(() => _busMinsRemaining = v.round()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TASK WIDGET TAB ─────────────────────────────────────────────────────────
  Widget _buildTaskWidgetTab(AppProvider provider) {
    final live = _resolveLiveTask(provider);
    final title = _overrideTask ? _taskTitle : live.title;
    final subtitle = _overrideTask ? _taskSubtitle : live.subtitle;
    final isRunning = _overrideTask ? _taskIsRunning : live.isRunning;
    final isCheckpoint = _overrideTask ? _taskIsCheckpoint : live.isCheckpoint;
    final accumulated = _overrideTask ? _taskAccumulatedSeconds : live.accumulatedSeconds;
    final progress = _overrideTask ? _taskProgress : live.progress;
    final capacity = _overrideTask ? _taskCapacity : live.capacity;

    final List<ResolvedDayPlanItem> previewMultitask;
    if (_overrideTask) {
      if (_taskMultitaskCount > 1) {
        previewMultitask = [
          ResolvedDayPlanItem(
            compoundId: 'test-1',
            name: _taskTitle,
            parentName: 'PRIMARY PROTOCOL',
            color: Colors.cyan,
            mainTaskId: 'm1',
            subTaskId: 's1',
            isRunning: _taskIsRunning,
            totalCheckpoints: 3,
            completedCheckpoints: 1,
            durationMinutes: 45,
          ),
          ResolvedDayPlanItem(
            compoundId: 'test-2',
            name: 'SYSTEM RECON & TELEMETRY',
            parentName: 'ARCANE CORE',
            color: Colors.amber,
            mainTaskId: 'm2',
            subTaskId: 's2',
            isRunning: false,
            totalCheckpoints: 0,
            completedCheckpoints: 0,
            durationMinutes: 30,
          ),
          if (_taskMultitaskCount >= 3)
            ResolvedDayPlanItem(
              compoundId: 'test-3',
              name: 'SECURITY AUDIT // SUITE',
              parentName: 'CYBERPUNK OPS',
              color: Colors.purple,
              mainTaskId: 'm3',
              subTaskId: 's3',
              isRunning: false,
              totalCheckpoints: 4,
              completedCheckpoints: 2,
              durationMinutes: 20,
            ),
        ];
      } else {
        previewMultitask = const [];
      }
    } else {
      previewMultitask = live.multitaskTasks;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            isLive: !_overrideTask,
            child: Center(
              child: RunningTaskHomeWidget(
                hasTask: _overrideTask ? true : live.hasTask,
                title: title,
                subtitle: subtitle,
                isRunning: isRunning,
                isCheckpoint: isCheckpoint,
                accumulatedSeconds: accumulated,
                progress: progress,
                capacity: capacity,
                multitaskTasks: previewMultitask,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButtons(
            syncLabel: "SYNC TASK WIDGET",
            onSync: () => _pushTaskToAndroid(provider),
            onPin: () => _pinWidget(HomeWidgetService.instance.requestPinTask, "Active Task Widget"),
          ),
          const SizedBox(height: 20),
          _buildTestControlsAccordion(
            isOverriding: _overrideTask,
            onToggleOverride: (val) {
              setState(() {
                _overrideTask = val;
                if (val) {
                  _taskTitle = live.title;
                  _taskSubtitle = live.subtitle;
                  _taskIsRunning = live.isRunning;
                  _taskProgress = live.progress;
                  _taskCapacity = live.capacity;
                }
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: Text("Is Active / Running", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  value: _taskIsRunning,
                  activeTrackColor: JweTheme.accentAmber,
                  onChanged: (val) => setState(() => _taskIsRunning = val),
                ),
                const SizedBox(height: 8),
                _buildTextField("Mission Title", _taskTitle, (val) => setState(() => _taskTitle = val)),
                const SizedBox(height: 8),
                _buildTextField("Subtitle / Checkpoint", _taskSubtitle, (val) => setState(() => _taskSubtitle = val)),
                const SizedBox(height: 8),
                _buildTextField("Capacity String", _taskCapacity, (val) => setState(() => _taskCapacity = val)),
                const SizedBox(height: 12),
                Text("Progress: ${(_taskProgress * 100).toStringAsFixed(0)}%", style: TextStyle(color: JweTheme.textWhite, fontSize: 12)),
                Slider(
                  value: _taskProgress,
                  min: 0.0,
                  max: 1.0,
                  activeColor: JweTheme.accentAmber,
                  onChanged: (v) => setState(() => _taskProgress = v),
                ),
                const SizedBox(height: 12),
                Text("Multitask Layout Mode", style: TextStyle(color: JweTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text("1 Task", style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 2, label: Text("2 Tasks", style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 3, label: Text("3 Tasks", style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_taskMultitaskCount},
                  onSelectionChanged: (set) => setState(() => _taskMultitaskCount = set.first),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FINANCE WIDGET TAB ──────────────────────────────────────────────────────
  Widget _buildFinanceWidgetTab(AppProvider provider) {
    final live = _resolveLiveFinance(provider);
    final balance = _overrideFinance ? _financeBalance : live.balance;
    final todaySpend = _overrideFinance ? _financeSpentToday : live.todaySpend;
    final monthSpend = _overrideFinance ? _financeMonthSpend : live.monthSpend;
    final budgetPct = _overrideFinance ? _financeBudgetPct : live.budgetPct;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            isLive: !_overrideFinance,
            child: Center(
              child: FinanceHomeWidget(
                balance: balance,
                todaySpend: todaySpend,
                monthSpend: monthSpend,
                budgetPct: budgetPct,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButtons(
            syncLabel: "SYNC FINANCE WIDGET",
            onSync: () => _pushFinanceToAndroid(provider),
            onPin: () => _pinWidget(HomeWidgetService.instance.requestPinFinance, "Finance Widget"),
          ),
          const SizedBox(height: 20),
          _buildTestControlsAccordion(
            isOverriding: _overrideFinance,
            onToggleOverride: (val) {
              setState(() {
                _overrideFinance = val;
                if (val) {
                  _financeBalance = live.balance;
                  _financeSpentToday = live.todaySpend;
                  _financeMonthSpend = live.monthSpend;
                  _financeBudgetPct = live.budgetPct;
                }
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField("Liquid Balance", _financeBalance.toString(), (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null) setState(() => _financeBalance = parsed);
                }),
                const SizedBox(height: 8),
                _buildTextField("Today Spend", _financeSpentToday.toString(), (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null) setState(() => _financeSpentToday = parsed);
                }),
                const SizedBox(height: 8),
                _buildTextField("Month Spend", _financeMonthSpend.toString(), (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null) setState(() => _financeMonthSpend = parsed);
                }),
                const SizedBox(height: 12),
                Text("Budget %: $_financeBudgetPct%", style: TextStyle(color: JweTheme.textWhite, fontSize: 12)),
                Slider(
                  value: _financeBudgetPct.toDouble().clamp(0.0, 100.0),
                  min: 0,
                  max: 100,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _financeBudgetPct = v.round()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── JOURNAL WIDGET TAB ──────────────────────────────────────────────────────
  Widget _buildJournalWidgetTab(AppProvider provider) {
    final live = _resolveLiveJournal(provider);
    final count = _overrideJournal ? _journalCount : live.count;
    final wake = _overrideJournal ? _journalWake : live.wake;
    final morn = _overrideJournal ? _journalMorn : live.morn;
    final aft = _overrideJournal ? _journalAft : live.aft;
    final eve = _overrideJournal ? _journalEve : live.eve;
    final night = _overrideJournal ? _journalNight : live.night;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewContainer(
            title: "ANDROID HOMESCREEN PREVIEW (4x2)",
            isLive: !_overrideJournal,
            child: Center(
              child: JournalHomeWidget(
                count: count,
                wake: wake,
                morn: morn,
                aft: aft,
                eve: eve,
                night: night,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButtons(
            syncLabel: "SYNC JOURNAL WIDGET",
            onSync: () => _pushJournalToAndroid(provider),
            onPin: () => _pinWidget(HomeWidgetService.instance.requestPinJournal, "Journal Widget"),
          ),
          const SizedBox(height: 20),
          _buildTestControlsAccordion(
            isOverriding: _overrideJournal,
            onToggleOverride: (val) {
              setState(() {
                _overrideJournal = val;
                if (val) {
                  _journalCount = live.count;
                  _journalWake = live.wake;
                  _journalMorn = live.morn;
                  _journalAft = live.aft;
                  _journalEve = live.eve;
                  _journalNight = live.night;
                }
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField("Entry Count", _journalCount.toString(), (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null) setState(() => _journalCount = parsed);
                }),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: Text("WAKE Cadence Complete", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  value: _journalWake,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _journalWake = v ?? false),
                ),
                CheckboxListTile(
                  title: Text("MORN Cadence Complete", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  value: _journalMorn,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _journalMorn = v ?? false),
                ),
                CheckboxListTile(
                  title: Text("AFT Cadence Complete", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  value: _journalAft,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _journalAft = v ?? false),
                ),
                CheckboxListTile(
                  title: Text("EVE Cadence Complete", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  value: _journalEve,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _journalEve = v ?? false),
                ),
                CheckboxListTile(
                  title: Text("NIGHT Cadence Complete", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  value: _journalNight,
                  activeColor: JweTheme.accentTeal,
                  onChanged: (v) => setState(() => _journalNight = v ?? false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SHARED HELPERS ──────────────────────────────────────────────────────────
  Widget _buildPreviewContainer({
    required String title,
    required Widget child,
    bool isLive = true,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JweTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smartphone, size: 14, color: JweTheme.accentAmber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: JweTheme.textMid,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLive ? JweTheme.accentTeal.withValues(alpha: 0.15) : JweTheme.accentAmber.withValues(alpha: 0.15),
                  border: Border.all(color: isLive ? JweTheme.accentTeal : JweTheme.accentAmber),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLive ? "LIVE DATA" : "TEST OVERRIDE",
                  style: GoogleFonts.jetBrainsMono(
                    color: isLive ? JweTheme.accentTeal : JweTheme.accentAmber,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildActionButtons({
    required String syncLabel,
    required VoidCallback onSync,
    required VoidCallback onPin,
  }) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              icon: const Icon(MdiIcons.cellphoneArrowDown, size: 16),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'ADD TO HOMESCREEN',
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: JweTheme.accentAmber,
                side: BorderSide(color: JweTheme.accentAmber.withValues(alpha: 0.6), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: onPin,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(MdiIcons.upload, size: 16),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  syncLabel,
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: _isSyncing ? null : onSync,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestControlsAccordion({
    required bool isOverriding,
    required ValueChanged<bool> onToggleOverride,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isOverriding ? JweTheme.accentAmber.withValues(alpha: 0.5) : JweTheme.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          iconColor: JweTheme.accentAmber,
          collapsedIconColor: JweTheme.textMuted,
          title: Row(
            children: [
              Icon(MdiIcons.tuneVariant, size: 16, color: isOverriding ? JweTheme.accentAmber : JweTheme.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "INTERACTIVE TEST CONTROLS",
                  style: GoogleFonts.rajdhani(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: isOverriding ? JweTheme.accentAmber : JweTheme.textWhite,
                  ),
                ),
              ),
              Text(
                isOverriding ? "CUSTOM" : "OPTIONAL",
                style: GoogleFonts.jetBrainsMono(
                  color: isOverriding ? JweTheme.accentAmber : JweTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: JweTheme.bgBase,
                      border: Border.all(color: JweTheme.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Override Realtime Feed",
                                style: TextStyle(color: JweTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Enable manual values for testing edge cases",
                                style: TextStyle(color: JweTheme.textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isOverriding,
                          activeThumbColor: JweTheme.accentAmber,
                          onChanged: onToggleOverride,
                        ),
                      ],
                    ),
                  ),
                  if (isOverriding) ...[
                    child,
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "Live app data is currently streaming into this widget preview. Toggle override above to simulate custom metrics.",
                        style: TextStyle(color: JweTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String initialValue, Function(String) onChanged) {
    return TextFormField(
      key: ValueKey(initialValue),
      initialValue: initialValue,
      style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: JweTheme.isLight ? JweTheme.bgDeep : Colors.black12,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: JweTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: JweTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: JweTheme.accentAmber)),
      ),
      onChanged: onChanged,
    );
  }
}
