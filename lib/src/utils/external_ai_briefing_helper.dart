import 'package:missions/src/utils/briefing_context_helper.dart';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/notification_journal_service.dart';
import 'package:flutter/foundation.dart';
import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';
import 'package:uuid/uuid.dart';

/// Helper utility for compiling external AI briefing datasets, prompt generation,
/// output parsing, and persistence.
class ExternalAiBriefingHelper {
  /// Writing style added to every briefing prompt. Based on ASD-STE100 Simplified Technical English.
  static const String steWritingStyle = """
WRITING STYLE (ASD-STE100 Simplified Technical English). Apply it to every text string in the JSON:
1. Write one idea in each sentence. Keep each sentence to 20 words or fewer.
2. Use active voice. Write "You finished the task." Do not write "The task was finished."
3. Use the simple tenses: present, past and future. Do not use the present perfect continuous.
4. Use one word for one meaning. Do not use synonyms. Write "start", not "begin" or "commence".
5. Do not use idioms, slang, humour or metaphors. Be literal and concrete.
6. Use a noun or a name instead of "it", "this" or "they" when the reference is not clear.
7. Do not use "and/or" or "etc.". Do not use "-ing" words as nouns.
8. Write numbers as digits. Write dates as YYYY-MM-DD.
9. Use "must" for a requirement, "should" for advice and "may" for an option.
10. Use only common words. Do not use abbreviations unless the data uses them.""";

  /// Builds the complete telemetry and historical context JSON dataset according to
  /// the operator's specification:
  /// - All weekly briefs of last 30 days
  /// - All monthly briefs of last year
  /// - All daily briefs of last 7 days (including today)
  /// - Raw activity telemetry for last 7 days (daily and weekly) or last 30 days (monthly)
  /// Notifications are kept in the native journal and only copied into the day record when the
  /// journal screen is opened. Export and prompts read the day record, so merge the journal in
  /// first (same merge rule as the journal screen: the journal wins for the same id).
  static Future<void> syncNotificationsFromJournal(AppProvider provider, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      final native = await NotificationJournalService.instance.getNotifications(dateStr);
      final unified = <String, NotificationJournalEntry>{};
      for (final raw in provider.getNotificationsForDate(dateStr)) {
        final e = NotificationJournalEntry.fromMap(raw);
        if (e.id.isNotEmpty) unified[e.id] = e;
      }
      for (final e in native) {
        if (e.id.isNotEmpty) unified[e.id] = e;
      }
      if (unified.isEmpty) return;
      final merged = unified.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      provider.saveNotificationsForDate(dateStr, merged.map((e) => e.toMap()).toList());
    } catch (e) {
      debugPrint('[ExternalAiBriefing] journal sync failed: $e');
    }
  }

  static Map<String, dynamic> buildExportData({
    required AppProvider provider,
    required DateTime targetDate,
    required BriefingType type,
  }) {
    final targetDateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    final targetDayEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999);

    // ── 1. HISTORICAL BRIEFS ──────────────────────────────────

    // Weekly briefs of last 30 days
    final weeklyCutoff = targetDate.subtract(const Duration(days: 30));
    final weeklyReports = <Map<String, dynamic>>[];
    final seenWeeklyDates = <String>{};

    for (final entry in provider.completedByDay.entries) {
      final d = DateTime.tryParse(entry.key);
      if (d != null && !d.isBefore(weeklyCutoff) && !d.isAfter(targetDate)) {
        final dayData = entry.value;
        if (dayData is Map && dayData['weeklyReport'] != null) {
          seenWeeklyDates.add(entry.key);
          weeklyReports.add({
            'date': entry.key,
            'report': dayData['weeklyReport'],
          });
        }
      }
    }
    for (final item in provider.cachedWeeklyReports) {
      final id = item['id'] as String?;
      final d = id != null ? DateTime.tryParse(id) : null;
      if (id != null && d != null && !d.isBefore(weeklyCutoff) && !d.isAfter(targetDate)) {
        if (!seenWeeklyDates.contains(id)) {
          seenWeeklyDates.add(id);
          weeklyReports.add({
            'date': id,
            'report': item['report'] ?? item,
          });
        }
      }
    }
    weeklyReports.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    // Monthly briefs of last year (365 days)
    final monthlyCutoff = targetDate.subtract(const Duration(days: 365));
    final monthlyReports = <Map<String, dynamic>>[];
    final seenMonthlyDates = <String>{};

    for (final entry in provider.completedByDay.entries) {
      final d = DateTime.tryParse(entry.key);
      if (d != null && !d.isBefore(monthlyCutoff) && !d.isAfter(targetDate)) {
        final dayData = entry.value;
        if (dayData is Map && dayData['monthlyReport'] != null) {
          seenMonthlyDates.add(entry.key);
          monthlyReports.add({
            'date': entry.key,
            'report': dayData['monthlyReport'],
          });
        }
      }
    }
    for (final item in provider.cachedMonthlyReports) {
      final id = item['id'] as String?;
      final d = id != null ? DateTime.tryParse(id) : null;
      if (id != null && d != null && !d.isBefore(monthlyCutoff) && !d.isAfter(targetDate)) {
        if (!seenMonthlyDates.contains(id)) {
          seenMonthlyDates.add(id);
          monthlyReports.add({
            'date': id,
            'report': item['report'] ?? item,
          });
        }
      }
    }
    monthlyReports.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    // Daily briefs of last 7 days (including today)
    final dailyBriefs = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final d = targetDate.subtract(Duration(days: i));
      final dStr = DateFormat('yyyy-MM-dd').format(d);
      final b = provider.getTacticalBriefing(dStr);
      if (b != null && b.isNotEmpty) {
        dailyBriefs.add({
          'date': dStr,
          'briefing': b,
        });
      }
    }

    // ── 2. ACTIVITY TELEMETRY ─────────────────────────────────
    final isMonthly = type == BriefingType.monthly;
    final telemetryDays = isMonthly ? 30 : 7;
    final telemetryStart = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    ).subtract(Duration(days: telemetryDays - 1));

    // Reflections within the telemetry window
    final reflections = provider.reflectionLogs.where((l) =>
      !l.timestamp.isBefore(telemetryStart) && !l.timestamp.isAfter(targetDayEnd)
    ).map((l) => {
      'timestamp': l.timestamp.toIso8601String(),
      'date': DateFormat('yyyy-MM-dd').format(l.timestamp),
      'trigger': l.trigger,
      'emotion': l.emotion,
      'reason': l.reason,
      'action': l.action,
      if (l.aiFeedback.isNotEmpty) 'aiFeedback': l.aiFeedback,
      if (l.needs.isNotEmpty) 'wellbeing_needs': l.needs,
    }).toList();

    // Goals active
    final goals = provider.goals.map((g) {
      final placeNames = g.placeIds
          .map((id) => provider.getGoalPlace(id)?.name)
          .whereType<String>()
          .toList();
      return {
        'id': g.id,
        'title': g.title,
        'scope': g.scope.name,
        'metricType': g.metricType.name,
        'isCompleted': g.getIsEffectiveCompleted(),
        'progressRatio': g.getProgressRatio(),
        'currentValue': g.currentValue,
        'targetValue': g.targetValue,
        if (placeNames.isNotEmpty) 'places': placeNames,
        if (g.reminderTimes.isNotEmpty)
          'reminderTimes': g.reminderTimes,
        if (g.subChecklist.isNotEmpty)
          'subChecklist': g.subChecklist
              .map((s) => {'title': s.title, 'isCompleted': s.isCompleted})
              .toList(),
      };
    }).toList();

    // Finance in window
    double totalIncome = 0;
    double totalExpense = 0;
    final transactionsList = <Map<String, dynamic>>[];
    for (final t in provider.transactions) {
      if (!t.timestamp.isBefore(telemetryStart) && !t.timestamp.isAfter(targetDayEnd)) {
        if (t.isIncome) {
          totalIncome += t.amount;
        } else {
          totalExpense += t.amount;
        }
        transactionsList.add({
          'date': DateFormat('yyyy-MM-dd').format(t.timestamp),
          'note': t.note,
          'amount': t.amount,
          'isIncome': t.isIncome,
          'categoryId': t.categoryId,
        });
      }
    }

    // Time sessions from mainTasks
    final timeByTask = <String, int>{};
    int totalTrackedMinutes = 0;
    for (final task in provider.mainTasks) {
      for (final sub in task.subTasks) {
        for (final session in sub.sessions) {
          if (!session.startTime.isBefore(telemetryStart) && !session.startTime.isAfter(targetDayEnd)) {
            final key = '${task.name} - ${sub.name}';
            final mins = session.durationMinutes.toInt();
            timeByTask[key] = (timeByTask[key] ?? 0) + mins;
            totalTrackedMinutes += mins;
          }
        }
      }
    }

    // Which well-being areas the reflections touched in this window (raw weights, for context)
    final wellbeingTotals = <String, int>{};
    for (final log in provider.reflectionLogs) {
      if (!log.timestamp.isBefore(telemetryStart) && !log.timestamp.isAfter(targetDayEnd)) {
        log.needs.forEach((k, v) {
          wellbeingTotals[k] = (wellbeingTotals[k] ?? 0) + v;
        });
      }
    }

    // Known people: the whole record for each person, including their intel, so the external AI
    // can propose increments to it.
    final people = provider.chatbotMemory.people.map(_personRecord).toList();

    // Notifications / Communications Journal for target date
    final dayNotifications = provider.getNotificationsForDate(targetDateStr);
    final notificationsList = dayNotifications.map((n) => {
      'time': n['timeStr'] ?? '',
      'app': n['appName'] ?? n['packageName'] ?? '',
      'title': n['title'] ?? '',
      'text': n['text'] ?? '',
      if (n['subText'] != null && (n['subText'] as String).isNotEmpty)
        'subText': n['subText'],
    }).toList();

    return {
      'meta': {
        'target_date': targetDateStr,
        'briefing_type': type.name,
        'generated_at': DateTime.now().toIso8601String(),
        'telemetry_window_days': telemetryDays,
        'telemetry_range': {
          'start': DateFormat('yyyy-MM-dd').format(telemetryStart),
          'end': targetDateStr,
        },
      },
      'previous_quotes': provider.getPreviouslyUsedQuotes(),
      'historical_briefs': {
        'weekly_briefs_last_30_days': weeklyReports,
        'monthly_briefs_last_year': monthlyReports,
        'daily_briefs_last_7_days': dailyBriefs,
      },
      'activity_telemetry': {
        'reflections_count': reflections.length,
        'reflections': reflections,
        'goals_count': goals.length,
        'goals': goals,
        'finance': {
          'total_income': totalIncome,
          'total_expense': totalExpense,
          'net': totalIncome - totalExpense,
          'current_balance': provider.financeActions.currentBalance,
          'transactions': transactionsList,
        },
        'time_tracking': {
          'total_minutes': totalTrackedMinutes,
          'by_task': timeByTask,
        },
        'wellbeing_needs': wellbeingTotals,
        'known_people': people,
        'notifications_journal_count': notificationsList.length,
        'notifications_journal': notificationsList,
      },
      'day_context': BriefingContextHelper.buildDayContextMap(provider, targetDate),
    };
  }

  /// Builds the optimized prompt instructing the external AI (ChatGPT, Claude, Gemini, etc.)
  /// to analyze the exported JSON and return valid JSON matching the exact schema.
  static String buildPrompt({
    required BriefingType type,
    required DateTime targetDate,
    required AppProvider provider,
  }) {
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    final monthLabel = DateFormat('MMMM yyyy').format(targetDate);

    switch (type) {
      case BriefingType.daily:
        final tomorrow = targetDate.add(const Duration(days: 1));
        final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);

        return """
You are an expert executive coach and tactical psychological analyst for Arcane.
You are provided with a complete JSON dataset containing the user's historical briefings and activity telemetry for today ($dateStr).
The dataset also includes "notifications_journal" containing communications, alerts, and messages logged throughout the day — use them to identify meaningful interactions, updates, and context for grateful_people, savor_moment, summary, small_win, and tomorrow's directives.
The dataset also includes "day_context" with the day's tracked work sessions, completed steps, health (sleep, water, activity, energy), spending by category and communication volume — ground the summary, small_win and directives in these facts.
The dataset also includes "previous_quotes" listing all quotes and authors previously used across daily briefings and morning reports.
The dataset also includes "known_people": every person in the user's database with their full record: relation, manualNotes, manualLastContactIntel (dated intel log), manualNextMeetPlan, biodata (occupation, location, birthday, contact) and "dossier" (psychological_profile, interaction_history, communication_tips). Treat this as the current intel on each person.

CRITICAL DEDUPLICATION RULE:
You MUST NOT duplicate or reuse any quote or author that appears in "previous_quotes".
Pick a fresh, unique, inspiring quote and author for "motivational_quote", and ensure "yesterday_quote" does not repeat previous quotes.

MISSION:
1. Analyze the attached JSON dataset.
2. Generate TODAY's official DAILY TACTICAL BRIEFING ($dateStr).
3. To save time tomorrow morning, ALSO synthesize TOMORROW's System Start-Up Sequence ($tomorrowStr) grounded in today's accomplishments, momentum, remaining tasks, and goals!
4. PEOPLE INTEL INCREMENTS: For each person in "known_people" that today's reflections, notifications_journal or telemetry mention, write ONLY what is NEW since their current record (the latest reflection, the new event, the new change). Never repeat intel already in their record. Use the exact name from known_people. Leave people with nothing new out of the list.

Tone: Uplifting, highly optimistic, empowering, and deeply appreciative. Celebrate all accomplishments, small wins, and positive turning points. NEVER give negative or critical advice.
Writing rules: Address the user directly as "you". Plain prose only — no markdown, no headers, no bullet/numbered lists inside any string. Be concrete and specific to the data.
$steWritingStyle

VALUE FIELDS RULE: Fields that show a value on a small card (finance income, expense and net, counts, amounts, scores) must hold ONLY the bare value. Do not add units, currency symbols, labels or descriptions inside those fields. Put any explanation in a separate description or note field.

CRITICAL OUTPUT FORMAT:
Return a single valid JSON object containing BOTH "daily_briefing" and "tomorrow_startup_report" adhering strictly to this schema:

{
  "daily_briefing": {
    "summary": "string (uplifting read of today celebrating wins and progress with 1-2 granular emotion words and an empowering positive reframe, max 80 words)",
    "quote_reflections": [
      {
        "user_quote": "string (the user's exact positive statement from reflections/logs)",
        "ai_comment": "string (warm, appreciative validation celebrating what the user wrote)"
      }
    ],
    "improvements": [
      {
        "ability": "string",
        "insight": "string"
      }
    ],
    "grateful_people": [
      {
        "name": "string",
        "relation": "string",
        "reason": "string",
        "express": "string"
      }
    ],
    "grateful_today": [
      {
        "text": "string (2-7 words)",
        "icon_type": "string (people/nature/health/learning/work/home/food/social/growth/mind/moment/general)"
      }
    ],
    "savor_moment": "string (single best moment of the day in 2-3 sensory sentences)",
    "small_win": "string (today's most meaningful concrete progress step)",
    "tomorrow_intention": "string (positive implementation intention: When [cue], I will [action])",
    "suggested_activities": [
      {
        "activity": "string",
        "reason": "string"
      }
    ],
    "finance_briefing": {
      "income": "string (bare number only, e.g. 1200: no currency symbol, no unit, no words)",
      "expense": "string (bare number only, e.g. 850: no currency symbol, no unit, no words)",
      "net": "string (bare number only, e.g. 350 or -120: no currency symbol, no unit, no words)",
      "finance_note": "string (one short sentence describing the day's money, with any units or sources here only; empty string if no activity)",
      "ai_feedback": "string (encouraging positive feedback, or empty string if no activity)"
    },
    "suggested_sops": [
      {
        "title": "string (e.g. Protocol: Evening Transition)",
        "description": "string (2-3 sentences specifying trigger condition and context)"
      },
      {
        "title": "string",
        "description": "string"
      },
      {
        "title": "string",
        "description": "string"
      }
    ],
    "contingency": {
      "risk": "string (one realistic obstacle or friction point likely to show up tomorrow)",
      "if_then": "string (concrete if-then plan to route around it)"
    }
  },
  "tomorrow_startup_report": {
    "forecast": "string (40-70 words: energizing morning forecast setting an inspiring tone for tomorrow)",
    "yesterday_quote": "string (a prominent positive or representative good quote from today's reflections)",
    "ai_today_advice": "string (warm, appreciative AI encouragement inspired by that quote)",
    "motivational_quote": {
      "quote": "string",
      "author": "string"
    },
    "suggested_contacts": [
      {
        "name": "string",
        "relation": "string",
        "type": "RECONNECT|FOLLOW UP|APPRECIATION|STAY IN TOUCH",
        "reason": "string"
      }
    ],
    "highlight": "string (single most leveraged task for tomorrow)",
    "obstacle_plan": {
      "obstacle": "string",
      "if_then": "string"
    },
    "anticipate": "string (one concrete thing tomorrow worth genuinely looking forward to)",
    "directives": [
      "string",
      "string",
      "string"
    ]
  },
  "people_intel_increments": [
    {
      "name": "string (exactly as written in known_people)",
      "new_intel": "string (one new dated fact or change from the latest reflections; empty string if nothing new)",
      "next_meet_plan": "string (concrete next interaction; empty string if none)",
      "interaction_history": [
        {"highlight": "string (short event label)", "text": "string (the new event or pattern)"}
      ]
    }
  ]
}

OUTPUT RULES:
1. Output JSON ONLY.
2. Ensure valid JSON without trailing commas.
3. No conversational preambles or explanations outside the JSON block.
""";

      case BriefingType.weekly:
        return """
You are an expert executive coach and tactical psychological analyst for Arcane.
You are provided with a complete JSON dataset containing the user's historical briefings and activity telemetry for the week ending $dateStr.

Generate a comprehensive 7-DAY REVIEW REPORT grounded in GTD, Atomic Habits, positive psychology, and optimistic encouragement.
Tone: Uplifting, highly optimistic, empowering, and deeply appreciative. Celebrate all accomplishments and positive turning points.

$steWritingStyle

Generate the official WEEKLY REPORT adhering strictly to this JSON schema:

{
  "summary": "string (comprehensive review of the week, max 150 words)",
  "wellbeing_analysis": "string",
  "health_analysis": "string",
  "health_intel": {
    "sleep_insight": "string",
    "activity_insight": "string",
    "recovery_score": "string",
    "vitality_quote": "string",
    "actionable_tip": "string"
  },
  "gtd_get_current": [
    {"task": "string", "next_action": "string"}
  ],
  "gtd_get_creative": [
    {"idea": "string", "reason": "string"}
  ],
  "atomic_friction": [
    {"struggle": "string", "adjustment": "string"}
  ],
  "identity_votes": [
    {"action": "string", "identity": "string"}
  ],
  "improved_abilities": [
    {"name": "string", "reason": "string", "score": 8}
  ],
  "grateful_people": [
    {"name": "string", "category": "Family & Partner | Friends | Professional & Mentors | Acquaintances & Others", "relation": "string", "reason": "string"}
  ],
  "gratitude_by_day": [
    {
      "date": "YYYY-MM-DD",
      "day_name": "string",
      "items": [{"text": "string", "icon_type": "string"}]
    }
  ],
  "gratitude_highlights": [
    {"text": "string", "icon_type": "string"}
  ],
  "after_action": {
    "intended": "string",
    "actual": "string",
    "lesson": "string"
  },
  "energy_map": {
    "energizers": ["string"],
    "drainers": ["string"]
  },
  "share_win": {
    "win": "string",
    "person": "string",
    "how": "string"
  },
  "creative_story": {
    "title": "string",
    "story": "string (100-180 words, real inspiring story from history/science)",
    "takeaway": "string"
  }
}

OUTPUT RULES:
1. Output JSON ONLY.
2. Ensure valid JSON without trailing commas.
3. No conversational preambles or explanations outside the JSON block.
""";

      case BriefingType.monthly:
        return """
You are an expert executive coach and tactical psychological analyst for Arcane.
You are provided with a complete JSON dataset containing the user's historical briefings and activity telemetry for $monthLabel (ending $dateStr).

Generate a MONTHLY BRIEFING grounded in positive psychology and optimistic encouragement.
Tone: Uplifting, highly optimistic, empowering, and deeply appreciative. Celebrate all accomplishments, growth, and positive turning points.

$steWritingStyle

Generate the official MONTHLY BRIEFING adhering strictly to this JSON schema:

{
  "narrative": "string (inspiring story of the month highlighting growth and milestones, 150-220 words)",
  "quote_reflections": [
    {"user_quote": "string", "ai_comment": "string"}
  ],
  "emotional_climate": {
    "dominant_emotions": ["string"],
    "trajectory": "string",
    "patterns": [{"pattern": "string", "evidence": "string"}]
  },
  "after_action_review": [
    {"intended": "string", "actual": "string", "gap_why": "string", "adjustment": "string"}
  ],
  "progress_review": [
    {"area": "string", "small_wins": "string", "compound_effect": "string"}
  ],
  "identity_trajectory": "string",
  "relationship_audit": [
    {"name": "string", "trend": "string", "action": "string"}
  ],
  "wellbeing_deltas": [
    {"area": "string", "direction": "string", "hypothesis": "string"}
  ],
  "life_domains": [
    {"domain": "string", "rating": 8, "evidence": "string"}
  ],
  "best_possible_self": "string",
  "next_month_woop": [
    {"wish": "string", "outcome": "string", "obstacle": "string", "plan": "string"}
  ],
  "gratitude_reminiscence": [
    {"text": "string", "icon_type": "string"}
  ],
  "letting_go": "string",
  "creative_story": {
    "title": "string",
    "story": "string (inspiring real story of a scientist, thinker, or artist mirroring user's journey)",
    "takeaway": "string"
  }
}

OUTPUT RULES:
1. Output JSON ONLY.
2. Ensure valid JSON without trailing commas.
3. No conversational preambles or explanations outside the JSON block.
""";

      case BriefingType.startup:
        return buildPrompt(type: BriefingType.daily, targetDate: targetDate, provider: provider);
    }
  }

  /// Parses raw AI output from external models (Claude, ChatGPT, etc.).
  /// Handles markdown code blocks, prefixes/suffixes, and validates that
  /// a valid JSON Map is returned.
  static Map<String, dynamic> parseAiOutput(String rawText) {
    var cleaned = rawText.trim();

    // 1. Remove markdown code fences if present
    if (cleaned.startsWith('```')) {
      final firstLineEnd = cleaned.indexOf('\n');
      if (firstLineEnd != -1) {
        cleaned = cleaned.substring(firstLineEnd + 1);
      } else {
        cleaned = cleaned.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '');
      }
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3).trim();
    }

    // 2. Extract JSON object substring between first '{' and last '}'
    final startIdx = cleaned.indexOf('{');
    final endIdx = cleaned.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      cleaned = cleaned.substring(startIdx, endIdx + 1);
    } else {
      throw const FormatException('No valid JSON object detected in input.');
    }

    final decoded = jsonDecode(cleaned);
    if (decoded is! Map) {
      throw const FormatException('Expected JSON object at root of response.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  /// Saves the parsed briefing directly to AppProvider and synchronizes any
  /// grateful items into chatbotMemory.
  static Future<void> saveBriefing({
    required AppProvider provider,
    required BriefingType type,
    required DateTime targetDate,
    required Map<String, dynamic> data,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

    switch (type) {
      case BriefingType.daily:
        Map<String, dynamic> dailyData;
        Map<String, dynamic>? startupData;

        if (data.containsKey('daily_briefing') && data['daily_briefing'] is Map) {
          dailyData = Map<String, dynamic>.from(data['daily_briefing'] as Map);
          if (data.containsKey('tomorrow_startup_report') && data['tomorrow_startup_report'] is Map) {
            startupData = Map<String, dynamic>.from(data['tomorrow_startup_report'] as Map);
          }
        } else {
          dailyData = Map<String, dynamic>.from(data);
          if (data.containsKey('tomorrow_startup_report') && data['tomorrow_startup_report'] is Map) {
            startupData = Map<String, dynamic>.from(data['tomorrow_startup_report'] as Map);
            dailyData.remove('tomorrow_startup_report');
          }
        }

        provider.saveTacticalBriefing(dateStr, dailyData);
        _syncGratitudeItems(provider, dailyData);
        _syncPeopleIntelIncrements(provider, data['people_intel_increments'], targetDate);

        // Also save tomorrow's startup sequence if generated
        if (startupData != null) {
          final tomorrow = targetDate.add(const Duration(days: 1));
          final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);
          startupData['snapshot_time'] = DateTime.now().toIso8601String();
          provider.saveStartDayReport(tomorrowStr, startupData);
          _syncSuggestedContacts(provider, startupData, tomorrow);
        }
        break;

      case BriefingType.startup:
        provider.saveStartDayReport(dateStr, data);
        _syncSuggestedContacts(provider, data, targetDate);
        break;

      case BriefingType.weekly:
        await provider.saveWeeklyReport(dateStr, data);
        break;

      case BriefingType.monthly:
        await provider.saveMonthlyReport(dateStr, data);
        break;
    }
  }

  /// The full record of one person for the external AI: every stored field, with the dossier
  /// (stored as a JSON string) decoded so it reads as an object.
  static Map<String, dynamic> _personRecord(PersonInfo p) {
    final json = p.toJson();
    final details = p.details;
    if (details != null && details.isNotEmpty) {
      try {
        json['dossier'] = jsonDecode(details);
        json.remove('details');
      } catch (_) {
        // Not JSON: keep it as plain text.
      }
    }
    return json;
  }

  /// Applies the external AI's intel increments to people already in the database. The entries
  /// go through the same logging path as the in-app updates, which skips anything already logged,
  /// so applying the same reply twice does not duplicate intel. Unknown names are ignored.
  static void _syncPeopleIntelIncrements(AppProvider provider, Object? raw, DateTime date) {
    if (raw is! List) return;
    for (final item in raw.whereType<Map>()) {
      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final person = provider.chatbotMemory.people
          .firstWhereOrNull((p) => p.name.toLowerCase() == name.toLowerCase());
      if (person == null) continue;

      final newIntel = (item['new_intel'] ?? '').toString().trim();
      final nextPlan = (item['next_meet_plan'] ?? '').toString().trim();
      if (newIntel.isNotEmpty || nextPlan.isNotEmpty) {
        provider.logInteractionForPerson(
          name: person.name,
          interactionSummary: newIntel.isEmpty ? null : newIntel,
          nextActionPlan: nextPlan.isEmpty ? null : nextPlan,
          date: date,
        );
      }

      final history = item['interaction_history'];
      if (history is List) {
        for (final h in history.whereType<Map>()) {
          final text = (h['text'] ?? '').toString().trim();
          if (text.isEmpty) continue;
          provider.logInteractionForPerson(name: person.name, interactionSummary: text, date: date);
        }
      }
    }
  }

  static void _syncGratitudeItems(AppProvider provider, Map<String, dynamic> data) {
    final rawAssets = data['grateful_today'] ?? data['grateful_assets'];
    if (rawAssets is List && rawAssets.isNotEmpty) {
      final currentAssets = List<GratitudeItem>.from(provider.chatbotMemory.gratitudeList);
      bool changed = false;
      for (final item in rawAssets) {
        String name = '';
        String type = 'resource';
        String why = '';
        String what = '';
        if (item is Map) {
          name = (item['text'] ?? item['name'])?.toString() ?? '';
          type = item['icon_type']?.toString() ?? item['type']?.toString() ?? 'resource';
          why = item['why']?.toString() ?? '';
          what = item['what']?.toString() ?? '';
        } else if (item is String) {
          name = item;
        }
        if (name.trim().isNotEmpty) {
          final existingIdx = currentAssets.indexWhere((a) => a.name.toLowerCase() == name.trim().toLowerCase());
          if (existingIdx != -1) {
            if (why.isNotEmpty && !currentAssets[existingIdx].why.contains(why)) {
              currentAssets[existingIdx].why += (currentAssets[existingIdx].why.isEmpty ? '' : ' ') + why;
              changed = true;
            }
          } else {
            currentAssets.insert(
              0,
              GratitudeItem(
                id: const Uuid().v4(),
                type: type,
                name: name.trim(),
                why: why,
                what: what,
              ),
            );
            changed = true;
          }
        }
      }
      if (changed) {
        provider.updateGratitudeList(currentAssets);
      }
    }
  }

  static void _syncSuggestedContacts(AppProvider provider, Map<String, dynamic> data, DateTime date) {
    if (data['suggested_contacts'] is List) {
      for (final c in data['suggested_contacts'] as List) {
        if (c is Map) {
          final name = c['name']?.toString() ?? '';
          final relation = c['relation']?.toString() ?? 'Acquaintance';
          final reason = c['reason']?.toString() ?? '';
          final type = c['type']?.toString() ?? 'CONTACT';
          if (name.isNotEmpty) {
            provider.logInteractionForPerson(
              name: name,
              relation: relation,
              interactionSummary: "Startup Recommendation [$type]: $reason",
              nextActionPlan: "[$type] $reason",
              date: date,
            );
          }
        }
      }
    }
  }
}
