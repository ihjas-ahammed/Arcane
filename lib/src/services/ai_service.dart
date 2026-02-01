import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:arcane/src/config/api_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:arcane/src/models/chatbot_models.dart';

class AIService {
  // Helper to clean markdown from JSON response
  String _cleanJsonString(String raw) {
    String jsonString = raw.trim();
    int jsonStart = jsonString.indexOf('{');
    int jsonEnd = jsonString.lastIndexOf('}');

    if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
      jsonString = jsonString.substring(jsonStart, jsonEnd + 1);
    }

    if (jsonString.startsWith("```json")) {
      jsonString = jsonString.replaceAll("```json", "").replaceAll("```", "");
    } else if (jsonString.startsWith("```")) {
      jsonString = jsonString.replaceAll("```", "");
    }

    return jsonString.trim();
  }

  Future<T> _executeWithModelAndKeyRotation<T>({
    required List<String> modelCandidates,
    required Future<T> Function(String apiKey, String modelName) requestFn,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final List<String> apiKeysToTry = [
      ...geminiApiKeys,
      if (customApiKeys != null) ...customApiKeys
    ].toSet().toList();

    if (apiKeysToTry.isEmpty) {
      throw Exception("No valid Gemini API keys found.");
    }

    for (final model in modelCandidates) {
      for (int i = 0; i < apiKeysToTry.length; i++) {
        int effectiveIndex = (currentApiKeyIndex + i) % apiKeysToTry.length;
        String effectiveKey = apiKeysToTry[effectiveIndex];

        if (effectiveKey.startsWith('YOUR_GEMINI_API_KEY')) continue;

        try {
          if (kDebugMode) {
            onLog("Trying Model: $model with Key Index: $effectiveIndex");
          }
          final result = await requestFn(effectiveKey, model);
          onNewApiKeyIndex(effectiveIndex);
          return result;
        } catch (e) {
          onLog(
              "<span style=\"color:var(--fh-accent-orange);\">Model $model + Key $effectiveIndex failed: ${e.toString()}</span>");
        }
      }
    }
    throw Exception(
        "All models and API keys failed. Please check your connection or settings.");
  }

  Future<Map<String, dynamic>> makeAICall({
    required String prompt,
    required List<String> modelCandidates,
    List<String>? customApiKeys,
    required int currentApiKeyIndex,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
    List<Uint8List>? images,
  }) async {
    return await _executeWithModelAndKeyRotation(
      currentApiKeyIndex: currentApiKeyIndex,
      customApiKeys: customApiKeys,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
      modelCandidates: modelCandidates,
      requestFn: (apiKey, modelName) async {
        final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
        
        genai.GenerateContentResponse response;
        if (images != null && images.isNotEmpty) {
          final parts = <genai.Part>[
            genai.TextPart(prompt),
            ...images.map((bytes) => genai.DataPart('image/jpeg', bytes))
          ];
          response = await model.generateContent([genai.Content.multi(parts)]);
        } else {
          response = await model.generateContent([genai.Content.text(prompt)]);
        }

        String? rawResponseText = response.text;
        if (rawResponseText == null || rawResponseText.trim().isEmpty) {
          throw Exception("AI response was empty.");
        }
        try {
          String jsonString = _cleanJsonString(rawResponseText);
          return jsonDecode(jsonString);
        } catch (e) {
          if (kDebugMode) print("JSON Parse Error. Raw: $rawResponseText");
          throw Exception("Failed to parse JSON from AI response.");
        }
      },
    );
  }

  // --- UPDATED TIME SYNC LOGIC ---
  Future<List<Map<String, dynamic>>> generateTimeSyncSchedule({
    required String userPrompt,
    required String fullJsonContext, 
    required String currentTime,
    required String date,
    required String location,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    String? customSystemPrompt,
    String? userTimezone, 
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    You are the 'Arcane Timekeeper', an advanced AI scheduling system.
    
    SYSTEM PARAMETERS:
    - Current Time: $currentTime
    - Date: $date
    - Location: $location
    - User Timezone: ${userTimezone ?? 'Unspecified'}
    ${customSystemPrompt != null ? "- User Override: $customSystemPrompt" : ""}
    
    DATA DUMP (JSON):
    $fullJsonContext
    
    TASK:
    Generate a 24-hour schedule starting strictly from $currentTime forward.
    
    CRITICAL INTELLIGENCE LOGIC:
    1. **Circadian Rhythm**: Assume standard human sleep cycle (e.g., 23:00 - 07:00) unless data proves otherwise. Do NOT schedule high-focus tasks during typical sleep hours unless explicitly requested. If it's late night (e.g., 12 AM), schedule SLEEP immediately.
    2. **Realism**: Do not stack tasks unreasonably. Include gaps.
    3. **Sleep Analysis**: Scan the 'sessions' in the JSON data. Identify long periods of inactivity.
    4. **Formatting**: Titles must be SHORT (< 5 words).
    
    USER REQUEST: "$userPrompt"
    
    OUTPUT FORMAT (JSON ONLY):
    {
      "blocks": [
        {
          "offset_minutes": int (minutes from NOW),
          "duration_minutes": int,
          "title": "string (short)",
          "description": "string (empathetic)",
          "type": "focus" | "routine" | "rest" | "leisure"
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
        
    return (result['blocks'] as List?)?.map((b) => b as Map<String, dynamic>).toList() ?? [];
  }

  Future<Map<String, dynamic>> generateProjectFromPrompt({
    required List<String> modelCandidates,
    required String userPrompt,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
    List<Uint8List>? images,
  }) async {
    final prompt = "Generate project JSON for: $userPrompt. Structure: {title, description, steps: [{title, description, substeps: []}]}. Analyze any attached images for context (charts, plans, diagrams).";
    
    return await makeAICall(
      prompt: prompt, 
      modelCandidates: modelCandidates, 
      customApiKeys: customApiKeys, 
      currentApiKeyIndex: currentApiKeyIndex, 
      onNewApiKeyIndex: onNewApiKeyIndex, 
      onLog: onLog,
      images: images
    );
  }

  // --- UPDATED START DAY REPORT ---
  Future<Map<String, dynamic>> generateStartDayReport({
    required String reflectionsList,
    required String sessionsList,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    String? customSystemPrompt,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Generate a 'System Start-Up Sequence' (Operative Forecast).
    ${customSystemPrompt != null ? "USER OVERRIDE: $customSystemPrompt" : ""}
    
    CONTEXT:
    Reflections (Last 7 days): $reflectionsList
    Sessions (Last 7 days): $sessionsList
    
    Directives:
    1. Analyze momentum.
    2. Forecast: Provide a futuristic yet empathetic prediction (max 2 sentences).
    3. Metrics: 3 key abstract stats (0-100) like 'Willpower', 'Clarity'.
    4. Directives: 3 short, punchy tactical tasks for today.
    
    Output JSON ONLY:
    {
      "forecast": "string",
      "metrics": [ {"label": "string", "value": int, "color_hex": "string"} ],
      "directives": ["string", "string", "string"]
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

  // --- Legacy Methods (Kept for compatibility) ---
  Future<String> queryNeuralArchive({
    required String query,
    required String logsContext,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Neural Archive Query.
    Logs: $logsContext
    User: "$query"
    
    Answer based strictly on logs. No markdown.
    """;

    return await _executeWithModelAndKeyRotation(
      currentApiKeyIndex: currentApiKeyIndex,
      customApiKeys: customApiKeys,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
      modelCandidates: modelCandidates,
      requestFn: (apiKey, modelName) async {
        final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([genai.Content.text(prompt)]);
        return response.text ?? "No data.";
      },
    );
  }

  Future<List<Map<String, dynamic>>> generateStepsForProject({
    required String projectTitle,
    required String projectDescription,
    required List<String> existingSteps,
    required String userPrompt,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = "Generate steps JSON for Project '$projectTitle'. Existing: $existingSteps. Request: $userPrompt. Output: {steps: [{title, description}]}";
    final result = await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
    return (result['steps'] as List?)?.map((s) => s as Map<String, dynamic>).toList() ?? [];
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
    final prompt = "Generate substeps JSON for Task '$parentStepTitle'. Existing: $existingSubsteps. Request: $userPrompt. Output: {steps: [{title, description}]}";
    final result = await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
    return (result['steps'] as List?)?.map((s) => s as Map<String, dynamic>).toList() ?? [];
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
    final prompt = "Generate $numSubquests subquests for '$mainTaskName'. JSON: {newSubquests: [{name, isCountable, targetCount, subSubTasksData: []}]}";
    final result = await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
    return (result['newSubquests'] as List?)?.map((sq) => sq as Map<String, dynamic>).toList() ?? [];
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
    final prompt = "Generate checkpoints JSON for subtask '$subtaskName'. Request: $userPrompt. Output: {checkpoints: [{name}]}";
    final result = await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
    return (result['checkpoints'] as List?)?.map((c) => c as Map<String, dynamic>).toList() ?? [];
  }

  Future<Map<String, dynamic>> evaluateReflection({
    required String trigger,
    required String emotion,
    required String reason,
    required List<String> modelCandidates,
    required List<Map<String, dynamic>> userValues, 
    List<Map<String, String>>? dailyReflections,
    List<String>? customApiKeys,
    String? systemInstruction,
  }) async {
    final prompt = """
    Analyze this reflection log.
    Context Values: ${jsonEncode(userValues)}
    Trigger: $trigger
    Emotion: $emotion
    Reason: $reason
    
    1. Feedback.
    2. XP (0-50).
    3. Value updates.
    
    Output JSON: {
      "feedback": "string", 
      "xp_allocation": {"Wisdom": int, ...},
      "value_updates": [] 
    }
    """;
    
    return await makeAICall(
        prompt: prompt,
        modelCandidates: modelCandidates,
        customApiKeys: customApiKeys,
        currentApiKeyIndex: 0,
        onNewApiKeyIndex: (_) {},
        onLog: (_) {});
  }

  Future<Map<String, dynamic>> generateDailySummary({
    required List<Map<String, String>> reflections,
    required List<String> previousBriefings, 
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = "Generate Tactical Briefing. Output JSON: { \"summary\": \"string\", \"improvements\": [{\"ability\": \"string\", \"insight\": \"string\"}] }";
    return await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
  }

  Future<Map<String, dynamic>> generateWeeklyReport({
    required String logsText,
    required String timeStatsText,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = "Weekly Report. Output JSON: { \"summary\": \"string\", \"improved_abilities\": [], \"time_insight\": \"string\" }.";
    return await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
  }

  Future<String> getChatbotResponse({
    required List<String> modelCandidates,
    required ChatbotMemory memory,
    required String userMessage,
    required String dataContext,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    String? systemInstruction,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = "Chatbot response. Context: $dataContext.";
    return await _executeWithModelAndKeyRotation(currentApiKeyIndex: currentApiKeyIndex, customApiKeys: customApiKeys, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog, modelCandidates: modelCandidates, requestFn: (k, m) async {
        final model = genai.GenerativeModel(model: m, apiKey: k);
        final resp = await model.generateContent([genai.Content.text(prompt)]);
        return resp.text ?? "Error";
    });
  }

  Future<Map<String, dynamic>> analyzeValueAlignment({
    required String valueName,
    required List<Map<String, String>> questionsAndAnswers,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = "Analyze value alignment. Output JSON: { \"score\": int, \"insight\": \"string\" }";
    return await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
  }

  Future<List<Map<String, dynamic>>> generateTasksFromValues({
    required String valueName,
    required List<Map<String, String>> questionsAndAnswers,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = "Generate tasks for value. Output JSON: { \"tasks\": [{ \"name\": \"string\", \"isCountable\": bool, \"targetCount\": int, \"type\": \"Task\" }] }";
    final result = await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
    return (result['tasks'] as List?)?.map((t) => t as Map<String, dynamic>).toList() ?? [];
  }
  
  Future<List<String>> fetchAvailableModels({String? customApiKey}) async {
    final apiKey = customApiKey ?? (geminiApiKeys.isNotEmpty ? geminiApiKeys.first : null);
    if (apiKey == null || apiKey.startsWith('YOUR_GEMINI')) throw Exception("No valid API Key.");
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['models'] as List).map((m) {
        final methods = List<String>.from(m['supportedGenerationMethods'] ?? []);
        if (methods.contains('generateContent')) return (m['name'] as String).replaceFirst('models/', '');
        return null;
      }).whereType<String>().toList();
    } else {
      throw Exception("Failed to fetch models.");
    }
  }

  Future<Map<String, dynamic>> generateFinancePrediction({
    required String transactionsList,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = "Finance prediction. Output JSON: { \"message\": \"string\", \"predictions\": [] }";
    return await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
  }
}