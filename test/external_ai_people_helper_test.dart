import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/utils/external_ai_people_helper.dart';

void main() {
  group('ExternalAiPeopleHelper.parseOutput', () {
    test('reads the people list from a plain reply', () {
      final people = ExternalAiPeopleHelper.parseOutput(
        '{"people":[{"name":"Ravi","relation":"Friend","context":"Coffee with Ravi","matched_existing_name":null}]}',
      );
      expect(people, hasLength(1));
      expect(people.first['name'], 'Ravi');
      expect(people.first['matched_existing_name'], isNull);
    });

    test('accepts a reply wrapped in a markdown code fence', () {
      final people = ExternalAiPeopleHelper.parseOutput(
        '```json\n{"people":[{"name":"Priya","relation":"Sister","context":"x","matched_existing_name":"Priya"}]}\n```',
      );
      expect(people.single['matched_existing_name'], 'Priya');
    });

    test('returns an empty list when the AI found nobody', () {
      expect(ExternalAiPeopleHelper.parseOutput('{"people":[]}'), isEmpty);
    });

    test('rejects a reply without a people list', () {
      expect(
        () => ExternalAiPeopleHelper.parseOutput('{"daily_briefing":{}}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects text that is not JSON', () {
      expect(
        () => ExternalAiPeopleHelper.parseOutput('Sorry, I cannot help.'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
