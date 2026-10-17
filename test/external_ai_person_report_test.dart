import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/utils/external_ai_person_report_helper.dart';

void main() {
  group('ExternalAiPersonReportHelper.parseOutput', () {
    test('returns one report per requested person, without person_id', () {
      final reports = ExternalAiPersonReportHelper.parseOutput(
        '{"reports":[{"person_id":"a","title":"The Realist","level":3,"psychological_profile":"x","interaction_history":[],"communication_tips":[]},'
        '{"person_id":"b","title":"The Mentor","level":5,"psychological_profile":"y","interaction_history":[],"communication_tips":[]}]}',
        {'a', 'b'},
      );
      expect(reports.keys, unorderedEquals(['a', 'b']));
      expect(reports['a']!['title'], 'The Realist');
      expect(reports['a']!.containsKey('person_id'), isFalse);
    });

    test('drops reports for people outside the selection', () {
      final reports = ExternalAiPersonReportHelper.parseOutput(
        '{"reports":[{"person_id":"a","title":"A"},{"person_id":"z","title":"Not selected"}]}',
        {'a'},
      );
      expect(reports.keys, ['a']);
    });

    test('drops reports without a person_id', () {
      final reports = ExternalAiPersonReportHelper.parseOutput(
        '{"reports":[{"title":"No id"},{"person_id":"a","title":"A"}]}',
        {'a'},
      );
      expect(reports.keys, ['a']);
    });

    test('accepts a fenced reply', () {
      final reports = ExternalAiPersonReportHelper.parseOutput(
        '```json\n{"reports":[{"person_id":"a","title":"A"}]}\n```',
        {'a'},
      );
      expect(reports['a']!['title'], 'A');
    });

    test('rejects a reply with no reports list', () {
      expect(
        () => ExternalAiPersonReportHelper.parseOutput('{"people":[]}', {'a'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a reply where no report matches the selection', () {
      expect(
        () => ExternalAiPersonReportHelper.parseOutput('{"reports":[{"person_id":"z"}]}', {'a'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
