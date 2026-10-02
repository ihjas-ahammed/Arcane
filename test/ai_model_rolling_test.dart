import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/models/app_state_models.dart';

void main() {
  group('AI Model Rolling & Fallback Configuration Tests', () {
    test('Default AppSettings has default Lite and Pro models', () {
      final settings = AppSettings();

      expect(settings.liteModels.length, AppSettings.defaultLiteModels.length);
      expect(settings.liteModels, AppSettings.defaultLiteModels);

      expect(settings.heavyModels.length, AppSettings.defaultHeavyModels.length);
      expect(settings.heavyModels, AppSettings.defaultHeavyModels);
    });

    test('AppSettings supports any amount of models (e.g. 6 models) and persists correctly', () {
      final customLite = [
        ...AppSettings.defaultLiteModels,
        'custom-experimental-model',
        'meta-llama/llama-3.3-70b',
      ];
      final customPro = [
        ...AppSettings.defaultHeavyModels,
        'openrouter/auto',
      ];

      final settings = AppSettings(
        liteModels: customLite,
        heavyModels: customPro,
      );

      expect(settings.liteModels.length, AppSettings.defaultLiteModels.length + 2);
      expect(settings.heavyModels.length, AppSettings.defaultHeavyModels.length + 1);

      final json = settings.toJson();
      final restored = AppSettings.fromJson(json);

      expect(restored.liteModels.length, AppSettings.defaultLiteModels.length + 2);
      expect(restored.liteModels, customLite);

      expect(restored.heavyModels.length, AppSettings.defaultHeavyModels.length + 1);
      expect(restored.heavyModels, customPro);
    });

    test('AppSettings.fromJson falls back to default models if empty list provided', () {
      final emptyJson = {
        'liteModels': <String>[],
        'heavyModels': <String>[],
      };

      final restored = AppSettings.fromJson(emptyJson);

      expect(restored.liteModels.length, AppSettings.defaultLiteModels.length);
      expect(restored.liteModels, AppSettings.defaultLiteModels);

      expect(restored.heavyModels.length, AppSettings.defaultHeavyModels.length);
      expect(restored.heavyModels, AppSettings.defaultHeavyModels);
    });

    test('AppSettings.fromJson trims whitespace and filters empty strings', () {
      final whitespaceJson = {
        'liteModels': [' gemini-2.0-flash-lite ', '', '  gemini-2.0-flash  '],
        'heavyModels': ['  gemini-2.0-flash ', '   ', ' gemini-1.5-pro '],
      };

      final restored = AppSettings.fromJson(whitespaceJson);

      expect(restored.liteModels, containsAll(['gemini-2.0-flash-lite', 'gemini-2.0-flash']));
      expect(restored.heavyModels, containsAll(['gemini-2.0-flash', 'gemini-1.5-pro']));
    });
  });
}
