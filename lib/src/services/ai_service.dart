import 'dart:convert';
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
  }) async {
    return await _executeWithModelAndKeyRotation(
      currentApiKeyIndex: currentApiKeyIndex,
      customApiKeys: customApiKeys,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
      modelCandidates: modelCandidates,
      requestFn: (apiKey, modelName) async {
        final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
        final response =
            await model.generateContent([genai.Content.text(prompt)]);

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
    You are the "Neural Archive", an empathetic and highly intelligent system interface for the user's life logs.
    
    Here are the logs from the requested timeline:
    $logsContext
    
    USER QUERY: "$query"
    
    INSTRUCTIONS:
    1. Answer the user's query based strictly on the provided logs.
    2. Be empathetic, human-like, and insightful. Avoid robotic or list-heavy responses unless asked.
    3. Do NOT use any Markdown formatting (no bold, no italics, no code blocks). Pure text only.
    4. If the answer isn't in the logs, gently state that the data is missing.
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
        return response.text ?? "Archive data corrupted or empty.";
      },
    );
  }

  Future<List<Map<String, dynamic>>> generateTimeSyncSchedule({
    required String userPrompt,
    required String contextData, 
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Create a 24-hour schedule (starting NOW) for the user.
    
    CONTEXT:
    $contextData
    
    USER REQUEST: "$userPrompt"
    
    INSTRUCTIONS:
    1. Generate a sequence of blocks covering the next 24 hours.
    2. Be realistic with durations. Include breaks if 'focus' sessions are long.
    3. Types: 'focus' (work/study), 'routine' (food/commute), 'rest' (sleep/break), 'leisure' (fun).
    4. Output JSON ONLY: { "blocks": [ { "offset_minutes": int (minutes from now), "duration_minutes": int, "title": "string", "description": "string", "type": "string" } ] }
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
  }) async {
    final prompt = "Generate project JSON for: $userPrompt. Structure: {title, description, steps: [{title, description, substeps: []}]}";
    return await makeAICall(prompt: prompt, modelCandidates: modelCandidates, customApiKeys: customApiKeys, currentApiKeyIndex: currentApiKeyIndex, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog);
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
    final prompt = "Generate steps JSON for Project '$projectTitle' ('$projectDescription'). Existing: $existingSteps. Request: $userPrompt. Output: {steps: [{title, description}]}";
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
    
    1. Provide constructive feedback.
    2. Allocate XP (0-50) to virtues (Wisdom, Courage, Humanity, Justice, Temperance, Transcendence).
    3. CHECK if this reflection implies an update to a Value's questions or answers. If the user realizes something about their values, suggest an update.
    
    Output JSON: {
      "feedback": "string", 
      "xp_allocation": {"Wisdom": int, ...},
      "value_updates": [ { "valueId": "string", "questionId": "string", "suggestedAnswer": "string", "reason": "string" } ] (Optional, empty if none)
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
    final prompt = """
    Generate a Tactical Briefing based on today's reflections.
    Current Logs: ${jsonEncode(reflections)}
    Previous Briefings (Context): ${jsonEncode(previousBriefings)}
    
    Tone: Empathetic, psychologically wise, tactical advisor.
    
    Tasks:
    1. Create a concise summary of the day's psychological state.
    2. Identify specific ability improvements or growth by comparing with previous context.
    
    Output JSON: {
      "summary": "string (max 60 words)",
      "improvements": [ {"ability": "string", "insight": "string"} ]
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

  Future<Map<String, dynamic>> generateWeeklyReport({
    required String logsText,
    required String timeStatsText,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = "Analyze logs and time stats for a Weekly Report. Output JSON: { \"summary\": \"string\", \"improved_abilities\": [ {\"name\": \"string\", \"reason\": \"string\", \"score\": int} ], \"time_insight\": \"string\" }. Logs: $logsText. Time: $timeStatsText";
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
    final prompt = "Chatbot response. Context: $dataContext. History included.";
    return await _executeWithModelAndKeyRotation(currentApiKeyIndex: currentApiKeyIndex, customApiKeys: customApiKeys, onNewApiKeyIndex: onNewApiKeyIndex, onLog: onLog, modelCandidates: modelCandidates, requestFn: (k, m) async {
        final model = genai.GenerativeModel(model: m, apiKey: k);
        final resp = await model.generateContent([genai.Content.text(prompt)]);
        return resp.text ?? "Error";
    });
  }

  Future<Map<String, dynamic>> analyzeValueAlignment({required String valueName, required List<Map<String, String>> questionsAndAnswers, required List<String> modelCandidates, required int currentApiKeyIndex, List<String>? customApiKeys, required Function(int) onNewApiKeyIndex, required Function(String) onLog}) async {
    return {'score': 50, 'insight': 'Analysis placeholder'};
  }
  Future<List<Map<String, dynamic>>> generateTasksFromValues({required String valueName, required List<Map<String, String>> questionsAndAnswers, required List<String> modelCandidates, required int currentApiKeyIndex, List<String>? customApiKeys, required Function(int) onNewApiKeyIndex, required Function(String) onLog}) async {
    return [];
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
          final methods = List<String>.from(m['supportedGenerationMethods'] ?? []);
          if (methods.contains('generateContent')) {
            return (m['name'] as String).replaceFirst('models/', '');
          }
          return null;
        }).whereType<String>().toList();
        return models;
      }
      return [];
    } else {
      throw Exception("Failed to fetch models: ${response.statusCode} ${response.body}");
    }
  }

  // --- Finance Prediction ---
  Future<Map<String, dynamic>> generateFinancePrediction({
    required String transactionsList,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    Analyze these wallet transactions:
    $transactionsList
    
    1. Analyze spending habits.
    2. Predict upcoming expenses for next week by category.
    3. Provide a short, empathetic financial advice message.
    
    Output JSON ONLY:
    {
      "message": "string",
      "predictions": [ { "category": "string", "amount": number, "reason": "string" } ]
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

  // --- Start Day Report ---
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
    
    Task:
    1. Analyze the user's momentum.
    2. Provide a futuristic, empathetic 'Forecast' message (max 2 sentences) focusing on what *might* happen today based on their trajectory. Be encouraging but realistic.
    3. Determine 3 key 'System Metrics' (e.g., 'Willpower', 'Clarity', 'Momentum', 'Rest') with a value 0-100 based on the logs.
    4. Suggest 3 specific 'Tactical Directives' (short tasks) for today.
    
    Output JSON ONLY:
    {
      "forecast": "string",
      "metrics": [ {"label": "string", "value": int, "color_hex": "string (optional hex)"} ],
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
}
