import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:intl/intl.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/config/api_keys.dart';
import 'package:missions/src/services/secrets_service.dart';
import 'package:flutter/foundation.dart';
import 'package:missions/src/utils/json_utils.dart';

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

  // ---------------------------------------------------------------------------
  // Additional OpenAI-compatible providers (Groq, Cerebras, OpenRouter).
  //
  // These act as fallbacks after Gemini fails. Their shared keys come from the
  // Firestore secrets document via [SecretsService]; model lists come from
  // SharedPreferences (managed in Settings) with sensible defaults. See
  // [_generateWithProviderFallback] for the fallback ladder.
  // ---------------------------------------------------------------------------

  /// Flattens Gemini [genai.Part]s into a plain prompt string plus a list of
  /// image bytes, so the same request can be replayed against the
  /// OpenAI-compatible fallback providers.
  (String, List<Uint8List>?) _extractPromptAndImages(List<genai.Part> parts) {
    final buffer = StringBuffer();
    final List<Uint8List> images = [];
    for (final p in parts) {
      if (p is genai.TextPart) {
        buffer.writeln(p.text);
      } else if (p is genai.DataPart) {
        images.add(p.bytes);
      }
    }
    return (buffer.toString(), images.isNotEmpty ? images : null);
  }

  String _cleanJsonFences(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith("```")) {
      final lines = cleaned.split("\n");
      if (lines.first.startsWith("```")) lines.removeAt(0);
      if (lines.isNotEmpty && lines.last.startsWith("```")) lines.removeLast();
      cleaned = lines.join("\n").trim();
    }
    return cleaned;
  }

  /// Parses a NORA agent response into the `{messages, actions}` map, tolerating
  /// stray markdown code fences. Falls back to wrapping the raw text as a single
  /// message. Shared by the Gemini path and the provider fallback.
  Map<String, dynamic> _parseNoraResponse(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith("```")) {
      final lines = cleaned.split("\n");
      if (lines.first.startsWith("```")) lines.removeAt(0);
      if (lines.isNotEmpty && lines.last.startsWith("```")) lines.removeLast();
      cleaned = lines.join("\n").trim();
    }
    final decoded = JsonUtils.tryDecode(cleaned);
    if (decoded is Map<String, dynamic>) return decoded;
    return {
      "messages": [cleaned],
      "actions": []
    };
  }

  /// Parses a JSON array of chat messages into a `List<String>`. Shared by the
  /// Gemini path and the provider fallback.
  List<String> _parseMessageSequence(String raw) {
    final decoded = JsonUtils.tryDecode(raw);
    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList();
    }
    return ["system error: could not parse response sequence."];
  }

  Future<List<String>> _providerModels(String prefsKey, List<String> fallback) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(prefsKey) ?? [];
    return list.isNotEmpty ? list : fallback;
  }

  /// Single OpenAI-compatible chat-completions caller. Iterates [models] x
  /// [apiKeys] and returns the first non-empty completion. Throws when all
  /// combinations fail.
  Future<String> _callOpenAICompatible({
    required String providerLabel,
    required Uri url,
    required List<String> apiKeys,
    required List<String> models,
    required String prompt,
    Map<String, String> extraHeaders = const {},
    bool responseJson = false,
    List<Uint8List>? attachedImages,
    String? systemPrompt,
    Function(String)? onLog,
  }) async {
    if (apiKeys.isEmpty) {
      throw Exception('No $providerLabel API keys available.');
    }
    if (models.isEmpty) {
      throw Exception('No $providerLabel models configured.');
    }

    final List<Map<String, dynamic>> messages = [];
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt.trim()});
    }
    final List<Map<String, dynamic>> contentParts = [
      {'type': 'text', 'text': prompt}
    ];
    if (attachedImages != null) {
      for (final img in attachedImages) {
        contentParts.add({
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,${base64Encode(img)}'}
        });
      }
    }
    messages.add({
      'role': 'user',
      'content': contentParts.length == 1 ? prompt : contentParts,
    });

    Object? lastErr;
    for (final modelName in models) {
      for (final apiKey in apiKeys) {
        try {
          final Map<String, dynamic> body = {
            'model': modelName,
            'messages': messages,
          };
          if (responseJson) {
            body['response_format'] = {'type': 'json_object'};
          }
          final response = await http
              .post(
                url,
                headers: {
                  'Authorization': 'Bearer $apiKey',
                  'Content-Type': 'application/json',
                  ...extraHeaders,
                },
                body: jsonEncode(body),
              )
              .timeout(const Duration(minutes: 2));

          if (response.statusCode != 200) {
            throw Exception(
                '$providerLabel API error (${response.statusCode}): ${response.body}');
          }
          final jsonMap = jsonDecode(response.body);
          final String? text =
              jsonMap['choices']?[0]?['message']?['content'] as String?;
          if (text == null || text.trim().isEmpty) {
            throw Exception('Empty response from $providerLabel model $modelName');
          }
          return text;
        } catch (e) {
          lastErr = e;
          onLog?.call(
              "<span style=\"color:var(--fh-accent-orange);\">$providerLabel $modelName failed: ${e.toString()}</span>");
        }
      }
    }
    throw lastErr ?? Exception('$providerLabel: all models/keys failed.');
  }

  Future<String> _callGroq(String prompt,
          {bool responseJson = false,
          List<Uint8List>? attachedImages,
          String? systemPrompt,
          Function(String)? onLog}) async =>
      _callOpenAICompatible(
        providerLabel: 'Groq',
        url: Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        apiKeys: await SecretsService.instance.groqKeys(),
        models: await _providerModels('groq_model_primary_text_list',
            const ['llama-3.3-70b-versatile', 'groq/compound']),
        prompt: prompt,
        responseJson: responseJson,
        attachedImages: attachedImages,
        systemPrompt: systemPrompt,
        onLog: onLog,
      );

  Future<String> _callCerebras(String prompt,
          {bool responseJson = false,
          List<Uint8List>? attachedImages,
          String? systemPrompt,
          Function(String)? onLog}) async =>
      _callOpenAICompatible(
        providerLabel: 'Cerebras',
        url: Uri.parse('https://api.cerebras.ai/v1/chat/completions'),
        apiKeys: await SecretsService.instance.cerebrasKeys(),
        models: await _providerModels('cerebras_model_primary_text_list',
            const ['llama-3.3-70b', 'llama-3.1-70b']),
        prompt: prompt,
        responseJson: responseJson,
        attachedImages: attachedImages,
        systemPrompt: systemPrompt,
        onLog: onLog,
      );

  Future<String> _callOpenRouter(String prompt,
          {bool responseJson = false,
          List<Uint8List>? attachedImages,
          String? systemPrompt,
          Function(String)? onLog}) async =>
      _callOpenAICompatible(
        providerLabel: 'OpenRouter',
        url: Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        apiKeys: await SecretsService.instance.openrouterKeys(),
        models: await _providerModels('openrouter_model_primary_text_list',
            const ['meta-llama/llama-3.3-70b-instruct', 'google/gemini-2.5-pro']),
        prompt: prompt,
        responseJson: responseJson,
        attachedImages: attachedImages,
        systemPrompt: systemPrompt,
        extraHeaders: const {
          'HTTP-Referer': 'https://arcane.app',
          'X-Title': 'Arcane',
        },
        onLog: onLog,
      );

  /// Fallback ladder used when every Gemini model+key combination fails.
  /// Tries Groq -> Cerebras -> OpenRouter in order and returns the first raw
  /// text response. Throws when all providers fail.
  Future<String> _generateWithProviderFallback({
    required String prompt,
    bool responseJson = false,
    List<Uint8List>? attachedImages,
    String? systemPrompt,
    Function(String)? onLog,
  }) async {
    Object? lastErr;
    for (final call in <Future<String> Function()>[
      () => _callGroq(prompt,
          responseJson: responseJson,
          attachedImages: attachedImages,
          systemPrompt: systemPrompt,
          onLog: onLog),
      () => _callCerebras(prompt,
          responseJson: responseJson,
          attachedImages: attachedImages,
          systemPrompt: systemPrompt,
          onLog: onLog),
      () => _callOpenRouter(prompt,
          responseJson: responseJson,
          attachedImages: attachedImages,
          systemPrompt: systemPrompt,
          onLog: onLog),
    ]) {
      try {
        return await call();
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr ?? Exception('All fallback providers failed.');
  }

  Future<T> _executeWithModelAndKeyRotation<T>({
    required List<String> modelCandidates,
    required Future<T> Function(String apiKey, String modelName) requestFn,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
    String? fallbackPrompt,
    List<Uint8List>? fallbackImages,
    String? fallbackSystemPrompt,
    bool fallbackJson = false,
    T Function(String raw)? fallbackParse,
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
          onLog("Model $model succeeded with Key Index: $effectiveIndex");
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

    // Gemini exhausted. Fall back to the OpenAI-compatible provider ladder
    // (Groq -> Cerebras -> OpenRouter) when the caller supplied a raw prompt
    // and a parser to convert the string response into T.
    if (fallbackPrompt != null && fallbackParse != null) {
      onLog(
          "<span style=\"color:var(--fh-accent-orange);\">Gemini exhausted. Falling back to Groq/Cerebras/OpenRouter...</span>");
      final raw = await _generateWithProviderFallback(
        prompt: fallbackPrompt,
        responseJson: fallbackJson,
        attachedImages: fallbackImages,
        systemPrompt: fallbackSystemPrompt,
        onLog: onLog,
      );
      return fallbackParse(raw);
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
    final contentParts = parts ?? [genai.TextPart(prompt!)];
    final (fbPrompt, fbImages) = _extractPromptAndImages(contentParts);
    try {
      return await _executeWithModelAndKeyRotation(
        currentApiKeyIndex: currentApiKeyIndex,
        customApiKeys: customApiKeys,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog,
        modelCandidates: modelCandidates,
        fallbackPrompt: fbPrompt,
        fallbackImages: fbImages,
        fallbackJson: true,
        fallbackParse: (raw) => JsonUtils.tryDecode(_cleanJsonFences(raw)),
        requestFn: (apiKey, modelName) async {
          final model = genai.GenerativeModel(
            model: modelName,
            apiKey: apiKey,
            generationConfig: genai.GenerationConfig(responseMimeType: 'application/json'),
          );

          final response = await model.generateContent([genai.Content.multi(contentParts)]);

          String? rawResponseText = response.text;
          if (rawResponseText == null || rawResponseText.trim().isEmpty) {
            throw Exception("AI response was empty.");
          }

          return JsonUtils.tryDecode(_cleanJsonFences(rawResponseText));
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
        fallbackPrompt: prompt,
        fallbackJson: true,
        fallbackParse: _parseMessageSequence,
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

          return _parseMessageSequence(raw);
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
        fallbackPrompt: prompt,
        fallbackJson: true,
        fallbackParse: _parseNoraResponse,
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

          return _parseNoraResponse(raw);
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

  Future<List<String>> generateSopSteps({
    required String situation,
    required List<ReflectionLog> reflectionLogs,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
    var filteredLogs = reflectionLogs.where((l) => l.timestamp.isAfter(oneMonthAgo)).toList();
    if (filteredLogs.isEmpty && reflectionLogs.isNotEmpty) {
      filteredLogs = List<ReflectionLog>.from(reflectionLogs)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      filteredLogs = filteredLogs.take(20).toList();
    }

    final reflectionsContext = filteredLogs.isEmpty
        ? 'No reflection logs available.'
        : filteredLogs.map((l) {
            final dateStr = DateFormat('yyyy-MM-dd').format(l.timestamp);
            return '[$dateStr] Trigger: ${l.trigger} | Emotion: ${l.emotion} | Reason: ${l.reason} | Action Taken: ${l.action} | AI Feedback: ${l.aiFeedback}';
          }).join('\n');

    final prompt = """
You are an expert Standard Operational Procedure (SOP) architect and behavioral systems designer.
Your goal is to generate concrete, highly actionable, step-by-step operational instructions (SOP steps) for a user's specific situation, grounded in their historical reflection logs.

USER SITUATION:
"$situation"

USER'S RECENT REFLECTION LOGS (LAST MONTH):
$reflectionsContext

Instructions:
1. Analyze the situation and synthesize insights/lessons from the historical reflection logs.
2. Formulate 4 to 8 clear, sequential, imperative operational steps that the user must follow when this situation occurs.
3. Keep each step concise, practical, direct, and under 120 characters.
4. Do NOT include numbers or bullet prefixes (e.g. "1.", "Step 1:"). Plain step text only.

Return JSON strictly in the following format:
{"steps": ["First step description", "Second step description", "Third step description"]}
ENSURE VALID JSON. NO TRAILING COMMAS.
""";

    final result = await makeAICall(
      prompt: prompt,
      modelCandidates: modelCandidates,
      customApiKeys: customApiKeys,
      currentApiKeyIndex: currentApiKeyIndex,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
    );

    return ((result['steps'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> generateSchedulePrediction({
    required String sessionHistory, 
    required String currentTime,
    required String availableTasksContext, 
    required String reflectionLogsContext,
    required String uncompletedPlanContext,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    You are an intelligent schedule predictor. Based on the user's recent session history, reflection logs, and today's remaining uncompleted plan, predict a realistic schedule for the REST of today (starting from $currentTime).
    
    HISTORICAL SESSIONS (Last 14 days):
    $sessionHistory
    
    RECENT REFLECTION LOGS (Last 30 days):
    $reflectionLogsContext
    
    TODAY'S REMAINING UNCOMPLETED PLAN:
    $uncompletedPlanContext

    AVAILABLE ACTIVE TASKS & PROTOCOLS:
    $availableTasksContext
    
    INSTRUCTIONS:
    1. Analyze user habits, energy patterns, reflection logs, and remaining plan items.
    2. PRIORITIZE scheduling today's remaining uncompleted plan items during realistic available time slots today.
    3. Suggest 1-8 likely sessions for the remainder of today.
    4. Do not predict past midnight. Respect regular sleep time.
    5. CONFIDENTIALITY: Do not use specific names of real people.
    
    CRITICAL OUTPUT FORMATTING:
    - Return ONLY valid JSON.
    - Do NOT wrap in markdown code blocks (e.g. ```json ... ```).
    - Do NOT include comments or trailing commas.
    
    OUTPUT JSON ARRAY STRUCTURE:
    [
      {
        "taskName": "Exact Main Task Name from Available Tasks",
        "subTaskName": "Specific Activity / Subtask Name",
        "startOffsetMinutes": int (minutes from NOW to start session, e.g. 15 for 15 minutes from now),
        "durationMinutes": int (duration of session in minutes, e.g. 30)
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
    String? financeText,
    String? goalsText,
    String? previousQuotesContext,
  }) async {
    String systemStyle = "";
    if (writingStyleMap != null && writingStyleMap.isNotEmpty) {
      systemStyle = "\n\nAdhere to the following writing style map for your response. IMPORTANT: You must write in the absolute BEST version of this writing style, with all grammar, spelling, casing, capitalization, and punctuation corrected. Do NOT directly copy the user's typing style if it has typos, run-on sentences, lack of capitalization, or lazy texting shortcuts. Every sentence must use proper capitalization, standard punctuation, and perfect grammar while keeping the user's tone, vocabulary, and personality:\n$writingStyleMap\n";
    }
    final prompt = """
    Generate an end-of-day Tactical Briefing grounded in positive psychology, gratitude, and optimistic reinforcement.
    $systemStyle

    Current Logs (TODAY'S LOGS — FOR QUOTING AND TODAY'S ANALYSIS): ${jsonEncode(reflections)}
    Reflection History (BROADER WEEKLY CONTEXT — FOR CONTEXT ONLY, DO NOT QUOTE FROM THIS): $fullContext
    Previous Briefings (Context): ${jsonEncode(previousBriefings)}
    ${previousQuotesContext != null && previousQuotesContext.isNotEmpty ? 'Previously Used Quotes & Reflections (STRICT EXCLUSION LIST - DO NOT REPEAT ANY OF THESE):\n$previousQuotesContext' : ''}
    ${financeText != null && financeText.isNotEmpty ? 'Today Finance Context: $financeText' : ''}
    ${goalsText != null && goalsText.isNotEmpty ? 'Today Goals Context:\n$goalsText' : ''}
    ${customInstruction != null && customInstruction.isNotEmpty ? 'User Custom Instruction: $customInstruction' : ''}

    Apply the following principles - do NOT name them in your output, just use them:
    - Positive Psychology & Strengths-Based Reframing: focus on user strengths, achievements, and progress with an encouraging, optimistic reframe.
    - Emotional granularity (Susan David, "Emotional Agility"; Lisa Feldman Barrett): name specific authentic positive and grounding emotions.
    - Gratitude with specificity and brevity: short, punchy, concrete items rather than long sentences.
    - Financial awareness: provide encouraging, constructive, and positive tactical feedback on financial choices logged today.
    - QUOTING & UNIQUENESS MANDATE: All user quotes ("user_quote") MUST be taken EXCLUSIVELY from today's Current Logs (text written on the same day). NEVER quote text from Reflection History or previous days. Ensure that all quote reflections and AI insights are 100% unique, fresh, and never repeat past themes or phrased commentary.

    Tone: Warm, highly optimistic, deeply supportive, appreciative, and empowering. ALWAYS celebrate wins, highlight the user's strengths, and appreciate good efforts. NEVER give negative, critical, or unsolicited corrective advice. NEVER point out flaws or cognitive distortions in a negative way.

    Task:
    1. "summary" (max 100 words): An uplifting, highly optimistic read of today celebrating wins and progress with 1-2 granular emotion words and an empowering positive reframe.
    2. "quote_reflections": 2 to 4 items selecting the user's BEST, most positive, inspiring, or meaningful text/statements STRICTLY ONLY from today's Current Logs (same day text only), paired with warm AI appreciation and validation. Each item: "user_quote" (the exact or key excerpt of the user's good/positive text from today's Current Logs ONLY) and "ai_comment" (warm, appreciative, encouraging AI review/validation celebrating what the user wrote — DO NOT criticize, give negative advice, or point out flaws).
    3. "improvements": 1-3 specific capabilities the user is building or strengthening, expressed with optimism and pride.
    4. "grateful_people": EVERY person who earned appreciation today. "name", "relation", "reason", "express".
    5. "grateful_today": 5 to 8 SHORT, CONCISE gratitude items (2 to 6 words each, small sized text style) — e.g. "Energizing morning walk", "Quiet 7 hours sleep". Each with "text" and "icon_type" (people/nature/health/learning/work/home/food/social/growth/mind/moment/general).
    6. "savor_moment": single best moment of the day in 2-3 sensory sentences.
    7. "small_win": today's most meaningful concrete progress step.
    8. "tomorrow_intention": positive implementation intention "When [cue], I will [action]".
    9. "suggested_activities": 2-3 fresh, exciting things/actions/experiments the user can try based on today's logs. Each: "activity", "reason".
    10. "finance_briefing": summary of today's finance with "income", "expense", "net", and "ai_feedback" (1 short sentence of encouraging positive AI feedback).

    Output JSON ONLY:
    {
      "summary": "string",
      "quote_reflections": [ {"user_quote": "string", "ai_comment": "string"} ],
      "improvements": [ {"ability": "string", "insight": "string"} ],
      "grateful_people": [ {"name": "string", "relation": "string", "reason": "string", "express": "string"} ],
      "grateful_today": [ {"text": "string (2-6 words)", "icon_type": "string"} ],
      "savor_moment": "string",
      "small_win": "string",
      "tomorrow_intention": "string",
      "suggested_activities": [ {"activity": "string", "reason": "string"} ],
      "finance_briefing": {"income": "string", "expense": "string", "net": "string", "ai_feedback": "string"}
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
    String? weeklyBriefingContext,
    String? writingStyleMap,
    String? pastStoriesContext,
    String? pastQuotesContext,
  }) async {
    String systemStyle = "";
    if (writingStyleMap != null && writingStyleMap.isNotEmpty) {
      systemStyle = "\n\nAdhere to the following writing style map for your response. IMPORTANT: You must write in the absolute BEST version of this writing style, with all grammar, spelling, casing, capitalization, and punctuation corrected. Do NOT directly copy the user's typing style if it has typos, run-on sentences, lack of capitalization, or lazy texting shortcuts. Every sentence must use proper capitalization, standard punctuation, and perfect grammar while keeping the user's tone, vocabulary, and personality:\n$writingStyleMap\n";
    }
    final prompt = """
    Generate a comprehensive 7-Day Review Report grounded in GTD, Atomic Habits, positive psychology, and optimistic encouragement.
    $systemStyle

    Reflection Logs: $logsText
    Time Data: $timeStatsText
    Wellbeing Progress: $wellbeingStatsText
    ${financeText != null && financeText.isNotEmpty ? 'Finance: $financeText' : ''}
    ${agentProgressText != null && agentProgressText.isNotEmpty ? 'Agent Progress (Tasks): $agentProgressText' : ''}
    ${weeklyBriefingContext != null && weeklyBriefingContext.isNotEmpty ? 'Weekly Context: \n$weeklyBriefingContext' : ''}
    ${pastStoriesContext != null && pastStoriesContext.isNotEmpty ? 'Previously Featured Stories & Figures (STRICT EXCLUSION LIST - DO NOT REPEAT ANY OF THESE FIGURES OR THEMES):\n$pastStoriesContext' : ''}
    ${pastQuotesContext != null && pastQuotesContext.isNotEmpty ? 'Previously Used Quotes Context:\n$pastQuotesContext' : ''}

    Tone: Warm, highly optimistic, empowering, constructive, and deeply encouraging. Highlight growth, progress, and strengths. Celebrate every victory. NEVER give negative or critical feedback.

    Task:
    1. "summary": Uplifting, optimistic read of the week celebrating growth, wins, and progress.
    2. "wellbeing_analysis": Positive comparison of wellbeing progress compared to previous week.
    3. "gtd_get_current": 2-4 active or stalled projects/tasks with one specific Next Action.
    4. "gtd_get_creative": 1-2 new exciting ideas or Someday/Maybe items.
    5. "atomic_friction": 1-2 areas of friction and encouraging environmental/habit adjustments.
    6. "identity_votes": 1-2 ways actions voted for desired identity.
    7. "improved_abilities": 2-4 specific capabilities built, score 1-10.
    8. "grateful_people": EVERY person to appreciate. Categorize by standard DEFAULT CATEGORY: "Family & Partner", "Friends", "Professional & Mentors", or "Acquaintances & Others". Format: [{"name": "string", "category": "Family & Partner | Friends | Professional & Mentors | Acquaintances & Others", "relation": "string", "reason": "string"}].
    9. "gratitude_highlights": 5 specific concise gratitude highlights.
    10. "after_action": "intended", "actual", "lesson".
    11. "energy_map": "energizers", "drainers".
    12. "share_win": "win", "person", "how".
    13. "creative_story": A short (100-180 words) inspiring real story of a famous scientist, historical figure, writer, explorer, polymath, or artist whose struggles/journey mirrors what the user experienced this week, connecting their lesson directly to the user's journey.
        CRITICAL UNIQUENESS MANDATE: The historical figure MUST BE ENTIRELY UNIQUE and NEVER chosen from the exclusion list above. Draw from diverse world history, scientific breakthroughs, artistic milestones, and human resilience across centuries and cultures (e.g. Richard Feynman, Ada Lovelace, Hypatia, Alexander von Humboldt, Rosalind Franklin, Johannes Kepler, Hokusai, Alan Turing, Ibn Battuta, Rachel Carson, Leonardo da Vinci, Srinivasa Ramanujan, Mary Shelley, Michael Faraday, etc.). "title", "story", "takeaway".

    Output JSON ONLY:
    {
      "summary": "string",
      "wellbeing_analysis": "string",
      "gtd_get_current": [{"task": "string", "next_action": "string"}],
      "gtd_get_creative": [{"idea": "string", "reason": "string"}],
      "atomic_friction": [{"struggle": "string", "adjustment": "string"}],
      "identity_votes": [{"action": "string", "identity": "string"}],
      "improved_abilities": [{"name": "string", "reason": "string", "score": int}],
      "grateful_people": [{"name": "string", "category": "string", "relation": "string", "reason": "string"}],
      "gratitude_highlights": [{"text": "string", "icon_type": "string"}],
      "after_action": {"intended": "string", "actual": "string", "lesson": "string"},
      "energy_map": {"energizers": ["string"], "drainers": ["string"]},
      "share_win": {"win": "string", "person": "string", "how": "string"},
      "creative_story": {"title": "string", "story": "string", "takeaway": "string"}
    }
    ENSURE VALID JSON. NO TRAILING COMMAS.
    """;
    return await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
  }

  Future<Map<String, dynamic>> generateMonthlyReport({
    required String monthLabel,
    required String logsText,
    required String timeStatsText,
    required String wellbeingStatsText,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
    String? financeText,
    String? healthText,
    String? peopleContext,
    String? weeklyReportsContext,
    String? previousMonthlyContext,
    String? writingStyleMap,
    String? pastStoriesContext,
    String? pastQuotesContext,
  }) async {
    String systemStyle = "";
    if (writingStyleMap != null && writingStyleMap.isNotEmpty) {
      systemStyle = "\n\nAdhere to the following writing style map for your response. IMPORTANT: You must write in the absolute BEST version of this writing style, with all grammar, spelling, casing, capitalization, and punctuation corrected. Do NOT directly copy the user's typing style if it has typos, run-on sentences, lack of capitalization, or lazy texting shortcuts. Every sentence must use proper capitalization, standard punctuation, and perfect grammar while keeping the user's tone, vocabulary, and personality:\n$writingStyleMap\n";
    }
    final prompt = """
    Generate a MONTHLY BRIEFING for $monthLabel grounded in positive psychology and optimistic encouragement.
    $systemStyle

    Reflection Logs (last ~30 days): $logsText
    Time Data (last ~30 days): $timeStatsText
    Wellbeing Progress: $wellbeingStatsText
    ${financeText != null && financeText.isNotEmpty ? 'Finance: $financeText' : ''}
    ${healthText != null && healthText.isNotEmpty ? 'Health: $healthText' : ''}
    ${peopleContext != null && peopleContext.isNotEmpty ? 'Known People: $peopleContext' : ''}
    ${weeklyReportsContext != null && weeklyReportsContext.isNotEmpty ? 'Weekly Summaries:\n$weeklyReportsContext' : ''}
    ${previousMonthlyContext != null && previousMonthlyContext.isNotEmpty ? 'Previous Monthly Context:\n$previousMonthlyContext' : ''}
    ${pastStoriesContext != null && pastStoriesContext.isNotEmpty ? 'Previously Featured Stories & Figures (STRICT EXCLUSION LIST - DO NOT REPEAT ANY OF THESE FIGURES/THEMES):\n$pastStoriesContext' : ''}
    ${pastQuotesContext != null && pastQuotesContext.isNotEmpty ? 'Previously Used Quotes (STRICT EXCLUSION LIST):\n$pastQuotesContext' : ''}

    Tone: Uplifting, highly optimistic, empowering, and deeply appreciative. Celebrate all accomplishments, growth, and positive turning points. NEVER give negative or critical advice.

    Task:
    1. "narrative": Inspiring, optimistic story of the month highlighting growth and milestones (150-220 words).
    2. "quote_reflections": 3-5 items selecting the user's best, most positive, or inspiring statements from the month paired with warm AI appreciation and validation: `[ {"user_quote": "string", "ai_comment": "string"} ]` (DO NOT criticize, give negative advice, or point out flaws). Ensure quotes are distinct from past monthly reviews.
    3. "emotional_climate": "dominant_emotions", "trajectory", "patterns".
    4. "after_action_review": "intended", "actual", "gap_why", "adjustment".
    5. "progress_review": "area", "small_wins", "compound_effect".
    6. "identity_trajectory": Who the user became.
    7. "relationship_audit": EVERY person who mattered. "name", "trend", "action".
    8. "wellbeing_deltas": 2-4 movements in wellbeing.
    9. "life_domains": rate domains 1-10 with evidence.
    10. "best_possible_self": One-month-out portrait.
    11. "next_month_woop": 1-3 goals.
    12. "gratitude_reminiscence": exactly 5 moments.
    13. "letting_go": ONE commitment to drop.
    14. "creative_story": An inspiring real story of a scientist, historical thinker, explorer, or artist mirroring the user's month.
        CRITICAL UNIQUENESS MANDATE: The "creative_story" MUST feature a profound real historical figure and narrative that has NEVER appeared in any previous monthly or weekly briefing. Pick a novel, deeply inspiring figure and journey from world history. "title", "story", "takeaway".

    Output JSON ONLY:
    {
      "narrative": "string",
      "quote_reflections": [{"user_quote": "string", "ai_comment": "string"}],
      "emotional_climate": {"dominant_emotions": ["string"], "trajectory": "string", "patterns": [{"pattern": "string", "evidence": "string"}]},
      "after_action_review": [{"intended": "string", "actual": "string", "gap_why": "string", "adjustment": "string"}],
      "progress_review": [{"area": "string", "small_wins": "string", "compound_effect": "string"}],
      "identity_trajectory": "string",
      "relationship_audit": [{"name": "string", "trend": "string", "action": "string"}],
      "wellbeing_deltas": [{"area": "string", "direction": "string", "hypothesis": "string"}],
      "life_domains": [{"domain": "string", "rating": int, "evidence": "string"}],
      "best_possible_self": "string",
      "next_month_woop": [{"wish": "string", "outcome": "string", "obstacle": "string", "plan": "string"}],
      "gratitude_reminiscence": [{"text": "string", "icon_type": "string"}],
      "letting_go": "string",
      "creative_story": {"title": "string", "story": "string", "takeaway": "string"}
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
    String? knownPeopleText,
    String? goalsText,
    String? previousQuotesContext,
  }) async {
    String systemStyle = "";
    if (writingStyleMap != null && writingStyleMap.isNotEmpty) {
      systemStyle = "\n\nAdhere to the following writing style map for your response. IMPORTANT: You must write in the absolute BEST version of this writing style, with all grammar, spelling, casing, capitalization, and punctuation corrected. Do NOT directly copy the user's typing style if it has typos, run-on sentences, lack of capitalization, or lazy texting shortcuts. Every sentence must use proper capitalization, standard punctuation, and perfect grammar while keeping the user's tone, vocabulary, and personality:\n$writingStyleMap\n";
    }
    final prompt = """
    Generate a 'System Start-Up Sequence' (a morning briefing) grounded in positive psychology and optimistic encouragement.
    $systemStyle

    Context:
    Reflections (Last 7 days): $reflectionsList
    Sessions (Last 7 days): $sessionsList
    ${knownPeopleText != null && knownPeopleText.isNotEmpty ? 'Known Contacts/People: $knownPeopleText' : ''}
    ${goalsText != null && goalsText.isNotEmpty ? 'Goals Context:\n$goalsText' : ''}
    ${previousQuotesContext != null && previousQuotesContext.isNotEmpty ? 'Previously Used Quotes & Authors (STRICT EXCLUSION LIST - NEVER REPEAT ANY OF THESE QUOTES OR AUTHORS):\n$previousQuotesContext' : ''}

    Tone: Highly optimistic, energizing, empowering, deeply supportive, and appreciative. ALWAYS encourage the user and highlight potential. NEVER give negative, critical, or adversarial advice.

    Task:
    1. "forecast" (40-80 words): An optimistic, energizing morning forecast celebrating recent momentum and setting an inspiring tone for the day.
    2. "yesterday_quote": A prominent positive, inspiring, or representative good quote/phrase from yesterday's reflections.
    3. "ai_today_advice": Warm, appreciative, and optimistic AI encouragement for today inspired by that yesterday quote — celebrating what the user wrote and boosting their momentum for today (DO NOT give negative or critical advice).
    4. "motivational_quote": A famous, deeply inspiring quote from a scientist, philosopher, writer, polymath, inventor, or historical figure that has NEVER been featured in previous morning briefings.
       CRITICAL UNIQUENESS MANDATE: Draw from thousands of years of human history across world cultures, scientific pioneers, polymaths, and literature (e.g. Richard Feynman, Hypatia, Leonardo da Vinci, Ada Lovelace, Alexander von Humboldt, Rosalind Franklin, Lao Tzu, Marcus Aurelius, Carl Sagan, Buckminster Fuller, Mary Oliver, Jane Goodall, etc.). Every single day must deliver a brand-new, never-before-seen quote and author. Format: {"quote": "string", "author": "string"}.
    5. "suggested_contacts": Pick 2-3 specific people from Known Contacts that the user should reach out to or check in with today. Format: [{"name": "string", "relation": "string", "type": "RECONNECT|FOLLOW UP|APPRECIATION|STAY IN TOUCH", "reason": "string"}].
    6. "highlight": ONE sentence naming the single most leveraged task for today.
    7. "obstacle_plan": "obstacle" and "if_then".
    8. "anticipate": one concrete thing today worth genuinely looking forward to.
    9. "directives" (exactly 3): specific implementation intentions.

    Output JSON ONLY:
    {
      "forecast": "string",
      "yesterday_quote": "string",
      "ai_today_advice": "string",
      "motivational_quote": {"quote": "string", "author": "string"},
      "suggested_contacts": [{"name": "string", "relation": "string", "type": "string", "reason": "string"}],
      "highlight": "string",
      "obstacle_plan": {"obstacle": "string", "if_then": "string"},
      "anticipate": "string",
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
      fallbackPrompt: prompt,
      fallbackParse: (raw) => raw.trim(),
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