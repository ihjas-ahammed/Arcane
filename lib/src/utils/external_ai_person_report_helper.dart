import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/external_ai_briefing_helper.dart';

/// External AI intelligence reports for one or more people.
/// The context is the same as the in-app dossier (the full reflection log, as lines of
/// trigger, emotion and reason), plus each selected person's id, name, relation and any
/// notes or profile already on file. The reply is one report per person, in the same schema
/// the in-app dossier stores, so the dossier tab reads it without changes.
class ExternalAiPersonReportHelper {
  static Map<String, dynamic> buildExportData(AppProvider provider, List<String> personIds) {
    final logs = [...provider.reflectionLogs]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final people = provider.chatbotMemory.people.where((p) => personIds.contains(p.id));

    return {
      'meta': {
        'scan': 'person_reports',
        'generated_at': DateTime.now().toIso8601String(),
        'people_count': personIds.length,
        'reflections_count': logs.length,
        if (logs.isNotEmpty)
          'reflections_range': {
            'start': DateFormat('yyyy-MM-dd').format(logs.first.timestamp),
            'end': DateFormat('yyyy-MM-dd').format(logs.last.timestamp),
          },
      },
      'people': [
        for (final p in people) _personContext(p),
      ],
      'reflections': [
        for (final l in logs)
          {
            'timestamp': l.timestamp.toIso8601String(),
            'trigger': l.trigger,
            'emotion': l.emotion,
            'reason': l.reason,
          },
      ],
    };
  }

  static Map<String, dynamic> _personContext(PersonInfo p) {
    Object? currentProfile;
    if (p.details != null && p.details!.isNotEmpty) {
      try {
        currentProfile = jsonDecode(p.details!);
      } catch (_) {
        currentProfile = p.details;
      }
    }
    return {
      'person_id': p.id,
      'name': p.name,
      'relation': p.relation,
      if (p.manualNotes != null && p.manualNotes!.isNotEmpty) 'manual_notes': p.manualNotes,
      if (currentProfile != null) 'current_profile': currentProfile,
    };
  }

  /// Prompt for the external AI. It asks for the same dossier the in-app AI writes, once per person.
  static String buildPrompt() {
    return """
You are given a JSON dataset. "people" lists the people to report on, each with a "person_id". "reflections" is the user's complete reflection archive (all time), as trigger, emotion and reason.

For EACH person in "people", analyze the reflections focusing on interactions or feelings involving that person. Write an intelligence dossier for the user, who is dealing with this person.

Rules:
- Use only what the reflections, manual_notes or current_profile support. Do not invent events.
- If a person has little or no mention in the reflections, say so in psychological_profile and keep the lists short.
- Copy each person_id exactly from "people".

Output JSON ONLY, with no prose and no markdown:
{
  "reports": [
    {
      "person_id": "string (copied from people)",
      "title": "A short alias for them (e.g. The Realist, The Mentor)",
      "level": 1,
      "role": "Their inferred role (e.g. Student, Colleague)",
      "status": "Current relationship status (e.g. Active, Calibration Phase)",
      "psychological_profile": "A solid paragraph on their traits and dynamics with the user",
      "interaction_history": [
        {"highlight": "Event or theme:", "text": "Description of the event or pattern."}
      ],
      "communication_tips": [
        {"highlight": "Tip name:", "text": "Description of the tip."}
      ]
    }
  ]
}
""";
  }

  /// Parses the reply into one report per person id. Reports for ids that were not requested
  /// are dropped, so a reply cannot overwrite someone outside the selection.
  static Map<String, Map<String, dynamic>> parseOutput(String rawText, Set<String> requestedIds) {
    final decoded = ExternalAiBriefingHelper.parseAiOutput(rawText);
    final reports = decoded['reports'];
    if (reports is! List) {
      throw const FormatException('Response has no "reports" list.');
    }

    final byId = <String, Map<String, dynamic>>{};
    for (final item in reports.whereType<Map>()) {
      final report = Map<String, dynamic>.from(item);
      final id = report.remove('person_id') as String?;
      if (id == null || !requestedIds.contains(id)) continue;
      byId[id] = report;
    }
    if (byId.isEmpty) {
      throw const FormatException('None of the reports match the selected people.');
    }
    return byId;
  }
}
