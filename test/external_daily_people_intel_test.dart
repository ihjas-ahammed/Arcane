import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/external_ai_briefing_helper.dart';
import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';
import './mock.dart';

/// Example reply from the external AI. The first person is in the database, so the increments apply.
/// "Nobody" is not in the database, so it is ignored.
const exampleReply = '''
{
  "daily_briefing": {"summary": "A steady day with one good conversation."},
  "tomorrow_startup_report": {"forecast": "A calm morning."},
  "people_intel_increments": [
    {
      "name": "Sam",
      "new_intel": "Sam moved the Saturday run to Sunday after your reflection about the trip.",
      "next_meet_plan": "Sunday run at 7 am",
      "interaction_history": [
        {"highlight": "Oct 21", "text": "Rescheduled the Saturday run to Sunday."}
      ]
    },
    {
      "name": "Nobody",
      "new_intel": "Not in the database, so this is ignored.",
      "next_meet_plan": "",
      "interaction_history": []
    }
  ]
}
''';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  AppProvider seededProvider() {
    final provider = AppProvider.forTest();
    provider.updatePeopleList([
      PersonInfo(
        id: 'p_sam',
        name: 'Sam',
        relation: 'Friend',
        manualNotes: 'Runs on weekends',
        manualLastContactIntel: ['[2026-10-10] Called about the trip'],
        details: jsonEncode({
          'psychological_profile': 'Steady and practical.',
          'interaction_history': [
            {'highlight': 'Jan', 'text': 'Coffee catch-up.'},
          ],
        }),
      ),
    ]);
    return provider;
  }

  test('the daily export carries each person\'s full record, including the dossier', () {
    final provider = seededProvider();

    final data = ExternalAiBriefingHelper.buildExportData(
      provider: provider,
      targetDate: DateTime(2026, 10, 21),
      type: BriefingType.daily,
    );

    final people = (data['activity_telemetry'] as Map)['known_people'] as List;
    expect(people, hasLength(1));
    final sam = people.first as Map;
    expect(sam['name'], 'Sam');
    expect(sam['manualNotes'], 'Runs on weekends');
    expect(sam['manualLastContactIntel'], ['[2026-10-10] Called about the trip']);
    expect((sam['dossier'] as Map)['psychological_profile'], 'Steady and practical.');
    expect(sam.containsKey('details'), isFalse, reason: 'The dossier is decoded, not sent as a string');
  });

  test('the daily prompt asks for people intel increments', () {
    final provider = seededProvider();

    final prompt = ExternalAiBriefingHelper.buildPrompt(
      type: BriefingType.daily,
      targetDate: DateTime(2026, 10, 21),
      provider: provider,
    );

    expect(prompt, contains('"people_intel_increments"'));
    expect(prompt, contains('"known_people"'));
    expect(prompt, contains('PEOPLE INTEL INCREMENTS'));
  });

  test('the example reply applies its increments, ignores unknown names, and does not duplicate on a second apply', () async {
    final provider = seededProvider();
    final target = DateTime(2026, 10, 21);

    Future<void> applyExample() async {
      final parsed = ExternalAiBriefingHelper.parseAiOutput(exampleReply);
      await ExternalAiBriefingHelper.saveBriefing(
        provider: provider,
        type: BriefingType.daily,
        targetDate: target,
        data: parsed,
      );
    }

    await applyExample();

    final sam = provider.chatbotMemory.people.firstWhere((p) => p.name == 'Sam');
    expect(sam.manualLastContactIntel,
        contains('[2026-10-21] Sam moved the Saturday run to Sunday after your reflection about the trip.'));
    expect(sam.manualLastContactIntel, contains('[2026-10-10] Called about the trip'),
        reason: 'Existing intel is kept');
    expect(sam.manualNextMeetPlan, contains('Sunday run at 7 am'));
    final dossier = jsonDecode(sam.details!) as Map<String, dynamic>;
    final history = dossier['interaction_history'] as List;
    expect((history.first as Map)['text'], 'Rescheduled the Saturday run to Sunday.');
    expect(provider.chatbotMemory.people.map((p) => p.name), ['Sam'],
        reason: 'The unknown name must not create a person');

    final intelCount = sam.manualLastContactIntel!.length;
    final historyCount = history.length;

    await applyExample();

    final samAgain = provider.chatbotMemory.people.firstWhere((p) => p.name == 'Sam');
    expect(samAgain.manualLastContactIntel!.length, intelCount, reason: 'Second apply must not duplicate intel');
    final historyAgain = (jsonDecode(samAgain.details!) as Map)['interaction_history'] as List;
    expect(historyAgain.length, historyCount, reason: 'Second apply must not duplicate dossier history');
  });
}
