import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/services/assistant_routing_service.dart';
import 'package:missions/src/services/stt_service.dart';
import 'package:missions/src/services/tts_service.dart';
import 'package:missions/src/models/app_state_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InstalledAssistant & InstalledApp Models Tests', () {
    test('InstalledAssistant properly holds package and label and formats toString', () {
      const assistant = InstalledAssistant(
        package: 'com.openai.chatgpt',
        label: 'ChatGPT',
      );
      expect(assistant.package, 'com.openai.chatgpt');
      expect(assistant.label, 'ChatGPT');
      expect(assistant.toString(), 'ChatGPT (com.openai.chatgpt)');
    });

    test('InstalledAppInfo parses from map and handles fields', () {
      final app = InstalledAppInfo.fromMap({
        'package': 'com.openai.chatgpt',
        'label': 'ChatGPT',
        'isSystem': false,
        'isLaunchable': true,
      });
      expect(app.package, 'com.openai.chatgpt');
      expect(app.label, 'ChatGPT');
      expect(app.isSystem, isFalse);
      expect(app.isLaunchable, isTrue);
    });

    test('AppActivityInfo parses from map and handles fields', () {
      final act = AppActivityInfo.fromMap({
        'name': 'com.openai.voice.VoiceActivity',
        'label': 'Voice Mode',
        'exported': true,
        'isVoiceOrAssist': true,
      });
      expect(act.name, 'com.openai.voice.VoiceActivity');
      expect(act.label, 'Voice Mode');
      expect(act.exported, isTrue);
      expect(act.isVoiceOrAssist, isTrue);
      expect(act.shortName, 'VoiceActivity');
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

    test('getAllInstalledApps returns list of all apps from native', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getAllInstalledApps') {
          return [
            {
              'package': 'com.openai.chatgpt',
              'label': 'ChatGPT',
              'isSystem': false,
              'isLaunchable': true,
            },
            {
              'package': 'com.android.settings',
              'label': 'Settings',
              'isSystem': true,
              'isLaunchable': true,
            },
          ];
        }
        return null;
      });

      final list = await AssistantRoutingService.instance.getAllInstalledApps();
      expect(list.length, 2);
      expect(list[0].package, 'com.openai.chatgpt');
      expect(list[0].isSystem, isFalse);
      expect(list[1].package, 'com.android.settings');
      expect(list[1].isSystem, isTrue);
    });

    test('getAppActivities returns declared activities for package', () async {
      String? requestedPackage;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getAppActivities') {
          requestedPackage = (methodCall.arguments as Map)['package'] as String?;
          return [
            {
              'name': 'com.openai.chatgpt.MainActivity',
              'label': 'ChatGPT',
              'exported': true,
              'isVoiceOrAssist': false,
            },
            {
              'name': 'com.openai.voice.AssistantActivity',
              'label': 'Voice Assistant',
              'exported': true,
              'isVoiceOrAssist': true,
            },
          ];
        }
        return null;
      });

      final activities = await AssistantRoutingService.instance.getAppActivities('com.openai.chatgpt');
      expect(requestedPackage, 'com.openai.chatgpt');
      expect(activities.length, 2);
      expect(activities[1].isVoiceOrAssist, isTrue);
      expect(activities[1].shortName, 'AssistantActivity');
    });

    test('launchVoiceMode sends correct package and activity to native channel', () async {
      String? launchedPackage;
      String? launchedActivity;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'launchAssistantPackage') {
          final args = methodCall.arguments as Map;
          launchedPackage = args['package'] as String?;
          launchedActivity = args['activity'] as String?;
          return true;
        }
        return null;
      });

      final success = await AssistantRoutingService.instance.launchVoiceMode(
        'com.openai.chatgpt',
        activity: 'com.openai.voice.AssistantActivity',
      );
      expect(success, isTrue);
      expect(launchedPackage, 'com.openai.chatgpt');
      expect(launchedActivity, 'com.openai.voice.AssistantActivity');
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
      expect(settings.bluetoothAssistantCustomActivity, '');

      settings.bluetoothAssistantRedirectTarget = 'custom';
      settings.bluetoothAssistantCustomPackage = 'com.custom.assistant';
      settings.bluetoothAssistantCustomActivity = 'com.custom.assistant.VoiceActivity';

      final json = settings.toJson();
      expect(json['bluetoothAssistantRedirectTarget'], 'custom');
      expect(json['bluetoothAssistantCustomPackage'], 'com.custom.assistant');
      expect(json['bluetoothAssistantCustomActivity'], 'com.custom.assistant.VoiceActivity');

      final reconstructed = AppSettings.fromJson(json);
      expect(reconstructed.bluetoothAssistantRedirectTarget, 'custom');
      expect(reconstructed.bluetoothAssistantCustomPackage, 'com.custom.assistant');
      expect(reconstructed.bluetoothAssistantCustomActivity, 'com.custom.assistant.VoiceActivity');
    });
  });
}
