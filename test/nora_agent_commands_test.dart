import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dart/firebase_dart.dart' as fd;
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/nora_agent_engine.dart';
import 'package:missions/src/services/ai_service.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    try {
      fd.FirebaseDart.setup(storagePath: '/tmp/firebase_test_nora_commands');
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

  group('NORA Reasoning Parser (_parseNoraResponse) Tests', () {
    final aiService = AIService();

    test('Parses direct JSON with messages and actions', () {
      const raw = '''
{
  "thought": "User wants to add meditation.",
  "messages": ["I have added meditation to your day plan."],
  "actions": [
    {"type": "add_task", "name": "Meditate", "taskType": "sub"},
    {"type": "add_to_plan", "name": "Meditate", "estimateMinutes": 15}
  ]
}''';
      final parsed = aiService.parseNoraResponseForTest(raw);
      expect(parsed['thought'], "User wants to add meditation.");
      expect(parsed['messages'], ["I have added meditation to your day plan."]);
      expect((parsed['actions'] as List).length, 2);
    });

    test('Parses output wrapped in <think> tags followed by markdown JSON block', () {
      const raw = '''
<think>
The user is asking to add a new workout task and schedule it on today's plan.
I should create a subtask under Physical and add it to today's plan.
</think>

```json
{
  "messages": ["Workout task created and scheduled!"],
  "actions": [
    {"type": "add_task", "name": "Pushups", "taskType": "sub"},
    {"type": "add_to_plan", "name": "Pushups"}
  ]
}
```''';
      final parsed = aiService.parseNoraResponseForTest(raw);
      expect(parsed['thought'], contains("workout task"));
      expect(parsed['messages'], ["Workout task created and scheduled!"]);
      expect((parsed['actions'] as List).length, 2);
    });

    test('Parses output wrapped in <thought> tags with bare JSON', () {
      const raw = '''
<thought>
Let me check the tasks and add Reading.
</thought>
{
  "thought": "Scheduling reading session.",
  "messages": ["Scheduled 30 minutes of reading."],
  "actions": [
    {"type": "add_task", "name": "Read Book", "taskType": "sub"},
    {"type": "add_to_plan", "name": "Read Book", "estimateMinutes": 30}
  ]
}''';
      final parsed = aiService.parseNoraResponseForTest(raw);
      expect(parsed['thought'], "Scheduling reading session.");
      expect(parsed['messages'], ["Scheduled 30 minutes of reading."]);
      expect((parsed['actions'] as List).length, 2);
    });

    test('Handles non-JSON plain text fallback without crashing', () {
      const raw = "Sure thing! I can help you with your daily missions.";
      final parsed = aiService.parseNoraResponseForTest(raw);
      expect(parsed['messages'], [raw]);
      expect(parsed['actions'], isEmpty);
    });
  });

  group('NoraAgentEngine Inbuilt Database Tools: Tasks & Day Plan', () {
    late AppProvider provider;
    late NoraAgentEngine engine;

    setUp(() {
      provider = AppProvider.forTest();

      provider.setMainTasks([
        MainTask(
          id: 'main_focus',
          name: 'Core Operations',
          theme: 'Work',
          colorHex: '#00F8F8',
          description: 'Primary daily missions',
          subTasks: [
            SubTask(
              id: 'sub_review',
              name: 'Code Review',
              why: 'Maintain excellence',
              what: 'Review open pull requests',
              completed: false,
              subSubTasks: [],
            ),
          ],
        ),
      ]);

      engine = NoraAgentEngine(provider: provider, aiService: AIService());
    });

    test('add_task tool creates subtask and returns compound ID', () async {
      final res = await engine.dispatchToolForTest(
        toolName: 'add_task',
        toolArgs: {
          'name': 'Deep Focus Block',
          'description': 'Uninterrupted architecture planning',
        },
        personaId: 'persona_assistant',
      );

      expect(res['status'], 'success');
      expect(res['task_type'], 'sub');
      expect(res['compound_id'], startsWith('main_focus|'));
      expect(res['name'], 'Deep Focus Block');

      final activeMains = provider.mainTasks.firstWhere((t) => t.id == 'main_focus');
      expect(activeMains.subTasks.any((s) => s.name == 'Deep Focus Block'), isTrue);
    });

    test('add_to_plan tool schedules task and sets estimate', () async {
      // First schedule existing task 'Code Review'
      final res = await engine.dispatchToolForTest(
        toolName: 'add_to_plan',
        toolArgs: {
          'task_name': 'Code Review',
          'date': '2026-09-29',
          'estimate_minutes': 45,
        },
        personaId: 'persona_assistant',
      );

      expect(res['status'], 'success');
      expect(res['compound_id'], 'main_focus|sub_review');

      final plan = provider.taskActions.getDayPlan('2026-09-29');
      expect(plan, contains('main_focus|sub_review'));

      final estimates = provider.taskActions.getDayPlanEstimates('2026-09-29');
      expect(estimates['main_focus|sub_review'], 45);
    });

    test('check_task tool marks subtask as completed', () async {
      expect(provider.mainTasks.first.subTasks.first.completed, isFalse);

      final res = await engine.dispatchToolForTest(
        toolName: 'check_task',
        toolArgs: {
          'task_name': 'Code Review',
          'completed': true,
        },
        personaId: 'persona_assistant',
      );

      expect(res['status'], 'success');
      expect(res['completed'], isTrue);
      expect(provider.mainTasks.first.subTasks.first.completed, isTrue);
    });

    test('remove_from_plan tool removes item from day plan', () async {
      provider.taskActions.addToDayPlan('main_focus|sub_review', '2026-09-29');
      expect(provider.taskActions.getDayPlan('2026-09-29'), contains('main_focus|sub_review'));

      final res = await engine.dispatchToolForTest(
        toolName: 'remove_from_plan',
        toolArgs: {
          'task_name': 'Code Review',
          'date': '2026-09-29',
        },
        personaId: 'persona_assistant',
      );

      expect(res['status'], 'success');
      expect(provider.taskActions.getDayPlan('2026-09-29'), isNot(contains('main_focus|sub_review')));
    });
  });

  group('executeNoraAgentActions in AppProvider Tests', () {
    late AppProvider provider;

    setUp(() {
      provider = AppProvider.forTest();
      provider.setMainTasks([
        MainTask(
          id: 'main_ops',
          name: 'Tactical Missions',
          theme: 'Tactical',
          colorHex: '#FF4655',
          description: 'High priority tasks',
          subTasks: [
            SubTask(
              id: 'sub_recon',
              name: 'Reconnaissance',
              why: 'Gain intelligence',
              what: 'Scan radar',
              completed: false,
              subSubTasks: [],
            ),
          ],
        ),
      ]);
    });

    test('Chained add_task followed by add_to_plan automatically links compoundId', () async {
      final actions = [
        {
          'type': 'add_task',
          'name': 'Deploy Satellite Link',
          'taskType': 'sub',
          'description': 'Initialize secure comms',
        },
        {
          'type': 'add_to_plan',
          'name': 'Deploy Satellite Link',
          'date': '2026-09-29',
          'estimateMinutes': 20,
        },
      ];

      await provider.executeNoraAgentActions(actions);

      // Verify task was created
      final main = provider.mainTasks.firstWhere((t) => t.id == 'main_ops');
      final newSub = main.subTasks.firstWhere((s) => s.name == 'Deploy Satellite Link');
      expect(newSub, isNotNull);

      // Verify task was added to today plan
      final plan = provider.taskActions.getDayPlan('2026-09-29');
      expect(plan, contains('main_ops|${newSub.id}'));

      final estimates = provider.taskActions.getDayPlanEstimates('2026-09-29');
      expect(estimates['main_ops|${newSub.id}'], 20);
    });

    test('check_task completes task by name', () async {
      expect(provider.mainTasks.first.subTasks.first.completed, isFalse);

      await provider.executeNoraAgentActions([
        {
          'type': 'check_task',
          'name': 'Reconnaissance',
          'completed': true,
        },
      ]);

      expect(provider.mainTasks.first.subTasks.first.completed, isTrue);
    });
  });
}
