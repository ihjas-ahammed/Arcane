import 'package:intl/intl.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/external_ai_briefing_helper.dart';

/// External AI variant of the People Intel scan.
/// Sends the same context as the in-app scan (reflection triggers, emotions and reasons, plus the
/// known people as name and relation), but over the whole reflection archive instead of a date range.
/// The reply uses the same {"people": [...]} shape, so it goes through the same resolve step.
class ExternalAiPeopleHelper {
  static Map<String, dynamic> buildExportData(AppProvider provider) {
    final logs = [...provider.reflectionLogs]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return {
      'meta': {
        'scan': 'people_intel',
        'generated_at': DateTime.now().toIso8601String(),
        'reflections_count': logs.length,
        if (logs.isNotEmpty)
          'reflections_range': {
            'start': DateFormat('yyyy-MM-dd').format(logs.first.timestamp),
            'end': DateFormat('yyyy-MM-dd').format(logs.last.timestamp),
          },
      },
      'known_people': [
        for (final p in provider.chatbotMemory.people) {'name': p.name, 'relation': p.relation},
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

  /// Prompt for the external AI. It asks for the same scan the in-app AI runs, over the attached dataset.
  static String buildPrompt() {
    return """
You are given a JSON dataset: "reflections" is the user's complete reflection archive (all time), and "known_people" lists people already identified in their database.

Scan the reflections the same way the app's people scan does:
- Extract every specific person the user mentions by name. Skip unnamed references such as "my boss" with no name.
- For each person, infer their relationship to the user (for example Friend, Boss, Partner, Colleague, Trainer).
- Add "context": the short snippet from the reflections where the person is mentioned.
- Match against "known_people". If it is the same person (a nickname or first name counts), set "matched_existing_name" to that exact known name. Otherwise set it to null.
- Do not invent people or details that the reflections do not support.

Output JSON ONLY, with no prose and no markdown:
{
  "people": [
    {
      "name": "string (extracted name)",
      "relation": "string (inferred relation)",
      "context": "string (snippet where they were mentioned)",
      "matched_existing_name": "string or null"
    }
  ]
}
""";
  }

  /// Parses the external AI reply into the list the people scan resolves.
  static List<Map<String, dynamic>> parseOutput(String rawText) {
    final decoded = ExternalAiBriefingHelper.parseAiOutput(rawText);
    final people = decoded['people'];
    if (people is! List) {
      throw const FormatException('Response has no "people" list.');
    }
    return people
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }
}
