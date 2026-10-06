import 'package:intl/intl.dart';
import 'package:missions/src/providers/app_provider.dart';

/// Gathers the "what actually happened today" context that daily briefings (built-in and
/// external AI) are grounded in: tracked work, completed steps, health, finance detail and the
/// communications journal. Everything is derived from existing app state; nothing is stored.
class BriefingContextHelper {
  static String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// Structured form, used for the external-AI export JSON.
  static Map<String, dynamic> buildDayContextMap(AppProvider provider, DateTime date) {
    final dateStr = _day(date);
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // ── Work sessions that started on this day ──
    final sessions = <Map<String, dynamic>>[];
    final minutesByTask = <String, int>{};
    for (final task in provider.mainTasks) {
      if (task.isDeleted) continue;
      for (final sub in task.subTasks) {
        for (final s in sub.sessions) {
          if (s.startTime.isBefore(dayStart) || !s.startTime.isBefore(dayEnd)) continue;
          final mins = s.durationMinutes;
          sessions.add({
            'task': task.name,
            'step': sub.name,
            'start': DateFormat('HH:mm').format(s.startTime),
            'end': DateFormat('HH:mm').format(s.endTime),
            'minutes': mins,
          });
          minutesByTask[task.name] = (minutesByTask[task.name] ?? 0) + mins;
        }
      }
    }
    sessions.sort((a, b) => (a['start'] as String).compareTo(b['start'] as String));

    // ── Steps / checkpoints completed that day (from the history ledger) ──
    final dayRaw = provider.completedByDay[dateStr];
    final dayData = dayRaw is Map ? Map<String, dynamic>.from(dayRaw) : <String, dynamic>{};
    final completedSteps = <String>[
      for (final s in (dayData['subtasksCompleted'] as List? ?? const []).whereType<Map>())
        (s['subtaskName'] ?? s['name'] ?? '').toString(),
    ].where((n) => n.isNotEmpty).toList();
    final completedCheckpoints = <String>[
      for (final c in (dayData['checkpointsCompleted'] as List? ?? const []).whereType<Map>())
        (c['name'] ?? '').toString(),
    ].where((n) => n.isNotEmpty).toList();

    // ── Day plan, resolved to names ──
    final plan = <String>[];
    for (final id in provider.taskActions.getDayPlan(dateStr)) {
      final parts = id.split('|');
      if (parts.length != 2) continue;
      for (final t in provider.mainTasks) {
        if (t.id != parts[0]) continue;
        for (final st in t.subTasks) {
          if (st.id == parts[1]) plan.add('${t.name} - ${st.name}${st.completed ? ' (done)' : ''}');
        }
      }
    }

    // ── Health ──
    final health = <String, dynamic>{};
    final log = provider.healthLogs[dateStr];
    if (log != null) {
      final foodById = {for (final f in provider.foodItems) f.id: f};
      var kcal = 0;
      final meals = <String>[];
      for (final m in log.meals) {
        final f = foodById[m.foodItemId];
        if (f == null) continue;
        kcal += f.calories;
        meals.add('${DateFormat('HH:mm').format(m.timestamp)} ${f.name} (${f.calories} kcal)');
      }
      health['water_glasses'] = log.waterGlasses;
      if (meals.isNotEmpty) {
        health['meals'] = meals;
        health['total_calories'] = kcal;
      }
      if (log.sleepLogs.isNotEmpty) {
        health['sleep'] = [
          for (final s in log.sleepLogs)
            {
              'from': DateFormat('MM-dd HH:mm').format(s.startTime),
              'to': DateFormat('MM-dd HH:mm').format(s.endTime),
              'hours': double.parse((s.durationMinutes / 60).toStringAsFixed(1)),
              'nap': s.isNap,
            }
        ];
      }
      if (log.activityLogs.isNotEmpty) {
        health['activity'] = {
          'walk_km': double.parse(log.activityLogs.fold<double>(0, (a, b) => a + b.walkDistanceKm).toStringAsFixed(2)),
          'workout_minutes': log.activityLogs.fold<int>(0, (a, b) => a + b.workoutMinutes),
        };
      }
      if (log.energyLogs.isNotEmpty) {
        health['energy_timeline'] = [
          for (final e in log.energyLogs)
            {
              'time': DateFormat('HH:mm').format(e.timestamp),
              'level': e.level,
              if (e.note != null && e.note!.isNotEmpty) 'note': e.note,
            }
        ];
      }
    }

    // ── Finance detail (top spends, by category) ──
    final catName = {for (final c in provider.categories) c.id: c.name};
    final spendByCategory = <String, double>{};
    final dayTx = <Map<String, dynamic>>[];
    for (final t in provider.transactions) {
      if (t.timestamp.isBefore(dayStart) || !t.timestamp.isBefore(dayEnd)) continue;
      final name = catName[t.categoryId] ?? 'Other';
      if (!t.isIncome) spendByCategory[name] = (spendByCategory[name] ?? 0) + t.amount;
      dayTx.add({
        'type': t.isIncome ? 'income' : 'expense',
        'amount': t.amount,
        'category': name,
        if (t.note.isNotEmpty) 'note': t.note,
      });
    }

    // ── Communications journal, grouped by app ──
    final notifs = provider.getNotificationsForDate(dateStr);
    final notifsByApp = <String, int>{};
    for (final n in notifs) {
      final app = (n['appName'] ?? n['packageName'] ?? 'Unknown').toString();
      notifsByApp[app] = (notifsByApp[app] ?? 0) + 1;
    }

    return {
      'date': dateStr,
      'work_sessions': sessions,
      'minutes_by_task': minutesByTask,
      'steps_completed': completedSteps,
      'checkpoints_completed': completedCheckpoints,
      'day_plan': plan,
      'health': health,
      'finance_detail': {
        'spend_by_category': spendByCategory,
        'transactions': dayTx,
      },
      'communications': {
        'total': notifs.length,
        'by_app': notifsByApp,
      },
    };
  }

  /// Compact plain-text form for the built-in briefing prompt. Empty string when there is
  /// nothing worth adding.
  static String buildDayContextText(AppProvider provider, DateTime date) {
    final m = buildDayContextMap(provider, date);
    final b = StringBuffer();

    final sessions = m['work_sessions'] as List;
    if (sessions.isNotEmpty) {
      final byTask = (m['minutes_by_task'] as Map).entries.map((e) => '${e.key}: ${e.value}m').join(', ');
      b.writeln('WORK TRACKED TODAY: $byTask');
      for (final s in sessions.take(20)) {
        b.writeln('  - ${s['start']}-${s['end']} ${s['task']} / ${s['step']} (${s['minutes']}m)');
      }
    }
    final steps = m['steps_completed'] as List;
    if (steps.isNotEmpty) b.writeln('STEPS COMPLETED TODAY: ${steps.take(25).join('; ')}');
    final cps = m['checkpoints_completed'] as List;
    if (cps.isNotEmpty) b.writeln('CHECKPOINTS COMPLETED TODAY (${cps.length}): ${cps.take(25).join('; ')}');
    final plan = m['day_plan'] as List;
    if (plan.isNotEmpty) b.writeln('DAY PLAN: ${plan.join('; ')}');

    final h = m['health'] as Map;
    if (h.isNotEmpty) {
      b.writeln('HEALTH TODAY:');
      if (h['sleep'] != null) {
        b.writeln('  - Sleep: ${(h['sleep'] as List).map((s) => '${s['hours']}h${s['nap'] == true ? ' (nap)' : ''}').join(', ')}');
      }
      if (h['water_glasses'] != null) b.writeln('  - Water: ${h['water_glasses']} glasses');
      if (h['meals'] != null) b.writeln('  - Meals (${h['total_calories']} kcal): ${(h['meals'] as List).join('; ')}');
      if (h['activity'] != null) {
        b.writeln('  - Activity: ${h['activity']['walk_km']} km walked, ${h['activity']['workout_minutes']} min workout');
      }
      if (h['energy_timeline'] != null) {
        b.writeln('  - Energy (1-10): ${(h['energy_timeline'] as List).map((e) => '${e['time']}=${e['level']}${e['note'] != null ? ' "${e['note']}"' : ''}').join(', ')}');
      }
    }

    final spend = (m['finance_detail']['spend_by_category'] as Map);
    if (spend.isNotEmpty) {
      b.writeln('SPENDING BY CATEGORY: ${spend.entries.map((e) => '${e.key} ₹${(e.value as double).toStringAsFixed(0)}').join(', ')}');
    }

    final comms = m['communications'] as Map;
    if ((comms['total'] as int) > 0) {
      b.writeln('COMMUNICATIONS VOLUME: ${comms['total']} notifications (${(comms['by_app'] as Map).entries.map((e) => '${e.key} ${e.value}').join(', ')})');
    }
    return b.toString().trim();
  }

  /// Notifications formatted for prompts: grouped by app, newest first, capped so one noisy app
  /// can't crowd the rest out.
  static String buildNotificationsText(AppProvider provider, String dateStr, {int perApp = 12, int total = 120}) {
    final notifs = provider.getNotificationsForDate(dateStr);
    if (notifs.isEmpty) return '';
    int tsOf(Map<String, dynamic> n) {
      final t = n['timestamp'] ?? n['postTime'] ?? 0;
      return t is num ? t.toInt() : (int.tryParse('$t') ?? 0);
    }

    final byApp = <String, List<Map<String, dynamic>>>{};
    for (final n in notifs) {
      final app = (n['appName'] ?? n['packageName'] ?? 'Unknown').toString();
      byApp.putIfAbsent(app, () => []).add(n);
    }
    final lines = <MapEntry<int, String>>[];
    byApp.forEach((app, list) {
      list.sort((a, b) => tsOf(b).compareTo(tsOf(a)));
      for (final n in list.take(perApp)) {
        final text = (n['text'] ?? '').toString();
        final clipped = text.length > 220 ? '${text.substring(0, 220)}…' : text;
        lines.add(MapEntry(tsOf(n), '[${n['timeStr'] ?? ''} $app] ${n['title'] ?? ''}: $clipped'));
      }
    });
    lines.sort((a, b) => a.key.compareTo(b.key));
    return lines.take(total).map((e) => e.value).join('\n');
  }
}
