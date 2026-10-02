import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:collection/collection.dart';

/// Helper utility for compiling external AI schedule prediction datasets,
/// prompt generation, output parsing, and converting to non-editable overlay entries.
class ExternalAiScheduleHelper {
  /// Builds the complete telemetry and context JSON dataset for external AI:
  /// - Target date and plan start time
  /// - Today's remaining uncompleted plan items
  /// - Already recorded sessions on target date
  /// - Available active tasks and subtasks
  /// - Historical sessions over last 14 days
  /// - Reflection logs over last 30 days
  static Map<String, dynamic> buildExportData({
    required AppProvider provider,
    required DateTime targetDate,
    TimeOfDay? startTime,
  }) {
    final targetDateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    final now = DateTime.now();
    final isToday = targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;
    final effectiveStartTime = startTime ?? (isToday ? TimeOfDay.now() : const TimeOfDay(hour: 8, minute: 0));
    final startHourStr = effectiveStartTime.hour.toString().padLeft(2, '0');
    final startMinStr = effectiveStartTime.minute.toString().padLeft(2, '0');
    final planStartTimeStr = "$startHourStr:$startMinStr";
    final currentTimeStr = DateFormat('HH:mm').format(now);

    final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // 1. Target date's recorded sessions
    final recordedSessions = <Map<String, dynamic>>[];
    for (final task in provider.mainTasks) {
      for (final sub in task.subTasks) {
        for (final session in sub.sessions) {
          if (session.startTime.isBefore(dayEnd) && session.endTime.isAfter(dayStart)) {
            recordedSessions.add({
              'taskName': task.name,
              'subTaskName': sub.name,
              'startTime': DateFormat('HH:mm').format(session.startTime),
              'endTime': DateFormat('HH:mm').format(session.endTime),
              'durationMinutes': session.durationMinutes.toInt(),
            });
          }
        }
      }
    }
    recordedSessions.sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));

    // 2. Available active tasks and subtasks
    final availableTasks = provider.mainTasks
        .where((t) => !t.isDeleted && t.isActive)
        .map((t) => {
              'taskName': t.name,
              'theme': t.theme,
              'subtasks': t.subTasks
                  .where((s) => !s.isDeleted && s.isActive && !s.completed)
                  .map((s) => s.name)
                  .toList(),
            })
        .toList();

    // 3. Historical sessions over last 14 days
    final cutoff14Days = targetDate.subtract(const Duration(days: 14));
    final historySummary = <Map<String, dynamic>>[];
    for (final task in provider.mainTasks) {
      for (final sub in task.subTasks) {
        for (final session in sub.sessions) {
          if (!session.startTime.isBefore(cutoff14Days) && session.startTime.isBefore(dayStart)) {
            historySummary.add({
              'date': DateFormat('yyyy-MM-dd').format(session.startTime),
              'taskName': task.name,
              'subTaskName': sub.name,
              'durationMinutes': session.durationMinutes.toInt(),
              'hourOfDay': session.startTime.hour,
            });
          }
        }
      }
    }

    // 4. Uncompleted plan for target date
    final uncompletedPlanStr = provider.getTodayUncompletedPlanContext();
    final dayPlanRaw = provider.taskActions.getDayPlan(targetDateStr);

    // 5. Recent reflections
    final reflectionLogsStr = provider.getLast30DaysReflectionLogsContext();

    // 6. Goals for target date
    final targetGoals = provider.goals
        .where((g) => g.dateKey == targetDateStr || g.scope == GoalScope.daily)
        .map((g) => {
              'title': g.title,
              'scope': g.scope.name,
              'completed': g.isCompleted,
              'targetValue': g.targetValue,
              'currentValue': g.currentValue,
            })
        .toList();

    return {
      'meta': {
        'target_date': targetDateStr,
        'plan_start_time': planStartTimeStr,
        'is_future_date': !isToday,
        'current_time': currentTimeStr,
        'generated_at': now.toIso8601String(),
        'instructions': 'Generate predicted schedule overlay blocks for $targetDateStr starting from $planStartTimeStr onward.',
      },
      'plan_context': {
        'uncompleted_plan_context': uncompletedPlanStr,
        'plan_items': dayPlanRaw,
        'goals': targetGoals,
      },
      'already_recorded_sessions_on_date': recordedSessions,
      'available_active_tasks': availableTasks,
      'historical_sessions_last_14_days_sample': historySummary.take(100).toList(),
      'reflection_logs_last_30_days': reflectionLogsStr,
    };
  }

  /// Builds the compact prompt formatted for external frontier AI models (ChatGPT, Claude, Gemini, etc.)
  /// NOTE: Bulky reflection logs, active tasks, and history are kept entirely inside the exported JSON
  /// to keep the clipboard content small and lightweight.
  static String buildPrompt({
    required AppProvider provider,
    required DateTime targetDate,
    TimeOfDay? startTime,
  }) {
    final targetDateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    final now = DateTime.now();
    final isToday = targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;
    final effectiveStartTime = startTime ?? (isToday ? TimeOfDay.now() : const TimeOfDay(hour: 8, minute: 0));
    final startHourStr = effectiveStartTime.hour.toString().padLeft(2, '0');
    final startMinStr = effectiveStartTime.minute.toString().padLeft(2, '0');
    final planStartTimeStr = "$startHourStr:$startMinStr";

    return """
You are Arcane's Tactical Schedule Predictor & Daily Planner AI.
Your mission is to predict and generate a realistic, high-leverage schedule plan for $targetDateStr, starting from reference time $planStartTimeStr onward.

CONTEXT:
All activity telemetry, uncompleted plan items, active tasks, historical sessions, and reflection logs are provided in the attached JSON dataset.

INSTRUCTIONS:
1. Analyze user habits, reflection patterns, and remaining plan in the attached JSON dataset.
2. PRIORITIZE scheduling uncompleted plan items and active protocols from the JSON dataset into realistic time slots on $targetDateStr.
3. Schedule sessions starting from $planStartTimeStr onward for $targetDateStr.
4. Each session MUST specify explicit "startTime": "HH:mm" and "endTime": "HH:mm" in 24-hour format on $targetDateStr.
5. Provide appropriate breaks (10-15m) between intensive focus sessions.
6. Do NOT schedule past 23:59. Respect regular sleep and evening wind-down time.
7. Match "taskName" to the EXACT Available Task Names provided in the JSON dataset whenever possible.
8. Return between 2 to 8 focused session blocks.

CRITICAL OUTPUT FORMATTING:
- Return ONLY a valid JSON array.
- Do NOT wrap in markdown code blocks (e.g. no ```json ... ```).
- Do NOT include comments, explanations, or trailing commas.

OUTPUT JSON SCHEMA:
[
  {
    "taskName": "Exact Main Task Name from active tasks in JSON",
    "subTaskName": "Specific subtask or activity description",
    "startTime": "HH:mm",
    "endTime": "HH:mm",
    "durationMinutes": 45
  }
]
""";
  }

  /// Parses external AI output defensively into a list of [TimelineEntry] objects.
  /// All parsed entries are strictly configured as:
  /// - `isPredicted = true`
  /// - `isEditable = false`
  /// - Anchored directly to `targetDate`
  /// - Non-editable background overlay blueprint
  static List<TimelineEntry> parsePredictions(
    String rawText, {
    required DateTime targetDate,
    required AppProvider provider,
    TimeOfDay? startTime,
  }) {
    if (rawText.trim().isEmpty) return [];

    // Strip markdown code fences if present
    String cleaned = rawText.trim();
    if (cleaned.startsWith('```')) {
      final firstNewline = cleaned.indexOf('\n');
      if (firstNewline != -1) {
        cleaned = cleaned.substring(firstNewline + 1);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();
    }

    // Extract JSON array between '[' and ']'
    final startIndex = cleaned.indexOf('[');
    final endIndex = cleaned.lastIndexOf(']');
    if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
      throw const FormatException("No valid JSON array found in output. Ensure the response starts with '[' and ends with ']'.");
    }

    final jsonStr = cleaned.substring(startIndex, endIndex + 1);
    final dynamic decoded = jsonDecode(jsonStr);

    if (decoded is! List) {
      throw const FormatException("Decoded JSON is not an array of schedule sessions.");
    }

    final now = DateTime.now();
    final isToday = targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;
    final effectiveStartTime = startTime ?? (isToday ? TimeOfDay.now() : const TimeOfDay(hour: 8, minute: 0));
    final baseAnchor = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      effectiveStartTime.hour,
      effectiveStartTime.minute,
    );

    final entries = <TimelineEntry>[];

    for (int i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map) continue;

      final taskName = (item['taskName'] ?? item['task'] ?? 'Predicted').toString();
      final subTaskName = (item['subTaskName'] ?? item['subtask'] ?? item['title'] ?? 'Predicted Session').toString();

      DateTime? start;
      DateTime? end;

      // Format 1: startTime & endTime ("HH:mm")
      final startStr = item['startTime']?.toString();
      final endStr = item['endTime']?.toString();

      if (startStr != null && startStr.contains(':')) {
        final parts = startStr.split(':');
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          start = DateTime(targetDate.year, targetDate.month, targetDate.day, h, m);
        }
      }

      if (endStr != null && endStr.contains(':')) {
        final parts = endStr.split(':');
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          end = DateTime(targetDate.year, targetDate.month, targetDate.day, h, m);
        }
      }

      // Format 2: startOffsetMinutes & durationMinutes
      final offsetMins = item['startOffsetMinutes'] is num ? (item['startOffsetMinutes'] as num).toInt() : null;
      final durationMins = item['durationMinutes'] is num
          ? (item['durationMinutes'] as num).toInt()
          : (item['duration'] is num ? (item['duration'] as num).toInt() : 30);

      if (start == null && offsetMins != null) {
        start = baseAnchor.add(Duration(minutes: offsetMins));
      }

      start ??= baseAnchor.add(Duration(minutes: i * 45));

      end ??= start.add(Duration(minutes: durationMins.clamp(5, 240)));

      // Ensure end is strictly after start
      if (!end.isAfter(start)) {
        end = start.add(const Duration(minutes: 30));
      }

      // Match task color from provider
      Color taskColor = AppTheme.fhTextDisabled;
      final matchedTask = provider.mainTasks.firstWhereOrNull(
        (t) => t.name.toLowerCase().trim() == taskName.toLowerCase().trim() ||
            t.name.toLowerCase().contains(taskName.toLowerCase()),
      );
      if (matchedTask != null) {
        taskColor = matchedTask.taskColor;
      } else {
        // Alternate cyan / amber / teal accents if unmatched
        taskColor = (i % 2 == 0) ? JweTheme.accentCyan : JweTheme.accentAmber;
      }

      entries.add(TimelineEntry(
        id: "pred_${targetDate.millisecondsSinceEpoch}_${i}_${DateTime.now().microsecondsSinceEpoch}",
        startTime: start,
        endTime: end,
        title: subTaskName,
        subtitle: taskName,
        color: taskColor,
        isPredicted: true,
        isEditable: false,
      ));
    }

    return entries;
  }
}
