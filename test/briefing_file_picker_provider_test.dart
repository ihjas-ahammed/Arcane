import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/providers/briefing_file_picker_provider.dart';
import 'package:missions/src/utils/external_ai_briefing_helper.dart';
import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';

String _export({
  String type = 'daily',
  String targetDate = '2026-10-31',
  String generatedAt = '2026-10-31T09:30:00.000',
}) {
  return jsonEncode({
    'meta': {
      'target_date': targetDate,
      'briefing_type': type,
      'generated_at': generatedAt,
    },
  });
}

void main() {
  final now = DateTime(2026, 10, 31, 18, 0);

  group('BriefingFilePickerProvider.checkFile', () {
    test('accepts today export of the matching type', () {
      final check = BriefingFilePickerProvider.checkFile(_export(), BriefingType.daily, now);
      expect(check.isValid, isTrue);
      expect(check.generatedAt, DateTime(2026, 10, 31, 9, 30));
    });

    test('rejects a file of another type', () {
      final check = BriefingFilePickerProvider.checkFile(_export(type: 'weekly'), BriefingType.daily, now);
      expect(check.isValid, isFalse);
      expect(check.message, contains('Wrong file'));
    });

    test('rejects a target date that is not today', () {
      final check = BriefingFilePickerProvider.checkFile(
        _export(targetDate: '2026-10-30'),
        BriefingType.daily,
        now,
      );
      expect(check.isValid, isFalse);
      expect(check.message, contains('Not current'));
    });

    test('rejects stale data generated on an earlier day', () {
      final check = BriefingFilePickerProvider.checkFile(
        _export(generatedAt: '2026-10-29T23:10:00.000'),
        BriefingType.daily,
        now,
      );
      expect(check.isValid, isFalse);
      expect(check.message, contains('Stale'));
    });

    test('rejects text that is not JSON', () {
      final check = BriefingFilePickerProvider.checkFile('not json', BriefingType.daily, now);
      expect(check.isValid, isFalse);
    });

    test('rejects JSON without a meta block', () {
      final check = BriefingFilePickerProvider.checkFile('{"daily_briefing": {}}', BriefingType.daily, now);
      expect(check.isValid, isFalse);
      expect(check.message, contains('Missing meta'));
    });
  });

  group('ExternalAiBriefingHelper.steWritingStyle', () {
    test('names the ASD-STE100 style and its sentence limit', () {
      expect(ExternalAiBriefingHelper.steWritingStyle, contains('ASD-STE100'));
    });
  });
}
