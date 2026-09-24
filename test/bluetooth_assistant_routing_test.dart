import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/services/assistant_routing_service.dart';
import 'package:missions/src/services/stt_service.dart';
import 'package:missions/src/services/tts_service.dart';
import 'package:missions/src/models/app_state_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InstalledAssistant Model Tests', () {
    test('InstalledAssistant properly holds package and label and formats toString', () {
      const assistant = InstalledAssistant(
        package: 'com.openai.chatgpt',
        label: 'ChatGPT',
      );
      expect(assistant.package, 'com.openai.chatgpt');
      expect(assistant.label, 'ChatGPT');
      expect(assistant.toString(), 'ChatGPT (com.openai.chatgpt)');
    });
  });

  group('AssistantRoutingService Tests', () {
    const channel = MethodChannel('arcane/assistant');

    test('getInstalledAssistants returns parsed list of installed assistant apps', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getInstalledAssistants') {
          return [
            {'package': 'com.openai.chatgpt', 'label': 'ChatGPT'},
            {'package': 'com.google.android.apps.googleassistant', 'label': 'Google Assistant'},
            {'package': 'com.anthropic.claude', 'label': 'Anthropic Claude'},
          ];
        }
        return null;
      });

      final list = await AssistantRoutingService.instance.getInstalledAssistants();
      expect(list.length, 3);
      expect(list[0].package, 'com.openai.chatgpt');
      expect(list[0].label, 'ChatGPT');
      expect(list[1].package, 'com.google.android.apps.googleassistant');
      expect(list[2].package, 'com.anthropic.claude');
    });

    test('launchVoiceMode sends correct package to native channel', () async {
      String? launchedPackage;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'launchAssistantPackage') {
          launchedPackage = (methodCall.arguments as Map)['package'] as String?;
          return true;
        }
        return null;
      });

      final success = await AssistantRoutingService.instance.launchVoiceMode('com.openai.chatgpt');
      expect(success, isTrue);
      expect(launchedPackage, 'com.openai.chatgpt');
    });
  });

  group('SttService Native Channel & State Tests', () {
    const sttChannel = MethodChannel('arcane/stt');

    test('SttService initializes with default idle values', () {
      final stt = SttService.instance;
      expect(stt.isListening.value, isFalse);
      expect(stt.currentRms.value, 0.0);
      expect(stt.lastTranscription.value, isEmpty);
    });

    test('SttService startListening invokes native channel and updates state', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sttChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'startListening') {
          return true;
        }
        if (methodCall.method == 'stopListening') {
          return true;
        }
        return null;
      });

      final stt = SttService.instance;
      String recognizedResult = '';
      String partialResult = '';

      final started = await stt.startListening(
        onResult: (text) => recognizedResult = text,
        onPartial: (text) => partialResult = text,
      );
      expect(started, isTrue);

      // Simulate native callback for partial results
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'arcane/stt',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onPartialResult', 'Check my daily tasks'),
        ),
        (data) {},
      );
      expect(stt.lastTranscription.value, 'Check my daily tasks');
      expect(partialResult, 'Check my daily tasks');

      // Simulate native callback for RMS voice amplitude
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'arcane/stt',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onRmsChanged', 7.5),
        ),
        (data) {},
      );
      expect(stt.currentRms.value, 7.5);

      // Simulate native callback for final recognition result
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'arcane/stt',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onResult', 'Check my daily tasks completed'),
        ),
        (data) {},
      );
      expect(stt.lastTranscription.value, 'Check my daily tasks completed');
      expect(recognizedResult, 'Check my daily tasks completed');
      expect(stt.isListening.value, isFalse);
    });
  });

  group('TtsService Native Utterance Progression Tests', () {
    const ttsChannel = MethodChannel('arcane/tts');

    test('TtsService reacts to native onStart and onDone utterance events', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ttsChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'speak') return true;
        if (methodCall.method == 'stop') return true;
        return null;
      });

      final tts = TtsService.instance;
      bool completedFired = false;
      tts.onSpeechCompleted = () {
        completedFired = true;
      };

      // Native notifies onStart
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'arcane/tts',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onStart', 'utt_1'),
        ),
        (data) {},
      );
      expect(tts.isSpeakingNotifier.value, isTrue);

      // Native notifies onDone
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'arcane/tts',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onDone', 'utt_1'),
        ),
        (data) {},
      );
      expect(tts.isSpeakingNotifier.value, isFalse);
      expect(completedFired, isTrue);
    });
  });

  group('AppSettings Bluetooth Assistant Tests', () {
    test('AppSettings serialization preserves bluetooth assistant redirect values', () {
      final settings = AppSettings();
      expect(settings.bluetoothAssistantRedirectTarget, 'nora');
      expect(settings.bluetoothAssistantCustomPackage, '');

      settings.bluetoothAssistantRedirectTarget = 'com.openai.chatgpt';
      settings.bluetoothAssistantCustomPackage = 'com.custom.assistant';

      final json = settings.toJson();
      expect(json['bluetoothAssistantRedirectTarget'], 'com.openai.chatgpt');
      expect(json['bluetoothAssistantCustomPackage'], 'com.custom.assistant');

      final reconstructed = AppSettings.fromJson(json);
      expect(reconstructed.bluetoothAssistantRedirectTarget, 'com.openai.chatgpt');
      expect(reconstructed.bluetoothAssistantCustomPackage, 'com.custom.assistant');
    });
  });
}
