import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/ai_service.dart';
import 'package:uuid/uuid.dart';

/// NoraAgentEngine
/// Inbuilt function calling & multi-turn reasoning loop for Nora and custom personas.
/// Queries local app database on-demand and manages character-isolated Memory Space.
class NoraAgentEngine {
  final AppProvider provider;
  final AIService aiService;

  NoraAgentEngine({required this.provider, required this.aiService});

  /// Runs the agent reasoning loop for a user query in a NoraSession.
  Future<Map<String, dynamic>> executeAgentLoop({
    required NoraSession session,
    required String userQuery,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
    int maxIterations = 5,
  }) async {
    final persona = provider.getActiveNoraPersona(session);
    final personaId = persona.id;

    // Build initial compact overview catalog (NOT dumping full text)
    final catalogSummary = _buildDatabaseCatalogSummary(persona);

    // Build conversation scratchpad
    final List<Map<String, String>> scratchpad = [];

    // History from session (last 6 messages for context)
    final recentHistory = session.messages.length > 6
        ? session.messages.sublist(session.messages.length - 6)
        : session.messages;
    final historyStr = recentHistory
        .map((m) => "${m.sender == MessageSender.user ? 'USER' : persona.name.toUpperCase()}: ${m.text}")
        .join("\n");

    int iteration = 0;
    Map<String, dynamic>? finalResult;

    while (iteration < maxIterations) {
      iteration++;

      final prompt = _buildAgentPrompt(
        persona: persona,
        session: session,
        catalogSummary: catalogSummary,
        conversationHistory: historyStr,
        userQuery: userQuery,
        scratchpad: scratchpad,
        iteration: iteration,
      );

      try {
        final stepResponse = await aiService.queryNoraAgentTurn(
          prompt: prompt,
          modelCandidates: modelCandidates,
          currentApiKeyIndex: currentApiKeyIndex,
          customApiKeys: customApiKeys,
          onNewApiKeyIndex: onNewApiKeyIndex,
          onLog: onLog,
        );

        // Check if the agent wants to call a tool
        if (stepResponse.containsKey('tool_call') && stepResponse['tool_call'] is Map) {
          final toolCall = stepResponse['tool_call'] as Map<String, dynamic>;
          final toolName = toolCall['name']?.toString().trim() ?? '';
          final toolArgs = toolCall['args'] is Map<String, dynamic>
              ? toolCall['args'] as Map<String, dynamic>
              : (toolCall['args'] is Map ? Map<String, dynamic>.from(toolCall['args'] as Map) : <String, dynamic>{});
          final thought = stepResponse['thought']?.toString() ?? '';

          onLog("[NoraAgent] Step $iteration Tool Call: $toolName with args $toolArgs (Thought: $thought)");

          // Execute tool on local provider database
          final toolResult = await _dispatchTool(
            toolName: toolName,
            toolArgs: toolArgs,
            personaId: personaId,
          );

          scratchpad.add({
            'thought': thought,
            'tool_name': toolName,
            'tool_args': jsonEncode(toolArgs),
            'tool_result': jsonEncode(toolResult),
          });

          // Continue next iteration of agent loop
          continue;
        }

        // Check if the agent produced final messages
        if (stepResponse.containsKey('messages') && stepResponse['messages'] is List) {
          finalResult = stepResponse;
          break;
        }

        // If neither, fallback parse as a single message response
        if (stepResponse.isNotEmpty) {
          finalResult = stepResponse;
          break;
        }
      } catch (e) {
        onLog("[NoraAgent] Iteration $iteration error: $e");
        if (iteration == 1) rethrow;
        break;
      }
    }

    if (finalResult == null || (finalResult['messages'] as List? ?? []).isEmpty) {
      finalResult = {
        'messages': ["I processed your request, operative."],
        'actions': [],
      };
    }

    return finalResult;
  }

  /// Builds a lightweight catalog summary so the agent knows what exists in the database
  String _buildDatabaseCatalogSummary(NoraPersona persona) {
    final reflections = provider.reflectionLogs;
    final firstDate = reflections.isNotEmpty
        ? DateFormat('yyyy-MM-dd').format(reflections.first.timestamp)
        : 'N/A';
    final lastDate = reflections.isNotEmpty
        ? DateFormat('yyyy-MM-dd').format(reflections.last.timestamp)
        : 'N/A';

    final mainTasks = provider.mainTasks.where((t) => !t.isDeleted).toList();
    final taskNames = mainTasks.map((t) => "${t.name} (ID: ${t.id})").join(', ');

    final peopleCount = provider.chatbotMemory.people.length;
    final peopleNames = provider.chatbotMemory.people.map((p) => p.name).take(10).join(', ');

    final memoryItems = persona.memorySpace;
    final memoryKeys = memoryItems.map((m) => m.key).take(15).join(', ');

    return """
- Reflections in Database: ${reflections.length} logs (Date span: $firstDate to $lastDate)
- Active Main Tasks: ${mainTasks.length} [${taskNames.isEmpty ? 'None' : taskNames}]
- Known Contacts: $peopleCount [${peopleNames.isEmpty ? 'None' : peopleNames}]
- ${persona.name}'s Memory Space Entries: ${memoryItems.length} stored memories [${memoryKeys.isEmpty ? 'None yet' : memoryKeys}]
""";
  }

  /// Builds the prompt for the current step of the agent loop
  String _buildAgentPrompt({
    required NoraPersona persona,
    required NoraSession session,
    required String catalogSummary,
    required String conversationHistory,
    required String userQuery,
    required List<Map<String, String>> scratchpad,
    required int iteration,
  }) {
    final systemPrompt = session.systemPromptOverride ?? persona.systemPrompt;
    final nowStr = DateTime.now().toIso8601String();

    final buffer = StringBuffer();
    buffer.writeln("""
SYSTEM INSTRUCTION:
$systemPrompt

PERSONA IDENTITY:
Name: ${persona.name}
Tagline: ${persona.tagline}
Tone Mode: ${session.tone}

CURRENT DATE & TIME: $nowStr

DATABASE CATALOG SUMMARY (Overview):
$catalogSummary

CONVERSATION HISTORY:
$conversationHistory

USER QUERY: "$userQuery"

AVAILABLE INBUILT AGENT FUNCTIONS:
1. find_reflections(query: string?, emotion: string?, trigger: string?, start_date: string?, end_date: string?, limit: int?)
   - Searches reflection logs matching keywords, emotions, triggers, or date range. Returns list of matches with IDs and previews.
2. read_reflections(ids: string[]?, start_date: string?, end_date: string?, limit: int?)
   - Reads the FULL content (trigger, emotion, reason, action, notes) of reflections for specific IDs or a date range (e.g. start_date='2026-08-01', end_date='2026-08-15').
3. find_tasks(query: string?, completed: bool?)
   - Searches main tasks, subtasks, and sub-subtasks.
4. read_task(task_id: string)
   - Reads full hierarchy, description, why, what, and subtasks of a specific task.
5. get_day_plan(date: string?)
   - Gets scheduled plan items and checkpoints for a given date (default today).
6. find_people(query: string?)
   - Searches known contacts/people.
7. read_person(name: string?, id: string?)
   - Reads full biodata, notes, next meeting plans, and relation for a person.
8. memory_add(key: string, content: string, tags: string[]?)
   - Stores/updates a long-term realization, fact, user preference, or note in ${persona.name}'s dedicated Memory Space.
9. memory_read(key: string?, id: string?)
   - Reads a specific memory entry from ${persona.name}'s dedicated Memory Space.
10. memory_find(query: string?, tag: string?)
    - Searches ${persona.name}'s dedicated Memory Space.
11. memory_delete(key: string?, id: string?)
    - Removes a memory entry from ${persona.name}'s dedicated Memory Space.
12. memory_list(limit: int?)
    - Lists all memory keys and tags in ${persona.name}'s dedicated Memory Space.
13. add_task(name: string, description: string?, task_type: 'main'|'sub'|'subsub'?, main_task_id: string?, main_task_name: string?, subtask_id: string?, why: string?, what: string?, color_hex: string?)
    - Creates a new main task, subtask, or checkpoint. If task_type is omitted or 'sub', automatically adds it under the specified or best-fitting main task. Returns created task IDs and compound_id.
14. add_to_plan(task_name: string?, compound_id: string?, main_task_id: string?, subtask_id: string?, date: string?, estimate_minutes: int?)
    - Schedules and adds a task or checkpoint to the day plan for today (or specified YYYY-MM-DD date). Can reference by task_name or compound_id.
15. check_task(task_name: string?, compound_id: string?, main_task_id: string?, subtask_id: string?, checkpoint_id: string?, completed: bool?)
    - Marks a task or checkpoint as completed (or uncompleted).
16. remove_from_plan(task_name: string?, compound_id: string?, date: string?)
    - Removes a task from the scheduled day plan.

AGENT INSTRUCTIONS & PROTOCOL:
- You are an advanced autonomous agent with deep reasoning capabilities. Always use your step-by-step reasoning ("thought") to decide what actions or tools to call.
- For queries asking to add tasks, add to day plan, complete tasks, remember information, or search user journals:
  * First reason about the user's intent.
  * If needed, use tools like find_tasks() or get_day_plan() to inspect current tasks and plans.
  * You can call tools during your reasoning loop (like add_task or add_to_plan) OR specify mutating commands in the final "actions" array. Both methods will be executed!
  * If the user says "add task X and add to plan", you can call add_task first or return both in "actions" with type "add_task" and "add_to_plan".
- To call a function during reasoning, respond with JSON format:
  {
    "thought": "Reasoning about what information I need or what tool to invoke...",
    "tool_call": {
      "name": "<function_name>",
      "args": { ... }
    }
  }
- When you have completed all tool actions and are ready to deliver your final response to the user, respond with JSON format:
  {
    "thought": "Summary of reasoning and actions taken...",
    "messages": ["In-character response to user 1", "Optional response message 2"],
    "actions": [
      // Optional DB mutating actions executed after the conversation turn:
      // - {"type": "add_task", "name": "Task Name", "taskType": "sub", "mainTaskId": "...", "description": "..."}
      // - {"type": "add_to_plan", "name": "Task Name", "date": "YYYY-MM-DD", "estimateMinutes": 30}
      // - {"type": "check_task", "name": "Task Name", "completed": true}
      // - {"type": "remove_from_plan", "name": "Task Name"}
      // - {"type": "edit_person", "name": "...", "relation": "...", ...}
      // - {"type": "edit_reflection", "id": "...", ...}
      // - {"type": "add_nora_skill", "name": "...", ...}
      // - {"type": "custom_db_edit", "path": "...", "value": ...}
    ]
  }

RESPONSE FORMAT: Output ONLY the JSON object. No markdown fences.
""");

    if (scratchpad.isNotEmpty) {
      buffer.writeln("\nAGENT SCRATCHPAD (Previous Tool Executions in this turn):");
      for (int i = 0; i < scratchpad.length; i++) {
        final step = scratchpad[i];
        buffer.writeln("Step ${i + 1}:");
        buffer.writeln("  Thought: ${step['thought']}");
        buffer.writeln("  Tool Called: ${step['tool_name']}(${step['tool_args']})");
        buffer.writeln("  Tool Result: ${step['tool_result']}");
      }
      buffer.writeln("\nContinue reasoning or provide the final 'messages' response.");
    }

    return buffer.toString();
  }

  @visibleForTesting
  Future<dynamic> dispatchToolForTest({
    required String toolName,
    required Map<String, dynamic> toolArgs,
    required String personaId,
  }) => _dispatchTool(toolName: toolName, toolArgs: toolArgs, personaId: personaId);

  /// Dispatches the tool call to the corresponding local method
  Future<dynamic> _dispatchTool({
    required String toolName,
    required Map<String, dynamic> toolArgs,
    required String personaId,
  }) async {
    try {
      switch (toolName.toLowerCase()) {
        case 'find_reflections':
        case 'findreflections':
        case 'find':
          return _findReflections(toolArgs);

        case 'read_reflections':
        case 'readreflections':
        case 'read':
          return _readReflections(toolArgs);

        case 'find_tasks':
        case 'findtasks':
          return _findTasks(toolArgs);

        case 'read_task':
        case 'readtask':
          return _readTask(toolArgs);

        case 'get_day_plan':
        case 'getdayplan':
          return _getDayPlan(toolArgs);

        case 'add_task':
        case 'addtask':
          return _addTask(toolArgs);

        case 'add_to_plan':
        case 'addtoplan':
        case 'plan_add':
          return _addToPlan(toolArgs);

        case 'check_task':
        case 'checktask':
          return _checkTask(toolArgs);

        case 'remove_from_plan':
        case 'removefromplan':
        case 'plan_remove':
          return _removeFromPlan(toolArgs);

        case 'find_people':
        case 'findpeople':
          return _findPeople(toolArgs);

        case 'read_person':
        case 'readperson':
          return _readPerson(toolArgs);

        case 'memory_add':
        case 'memoryadd':
        case 'add':
          return _memoryAdd(personaId, toolArgs);

        case 'memory_read':
        case 'memoryread':
          return _memoryRead(personaId, toolArgs);

        case 'memory_find':
        case 'memoryfind':
          return _memoryFind(personaId, toolArgs);

        case 'memory_delete':
        case 'memorydelete':
        case 'delete':
          return _memoryDelete(personaId, toolArgs);

        case 'memory_list':
        case 'memorylist':
          return _memoryList(personaId, toolArgs);

        default:
          return {"error": "Unknown function: $toolName"};
      }
    } catch (e) {
      return {"error": "Tool execution exception: $e"};
    }
  }

  // --- Inbuilt Database Tool Implementations ---

  dynamic _findReflections(Map<String, dynamic> args) {
    final query = args['query']?.toString().toLowerCase();
    final emotion = args['emotion']?.toString().toLowerCase();
    final trigger = args['trigger']?.toString().toLowerCase();
    final startDateStr = args['start_date']?.toString();
    final endDateStr = args['end_date']?.toString();
    final limit = (args['limit'] as num?)?.toInt() ?? 10;

    DateTime? startDate = startDateStr != null ? DateTime.tryParse(startDateStr) : null;
    DateTime? endDate = endDateStr != null ? DateTime.tryParse(endDateStr)?.add(const Duration(days: 1)) : null;

    final results = <Map<String, dynamic>>[];

    for (final log in provider.reflectionLogs) {
      if (startDate != null && log.timestamp.isBefore(startDate)) continue;
      if (endDate != null && log.timestamp.isAfter(endDate)) continue;

      if (emotion != null && emotion.isNotEmpty && !log.emotion.toLowerCase().contains(emotion)) {
        continue;
      }
      if (trigger != null && trigger.isNotEmpty && !log.trigger.toLowerCase().contains(trigger)) {
        continue;
      }
      if (query != null && query.isNotEmpty) {
        final combined = "${log.trigger} ${log.emotion} ${log.reason} ${log.action}".toLowerCase();
        if (!combined.contains(query)) continue;
      }

      results.add({
        'id': log.id,
        'date': DateFormat('yyyy-MM-dd').format(log.timestamp),
        'trigger': log.trigger,
        'emotion': log.emotion,
        'preview': log.reason.length > 80 ? "${log.reason.substring(0, 80)}..." : log.reason,
      });

      if (results.length >= limit) break;
    }

    return {
      'matches_count': results.length,
      'reflections': results,
    };
  }

  dynamic _readReflections(Map<String, dynamic> args) {
    final ids = (args['ids'] as List<dynamic>?)?.map((e) => e.toString()).toSet();
    final startDateStr = args['start_date']?.toString();
    final endDateStr = args['end_date']?.toString();
    final limit = (args['limit'] as num?)?.toInt() ?? 20;

    DateTime? startDate = startDateStr != null ? DateTime.tryParse(startDateStr) : null;
    DateTime? endDate = endDateStr != null ? DateTime.tryParse(endDateStr)?.add(const Duration(days: 1)) : null;

    final results = <Map<String, dynamic>>[];

    for (final log in provider.reflectionLogs) {
      if (ids != null && ids.isNotEmpty) {
        if (!ids.contains(log.id)) continue;
      } else {
        if (startDate != null && log.timestamp.isBefore(startDate)) continue;
        if (endDate != null && log.timestamp.isAfter(endDate)) continue;
      }

      results.add({
        'id': log.id,
        'date': DateFormat('yyyy-MM-dd HH:mm').format(log.timestamp),
        'trigger': log.trigger,
        'emotion': log.emotion,
        'reason': log.reason,
        'action': log.action,
      });

      if (results.length >= limit) break;
    }

    return {
      'read_count': results.length,
      'entries': results,
    };
  }

  dynamic _findTasks(Map<String, dynamic> args) {
    final query = args['query']?.toString().toLowerCase() ?? '';
    final completed = args['completed'] as bool?;

    final results = <Map<String, dynamic>>[];

    for (final main in provider.mainTasks.where((t) => !t.isDeleted)) {
      bool mainMatches = query.isEmpty ||
          main.name.toLowerCase().contains(query) ||
          main.description.toLowerCase().contains(query);

      if (mainMatches) {
        results.add({
          'type': 'main_task',
          'id': main.id,
          'name': main.name,
          'description': main.description,
          'theme': main.theme,
          'subtasks_count': main.subTasks.where((s) => !s.isDeleted).length,
        });
      }

      for (final sub in main.subTasks.where((s) => !s.isDeleted)) {
        if (completed != null && sub.completed != completed) continue;
        bool subMatches = query.isEmpty ||
            sub.name.toLowerCase().contains(query) ||
            sub.description.toLowerCase().contains(query) ||
            sub.why.toLowerCase().contains(query) ||
            sub.what.toLowerCase().contains(query);

        if (subMatches) {
          results.add({
            'type': 'subtask',
            'main_task_id': main.id,
            'main_task_name': main.name,
            'subtask_id': sub.id,
            'name': sub.name,
            'completed': sub.completed,
            'why': sub.why,
            'what': sub.what,
          });
        }
      }
    }

    return {'matches': results};
  }

  dynamic _readTask(Map<String, dynamic> args) {
    final taskId = args['task_id']?.toString() ?? '';
    final main = provider.mainTasks.firstWhere(
      (t) => t.id == taskId && !t.isDeleted,
      orElse: () => MainTask(id: '', name: '', theme: '', colorHex: '', description: '', subTasks: []),
    );

    if (main.id.isEmpty) {
      return {'error': "Task with ID '$taskId' not found."};
    }

    return {
      'id': main.id,
      'name': main.name,
      'description': main.description,
      'theme': main.theme,
      'subtasks': main.subTasks.where((s) => !s.isDeleted).map((s) => {
        'id': s.id,
        'name': s.name,
        'completed': s.completed,
        'why': s.why,
        'what': s.what,
        'resources': s.resources,
        'sub_subtasks': s.subSubTasks.where((ss) => ss.isActive).map((ss) => {
          'id': ss.id,
          'name': ss.name,
          'completed': ss.completed,
          'checkpoints': ss.substeps.map((c) => {'id': c.id, 'name': c.name, 'completed': c.completed}).toList(),
        }).toList(),
      }).toList(),
    };
  }

  dynamic _getDayPlan(Map<String, dynamic> args) {
    final dateStr = args['date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final plan = provider.taskActions.getDayPlan(dateStr);

    final items = <Map<String, dynamic>>[];
    for (String idPair in plan) {
      final parts = idPair.split('|');
      if (parts.length >= 2) {
        final mTask = provider.mainTasks.firstWhere((t) => t.id == parts[0] && !t.isDeleted,
            orElse: () => MainTask(id: '', name: '', theme: '', colorHex: '', description: '', subTasks: []));
        final sTask = mTask.subTasks.firstWhere((s) => s.id == parts[1] && !s.isDeleted,
            orElse: () => SubTask(id: '', name: '', why: '', what: '', completed: false, subSubTasks: []));
        if (mTask.id.isNotEmpty && sTask.id.isNotEmpty) {
          items.add({
            'main_task': mTask.name,
            'subtask': sTask.name,
            'completed': sTask.completed,
            'checkpoint': parts.length == 3 ? parts[2] : null,
          });
        }
      }
    }

    return {'date': dateStr, 'plan_items': items};
  }

  dynamic _findPeople(Map<String, dynamic> args) {
    final query = args['query']?.toString().toLowerCase() ?? '';
    final people = provider.chatbotMemory.people
        .where((p) =>
            query.isEmpty ||
            p.name.toLowerCase().contains(query) ||
            p.relation.toLowerCase().contains(query) ||
            (p.details?.toLowerCase().contains(query) ?? false) ||
            (p.manualNotes?.toLowerCase().contains(query) ?? false))
        .map((p) => {
              'id': p.id,
              'name': p.name,
              'relation': p.relation,
              'age': p.manualAge,
              'gender': p.manualGender,
              'location': p.manualLocation,
              'notes': p.manualNotes,
            })
        .toList();

    return {'people': people};
  }

  dynamic _readPerson(Map<String, dynamic> args) {
    final name = args['name']?.toString().toLowerCase();
    final id = args['id']?.toString();

    final person = provider.chatbotMemory.people.firstWhere(
      (p) => (id != null && p.id == id) || (name != null && p.name.toLowerCase() == name),
      orElse: () => PersonInfo(id: '', name: '', relation: ''),
    );

    if (person.id.isEmpty) {
      return {'error': "Person not found."};
    }

    return person.toJson();
  }

  // --- Memory Space Tools for Character Personas ---

  dynamic _memoryAdd(String personaId, Map<String, dynamic> args) {
    final key = args['key']?.toString().trim() ?? 'note';
    final content = args['content']?.toString().trim() ?? '';
    final tags = (args['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    if (content.isEmpty) {
      return {'error': "Memory content cannot be empty."};
    }

    final item = NoraMemoryItem(
      id: Uuid().v4(),
      key: key,
      content: content,
      tags: tags,
    );

    provider.addPersonaMemoryItem(personaId, item);

    return {
      'status': 'stored',
      'key': key,
      'message': "Successfully added/updated '$key' in memory space.",
    };
  }

  dynamic _memoryRead(String personaId, Map<String, dynamic> args) {
    final key = args['key']?.toString().toLowerCase().trim();
    final id = args['id']?.toString().trim();

    final memories = provider.getPersonaMemories(personaId);
    final match = memories.firstWhere(
      (m) => (id != null && m.id == id) || (key != null && m.key.toLowerCase() == key),
      orElse: () => NoraMemoryItem(id: '', key: '', content: ''),
    );

    if (match.id.isEmpty) {
      return {'error': "Memory entry not found."};
    }

    return match.toJson();
  }

  dynamic _memoryFind(String personaId, Map<String, dynamic> args) {
    final query = args['query']?.toString().toLowerCase().trim() ?? '';
    final tag = args['tag']?.toString().toLowerCase().trim();

    final memories = provider.getPersonaMemories(personaId);
    final matches = memories.where((m) {
      if (tag != null && tag.isNotEmpty && !m.tags.any((t) => t.toLowerCase() == tag)) {
        return false;
      }
      if (query.isNotEmpty) {
        final combined = "${m.key} ${m.content} ${m.tags.join(' ')}".toLowerCase();
        return combined.contains(query);
      }
      return true;
    }).map((m) => m.toJson()).toList();

    return {'matches_count': matches.length, 'memories': matches};
  }

  dynamic _memoryDelete(String personaId, Map<String, dynamic> args) {
    final keyOrId = args['id']?.toString() ?? args['key']?.toString() ?? '';
    if (keyOrId.isEmpty) {
      return {'error': "Must provide 'key' or 'id' to delete."};
    }

    provider.deletePersonaMemoryItem(personaId, keyOrId);

    return {
      'status': 'deleted',
      'message': "Successfully deleted memory item '$keyOrId'.",
    };
  }

  dynamic _memoryList(String personaId, Map<String, dynamic> args) {
    final limit = (args['limit'] as num?)?.toInt() ?? 30;
    final memories = provider.getPersonaMemories(personaId).take(limit).map((m) => {
      'id': m.id,
      'key': m.key,
      'preview': m.content.length > 60 ? "${m.content.substring(0, 60)}..." : m.content,
      'tags': m.tags,
      'updated_at': m.updatedAt.toIso8601String(),
    }).toList();

    return {'total': memories.length, 'memories': memories};
  }

  dynamic _addTask(Map<String, dynamic> args) {
    final name = (args['name'] ?? args['task_name'] ?? args['title'])?.toString().trim();
    if (name == null || name.isEmpty) {
      return {'error': "Task name is required."};
    }

    final taskType = (args['task_type'] ?? args['taskType'])?.toString().toLowerCase() ?? 'sub';
    final description = (args['description'] ?? '').toString();
    final why = (args['why'] ?? '').toString();
    final what = (args['what'] ?? '').toString();
    final colorHex = (args['color_hex'] ?? args['colorHex'] ?? 'FF00F8F8').toString();
    final theme = (args['theme'] ?? 'General').toString();

    if (taskType == 'main') {
      provider.addMainTask(name: name, description: description, theme: theme, colorHex: colorHex);
      final created = provider.mainTasks.firstWhereOrNull((t) => t.name == name);
      return {
        'status': 'success',
        'task_type': 'main',
        'task_id': created?.id,
        'name': name,
      };
    }

    // Determine mainTaskId
    String? mainTaskId = (args['main_task_id'] ?? args['mainTaskId'])?.toString();
    final mainTaskName = (args['main_task_name'] ?? args['mainTaskName'])?.toString().trim();

    if (mainTaskId == null && mainTaskName != null && mainTaskName.isNotEmpty) {
      final match = provider.mainTasks.firstWhereOrNull(
        (t) => !t.isDeleted && t.name.toLowerCase() == mainTaskName.toLowerCase(),
      );
      mainTaskId = match?.id;
    }

    if (mainTaskId == null) {
      final active = provider.mainTasks.where((t) => !t.isDeleted).toList();
      if (active.isNotEmpty) {
        mainTaskId = active.first.id;
      } else {
        provider.addMainTask(name: 'General', description: 'Default category', theme: 'General', colorHex: colorHex);
        mainTaskId = provider.mainTasks.firstWhereOrNull((t) => !t.isDeleted)?.id;
      }
    }

    if (mainTaskId == null) {
      return {'error': 'Failed to resolve or create parent main task.'};
    }

    if (taskType == 'subsub') {
      final subtaskId = (args['subtask_id'] ?? args['subtaskId'])?.toString();
      if (subtaskId == null) {
        return {'error': 'subtask_id is required for checkpoint/subsubtask.'};
      }
      final assignedCpId = provider.addSubSubtask(mainTaskId, subtaskId, {
        'name': name,
        'completed': false,
      });
      return {
        'status': 'success',
        'task_type': 'subsub',
        'main_task_id': mainTaskId,
        'subtask_id': subtaskId,
        'checkpoint_id': assignedCpId,
        'compound_id': '$mainTaskId|$subtaskId|$assignedCpId',
        'name': name,
      };
    }

    // Default: subtask
    final assignedSubId = provider.addSubtask(mainTaskId, {
      'name': name,
      'description': description,
      'why': why,
      'what': what,
      'completed': false,
    });

    final compoundId = '$mainTaskId|$assignedSubId';
    return {
      'status': 'success',
      'task_type': 'sub',
      'main_task_id': mainTaskId,
      'subtask_id': assignedSubId,
      'compound_id': compoundId,
      'name': name,
    };
  }

  dynamic _addToPlan(Map<String, dynamic> args) {
    String? compoundId = (args['compound_id'] ?? args['compoundId'] ?? args['id'])?.toString();
    final name = (args['task_name'] ?? args['taskName'] ?? args['name'])?.toString().trim();
    final dateStr = (args['date'] ?? args['date_str'] ?? args['targetDate'])?.toString().trim() ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    final estVal = args['estimate_minutes'] ?? args['estimateMinutes'] ?? args['minutes'] ?? args['estimate'];
    int? estimateMinutes;
    if (estVal is num) {
      estimateMinutes = estVal.toInt();
    } else if (estVal is String) {
      estimateMinutes = int.tryParse(estVal);
    }

    if (compoundId == null && name != null && name.isNotEmpty) {
      final lower = name.toLowerCase();
      for (final m in provider.mainTasks.where((t) => !t.isDeleted)) {
        for (final s in m.subTasks.where((st) => !st.isDeleted)) {
          if (s.name.toLowerCase() == lower) {
            compoundId = "${m.id}|${s.id}";
            break;
          }
          for (final cp in s.subSubTasks.where((c) => c.isActive)) {
            if (cp.name.toLowerCase() == lower) {
              compoundId = "${m.id}|${s.id}|${cp.id}";
              break;
            }
          }
          if (compoundId != null) break;
        }
        if (compoundId != null) break;
      }

      // If not found, auto-create subtask
      if (compoundId == null) {
        var m = provider.mainTasks.firstWhereOrNull((t) => !t.isDeleted);
        if (m == null) {
          provider.addMainTask(name: 'General', description: 'Default category', theme: 'General', colorHex: 'FF00F8F8');
          m = provider.mainTasks.firstWhereOrNull((t) => !t.isDeleted);
        }
        if (m != null) {
          final assignedSubId = provider.addSubtask(m.id, {
            'name': name,
            'description': '',
            'why': '',
            'what': '',
            'completed': false,
          });
          compoundId = "${m.id}|$assignedSubId";
        }
      }
    }

    if (compoundId == null) {
      return {'error': 'Could not resolve task to add to plan.'};
    }

    provider.taskActions.addToDayPlan(compoundId, dateStr, estimateMinutes);
    return {
      'status': 'success',
      'compound_id': compoundId,
      'date': dateStr,
      'estimate_minutes': estimateMinutes,
    };
  }

  dynamic _checkTask(Map<String, dynamic> args) {
    String? taskId = (args['main_task_id'] ?? args['mainTaskId'] ?? args['taskId'])?.toString();
    String? subtaskId = (args['subtask_id'] ?? args['subtaskId'])?.toString();
    String? checkpointId = (args['checkpoint_id'] ?? args['checkpointId'] ?? args['subSubtaskId'])?.toString();
    final completed = args['completed'] as bool? ?? true;
    final compoundId = (args['compound_id'] ?? args['compoundId'])?.toString();
    final name = (args['task_name'] ?? args['taskName'] ?? args['name'])?.toString().trim();

    if (compoundId != null && compoundId.contains('|')) {
      final parts = compoundId.split('|');
      taskId = parts[0];
      if (parts.length > 1) subtaskId = parts[1];
      if (parts.length > 2) checkpointId = parts[2];
    } else if ((taskId == null || subtaskId == null) && name != null && name.isNotEmpty) {
      final lower = name.toLowerCase();
      for (final m in provider.mainTasks.where((t) => !t.isDeleted)) {
        for (final s in m.subTasks.where((st) => !st.isDeleted)) {
          if (s.name.toLowerCase() == lower) {
            taskId = m.id;
            subtaskId = s.id;
            break;
          }
          for (final cp in s.subSubTasks.where((c) => c.isActive)) {
            if (cp.name.toLowerCase() == lower) {
              taskId = m.id;
              subtaskId = s.id;
              checkpointId = cp.id;
              break;
            }
          }
          if (taskId != null) break;
        }
        if (taskId != null) break;
      }
    }

    if (taskId != null && subtaskId != null) {
      if (checkpointId != null) {
        if (completed) {
          provider.completeSubSubtask(taskId, subtaskId, checkpointId);
        } else {
          provider.uncompleteSubSubtask(taskId, subtaskId, checkpointId);
        }
      } else {
        if (completed) {
          provider.completeSubtask(taskId, subtaskId, fromSync: true);
        } else {
          provider.uncompleteSubtask(taskId, subtaskId, fromSync: true);
        }
      }
      return {'status': 'success', 'completed': completed};
    }

    return {'error': "Could not resolve task to mark completed."};
  }

  dynamic _removeFromPlan(Map<String, dynamic> args) {
    String? compoundId = (args['compound_id'] ?? args['compoundId'])?.toString();
    final name = (args['task_name'] ?? args['taskName'] ?? args['name'])?.toString().trim();
    final dateStr = (args['date'] ?? args['date_str'] ?? args['targetDate'])?.toString().trim() ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (compoundId == null && name != null && name.isNotEmpty) {
      final lower = name.toLowerCase();
      for (final m in provider.mainTasks.where((t) => !t.isDeleted)) {
        for (final s in m.subTasks.where((st) => !st.isDeleted)) {
          if (s.name.toLowerCase() == lower) {
            compoundId = "${m.id}|${s.id}";
            break;
          }
          for (final cp in s.subSubTasks.where((c) => c.isActive)) {
            if (cp.name.toLowerCase() == lower) {
              compoundId = "${m.id}|${s.id}|${cp.id}";
              break;
            }
          }
          if (compoundId != null) break;
        }
        if (compoundId != null) break;
      }
    }

    if (compoundId != null) {
      provider.taskActions.removeFromDayPlan(compoundId, dateStr);
      return {'status': 'success', 'removed': compoundId, 'date': dateStr};
    }
    return {'error': "Could not resolve task to remove from plan."};
  }
}
