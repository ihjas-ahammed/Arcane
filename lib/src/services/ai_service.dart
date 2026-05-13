import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:missions/src/config/api_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:missions/src/utils/json_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class AIService {
  
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
  }) async {
    final prompt = """
    $logsContext
    
    USER: "$query"

    RULES:
    1. Answer based on the provided context if applicable.
    2. Write casually, lower case, lazy texting style, use abbreviations like 'yk', 'tbh', 'idk'. NO markdown formatting.
    3. You must output your thoughts as a sequence of short text messages (1-2 sentences max per message).
    4. STRICT LIMIT: Generate a MAXIMUM of $maxMessages messages in this sequence. Do not exceed this.
    5. Your output MUST be ONLY a valid JSON array of strings. No JSON wrapper object.
    Example output format: ["yeah i remember that", "tbh you should just take a break", "what do you think?"]
    """;

    try {
      return await _executeWithModelAndKeyRotation(
        currentApiKeyIndex: currentApiKeyIndex,
        customApiKeys: customApiKeys,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog,
        modelCandidates: modelCandidates,
        requestFn: (apiKey, modelName) async {
          final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
          final response = await model.generateContent([genai.Content.text(prompt)]);
          final raw = response.text;
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
    1. Break down the execution into 3-6 concrete, actionable steps ("How"). Keep them concise. Incorporate user request.
    2. Define the expected result/reward ("What") upon completion.
    
    Output JSON ONLY:
    {
      "steps":[
        {"name": "Step description"}
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
  }) async {
    final defaultInstruction = "Be empathetic, also dont make it too long, just like a reaction of a therapist";
    final instruction = systemInstruction != null && systemInstruction.isNotEmpty ? systemInstruction : defaultInstruction;
    
    final prompt = """
    Analyze this reflection log.
    Situation: $trigger
    Feeling: $emotion
    Reason: $reason
    Action Planned: $action
    
    Recent Context (Last 7 Days):
    ${recentContext ?? 'No recent context available.'}
    
    1. Provide constructive feedback. ($instruction)
    2. Adopt an optimistic perspective (e.g., finding the silver lining or growth opportunity in bad situations). Focus on present actionability. Use recent context to understand patterns, but keep your feedback focused on THIS specific log.
    3. Allocate XP (0-50) to the relevant Sources of Well-Being (Positivity, Resilience, Satisfaction, Vitality, Env. Mastery, Relationships, Self-Acceptance, Mastery, Autonomy, Growth, Engagement, Meaning).

    Output JSON: {
      "feedback": "string", 
      "xp_allocation": {
        "Positivity": int,
        "Resilience": int,
        "Satisfaction": int,
        "Vitality": int,
        "Env. Mastery": int,
        "Relationships": int,
        "Self-Acceptance": int,
        "Mastery": int,
        "Autonomy": int,
        "Growth": int,
        "Engagement": int,
        "Meaning": int
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
    For each log, evaluate the user's progress across these 12 Sources of Well-Being:
    1. Positivity 2. Resilience 3. Satisfaction 4. Vitality 5. Env. Mastery 6. Relationships 
    7. Self-Acceptance 8. Mastery 9. Autonomy 10. Growth 11. Engagement 12. Meaning

    Award XP (0 to 50) for each category based on evidence in the specific log. If no evidence, award 0.

    Logs to evaluate:
    ${jsonEncode(logsPayload)}

    Output EXACTLY valid JSON matching this structure:
    {
      "updates":[
        {
          "log_id": "id_string_from_input",
          "xp_allocation": {
            "Positivity": int,
            "Resilience": int,
            "Satisfaction": int,
            "Vitality": int,
            "Env. Mastery": int,
            "Relationships": int,
            "Self-Acceptance": int,
            "Mastery": int,
            "Autonomy": int,
            "Growth": int,
            "Engagement": int,
            "Meaning": int
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
  }) async {
    final prompt = """
    Generate a Tactical Briefing based on today's reflections.
    Current Logs: ${jsonEncode(reflections)}
    Entire Reflection History (Context): $fullContext
    Previous Briefings (Context): ${jsonEncode(previousBriefings)}
    
    Tone: Empathetic, psychologically wise, therapist.
    ${customInstruction != null && customInstruction.isNotEmpty ? '\nUser Instruction: ' + customInstruction + '\n' : ''}
    Task:
    1. Create a concise summary. Adopt an inherently optimistic perspectiveâ€”if something bad happened, actively help find the good or the lesson in it. Focus on the present.
    2. Identify specific ability improvements or growth by comparing with previous context.
    3. Extract people to be grateful for based on today's logs (You MAY use their real names).
    4. Extract assets (resources, skills, objects) to be grateful for based on today's logs.
    
    Output JSON: {
      "summary": "string (max 120 words)",
      "improvements": [ {"ability": "string", "insight": "string"} ],
      "grateful_people": [ {"name": "string", "relation": "string", "reason": "string"} ],
      "grateful_assets":[ {"name": "string", "type": "skill|person|object|resource", "why": "string (Strategic value)", "what": "string (Expected yield)"} ]
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
  }) async {
    final prompt = """
    Task:
    1. Analyze logs and time stats for a Weekly Report. Focus EQUALLY on the good things achieved and specific improvements needed. Adopt a highly optimistic perspective, reframing failures into valuable lessons and focusing on present potential.
    2. Compare the user's wellbeing progress to last week. Highlight areas of major growth or decline.
    3. Explicitly list out people mentioned that the user should be grateful for, and tell them why. (You may use real names).
    4. Output JSON: 
    { 
      "summary": "string", 
      "wellbeing_analysis": "string",
      "improved_abilities":[ {"name": "string", "reason": "string", "score": int} ], 
      "time_insight": "string",
      "grateful_people": [ {"name": "string", "reason": "string"} ]
    } 
    Logs: $logsText. 
    Time: $timeStatsText. 
    Wellbeing Progress: $wellbeingStatsText.
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
  }) async {
    final prompt = """
    Generate a 'System Start-Up Sequence' for the user based on their recent history.
    Context:
    Reflections (Last 7 days): $reflectionsList
    Sessions (Last 7 days): $sessionsList
    
    Tone: A supportive, insightful human friend having a morning coffee with the user. Friendly, warm, but highly practical and focused on their growth.
    
    Task:
    1. Analyze the user's momentum.
    2. Provide a 'Forecast' message (a friendly morning greeting + specific advice on how they can be better today). Look at things optimisticallyâ€”help them find the good in recent bad events. Focus on the present day actionability.
    3. Suggest 3 specific 'Tactical Directives' (short tasks) for today.
    
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
    Create a list of upto 50 people
    
    Logs:
    $logsText
    
    Output JSON ONLY:
    {
      "people":[
        {
          "name": "string",
          "relation": "string"
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

    return (result['people'] as List?)?.map((p) => p as Map<String, dynamic>).toList() ??[];
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
}