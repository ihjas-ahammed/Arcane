import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/bus_location_service.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/utils/task_calculations.dart';
import 'widgets_studio_models.dart';

class WidgetsStudioResolvers {
  static BusWidgetData resolveLiveBus(AppProvider provider) {
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

    return BusWidgetData(
      origin: DefaultBusNetwork.formatPlaceName(origin),
      destination: DefaultBusNetwork.formatPlaceName(destination),
      nextTime: nextTime,
      nextSubStop: live.nextSubStop?.name ?? '',
      isOnBus: live.isOnBus,
      speedKmh: live.speedKmh.round(),
      minutesRemaining: smallestDiff < 9999 ? smallestDiff : -1,
    );
  }

  static TaskWidgetData resolveLiveTask(AppProvider provider) {
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

    return TaskWidgetData(
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

  static FinanceWidgetData resolveLiveFinance(AppProvider provider) {
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

    return FinanceWidgetData(
      balance: balance,
      todaySpend: todaySpend,
      monthSpend: monthSpend,
      budgetPct: budgetPct,
    );
  }

  static JournalWidgetData resolveLiveJournal(AppProvider provider) {
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

    return JournalWidgetData(
      count: todayLogs.length,
      wake: wake,
      morn: morn,
      aft: aft,
      eve: eve,
      night: night,
    );
  }
}
