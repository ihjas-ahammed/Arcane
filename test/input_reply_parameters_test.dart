import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/services/input_reply_service.dart';

void main() {
  group('InputReply Macro Parameters', () {
    test('parameterize splits typed text and assigns parameter correctly', () {
      const macro = InputReplyMacro(
        name: 'Greeting Macro',
        createdAt: '2026-10-01T10:00:00Z',
        steps: [
          InputReplyStep(type: 'click', x: 200, y: 400),
          InputReplyStep(type: 'type', text: 'Hello Farsan, welcome!'),
          InputReplyStep(type: 'key', key: 'ENTER'),
        ],
      );

      final parameterized = macro.parameterize(
        name: 'friend',
        value: 'Farsan',
        description: 'Name of the friend',
      );

      expect(parameterized.parameters.length, 1);
      expect(parameterized.parameters.first.name, 'friend');
      expect(parameterized.parameters.first.defaultValue, 'Farsan');
      expect(parameterized.parameters.first.description, 'Name of the friend');

      // The 'type' step should have been split into 3 steps: 'Hello ', 'Farsan' (with param), ', welcome!'
      expect(parameterized.steps.length, 5);
      expect(parameterized.steps[0].type, 'click');
      expect(parameterized.steps[1].type, 'type');
      expect(parameterized.steps[1].text, 'Hello ');
      expect(parameterized.steps[1].param, isNull);

      expect(parameterized.steps[2].type, 'type');
      expect(parameterized.steps[2].text, 'Farsan');
      expect(parameterized.steps[2].param, 'friend');

      expect(parameterized.steps[3].type, 'type');
      expect(parameterized.steps[3].text, ', welcome!');
      expect(parameterized.steps[3].param, isNull);

      expect(parameterized.steps[4].type, 'key');
    });

    test('parameterize handles exact full match without extra split steps', () {
      const macro = InputReplyMacro(
        name: 'Search Macro',
        createdAt: '2026-10-01T10:00:00Z',
        steps: [
          InputReplyStep(type: 'type', text: 'flutter best practices'),
        ],
      );

      final parameterized = macro.parameterize(
        name: 'query',
        value: 'flutter best practices',
      );

      expect(parameterized.steps.length, 1);
      expect(parameterized.steps.first.text, 'flutter best practices');
      expect(parameterized.steps.first.param, 'query');
      expect(parameterized.parameters.first.name, 'query');
    });

    test('parameterize rejects text that was never typed in macro', () {
      const macro = InputReplyMacro(
        name: 'Test',
        createdAt: '2026-10-01T10:00:00Z',
        steps: [
          InputReplyStep(type: 'type', text: 'quick brown fox'),
        ],
      );

      expect(
        () => macro.parameterize(name: 'target', value: 'lazy dog'),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('was never typed in this macro'),
        )),
      );
    });

    test('parameterize validates parameter name and rejects duplicates', () {
      const macro = InputReplyMacro(
        name: 'Test',
        createdAt: '2026-10-01T10:00:00Z',
        steps: [
          InputReplyStep(type: 'type', text: 'example text'),
        ],
      );

      // Invalid names
      expect(() => macro.parameterize(name: '123invalid', value: 'example'), throwsA(isA<ArgumentError>()));
      expect(() => macro.parameterize(name: 'bad name with spaces', value: 'example'), throwsA(isA<ArgumentError>()));
      expect(() => macro.parameterize(name: 'bad-dash', value: 'example'), throwsA(isA<ArgumentError>()));

      // Valid name
      final p1 = macro.parameterize(name: 'valid_name_1', value: 'example');
      expect(p1.parameters.first.name, 'valid_name_1');

      // Duplicate name
      expect(
        () => p1.parameterize(name: 'valid_name_1', value: 'text'),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('already exists'),
        )),
      );
    });

    test('removeParameter clears param and re-merges adjacent type steps', () {
      const macro = InputReplyMacro(
        name: 'Test',
        createdAt: '2026-10-01T10:00:00Z',
        steps: [
          InputReplyStep(type: 'type', text: 'Hello '),
          InputReplyStep(type: 'type', text: 'Farsan', param: 'friend'),
          InputReplyStep(type: 'type', text: '!'),
        ],
        parameters: [
          InputReplyParam(name: 'friend', defaultValue: 'Farsan'),
        ],
      );

      final removed = macro.removeParameter('friend');
      expect(removed.parameters.isEmpty, isTrue);
      // Adjacent unparameterized type steps should merge back into 'Hello Farsan!'
      expect(removed.steps.length, 1);
      expect(removed.steps.first.text, 'Hello Farsan!');
      expect(removed.steps.first.param, isNull);
    });

    test('resolve substitutes runtime parameters and keeps omitted parameters as default', () {
      const macro = InputReplyMacro(
        name: 'Test',
        createdAt: '2026-10-01T10:00:00Z',
        steps: [
          InputReplyStep(type: 'type', text: 'Search for: '),
          InputReplyStep(type: 'type', text: 'flutter', param: 'topic'),
          InputReplyStep(type: 'type', text: ' in '),
          InputReplyStep(type: 'type', text: 'Google', param: 'engine'),
        ],
        parameters: [
          InputReplyParam(name: 'topic', defaultValue: 'flutter'),
          InputReplyParam(name: 'engine', defaultValue: 'Google'),
        ],
      );

      // 1. Substitute both parameters
      final resolvedBoth = macro.resolve({
        'topic': 'dart',
        'engine': 'Bing',
      });
      // Consecutive steps merge into single complete text for atomic typing
      expect(resolvedBoth.length, 1);
      expect(resolvedBoth.first.text, 'Search for: dart in Bing');

      // 2. Omitted 'engine' parameter keeps default 'Google'
      final resolvedPartial = macro.resolve({
        'topic': 'rust',
      });
      expect(resolvedPartial.length, 1);
      expect(resolvedPartial.first.text, 'Search for: rust in Google');

      // 3. Resolve without merging if requested
      final resolvedUnmerged = macro.resolve({
        'topic': 'python',
        'engine': 'DuckDuckGo',
      }, mergeAdjacentTypeSteps: false);
      expect(resolvedUnmerged.length, 4);
      expect(resolvedUnmerged[1].text, 'python');
      expect(resolvedUnmerged[3].text, 'DuckDuckGo');
    });

    test(r'resolve handles inline template placeholders ($param and ${param})', () {
      const macro = InputReplyMacro(
        name: 'Template Test',
        createdAt: '2026-10-01T10:00:00Z',
        steps: [
          InputReplyStep(type: 'type', text: r'https://example.com?query=$query&user=${user_id}'),
        ],
        parameters: [
          InputReplyParam(name: 'query', defaultValue: 'shoes'),
          InputReplyParam(name: 'user_id', defaultValue: '1001'),
        ],
      );

      final resolved = macro.resolve({
        'query': 'boots',
        'user_id': '9999',
      });
      expect(resolved.first.text, 'https://example.com?query=boots&user=9999');
    });

    test('InputReplyMacro json serialization round-trip preserves parameters', () {
      const macro = InputReplyMacro(
        name: 'Serialized Macro',
        createdAt: '2026-10-01T10:00:00Z',
        targetPackage: 'com.android.chrome',
        parameters: [
          InputReplyParam(name: 'q', description: 'Search query', defaultValue: 'arcane launcher'),
        ],
        steps: [
          InputReplyStep(type: 'launch', app: 'com.android.chrome'),
          InputReplyStep(type: 'type', text: 'arcane launcher', param: 'q'),
          InputReplyStep(type: 'key', key: 'ENTER'),
        ],
      );

      final jsonMap = macro.toJson();
      final roundTrip = InputReplyMacro.fromJson(jsonMap);

      expect(roundTrip.name, macro.name);
      expect(roundTrip.targetPackage, 'com.android.chrome');
      expect(roundTrip.parameters.length, 1);
      expect(roundTrip.parameters.first.name, 'q');
      expect(roundTrip.parameters.first.description, 'Search query');
      expect(roundTrip.parameters.first.defaultValue, 'arcane launcher');
      expect(roundTrip.steps.length, 3);
      expect(roundTrip.steps[1].param, 'q');
    });
  });
}
