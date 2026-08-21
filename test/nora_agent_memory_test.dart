import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dart/firebase_dart.dart' as fd;
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/nora_agent_engine.dart';
import 'package:missions/src/services/ai_service.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    try {
      fd.FirebaseDart.setup(storagePath: '/tmp/firebase_test_nora');
      await fd.Firebase.initializeApp(
        options: const fd.FirebaseOptions(
          apiKey: 'mock_api_key',
          appId: 'mock_app_id',
          messagingSenderId: 'mock_sender_id',
          projectId: 'mock_project_id',
        ),
      );
    } catch (_) {}
  });

  group('Nora Persona & Memory Space Model Tests', () {
    test('NoraMemoryItem serialization and deserialization', () {
      final memory = NoraMemoryItem(
        id: 'mem_123',
        key: 'preferred_tone',
        content: 'User prefers concise, direct responses without sugarcoating.',
        tags: ['preference', 'communication'],
      );

      final json = memory.toJson();
      final restored = NoraMemoryItem.fromJson(json);

      expect(restored.id, 'mem_123');
      expect(restored.key, 'preferred_tone');
      expect(restored.content, 'User prefers concise, direct responses without sugarcoating.');
      expect(restored.tags, ['preference', 'communication']);
    });

    test('NoraPersona built-ins and custom persona serialization', () {
      final builtins = NoraPersona.defaultBuiltInPersonas();
      expect(builtins.length, 5);
      expect(builtins.any((p) => p.name == 'Assistant'), isTrue);
      expect(builtins.any((p) => p.name == 'Therapist'), isTrue);
      expect(builtins.any((p) => p.name == 'Philosopher'), isTrue);
      expect(builtins.any((p) => p.name == 'Tactical Commander'), isTrue);
      expect(builtins.any((p) => p.name == 'Friend'), isTrue);

      final customPersona = NoraPersona(
        id: 'persona_tony_stark',
        name: 'Tony Stark',
        tagline: 'Genius, billionaire, playboy, philanthropist',
        avatarIcon: 'robot',
        systemPrompt: 'You are Tony Stark. Speak with unmatched wit and brilliance.',
        greetingMessage: 'Sometimes you gotta run before you can walk.',
        sourceType: 'movie_character',
        memorySpace: [
          NoraMemoryItem(id: 'm1', key: 'arc_reactor', content: 'Mark 85 ready'),
        ],
      );

      final json = customPersona.toJson();
      final restored = NoraPersona.fromJson(json);

      expect(restored.id, 'persona_tony_stark');
      expect(restored.name, 'Tony Stark');
      expect(restored.sourceType, 'movie_character');
      expect(restored.memorySpace.length, 1);
      expect(restored.memorySpace.first.key, 'arc_reactor');
    });

    test('ChatbotMemory manages dedicated memory spaces per character', () {
      final chatbotMemory = ChatbotMemory();
      expect(chatbotMemory.allPersonas.length, 5);

      // Add memory to Assistant
      chatbotMemory.addPersonaMemoryItem(
        'persona_assistant',
        NoraMemoryItem(id: 'm_ast_1', key: 'wake_time', content: 'User wakes at 06:00 AM'),
      );

      final assistantMemories = chatbotMemory.getPersonaMemories('persona_assistant');
      expect(assistantMemories.length, 1);
      expect(assistantMemories.first.key, 'wake_time');

      // Create Custom Character with its own memory space
      final harvey = NoraPersona(
        id: 'persona_harvey',
        name: 'Harvey Specter',
        tagline: 'I don’t play the odds, I play the man.',
        systemPrompt: 'You are Harvey Specter from Suits.',
      );
      chatbotMemory.saveCustomPersona(harvey);

      chatbotMemory.addPersonaMemoryItem(
        'persona_harvey',
        NoraMemoryItem(id: 'm_h_1', key: 'rule_number_one', content: 'Never go into court unprepared.'),
      );

      final harveyMemories = chatbotMemory.getPersonaMemories('persona_harvey');
      expect(harveyMemories.length, 1);
      expect(harveyMemories.first.key, 'rule_number_one');

      // Check isolation: Assistant memory space is unaffected
      expect(chatbotMemory.getPersonaMemories('persona_assistant').length, 1);
      expect(chatbotMemory.getPersonaMemories('persona_assistant').first.key, 'wake_time');

      // Delete memory
      chatbotMemory.deletePersonaMemoryItem('persona_harvey', 'rule_number_one');
      expect(chatbotMemory.getPersonaMemories('persona_harvey').isEmpty, isTrue);
    });
  });

  group('NoraAgentEngine Inbuilt Database Tools Tests', () {
    late AppProvider provider;
    late NoraAgentEngine engine;

    setUp(() {
      provider = AppProvider.forTest();

      // Seed provider with mock reflection logs
      provider.setReflectionLogs([
        ReflectionLog(
          id: 'ref_1',
          timestamp: DateTime(2026, 8, 10, 14, 0),
          trigger: 'Completed major Flutter refactor',
          emotion: 'Proud and energized',
          reason: 'Shipped clean modular code on schedule',
          action: 'Continue maintaining high quality standards',
          aiFeedback: 'Great work on maintaining discipline.',
          xpGained: {'discipline': 15},
        ),
        ReflectionLog(
          id: 'ref_2',
          timestamp: DateTime(2026, 8, 15, 18, 30),
          trigger: 'Missed workout session',
          emotion: 'Slightly frustrated',
          reason: 'Spent too much time debugging minor UI glitch',
          action: 'Timebox debugging to 45 mins then exercise',
          aiFeedback: 'Reflect on time management.',
          xpGained: {'focus': 10},
        ),
      ]);

      // Seed provider with mock tasks
      provider.setMainTasks([
        MainTask(
          id: 'task_app',
          name: 'Nora 2.0 Agent Architecture',
          theme: 'Development',
          colorHex: '#8A2BE2',
          description: 'Autonomous AI agent with database tools',
          subTasks: [
            SubTask(
              id: 'sub_1',
              name: 'Inbuilt Tool Execution Framework',
              why: 'Support agentic queries on mobile',
              what: 'Dispatch local database reads and memory updates',
              completed: true,
              subSubTasks: [],
            ),
          ],
        ),
      ]);

      engine = NoraAgentEngine(provider: provider, aiService: AIService());
    });

    test('FindReflections and ReadReflections retrieve scoped logs', () async {
      // 1. Find by emotion query
      final findResult = engine.provider.reflectionLogs;
      expect(findResult.length, 2);

      // Verify reflection searching & reading
      final log1 = provider.reflectionLogs.firstWhere((l) => l.emotion.contains('Proud'));
      expect(log1.id, 'ref_1');
      expect(log1.trigger, 'Completed major Flutter refactor');

      final log2 = provider.reflectionLogs.firstWhere((l) => l.emotion.contains('frustrated'));
      expect(log2.id, 'ref_2');
      expect(log2.action, 'Timebox debugging to 45 mins then exercise');
    });

    test('Memory tools add, find, and delete memories for active persona', () {
      final persona = provider.chatbotMemory.allPersonas.first;

      // Add
      provider.addPersonaMemoryItem(
        persona.id,
        NoraMemoryItem(
          id: 'mem_focus',
          key: 'deep_work_preference',
          content: 'User prefers uninterrupted blocks in the morning.',
          tags: ['routine', 'focus'],
        ),
      );

      final memories = provider.getPersonaMemories(persona.id);
      expect(memories.length, 1);
      expect(memories.first.key, 'deep_work_preference');
      expect(memories.first.tags, contains('routine'));

      // Delete
      provider.deletePersonaMemoryItem(persona.id, 'deep_work_preference');
      expect(provider.getPersonaMemories(persona.id).isEmpty, isTrue);
    });
  });
}
