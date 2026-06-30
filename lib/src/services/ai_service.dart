import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:missions/src/config/api_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:missions/src/utils/json_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class AIService {

  static bool isLiveModel(String modelName) => modelName.toLowerCase().contains('live');

  /// Sends [prompt] over the Gemini Live API (WebSocket, TEXT modality) and
  /// returns the model's full text response. Uses the bidirectional streaming
  /// endpoint which has a separate quota and lower latency than the HTTP
  /// generateContent endpoint. Throws on socket error / empty response so the
  /// caller's rotation loop can fall back to a non-live model.
  Future<String> _liveTextCall(String apiKey, String modelName, String prompt) async {
    final uri = Uri.parse(
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$apiKey',
    );
    final channel = WebSocketChannel.connect(uri);
    final buffer = StringBuffer();
    final completer = Completer<String>();
    bool setupDone = false;

    await channel.ready;

    final sub = channel.stream.listen(
      (data) {
        try {
          // Server frames may arrive as text or binary (UTF-8 JSON).
          final String raw = data is String ? data : utf8.decode(data as List<int>);
          final Map<String, dynamic> msg = jsonDecode(raw) as Map<String, dynamic>;

          if (msg.containsKey('setupComplete')) {
            setupDone = true;
            channel.sink.add(jsonEncode({
              'clientContent': {
                'turns': [
                  {
                    'role': 'user',
                    'parts': [
                      {'text': prompt}
                    ]
                  }
                ],
                'turnComplete': true,
              }
            }));
            return;
          }

          final serverContent = msg['serverContent'] as Map<String, dynamic>?;
          if (serverContent != null) {
            final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>?;
            final parts = modelTurn?['parts'] as List<dynamic>?;
            if (parts != null) {
              for (final p in parts) {
                final t = (p as Map<String, dynamic>)['text'];
                if (t is String) buffer.write(t);
              }
            }
            final done = serverContent['turnComplete'] == true ||
                serverContent['generationComplete'] == true;
            if (done && !completer.isCompleted) {
              completer.complete(buffer.toString());
            }
          }
        } catch (_) {
          // Ignore malformed frames; rely on completion / error / timeout.
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e as Object);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(buffer.toString());
        }
      },
      cancelOnError: true,
    );

    // Open the session.
    channel.sink.add(jsonEncode({
      'setup': {
        'model': 'models/$modelName',
        'generationConfig': {
          'responseModalities': ['TEXT']
        }
      }
    }));

    String result;
    try {
      result = await completer.future.timeout(const Duration(seconds: 45));
    } finally {
      await sub.cancel();
      await channel.sink.close();
    }

    if (!setupDone) throw Exception('Live session setup never completed.');
    if (result.trim().isEmpty) throw Exception('Live AI response was empty.');
    return result;
  }

  Future<T> _executeWithModelAndKeyRotation<T>({
    required List<String> modelCandidates,
    required Future<T> Function(String apiKey, String modelName) requestFn,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final List<String> apiKeysToTry = <String>{
      ...geminiApiKeys,
      if (customApiKeys != null) ...customApiKeys
    }.where((k) => !k.contains('YOUR_GEMINI_API_KEY')).toList();

    if (apiKeysToTry.isEmpty) {
      onLog("No valid Gemini API keys found. Returning fallback data.");
      throw Exception("OFFLINE_MOCK_DATA");
    }

    for (final model in modelCandidates) {
      for (int i = 0; i < apiKeysToTry.length; i++) {
        int effectiveIndex = (currentApiKeyIndex + i) % apiKeysToTry.length;
        String effectiveKey = apiKeysToTry[effectiveIndex];

        try {
          if (kDebugMode) {
            onLog("Trying Model: $model with Key Index: $effectiveIndex");
          }
          final result = await requestFn(effectiveKey, model);
          onNewApiKeyIndex(effectiveIndex);
          return result;
        } catch (e) {
          if (e is FormatException && e.message.contains("JSON Decode Failed")) {
             onLog("<span style=\"color:var(--fh-accent-red);\">JSON ERROR: ${e.toString()}</span>");
             debugPrint("AI JSON PARSE ERROR:\n${e.message}");
          }
          onLog(
              "<span style=\"color:var(--fh-accent-orange);\">Model $model + Key $effectiveIndex failed: ${e.toString()}</span>");
        }
      }
    }
    throw Exception("All models and API keys failed. Please check your connection or settings.");
  }

  Future<Map<String, dynamic>> makeAICall({
    String? prompt, 
    List<genai.Part>? parts, 
    required List<String> modelCandidates,
    List<String>? customApiKeys,
    required int currentApiKeyIndex,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    try {
      return await _executeWithModelAndKeyRotation(
        currentApiKeyIndex: currentApiKeyIndex,
        customApiKeys: customApiKeys,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog,
        modelCandidates: modelCandidates,
        requestFn: (apiKey, modelName) async {
          final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
          
          final contentParts = parts ?? [genai.TextPart(prompt!)];
          final response = await model.generateContent([genai.Content.multi(contentParts)]);

          String? rawResponseText = response.text;
          if (rawResponseText == null || rawResponseText.trim().isEmpty) {
            throw Exception("AI response was empty.");
          }
          
          return JsonUtils.tryDecode(rawResponseText);
        },
      );
    } catch (e) {
      if (e.toString().contains("OFFLINE_MOCK_DATA")) {
        if (prompt != null && prompt.contains("System Start-Up Sequence")) {
          return { "forecast": "API KEY MISSING. Offline fallback mode active.", "directives": ["Add your Gemini API Key in Settings."] };
        }
        return {};
      }
      rethrow;
    }
  }

  Future<List<String>> queryNeuralArchive({
    required String query,
    required String logsContext,
    required int maxMessages,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
    String? writingStyleMap,
  }) async {
    String systemStyle = "";
    if (writingStyleMap != null && writingStyleMap.isNotEmpty) {
      systemStyle = "\n\nAdhere to the following writing style map for your response. IMPORTANT: You must write in the absolute BEST version of this writing style, with all grammar, spelling, casing, capitalization, and punctuation corrected. Do NOT directly copy the user's typing style if it has typos, run-on sentences, lack of capitalization, or lazy texting shortcuts. Every sentence must use proper capitalization, standard punctuation, and perfect grammar while keeping the user's tone, vocabulary, and personality:\n$writingStyleMap\n";
    }
    final prompt = """
    $logsContext
    $systemStyle
    
    USER: "$query"

    RULES:
    1. Answer based on the provided context if applicable.
    2. Write casually, but with proper grammar, punctuation, and capitalization. NO markdown formatting.
    3. You must output your thoughts as a sequence of short text messages (1-2 sentences max per message).
    4. STRICT LIMIT: Generate a MAXIMUM of $maxMessages messages in this sequence. Do not exceed this.
    5. Your output MUST be ONLY a valid JSON array of strings. No JSON wrapper object.
    Example output format: ["Yeah, I remember that.", "Tbh, you should just take a break.", "What do you think?"]
    """;

    try {
      return await _executeWithModelAndKeyRotation(
        currentApiKeyIndex: currentApiKeyIndex,
        customApiKeys: customApiKeys,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog,
        modelCandidates: modelCandidates,
        requestFn: (apiKey, modelName) async {
          final String? raw;
          if (isLiveModel(modelName)) {
            raw = await _liveTextCall(apiKey, modelName, prompt);
          } else {
            final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
            final response = await model.generateContent([genai.Content.text(prompt)]);
            raw = response.text;
          }
          if (raw == null) throw Exception("Empty AI response");

          final decoded = JsonUtils.tryDecode(raw);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
          return ["system error: could not parse response sequence."];
        },
      );
    } catch(e) {
      if (e.toString().contains("OFFLINE_MOCK_DATA")) return ["offline mock response: connect api key."];
      rethrow;
    }
  }

  Future<Map<String, dynamic>> queryNoraAgent({
    required String query,
    required String logsContext,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
$logsContext

USER QUERY: "$query"

RULES:
1. You are NORA, an agent assistant. You must address the user's query and optionally perform actions (edits/additions/retrievals) on their tasks, reflections, people info, gratitude/assets, progress points, or custom database paths.
2. Your response MUST be a single, valid JSON object containing:
   - "messages": a JSON array of strings (minimum 1, maximum 4). These are short, casual, lower-case, lazy-texting-style messages (use abbreviations like 'yk', 'tbh', 'idk', no markdown) that you speak to the user in chat.
   - "actions": a JSON array of action objects. If no action is requested or needed, this must be an empty array [].
3. The supported action object schemas in "actions" are:
   - Check/Uncheck task:
     {"type": "check_task", "taskId": "main-task-id", "subtaskId": "subtask-id", "subSubtaskId": "subsubtask-id (optional)", "completed": true/false}
   - Add task:
     {"type": "add_task", "taskType": "main"|"sub"|"subsub", "name": "task name", "description": "task description (optional)", "mainTaskId": "main-task-id (if sub/subsub)", "subtaskId": "subtask-id (if subsub)", "why": "why (optional)", "what": "what (optional)", "theme": "theme (optional)", "colorHex": "colorHex (optional)"}
   - Add data point to progress graph:
     {"type": "add_progress_point", "mainTaskId": "...", "subTaskId": "...", "progress": 0.0 to 1.0, "spentSeconds": integer}
   - Edit/Add person info:
     {"type": "edit_person", "name": "person name", "relation": "relation (optional)", "details": "details (optional)", "age": integer (optional), "gender": "gender (optional)", "notes": "notes (optional)"}
   - Edit/Add reflection log:
     {"type": "edit_reflection", "id": "reflection-id (or 'new')", "trigger": "...", "emotion": "...", "reason": "...", "action": "..."}
   - Add a new custom ability/skill to Nora:
     {"type": "add_nora_skill", "name": "skill name", "description": "what it does", "instructions": "rules/instructions for Nora on when and how to perform this skill"}
   - Arbitrary/Custom database edit (e.g. changing dynamic values or keys based on new skills/abilities):
     {"type": "custom_db_edit", "path": "dot-separated-path (e.g., 'settings.adaptWritingStyle' or 'mainTasks.0.name')", "value": any_value}

Examples of valid JSON responses:
{
  "messages": ["on it, checked that task for you", "anything else?"],
  "actions": [
    {"type": "check_task", "taskId": "t1", "subtaskId": "st1", "completed": true}
  ]
}
OR
{
  "messages": ["sure! added a skill to your chatbot memory", "now i can double all task names if you ask me to."],
  "actions": [
    {"type": "add_nora_skill", "name": "double_names", "description": "doubles all main task names", "instructions": "when asked to double names, output custom_db_edit action for each mainTask path like mainTasks.i.name"}
  ]
}
OR
{
  "messages": ["hey, looking at june 13th reflection:", "you felt happy due to completion", "i can change the trigger if you want"],
  "actions": []
}

Output ONLY the JSON object. Do not include markdown code block syntax (like ```json).
""";

    try {
      return await _executeWithModelAndKeyRotation(
        currentApiKeyIndex: currentApiKeyIndex,
        customApiKeys: customApiKeys,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog,
        modelCandidates: modelCandidates,
        requestFn: (apiKey, modelName) async {
          final String? raw;
          if (isLiveModel(modelName)) {
            raw = await _liveTextCall(apiKey, modelName, prompt);
          } else {
            final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
            final response = await model.generateContent([genai.Content.text(prompt)]);
            raw = response.text;
          }
          if (raw == null) throw Exception("Empty AI response");

          // Strip markdown block markers if generated by mistake
          String cleaned = raw.trim();
          if (cleaned.startsWith("```")) {
            final lines = cleaned.split("\n");
            if (lines.first.startsWith("```")) lines.removeAt(0);
            if (lines.isNotEmpty && lines.last.startsWith("```")) lines.removeLast();
            cleaned = lines.join("\n").trim();
          }

          final decoded = JsonUtils.tryDecode(cleaned);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
          // Fallback if not a map
          return {
            "messages": [cleaned],
            "actions": []
          };
        },
      );
    } catch(e) {
      if (e.toString().contains("OFFLINE_MOCK_DATA")) {
        return {
          "messages": ["offline mock response: connect api key."],
          "actions": []
        };
      }
      rethrow;
    }
  }

  Future<List<String>> autoAssignAssetsToTask({
    required String taskContext,
    required String assetsList,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Analyze the following Task context and select the most appropriate IDs from the provided Asset List that are required or helpful to complete this task.
    
    TASK CONTEXT:
    $taskContext
    
    ASSET LIST (Format: ID | Name | Type | Why | What):
    $assetsList
    
    Task:
    Match the task requirements with the asset list. Select the IDs of the assets that fit.
    
    Output JSON ONLY with an array of IDs:
    {
      "asset_ids": ["id_1", "id_2"]
    }
    ENSURE VALID JSON. NO TRAILING COMMAS.
    """;

    final result = await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);

    return (result['asset_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];
  }

  Future<Map<String, dynamic>> generateActionPlanSteps({
    required String taskName,
    required String why,
    required String userPrompt,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Create a tactical action plan (How) and expected outcome (What) for the following objective:
    
    OBJECTIVE: $taskName
    STRATEGIC INTENT (WHY): $why
    USER SPECIFIC REQUEST: $userPrompt
    
    Task:
    1. Break down the execution into concrete, actionable steps ("How"). Keep them concise. Incorporate user request.
    2. You can create nested sub-steps of any depth (any-level nested tasks) under any step if it requires more detailed execution.
    3. Define the expected result/reward ("What") upon completion.
    
    Output JSON ONLY:
    {
      "steps":[
        {
          "name": "Step description",
          "steps": [
            {
              "name": "Sub-step description",
              "steps": []
            }
          ]
        }
      ],
      "what": "Description of the result or reward"
    }
    ENSURE VALID JSON. NO TRAILING COMMAS.
    """;

    return await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);
  }

  Future<List<String>> generateStepsFromDescription({
    required String taskName,
    required String description,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Generate concrete, actionable sub-step names for a parent task based on a short user description.

    PARENT TASK: $taskName
    USER DESCRIPTION: $description

    Rules:
    1. Return between 1 and 12 step names. Honor any count implied by the user.
    2. Each name must be short (under 60 chars), imperative, and self-contained.
    3. Do NOT prefix with numbering ("1.", "Step 1:"). The name itself only.
    4. Preserve any explicit numbering the user asked for (e.g. "Round 1", "Round 2").

    Output JSON ONLY:
    {"steps": ["First step", "Second step"]}
    ENSURE VALID JSON. NO TRAILING COMMAS.
    """;

    final result = await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);

    return ((result['steps'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> generateSchedulePrediction({
    required String sessionHistory, 
    required String currentTime,
    required String availableTasksContext, 
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Based on the user's session history for the last 14 days, predict the schedule for the REST of today (starting from $currentTime).
    
    HISTORY:
    $sessionHistory
    
    AVAILABLE TASKS (Map prediction to these if possible):
    $availableTasksContext
    
    INSTRUCTIONS:
    1. Analyze patterns (time of day, duration, sequence).
    2. Suggest 1-10 likely sessions for the remainder of the day.
    3. Do not predict past midnight. Also regular sleep time, (based on daily end time of each session history)
    4. CONFIDENTIALITY: Do not use specific names of real people.
    
    CRITICAL OUTPUT FORMATTING:
    - Return ONLY valid JSON.
    - Do NOT wrap in markdown code blocks (e.g. ```json ... ```).
    - Do NOT include comments or trailing commas (e.g. `[{"a":1},]` is invalid).
    
    OUTPUT JSON ARRAY STRUCTURE:[
      {
        "taskName": "Exact Name from Available Tasks or New Name",
        "subTaskName": "Specific Activity",
        "startOffsetMinutes": int (minutes from Now to start),
        "durationMinutes": int
      }
    ]
    """;

    try {
      final result = await _executeWithModelAndKeyRotation(
        currentApiKeyIndex: currentApiKeyIndex,
        customApiKeys: customApiKeys,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog,
        modelCandidates: modelCandidates,
        requestFn: (apiKey, modelName) async {
          final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
          final response = await model.generateContent([genai.Content.text(prompt)]);
          String? raw = response.text;
          if (raw == null) throw Exception("Empty AI response");
          return JsonUtils.tryDecode(raw);
        },
      );

      if (result is List) {
        return result.map((e) => e as Map<String, dynamic>).toList();
      }
      return[];
    } catch(e) {
      if (e.toString().contains("OFFLINE_MOCK_DATA")) return [];
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> generateSubstepsForStep({
    required String parentStepTitle,
    required String parentStepDescription,
    required List<String> existingSubsteps,
    required String userPrompt,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = "Generate substeps JSON for Task '$parentStepTitle'. Existing: $existingSubsteps. Request: $userPrompt. Output: {steps: [{title, description}]}. CONFIDENTIALITY: Do not include specific names of real people. ENSURE VALID JSON. NO TRAILING COMMAS.";
    final result = await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
    return (result['steps'] as List?)?.map((s) => s as Map<String, dynamic>).toList() ??[];
  }

  Future<List<Map<String, dynamic>>> generateAISubquests({
    required List<String> modelCandidates,
    required String mainTaskName,
    required String mainTaskDescription,
    String? mainTaskTheme,
    required String generationMode,
    required String userInput,
    required int numSubquests,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = "Generate $numSubquests subquests for '$mainTaskName'. JSON: {newSubquests: [{name, isCountable, targetCount, subSubTasksData: []}]}. CONFIDENTIALITY: Do not include specific names of real people. ENSURE VALID JSON. NO TRAILING COMMAS.";
    final result = await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
    return (result['newSubquests'] as List?)?.map((sq) => sq as Map<String, dynamic>).toList() ??[];
  }

  Future<List<Map<String, dynamic>>> generateCheckpointsForSubtask({
    required String subtaskName,
    required String parentTaskName,
    required List<String> existingCheckpoints,
    required String userPrompt,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = "Generate checkpoints JSON for subtask '$subtaskName'. Request: $userPrompt. Output: {checkpoints: [{name}]}. CONFIDENTIALITY: Do not include specific names of real people. ENSURE VALID JSON. NO TRAILING COMMAS.";
    final result = await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
    return (result['checkpoints'] as List?)?.map((c) => c as Map<String, dynamic>).toList() ??[];
  }

  Future<Map<String, dynamic>> evaluateReflection({
    required String trigger,
    required String emotion,
    required String reason,
    required String action,
    required List<String> modelCandidates,
    String? recentContext,
    List<String>? customApiKeys,
    String? systemInstruction,
    String? writingStyleMap,
  }) async {
    final defaultInstruction = "Be empathetic, also dont make it too long, just like a reaction of a therapist";
    final instruction = systemInstruction != null && systemInstruction.isNotEmpty ? systemInstruction : defaultInstruction;

    String systemStyle = "";
    if (writingStyleMap != null && writingStyleMap.isNotEmpty) {
      systemStyle = "\n\nAdhere to the following writing style map for your response. IMPORTANT: You must write in the absolute BEST version of this writing style, with all grammar, spelling, casing, capitalization, and punctuation corrected. Do NOT directly copy the user's typing style if it has typos, run-on sentences, lack of capitalization, or lazy texting shortcuts. Every sentence must use proper capitalization, standard punctuation, and perfect grammar while keeping the user's tone, vocabulary, and personality:\n$writingStyleMap\n";
    }

    final prompt = """
    Analyze this reflection log.
    $systemStyle
    Situation: $trigger
    Feeling: $emotion
    Reason: $reason
    Action Planned: $action

    Recent Context (Last 7 Days):
    ${recentContext ?? 'No recent context available.'}

    1. Provide constructive feedback. ($instruction)
    2. Focus on present actionability. Use recent context to understand patterns but keep feedback focused on THIS specific log.
    3. Score XP for each Well-Being area as a float 0.0 to 1.0 using ONLY clear evidence in this log:
       - Positivity (0.0–1.0): Score ONLY if log shows moments of joy, gratitude, humor, awe, love, or contentment. No evidence = 0.0. Explicit positive emotion = 0.8–1.0.
       - Resilience (0.0–1.0): Score ONLY if log shows bouncing back from setback, tolerating distress, reframing a negative event, or regulating strong emotions. Mere acknowledgment of difficulty = 0.0.
       - Satisfaction (0.0–1.0): Score ONLY if log shows subjective sense of overall life going well or a meaningful accomplishment. Mundane tasks = 0.0.
       - Vitality (0.0–1.0): Score ONLY if log references physical energy, exercise, sleep quality, or bodily health positively.
       - Env. Mastery (0.0–1.0): Score ONLY if log shows user successfully shaped their environment: organized something, solved a logistical problem, or created a productive space.
       - Relationships (0.0–1.0): Score ONLY if log shows feeling loved, supported, or valued by a specific person — or a meaningful positive interaction.
       - Self-Acceptance (0.0–1.0): Score ONLY if log shows self-compassion, honest self-recognition without harsh judgment, or accepting a limitation gracefully.
       - Mastery (0.0–1.0): Score ONLY if log shows completing a challenging task, learning a hard concept, or demonstrating a skill under difficulty.
       - Autonomy (0.0–1.0): Score ONLY if log shows user making a self-determined choice, resisting social pressure, or acting according to their own values.
       - Growth (0.0–1.0): Score ONLY if log shows intentional development: learning something new, seeking feedback, or practicing a skill deliberately.
       - Engagement (0.0–1.0): Score ONLY if log shows flow state, absorption in a task, or genuine enthusiasm for an activity.
       - Meaning (0.0–1.0): Score ONLY if log shows connection to purpose, contribution to something larger, or acting in alignment with deep values.
    Use 0.0 when the evidence is absent or ambiguous. Partial evidence = 0.1–0.4. Clear evidence = 0.5–0.7. Exceptionally strong evidence = 0.8–1.0.

    Output JSON: {
      "feedback": "string",
      "xp_allocation": {
        "Positivity": float,
        "Resilience": float,
        "Satisfaction": float,
        "Vitality": float,
        "Env. Mastery": float,
        "Relationships": float,
        "Self-Acceptance": float,
        "Mastery": float,
        "Autonomy": float,
        "Growth": float,
        "Engagement": float,
        "Meaning": float
      }
    }
    ENSURE VALID JSON. NO TRAILING COMMAS.
    """;
    
    return await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: 0,
        onNewApiKeyIndex: (_) {},
        onLog: (_) {});
  }

  Future<List<Map<String, dynamic>>> evaluateBatchReflections({
    required List<Map<String, dynamic>> logsPayload,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Analyze the following array of reflection logs.
    For each log, score the user's well-being evidence across 12 areas as a float 0.0 to 1.0.

    Scoring rules (apply PER LOG — do NOT average across logs):
    - Positivity: joy, gratitude, humor, awe, love, contentment. 0.0 if absent.
    - Resilience: bouncing back, tolerating distress, reframing, emotion regulation. 0.0 if mere acknowledgment of difficulty.
    - Satisfaction: subjective sense of overall life going well or meaningful accomplishment. 0.0 for routine tasks.
    - Vitality: physical energy, exercise, good sleep, bodily health referenced positively.
    - Env. Mastery: successfully shaped environment, solved logistics, created productive space.
    - Relationships: feeling loved/supported/valued by a specific person; meaningful positive interaction.
    - Self-Acceptance: self-compassion, honest self-recognition without harsh judgment.
    - Mastery: completed a challenging task, learned hard concept, demonstrated skill under difficulty.
    - Autonomy: self-determined choice, resisting pressure, acting by own values.
    - Growth: deliberate learning, seeking feedback, practicing a skill intentionally.
    - Engagement: flow state, absorption, genuine enthusiasm for an activity.
    - Meaning: connection to purpose, contribution to something larger, acting by deep values.
    Absent or ambiguous evidence = 0.0. Partial = 0.1–0.4. Clear = 0.5–0.7. Exceptionally strong = 0.8–1.0.

    Logs to evaluate:
    ${jsonEncode(logsPayload)}

    Output EXACTLY valid JSON:
    {
      "updates":[
        {
          "log_id": "id_string_from_input",
          "xp_allocation": {
            "Positivity": float,
            "Resilience": float,
            "Satisfaction": float,
            "Vitality": float,
            "Env. Mastery": float,
            "Relationships": float,
            "Self-Acceptance": float,
            "Mastery": float,
            "Autonomy": float,
            "Growth": float,
            "Engagement": float,
            "Meaning": float
          }
        }
      ]
    }
    ENSURE VALID JSON. NO TRAILING COMMAS.
    """;

    final result = await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);
        
    return (result['updates'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ??[];
  }

  Future<Map<String, dynamic>> generateDailySummary({
    required List<Map<String, String>> reflections,
    required List<String> previousBriefings,
    required String fullContext,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
    String? customInstruction,
    String? writingStyleMap,
  }) async {
    String systemStyle = "";
    if (writingStyleMap != null && writingStyleMap.isNotEmpty) {
      systemStyle = "\n\nAdhere to the following writing style map for your response. IMPORTANT: You must write in the absolute BEST version of this writing style, with all grammar, spelling, casing, capitalization, and punctuation corrected. Do NOT directly copy the user's typing style if it has typos, run-on sentences, lack of capitalization, or lazy texting shortcuts. Every sentence must use proper capitalization, standard punctuation, and perfect grammar while keeping the user's tone, vocabulary, and personality:\n$writingStyleMap\n";
    }
    final prompt = """
    Generate an end-of-day Tactical Briefing grounded in evidence-based psychology.
    $systemStyle

    Current Logs: ${jsonEncode(reflections)}
    Reflection History (Context): $fullContext
    Previous Briefings (Context): ${jsonEncode(previousBriefings)}

    Apply the following frameworks - do NOT name them in your output, just use them:
    - Cognitive Behavioral Therapy (Beck; Burns, "Feeling Good"): when reflections show distorted thinking, name the distortion in the user's situation (all-or-nothing, mind-reading, catastrophizing, "should" statements, emotional reasoning, personalization, mental filter, overgeneralization). Offer a balanced thought - not a positive one.
    - Emotional granularity (Susan David, "Emotional Agility"; Lisa Feldman Barrett, "How Emotions Are Made"): name specific emotions ("resentful", "deflated", "anxious about X"), not generic "bad" or "stressed".
    - Self-compassion (Kristin Neff, "Self-Compassion"): when self-criticism appears, apply common humanity without dismissing the issue.
    - Deliberate practice (Ericsson, "Peak"): treat improvements as concrete capabilities the user is building, specific enough to act on.
    - Stoic dichotomy of control (Epictetus; Pigliucci, "How to Be a Stoic"): when the user is upset about external events, distinguish what was vs was not in their control.
    - Gratitude with specificity (Emmons and McCullough): name specific people and concrete reasons; avoid generic thankfulness.

    Tone: An honest, psychologically literate friend. Not a therapist, not a cheerleader. NEVER force a silver lining onto a hard event. Acknowledge difficulty in plain language. Insight is more useful than comfort. The user is a capable adult, not a patient.
    ${customInstruction != null && customInstruction.isNotEmpty ? '\nUser Instruction: ' + customInstruction + '\n' : ''}
    Task:
    1. "summary" (max 120 words): An honest read of today. Use 1-2 granular emotion words drawn from the logs. If a cognitive distortion is visible, name it in the user's own situation and offer a balanced reframe (balanced is not the same as positive). If the day was hard, say so plainly. Close with one observation about what was in vs not in their control today.
    2. "improvements": 1-3 specific capabilities the user is building or could build (e.g. "tolerating uncertainty without seeking reassurance", not vague traits like "patience"). Each "insight" must be specific enough to act on tomorrow.
    3. "grateful_people": specific people mentioned (use names). "reason" must reference a concrete thing they did or said.
    4. "grateful_today": exactly 10 specific things to be grateful for today. Draw from the logs — people, moments, resources, abilities, circumstances. Each must be concrete and specific (not "health" but "the energy to finish the task despite fatigue"). Each has an "icon_type" (choose one: people, nature, health, learning, work, home, food, social, growth, mind, moment, general).

    Output JSON: {
      "summary": "string (max 120 words)",
      "improvements": [ {"ability": "string", "insight": "string"} ],
      "grateful_people": [ {"name": "string", "relation": "string", "reason": "string"} ],
      "grateful_today": [ {"text": "string", "icon_type": "string"} ]
    }
    ENSURE VALID JSON. NO TRAILING COMMAS. grateful_today must have exactly 10 items.
    """;
    
    return await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);
  }

  Future<Map<String, dynamic>> generateWeeklyReport({
    required String logsText,
    required String timeStatsText,
    required String wellbeingStatsText,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
    String? financeText,
    String? agentProgressText,
    String? writingStyleMap,
  }) async {
    String systemStyle = "";
    if (writingStyleMap != null && writingStyleMap.isNotEmpty) {
      systemStyle = "\n\nAdhere to the following writing style map for your response. IMPORTANT: You must write in the absolute BEST version of this writing style, with all grammar, spelling, casing, capitalization, and punctuation corrected. Do NOT directly copy the user's typing style if it has typos, run-on sentences, lack of capitalization, or lazy texting shortcuts. Every sentence must use proper capitalization, standard punctuation, and perfect grammar while keeping the user's tone, vocabulary, and personality:\n$writingStyleMap\n";
    }
    final prompt = """
    Generate a comprehensive 7-Day Review Report grounded in "Getting Things Done" (GTD) and "Atomic Habits" principles, along with evidence-based psychology.
    $systemStyle

    Reflection Logs: $logsText
    Time Data: $timeStatsText
    Wellbeing Progress: $wellbeingStatsText
    ${financeText != null && financeText.isNotEmpty ? 'Finance: $financeText' : ''}
    ${agentProgressText != null && agentProgressText.isNotEmpty ? 'Agent Progress (Tasks): $agentProgressText' : ''}

    Task:
    1. "summary": Honest read of the week. Name 1-2 specific emotional themes. If the week was hard, say so plainly. Close with one actionable insight.
    2. "wellbeing_analysis": Compare wellbeing to previous week. Name specific areas of growth or decline with evidence from logs.
    3. "gtd_get_current": (GTD principle) Analyze the Agent Progress (Tasks) or logs. Identify 2-4 active or stalled projects/tasks and recommend ONE highly specific, immediate "Next Action" for each to prevent stalling.
    4. "gtd_get_creative": (GTD principle) Based on the user's logs, suggest 1-2 new ideas, experiments, or "Someday/Maybe" items they might want to explore.
    5. "atomic_friction": (Atomic Habits principle) Identify 1-2 areas where the user struggled or faced friction this week. Suggest ONE small, actionable environmental design or habit adjustment to make it easier next week.
    6. "identity_votes": (Atomic Habits principle) Highlight 1-2 ways the user's actions this week successfully "voted" for the type of person they want to become (their desired identity).
    7. "improved_abilities": 2-4 specific capabilities the user demonstrated or built this week. Score 1-10.
    8. "grateful_people": People mentioned the user should appreciate. Use real names. Concrete reasons.
    9. "gratitude_highlights": 5 specific things from this week worth being grateful for (not generic). Each with an icon_type (people/nature/health/learning/work/home/food/social/growth/mind/moment/general).

    Output JSON:
    {
      "summary": "string",
      "wellbeing_analysis": "string",
      "gtd_get_current": [{"task": "string", "next_action": "string"}],
      "gtd_get_creative": [{"idea": "string", "reason": "string"}],
      "atomic_friction": [{"struggle": "string", "adjustment": "string"}],
      "identity_votes": [{"action": "string", "identity": "string"}],
      "improved_abilities": [{"name": "string", "reason": "string", "score": int}],
      "grateful_people": [{"name": "string", "reason": "string"}],
      "gratitude_highlights": [{"text": "string", "icon_type": "string"}]
    }
    ENSURE VALID JSON. NO TRAILING COMMAS.
    """;
    return await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
  }

  Future<List<String>> fetchAvailableModels({String? customApiKey}) async {
    final apiKey = customApiKey ?? (geminiApiKeys.isNotEmpty ? geminiApiKeys.first : null);
    
    if (apiKey == null || apiKey.startsWith('YOUR_GEMINI')) {
      throw Exception("No valid API Key found to fetch models.");
    }

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['models'] != null && data['models'] is List) {
        final models = (data['models'] as List).map((m) {
          final methods = List<String>.from(m['supportedGenerationMethods'] ??[]);
          if (methods.contains('generateContent')) {
            return (m['name'] as String).replaceFirst('models/', '');
          }
          return null;
        }).whereType<String>().toList();
        return models;
      }
      return[];
    } else {
      throw Exception("Failed to fetch models: ${response.statusCode} ${response.body}");
    }
  }

  Future<Map<String, dynamic>> generateStartDayReport({
    required String reflectionsList,
    required String sessionsList,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
    String? writingStyleMap,
  }) async {
    String systemStyle = "";
    if (writingStyleMap != null && writingStyleMap.isNotEmpty) {
      systemStyle = "\n\nAdhere to the following writing style map for your response. IMPORTANT: You must write in the absolute BEST version of this writing style, with all grammar, spelling, casing, capitalization, and punctuation corrected. Do NOT directly copy the user's typing style if it has typos, run-on sentences, lack of capitalization, or lazy texting shortcuts. Every sentence must use proper capitalization, standard punctuation, and perfect grammar while keeping the user's tone, vocabulary, and personality:\n$writingStyleMap\n";
    }
    final prompt = """
    Generate a 'System Start-Up Sequence' (a morning briefing) grounded in evidence-based psychology.
    $systemStyle

    Context:
    Reflections (Last 7 days): $reflectionsList
    Sessions (Last 7 days): $sessionsList

    Apply the following frameworks - do NOT name them in your output, just use them:
    - Behavioral activation (Martell; Burns, "Feeling Good"): action precedes motivation. When momentum is low, prescribe a small concrete behavior, not a feeling-shift.
    - Implementation intentions (Gollwitzer): the format "When [specific cue or time], I will [specific observable action]" raises follow-through dramatically. Use it for every directive.
    - Mental contrasting / WOOP (Gabriele Oettingen, "Rethinking Positive Thinking"): pair the desired outcome with the most likely obstacle, then plan around it. Positive fantasy alone reduces follow-through.
    - Identity-based habits (James Clear, "Atomic Habits"): frame at least one action as a vote for the kind of person the user is becoming.
    - Self-Determination Theory (Deci and Ryan; Pink, "Drive"): when relevant, connect a task to autonomy, competence, or relatedness rather than external pressure.
    - Anti-perfectionism (Stoeber; Burns): include at least one minimum-viable version of a goal so a bad day still produces a win.

    Tone: Warm, honest, specific. NEVER force optimism or "find the good" in recent bad events - acknowledge difficulty plainly, then pivot to one concrete next action. The user is a capable adult, not a patient.

    Task:
    1. "forecast" (60-100 words): Read the user's recent momentum honestly. Name one obstacle visible in the data (mental contrasting). If the last few days have been hard, say so directly, then prescribe one small behavioral start that breaks inertia today. Do not reframe a bad week as good; pivot to action.
    2. "directives" (exactly 3): each must be a specific implementation intention in the form "When [specific cue or time], I will [specific observable action]." Avoid vague verbs like "focus", "be productive", "stay positive". At least one directive should be a minimum-viable version (anti-perfectionism) so the bar is reachable even on a bad day. At least one directive should connect to the user's identity or values when context allows.

    Output JSON ONLY:
    {
      "forecast": "string",
      "directives": ["string", "string", "string"]
    }
    ENSURE VALID JSON. NO TRAILING COMMAS.
    """;

    return await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);
  }

  Future<List<Map<String, dynamic>>> extractPeopleFromReflections({
    required String logsText,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Analyze the following reflection logs and extract a list of specific people mentioned by the user with name. 
    For each person, infer their relationship to the user (e.g., Friend, Boss, Partner, Colleague).
    Also, extract the short sentence or snippet from the logs where the person was mentioned (context).
    Create a list of upto 50 people
    
    Logs:
    $logsText
    
    Output JSON ONLY:
    {
      "people":[
        {
          "name": "string",
          "relation": "string",
          "context": "string (the sentence/snippet where they were mentioned)"
        }
      ]
    }
    """;

    final result = await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);

    return (result['people'] as List?)?.map((p) => p as Map<String, dynamic>).toList() ?? [];
  }

  Future<List<Map<String, dynamic>>> extractAssetsFromReflections({
    required String logsText,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Analyze the following reflection logs and extract a list of specific assets (resources, skills, objects, routines) the user relies on or is grateful for.
    Create a comprehensive list based purely on the logs.
    
    Logs:
    $logsText
    
    Output JSON ONLY:
    {
      "assets":[
        {
          "name": "string",
          "type": "skill|person|object|resource",
          "why": "string (Strategic value or why it is important)",
          "what": "string (Expected yield or what it does)"
        }
      ]
    }
    """;

    final result = await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);

    return (result['assets'] as List?)?.map((p) => p as Map<String, dynamic>).toList() ??[];
  }

  Future<List<Map<String, dynamic>>> extractFoodInfo({
    required String prompt,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final aiPrompt = """
    Analyze the following food description and estimate the nutritional value per serving.
    If multiple distinct items are mentioned, separate them.
    
    Description: $prompt
    
    Output JSON ONLY:
    {
      "items":[
        {
          "name": "string (Capitalized)",
          "calories": int,
          "protein": double (grams),
          "carbs": double (grams),
          "fat": double (grams)
        }
      ]
    }
    ENSURE VALID JSON. NO TRAILING COMMAS.
    """;
    
    final result = await makeAICall(
        prompt: aiPrompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);

    return (result['items'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ??[];
  }

  Future<Map<String, dynamic>> getMealInsights({
    required String mealName,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Provide a detailed but concise nutritional breakdown and health benefits of the meal: '$mealName'.
    
    Output JSON ONLY:
    {
      "description": "Short description of the meal and its general profile",
      "benefits": ["Benefit 1", "Benefit 2"],
      "warnings": ["Warning 1 (e.g. high sodium, allergens)"]
    }
    ENSURE VALID JSON. NO TRAILING COMMAS.
    """;

    return await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);
  }

  Future<Map<String, dynamic>> generatePersonDetails({
    required String personName,
    required String logsText,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Analyze the reflection logs focusing specifically on interactions or feelings involving '$personName'.
    Provide a psychological profile, interaction history summary, and communication tips for the user dealing with this person.
    
    Logs:
    $logsText
    
    Output JSON ONLY with exactly this structure (no markdown formatting, no trailing commas):
    {
      "title": "A short alias/title for them (e.g. 'The Realist' or 'The Mentor')",
      "level": int (1-100 based on relationship depth),
      "xp": int (total arbitrary xp based on significance, e.g. 2650),
      "role": "Their inferred role (e.g. Student, Colleague)",
      "status": "Current relationship status (e.g. Calibration Phase, Active)",
      "psychological_profile": "A solid paragraph describing their traits and dynamics with the user...",
      "interaction_history":[
        {"highlight": "Event Name/Theme:", "text": "Description of the event or pattern."}
      ],
      "communication_tips":[
        {"highlight": "Tip Name:", "text": "Description of the tip."}
      ]
    }
    """;

    return await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);
  }

  Future<Map<String, dynamic>> runQuickTherapy({
    required String reason,
    required String feeling,
    required String action,
    required String logsText,
    required String peopleContext,
    required bool requestComms,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final commsDirective = requestComms 
        ? "2. Review the 'Known People' list and suggest ONE person the user should talk to about this. If no one fits, return null. If a person is suggested, provide a brief 'conversation map' (3-4 steps) on how to approach the conversation."
        : "2. Do NOT suggest any person to contact, and return null for suggested_person and an empty list for conversation_map.";

    final prompt = """
    User needs immediate psychological assistance.
    Current Situation / Reason: $reason
    Current Feeling: $feeling
    Planned Action: $action
    
    Past Context (Reflections): $logsText
    Known People: $peopleContext
    
    Task:
    1. Provide a concise, empathetic, and tactical action plan for right now.
    $commsDirective
    
    Output JSON ONLY:
    {
      "action_plan": "string",
      "suggested_person": "string or null",
      "conversation_map": ["step 1", "step 2"]
    }
    """;

    return await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);
  }

  Future<Map<String, dynamic>> simulateEvent({
    required String situation,
    required String logsText,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    The user wants to simulate a future situation based on their past behavioral and psychological patterns.
    
    Proposed Situation: $situation
    
    Past Context (Reflections): $logsText
    
    Task:
    Write a highly plausible scenario note (2-3 paragraphs) of what might happen, how the user might feel, and potential pitfalls based on their history. Keep it realistic but constructive.
    
    Output JSON ONLY:
    {
      "simulation": "string"
    }
    """;

    return await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);
  }

  /// Generates a raw text response (not JSON) from the AI.
  Future<String> makeRawTextAICall({
    required String prompt,
    required List<String> modelCandidates,
    List<String>? customApiKeys,
    required int currentApiKeyIndex,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    return await _executeWithModelAndKeyRotation(
      currentApiKeyIndex: currentApiKeyIndex,
      customApiKeys: customApiKeys,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
      modelCandidates: modelCandidates,
      requestFn: (apiKey, modelName) async {
        final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([genai.Content.text(prompt)]);
        final text = response.text;
        if (text == null || text.trim().isEmpty) throw Exception("AI response was empty.");
        return text.trim();
      },
    );
  }

  Future<List<Map<String, dynamic>>> extractPeopleFromReflectionsWithLabels({
    required String logsText,
    required List<Map<String, String>> existingLabels,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Analyze the following reflection logs and extract a list of specific people mentioned by the user with name.
    For each person, infer their relationship to the user (e.g., Friend, Boss, Partner, Colleague).
    Also, extract the short sentence or snippet from the logs where the person was mentioned (context).
    
    Here is a list of already identified people in the user's database:
    ${jsonEncode(existingLabels)}

    Your goal is to match newly mentioned people to this list of existing people if they are the same person (even if they are referred to by a nickname or first name).
    If they match, output their matched existing name in "matched_existing_name".
    If they do not match, leave "matched_existing_name" as null.

    Logs:
    $logsText
    
    Output JSON ONLY:
    {
      "people":[
        {
          "name": "string (extracted name)",
          "relation": "string (inferred relation, e.g. Friend, Boss, Trainer)",
          "context": "string (the snippet where they were mentioned)",
          "matched_existing_name": "string (or null, matching existing name if same person)"
        }
      ]
    }
    """;

    final result = await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);

    return (result['people'] as List?)?.map((p) => Map<String, dynamic>.from(p as Map)).toList() ?? [];
  }
}