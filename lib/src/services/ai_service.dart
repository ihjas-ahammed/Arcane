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

    // Remove markdown code blocks if present inside the substring or outside
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
    String? customApiKey,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    // 1. Prioritize Custom API Key + First Model (or rotate models for custom key? Usually custom key is one user, one account)
    // Let's iterate models for custom key too, just in case a model is deprecated/unavailable for that key.

    // 2. Fallback to built-in keys
    final apiKeysToTry = (customApiKey != null && customApiKey.isNotEmpty)
        ? [
            customApiKey
          ] // Try custom key only if provided. If it fails, do we fall back to builtin? Usually yes if we want robustness, but maybe no if user specified custom.
        // Let's stick to: Custom Key -> If provided, ONLY use Custom Key.
        : geminiApiKeys;

    if (apiKeysToTry.isEmpty) {
      throw Exception("No valid Gemini API keys found.");
    }

    for (final model in modelCandidates) {
      for (int i = 0; i < apiKeysToTry.length; i++) {
        // If using built-in keys, rotate. If custom, just index 0.
        // For strict rotation updates, we only update if we succeed.

        // Optimization: If custom key, we don't really have an index to update in provider.
        // If built-in, we ideally want to start from `currentApiKeyIndex` but for simplicity in dual-loop, we just iterate all.
        // Re-implementing start-from-offset logic:

        String effectiveKey = apiKeysToTry[i];
        int effectiveIndex = i;

        if (customApiKey == null) {
          effectiveIndex = (currentApiKeyIndex + i) % apiKeysToTry.length;
          effectiveKey = apiKeysToTry[effectiveIndex];
          if (effectiveKey.startsWith('YOUR_GEMINI_API_KEY')) continue;
        }

        try {
          if (kDebugMode)
            onLog("Trying Model: $model with Key Index: $effectiveIndex");
          final result = await requestFn(effectiveKey, model);
          if (customApiKey == null) onNewApiKeyIndex(effectiveIndex);
          return result;
        } catch (e) {
          onLog(
              "<span style=\"color:var(--fh-accent-orange);\">Model $model + Key $effectiveIndex failed: ${e.toString()}</span>");
          // Continue to next key, then next model
        }

        if (customApiKey != null)
          break; // If custom key fails, don't try other keys (there aren't any), move to next model? Yes.
      }
    }
    throw Exception(
        "All models and API keys failed. Please check your connection or settings.");
  }

  Future<Map<String, dynamic>> makeAICall({
    required String prompt,
    required List<String> modelCandidates, // Changed from modelName
    String? customApiKey,
    required int currentApiKeyIndex,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    return await _executeWithModelAndKeyRotation(
      currentApiKeyIndex: currentApiKeyIndex,
      customApiKey: customApiKey,
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

  Future<Map<String, dynamic>> evaluateReflection({
    required String trigger,
    required String emotion,
    required String reason,
    required List<String> modelCandidates, // Changed
    String? customApiKey,
    String? systemInstruction,
  }) async {
    final String baseSystemPrompt = systemInstruction ??
        """
    You are a wise stoic mentor. A user has submitted a reflection log.
    Analyze this and provide a short, insightful, empathetic, and actionable textual feedback (max 3 sentences).
    Distribute exactly 50 XP points among these 6 virtues based on the reflection: Wisdom, Courage, Humanity, Justice, Temperance, Transcendence.
    """;

    final prompt = """
    $baseSystemPrompt

    REFLECTION DATA:
    1. What happened: "$trigger"
    2. Emotion felt: "$emotion"
    3. Why: "$reason"

    Output strictly JSON:
    {
      "feedback": "string",
      "xp_allocation": {
        "Wisdom": int,
        "Courage": int,
        "Humanity": int,
        "Justice": int,
        "Temperance": int,
        "Transcendence": int
      }
    }
    Ensure the sum of xp_allocation values is exactly 50.
    """;

    // We propagate errors here to allow the UI to show a 'Retry' button
    return await makeAICall(
      prompt: prompt,
      modelCandidates: modelCandidates, // Changed
      customApiKey: customApiKey,
      currentApiKeyIndex: 0, // This will be managed by the calling context
      onNewApiKeyIndex: (_) {}, // This will be managed by the calling context
      onLog: (_) {}, // This will be managed by the calling context
    );
  }

  Future<List<Map<String, dynamic>>> generateAISubquests({
    required List<String> modelCandidates, // Changed
    required String mainTaskName,
    required String mainTaskDescription,
    String? mainTaskTheme,
    required String generationMode,
    required String userInput,
    required int numSubquests,
    required int currentApiKeyIndex,
    String? customApiKey,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
You are an assistant for a gamified task management app.
Main quest: "$mainTaskName" (Description: "$mainTaskDescription", Theme: "${mainTaskTheme ?? 'General'}").
AI generation mode: "$generationMode".
User Input: "$userInput"

Break this down into approximately $numSubquests actionable sub-quests.
Provide the output as a single, valid JSON object with one key: "newSubquests".
"newSubquests" should be an array of sub-quest objects. Each sub-quest object MUST have:
- name: string
- isCountable: boolean
- targetCount: number
- subSubTasksData: array of objects { name, isCountable, targetCount }

Return ONLY the JSON object.
""";

    final rawData = await makeAICall(
      prompt: prompt,
      modelCandidates: modelCandidates,
      customApiKey: customApiKey,
      currentApiKeyIndex: currentApiKeyIndex,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
    );

    return (rawData['newSubquests'] as List?)
            ?.map((sq) => sq as Map<String, dynamic>)
            .toList() ??
        [];
  }

  // --- Projects Generation ---
  Future<Map<String, dynamic>> generateProjectFromPrompt({
    required List<String> modelCandidates, // Changed
    required String userPrompt,
    required int currentApiKeyIndex,
    String? customApiKey,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final prompt = """
    You are a project manager AI. Create a detailed project structure based on this prompt: "$userPrompt".
    
    Structure:
    - Project Title
    - Description
    - Steps (Recursive: steps can have substeps).
    
    Output strictly JSON matching this structure:
    {
      "title": "string",
      "description": "string",
      "steps": [
        {
          "title": "string",
          "description": "string",
          "substeps": [ ...recursive... ] 
        }
      ]
    }
    Go at least 2 levels deep if the topic implies complexity.
    """;

    return await makeAICall(
      prompt: prompt,
      modelCandidates: modelCandidates, // Changed
      customApiKey: customApiKey,
      currentApiKeyIndex: currentApiKeyIndex,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
    );
  }

  Future<String> generateDailySummary({
    required List<Map<String, String>> reflections,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    String? customApiKey,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    if (reflections.isEmpty) return "No reflections recorded for this day.";

    final StringBuffer reflectionsText = StringBuffer();
    for (int i = 0; i < reflections.length; i++) {
      reflectionsText.writeln("Entry ${i + 1}:");
      reflectionsText.writeln("  - Trigger: ${reflections[i]['trigger']}");
      reflectionsText.writeln("  - Emotion: ${reflections[i]['emotion']}");
      reflectionsText.writeln("  - Reason: ${reflections[i]['reason']}");
      reflectionsText.writeln("");
    }

    final prompt = """
    You are a wise Stoic mentor.
    
    Here are the user's reflection logs for today:
    $reflectionsText
    
    Based on these entries, provide a concise, insightful daily summary (max 100 words).
    Highlight the key emotional themes, acknowledge any progress in stoic virtues (Wisdom, Courage, Humanity, Justice, Temperance, Transcendence), and offer one clear, actionable thought for tomorrow.
    
    Tone: Empathetic, encouraging, profound but grounded.
    """;

    return await _executeWithModelAndKeyRotation(
        currentApiKeyIndex: currentApiKeyIndex,
        customApiKey: customApiKey,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog,
        modelCandidates: modelCandidates,
        requestFn: (apiKey, modelName) async {
          final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
          final response =
              await model.generateContent([genai.Content.text(prompt)]);
          return response.text ?? "Unable to generate summary.";
        });
  }

  Future<String> getChatbotResponse({
    required List<String> modelCandidates, // Changed
    required ChatbotMemory memory,
    required String userMessage,
    required String dataContext,
    required int currentApiKeyIndex,
    String? customApiKey,
    String? systemInstruction,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    // Construct context from memory (last 10 messages)
    String historyStr = "";
    final recentHistory = memory.conversationHistory.length > 10
        ? memory.conversationHistory
            .sublist(memory.conversationHistory.length - 10)
        : memory.conversationHistory;

    for (var msg in recentHistory) {
      historyStr += "${msg.sender.name.toUpperCase()}: ${msg.text}\n";
    }

    final String baseSystemPrompt = systemInstruction ??
        """
    You are Arcane Advisor, a helpful, slightly mystic yet efficient AI assistant for a productivity app called Arcane.
    You have access to the user's data context below. Use it to answer questions about their progress, tasks, and reflections.
    """;

    final prompt = """
    $baseSystemPrompt
    
    USER DATA CONTEXT (LAST 7 DAYS & CURRENT STATUS):
    $dataContext
    
    CONVERSATION HISTORY:
    $historyStr
    
    CURRENT USER MESSAGE: "$userMessage"
    
    Respond helpfully and concisely based on the provided data context if relevant.
    """;

    return await _executeWithModelAndKeyRotation(
        currentApiKeyIndex: currentApiKeyIndex,
        customApiKey: customApiKey,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog,
        modelCandidates: modelCandidates,
        requestFn: (apiKey, modelName) async {
          final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
          final response =
              await model.generateContent([genai.Content.text(prompt)]);
          return response.text ?? "I am unable to respond at this moment.";
        });
  }

  Future<List<String>> fetchAvailableModels({String? customApiKey}) async {
    final apiKey = customApiKey?.isNotEmpty == true
        ? customApiKey!
        : (geminiApiKeys.isNotEmpty ? geminiApiKeys.first : null);

    if (apiKey == null) {
      throw Exception("No API Key available to fetch models.");
    }

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('models')) {
          final List<dynamic> models = data['models'];
          return models
              .map<String>(
                  (m) => m['name'].toString().replaceFirst('models/', ''))
              .toList();
        }
      }
      throw Exception("Failed to fetch models: ${response.statusCode}");
    } catch (e) {
      throw Exception("Error fetching models: $e");
    }
  }
}
