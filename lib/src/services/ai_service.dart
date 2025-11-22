import 'dart:convert';
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

  // Internal helper to cycle keys and execute a function
  Future<T> _executeWithRotation<T>({
    required Future<T> Function(String apiKey) requestFn,
    required int currentApiKeyIndex,
    String? customApiKey,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    // 1. Prioritize Custom API Key
    if (customApiKey != null && customApiKey.isNotEmpty) {
      try {
        onLog("Using Custom API Key...");
        return await requestFn(customApiKey);
      } catch (e) {
        onLog("<span style=\"color:var(--fh-accent-red);\">Custom Key Error: ${e.toString()}</span>");
        onLog("Falling back to built-in keys...");
      }
    }

    // 2. Fallback to built-in keys
    if (geminiApiKeys.isEmpty) {
      throw Exception("No valid Gemini API keys found.");
    }

    for (int i = 0; i < geminiApiKeys.length; i++) {
      final int keyAttemptIndex = (currentApiKeyIndex + i) % geminiApiKeys.length;
      final String apiKey = geminiApiKeys[keyAttemptIndex];

      if (apiKey.startsWith('YOUR_GEMINI_API_KEY')) continue;

      try {
        onLog("Trying built-in key index $keyAttemptIndex...");
        final result = await requestFn(apiKey);
        onNewApiKeyIndex(keyAttemptIndex);
        return result;
      } catch (e) {
         onLog("<span style=\"color:var(--fh-accent-orange);\">Key $keyAttemptIndex failed: ${e.toString()}</span>");
      }
    }
    throw Exception("All API keys failed.");
  }

  Future<Map<String, dynamic>> makeAICall({
    required String prompt,
    required String modelName,
    String? customApiKey,
    required int currentApiKeyIndex,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    return await _executeWithRotation(
      currentApiKeyIndex: currentApiKeyIndex,
      customApiKey: customApiKey,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
      requestFn: (apiKey) async {
        final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([genai.Content.text(prompt)]);
        
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
    required String modelName,
    String? customApiKey,
    String? systemInstruction,
  }) async {
    final String baseSystemPrompt = systemInstruction ?? """
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

    try {
      return await makeAICall(
        prompt: prompt,
        modelName: modelName,
        customApiKey: customApiKey,
        currentApiKeyIndex: 0, 
        onNewApiKeyIndex: (_) {},
        onLog: (_) {},
      );
    } catch (e) {
      return {
        "feedback": "Analysis unavailable. Keep reflecting to grow.",
        "xp_allocation": {
          "Wisdom": 10, "Courage": 5, "Humanity": 5, "Justice": 5, "Temperance": 15, "Transcendence": 10
        }
      };
    }
  }

  Future<List<Map<String, dynamic>>> generateAISubquests({
    required String modelName,
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
      modelName: modelName,
      customApiKey: customApiKey,
      currentApiKeyIndex: currentApiKeyIndex,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
    );

    return (rawData['newSubquests'] as List?)
            ?.map((sq) => sq as Map<String, dynamic>)
            .toList() ?? [];
  }

   Future<String> getChatbotResponse({
    required String modelName,
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
        ? memory.conversationHistory.sublist(memory.conversationHistory.length - 10) 
        : memory.conversationHistory;

    for(var msg in recentHistory) {
      historyStr += "${msg.sender.name.toUpperCase()}: ${msg.text}\n";
    }

    final String baseSystemPrompt = systemInstruction ?? """
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

    return await _executeWithRotation(
      currentApiKeyIndex: currentApiKeyIndex,
      customApiKey: customApiKey,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
      requestFn: (apiKey) async {
        final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([genai.Content.text(prompt)]);
        return response.text ?? "I am unable to respond at this moment.";
      }
    );
  }
}