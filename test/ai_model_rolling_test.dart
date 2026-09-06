import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/models/app_state_models.dart';

void main() {
  group('AI Model Rolling & Fallback Configuration Tests', () {
    test('Default AppSettings has exactly 3 Lite and 3 Pro models', () {
      final settings = AppSettings();

      expect(settings.liteModels.length, 3);
      expect(settings.liteModels, [
        'gemini-2.0-flash-lite',
        'gemini-2.0-flash',
        'gemini-1.5-flash',
      ]);

      expect(settings.heavyModels.length, 3);
      expect(settings.heavyModels, [
        'gemini-2.0-flash',
        'gemini-2.0-pro-exp-02-05',
        'gemini-1.5-pro',
      ]);
    });

    test('AppSettings supports any amount of models (e.g. 6 models) and persists correctly', () {
      final customLite = [
        'gemini-2.0-flash-lite',
        'gemini-2.0-flash',
        'gemini-1.5-flash',
        'gemini-2.5-pro',
        'custom-experimental-model',
        'meta-llama/llama-3.3-70b',
      ];
      final customPro = [
        'gemini-2.0-flash',
        'gemini-2.0-pro-exp-02-05',
        'gemini-1.5-pro',
        'gemini-2.5-pro',
        'openrouter/auto',
      ];

      final settings = AppSettings(
        liteModels: customLite,
        heavyModels: customPro,
      );

      expect(settings.liteModels.length, 6);
      expect(settings.heavyModels.length, 5);

      final json = settings.toJson();
      final restored = AppSettings.fromJson(json);

      expect(restored.liteModels.length, 6);
      expect(restored.liteModels, customLite);

      expect(restored.heavyModels.length, 5);
      expect(restored.heavyModels, customPro);
    });

    test('AppSettings.fromJson falls back to 3 default models if empty list provided', () {
      final emptyJson = {
        'liteModels': <String>[],
        'heavyModels': <String>[],
      };

      final restored = AppSettings.fromJson(emptyJson);

      expect(restored.liteModels.length, 3);
      expect(restored.liteModels, AppSettings.defaultLiteModels);

      expect(restored.heavyModels.length, 3);
      expect(restored.heavyModels, AppSettings.defaultHeavyModels);
    });

    test('AppSettings.fromJson trims whitespace and filters empty strings', () {
      final whitespaceJson = {
        'liteModels': [' gemini-2.0-flash-lite ', '', '  gemini-2.0-flash  '],
        'heavyModels': ['  gemini-2.0-flash ', '   ', ' gemini-1.5-pro '],
      };

      final restored = AppSettings.fromJson(whitespaceJson);

      expect(restored.liteModels, ['gemini-2.0-flash-lite', 'gemini-2.0-flash']);
      expect(restored.heavyModels, ['gemini-2.0-flash', 'gemini-1.5-pro']);
    });
  });
}
