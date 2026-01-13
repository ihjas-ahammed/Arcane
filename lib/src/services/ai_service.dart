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
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    // 1. Prioritize Inbuild Keys, then Custom Keys
    final List<String> apiKeysToTry = [
      ...geminiApiKeys,
      if (customApiKeys != null) ...customApiKeys
    ].toSet().toList(); // Remove duplicates

    if (apiKeysToTry.isEmpty) {
      throw Exception("No valid Gemini API keys found.");
    }

    for (final model in modelCandidates) {
      for (int i = 0; i < apiKeysToTry.length; i++) {
        // Simple rotation strategy: start from current index
        int effectiveIndex = (currentApiKeyIndex + i) % apiKeysToTry.length;
        String effectiveKey = apiKeysToTry[effectiveIndex];

        if (effectiveKey.startsWith('YOUR_GEMINI_API_KEY')) continue;

        try {
          if (kDebugMode) {
            onLog("Trying Model: $model with Key Index: $effectiveIndex");
          }
          final result = await requestFn(effectiveKey, model);
          // Update the index so next call starts here (load balancing/avoid dead keys)
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

  // --- New Generation Methods ---

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
    final prompt = """
    You are a project manager AI assistant.
    Project: "$projectTitle"
    Description: "$projectDescription"
    Existing Steps: ${existingSteps.join(', ')}
    
    User Request: "$userPrompt"
    
    Generate 3-5 new, actionable steps for this project based on the user request.
    Structure:
    - Title
    - Description
    
    Output strictly JSON matching this structure:
    {
      "steps": [
        {
          "title": "string",
          "description": "string"
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
      onLog: onLog,
    );

    return (result['steps'] as List?)
            ?.map((s) => s as Map<String, dynamic>)
            .toList() ??
        [];
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
    final prompt = """
    You are a tactical planner.
    Parent Task: "$parentStepTitle"
    Context: "$parentStepDescription"
    Existing Sub-steps: ${existingSubsteps.join(', ')}
    
    User Request: "$userPrompt"
    
    Generate 3-5 concrete, actionable sub-steps to complete the parent task.
    
    Output strictly JSON matching this structure:
    {
      "steps": [
        {
          "title": "string",
          "description": "string (optional short note)"
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
      onLog: onLog,
    );

    return (result['steps'] as List?)
            ?.map((s) => s as Map<String, dynamic>)
            .toList() ??
        [];
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
    final prompt = """
    You are a senior analyst for a covert operative.
    Analyze the activity logs and time data from the LAST 7 DAYS.
    
    LOGS:
    $logsText
    
    TIME STATS:
    $timeStatsText
    
    Generate a "Compact Weekly Report".
    1. "summary": A concise, tactical summary of the week's performance (max 50 words).
    2. "improved_abilities": Identify up to 3 user abilities/virtues (e.g., Focus, Discipline, Wisdom, Coding, Health) that improved or were tested this week. 
       - "name": Name of ability.
       - "reason": Why it improved.
       - "score": A pseudo-score increase (1-10) based on effort.
    3. "time_insight": One specific observation about time allocation (e.g., "Heavy focus on Coding, minimal on Health").
    
    Output strictly JSON:
    {
      "summary": "string",
      "improved_abilities": [
        { "name": "string", "reason": "string", "score": int }
      ],
      "time_insight": "string"
    }
    """;

    return await makeAICall(
      prompt: prompt,
      modelCandidates: modelCandidates,
      customApiKeys: customApiKeys,
      currentApiKeyIndex: currentApiKeyIndex,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
    );
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
    final prompt = """
    You are a tactical assistant.
    Mission: "$parentTaskName"
    Sub-Mission: "$subtaskName"
    Existing Objectives: ${existingCheckpoints.join(', ')}
    
    User Request: "$userPrompt"
    
    Generate 3-5 concrete, checkable objectives (checkpoints) for this sub-mission.
    
    Output strictly JSON matching this structure:
    {
      "checkpoints": [
        {
          "name": "string (short actionable title)"
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
      onLog: onLog,
    );

    return (result['checkpoints'] as List?)
            ?.map((c) => c as Map<String, dynamic>)
            .toList() ??
        [];
  }

  // --- Value Analysis ---
  Future<Map<String, dynamic>> analyzeValueAlignment({
    required String valueName,
    required List<Map<String, String>> questionsAndAnswers,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    final buffer = StringBuffer();
    for (var qa in questionsAndAnswers) {
      buffer.writeln("Q: ${qa['question']}");
      buffer.writeln("A: ${qa['answer']}");
      buffer.writeln("");
    }

    final prompt = """
    You are a life coach analyzing a user's alignment with their personal value: "$valueName".
    
    Here are their answers to reflective questions:
    ${buffer.toString()}
    
    Task 1: Rate the clarity and depth of their definition of this value on a scale of 0 to 100.
    - 0 means they have no clear idea or haven't answered.
    - 100 means they have a crystal clear, actionable, and profound understanding of what this value means to them.
    
    Task 2: Provide a brief, actionable insight or encouragement based on their answers (max 2 sentences).
    
    Output strictly JSON:
    {
      "score": int,
      "insight": "string"
    }
    """;

    return await makeAICall(
      prompt: prompt,
      modelCandidates: modelCandidates,
      customApiKeys: customApiKeys,
      currentApiKeyIndex: currentApiKeyIndex,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
    );
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
    final buffer = StringBuffer();
    for (var qa in questionsAndAnswers) {
      buffer.writeln("Q: ${qa['question']}");
      buffer.writeln("A: ${qa['answer']}");
      buffer.writeln("");
    }

    final prompt = """
    Based on the user's definition of the value "$valueName", suggest 3-5 actionable tasks or 'sub-missions' they can do to embody this value.
    
    User's Answers:
    ${buffer.toString()}
    
    Output strictly JSON with this structure:
    {
      "tasks": [
        {
          "name": "string (short actionable title)",
          "isCountable": boolean (true if it's something like 'Read 10 pages', false if it's 'Call Mom'),
          "targetCount": number (0 if not countable, otherwise e.g. 10)
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
      onLog: onLog,
    );

    return (result['tasks'] as List?)
            ?.map((t) => t as Map<String, dynamic>)
            .toList() ??
        [];
  }

  // --- Existing Methods ---

  Future<Map<String, dynamic>> evaluateReflection({
    required String trigger,
    required String emotion,
    required String reason,
    required List<String> modelCandidates,
    List<Map<String, String>>? dailyReflections,
    List<String>? customApiKeys,
    String? systemInstruction,
  }) async {
    final String baseSystemPrompt = systemInstruction ??
        """
    You are a wise mentor. A user has submitted a reflection log.
    Analyze this and provide a short, insightful, empathetic, and actionable textual feedback (max 3 sentences).
    Determine a total XP score between 20 and 100 based on the depth, honesty, and effort of the reflection. 
    Distribute this total XP amount among these 6 virtues: Wisdom, Courage, Humanity, Justice, Temperance, Transcendence.
    """;

    String contextStr = "";
    if (dailyReflections != null && dailyReflections.isNotEmpty) {
      contextStr = "PREVIOUS REFLECTIONS TODAY:\n";
      for (var r in dailyReflections) {
        contextStr +=
            "- Trigger: ${r['trigger']}, Emotion: ${r['emotion']}, Reason: ${r['reason']}\n";
      }
      contextStr +=
          "\nConsidering the context of today's events above, analyze the NEW REFLECTION below:\n";
    }

    final prompt = """
    $baseSystemPrompt

    $contextStr
    NEW REFLECTION DATA:
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
    """;

    return await makeAICall(
      prompt: prompt,
      modelCandidates: modelCandidates,
      customApiKeys: customApiKeys,
      currentApiKeyIndex: 0,
      onNewApiKeyIndex: (_) {},
      onLog: (_) {},
    );
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
      customApiKeys: customApiKeys,
      currentApiKeyIndex: currentApiKeyIndex,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
    );

    return (rawData['newSubquests'] as List?)
            ?.map((sq) => sq as Map<String, dynamic>)
            .toList() ??
        [];
  }

  Future<Map<String, dynamic>> generateProjectFromPrompt({
    required List<String> modelCandidates,
    required String userPrompt,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
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
    """;

    return await makeAICall(
      prompt: prompt,
      modelCandidates: modelCandidates,
      customApiKeys: customApiKeys,
      currentApiKeyIndex: currentApiKeyIndex,
      onNewApiKeyIndex: onNewApiKeyIndex,
      onLog: onLog,
    );
  }

  Future<String> generateDailySummary({
    required List<Map<String, String>> reflections,
    required List<String> modelCandidates,
    required int currentApiKeyIndex,
    List<String>? customApiKeys,
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
    You are a wise mentor.
    
    Here are the user's reflection logs for today:
    $reflectionsText
    
    Based on these entries, provide a concise, insightful daily summary (max 100 words).
    Highlight the key emotional themes, acknowledge any progress in stoic virtues, and offer one clear, actionable thought for tomorrow.
    Note: Never use markdown and any type of formatting
    """;

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
          return response.text ?? "Unable to generate summary.";
        });
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
    You have access to the user's data context below.
    """;

    final prompt = """
    $baseSystemPrompt
    
    USER DATA CONTEXT:
    $dataContext
    
    CONVERSATION HISTORY:
    $historyStr
    
    CURRENT USER MESSAGE: "$userMessage"
    """;

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
