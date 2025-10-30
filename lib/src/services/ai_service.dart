import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:arcane/src/config/api_keys.dart'; // Your API keys file
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:arcane/src/models/chatbot_models.dart';

class AIService {
  Future<Map<String, dynamic>> makeAICall({
    required String prompt,
    required String modelName,
    required int currentApiKeyIndex,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    return await _makeAICall(
        prompt: prompt,
        modelName: modelName,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);
  }

  Future<Map<String, dynamic>> _makeAICall({
    required String prompt,
    required String modelName,
    required int currentApiKeyIndex,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    if (geminiApiKeys.isEmpty ||
        geminiApiKeys.every((key) => key.startsWith('YOUR_GEMINI_API_KEY'))) {
      const errorMsg =
          "No valid Gemini API keys found. Cannot generate content.";
      onLog(
          "<span style=\"color:var(--fh-accent-red);\">Error: AI content generation failed (No API Key or invalid key).</span>");
      throw Exception(errorMsg);
    }
    if (modelName.isEmpty) {
      const errorMsg = "AI model name not configured. Cannot generate content.";
      onLog(
          "<span style=\"color:var(--fh-accent-red);\">Error: AI content generation failed (AI model name not configured).</span>");
      throw Exception(errorMsg);
    }

    if (kDebugMode) {
      print("[AIService] AI Prompt:\n$prompt");
    }

    for (int i = 0; i < geminiApiKeys.length; i++) {
      final int keyAttemptIndex =
          (currentApiKeyIndex + i) % geminiApiKeys.length;
      final String apiKey = geminiApiKeys[keyAttemptIndex];

      if (apiKey.startsWith('YOUR_GEMINI_API_KEY')) {
        onLog(
            "<span style=\"color:var(--fh-accent-orange);\">Skipping invalid API key at index $keyAttemptIndex.</span>");
        continue;
      }

      try {
        onLog("Trying API key index $keyAttemptIndex for model $modelName...");
        final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
        final response =
            await model.generateContent([genai.Content.text(prompt)]);

        String? rawResponseText = response.text;
        if (rawResponseText == null || rawResponseText.trim().isEmpty) {
          throw Exception("AI response was empty or null.");
        }

        if (kDebugMode) {
          print(
              "[AIService] Raw AI Response (Key Index $keyAttemptIndex):\n$rawResponseText");
        }
        onLog("Raw AI Response received. Attempting to parse JSON...");

        String jsonString = rawResponseText.trim();
        int jsonStart = jsonString.indexOf('{');
        int jsonEnd = jsonString.lastIndexOf('}');

        if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
          jsonString = jsonString.substring(jsonStart, jsonEnd + 1);
        } else {
          onLog(
              "<span style=\"color:var(--fh-accent-red);\">Error: Could not find valid JSON object delimiters {{ ... }} in AI response.</span>");
          if (kDebugMode) {
            print(
                "[AIService] Failed to find JSON delimiters. Raw response was: $rawResponseText");
          }
          throw Exception("Could not extract JSON object from AI response.");
        }

        if (jsonString.startsWith("```json") && jsonString.endsWith("```")) {
          jsonString = jsonString.substring(7, jsonString.length - 3).trim();
        } else if (jsonString.startsWith("```") && jsonString.endsWith("```")) {
          jsonString = jsonString.substring(3, jsonString.length - 3).trim();
        }

        final Map<String, dynamic> generatedData = jsonDecode(jsonString);
        onNewApiKeyIndex(keyAttemptIndex);
        onLog(
            "<span style=\"color:var(--fh-accent-green);\">Successfully processed AI response with API key index $keyAttemptIndex.</span>");
        return generatedData;
      } catch (e) {
        String errorDetail = e.toString();
        if (e is FormatException) {
          errorDetail =
              "JSON FormatException: ${e.message}. Check AI response for syntax errors (e.g., trailing commas, unquoted keys, incorrect string escapes).";
          if (kDebugMode) {
            print(
                "[AIService] JSON Parsing Error: ${e.message}. Offending JSON string part (approx): ${e.source.toString().substring(0, (e.offset ?? e.source.toString().length).clamp(0, e.source.toString().length)).substring(0, 100)}");
          }
        } else if (errorDetail.contains("API key not valid")) {
          errorDetail = "API key not valid. Please check your configuration.";
        } else if (errorDetail.contains("quota")) {
          errorDetail = "API quota exceeded for this key.";
        } else if (errorDetail
            .contains("Candidate was blocked due to SAFETY")) {
          errorDetail =
              "AI response blocked due to safety settings. Try a different prompt or adjust safety settings if possible.";
        }
        onLog(
            "<span style=\"color:var(--fh-accent-red);\">Error with API key index $keyAttemptIndex: $errorDetail</span>");
        if (i == geminiApiKeys.length - 1) {
          throw Exception("All API keys failed. Last error: $errorDetail");
        }
      }
    }
    const finalErrorMsg = "All API keys failed or were invalid.";
    onLog("<span style=\"color:var(--fh-accent-red);\">$finalErrorMsg</span>");
    throw Exception(finalErrorMsg);
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
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    onLog(
        "Attempting to generate sub-quests for \"$mainTaskName\"... Mode: $generationMode");

    String modeSpecificInstructions = "";
    switch (generationMode) {
      case "book_chapter":
        modeSpecificInstructions = """
The user is providing details about a book chapter. Input: "$userInput"
Break this down into approximately $numSubquests actionable sub-quests.
For each sub-quest, suggest 1-3 smaller, concrete steps (sub-subtasks).
If a step involves reading pages, make it "countable" with "targetCount". E.g., "Read pages 10-25" -> name: "Read pages 10-25", isCountable: true, targetCount: 16.
""";
        break;
      case "text_list":
        modeSpecificInstructions = """
The user provided a hierarchical text list. Top-level items are sub-quests. Indented items are sub-subtasks. Input:
$userInput
Convert top-level items to sub-quests, indented items to sub-subtasks.
If an item mentions quantity (e.g., "3 sets", "10 pages"), make it "countable" and set "targetCount".
""";
        break;
      case "general_plan":
      default:
        modeSpecificInstructions = """
The user provided a general plan. Input: "$userInput"
Break this into approximately $numSubquests logical sub-quests.
For each sub-quest, suggest 1-3 smaller, concrete steps (sub-subtasks).
Make items "countable" with "targetCount" if they imply quantity.
""";
        break;
    }

    final String prompt = """
You are an assistant for a gamified task management app.
Main quest: "$mainTaskName" (Description: "$mainTaskDescription", Theme: "${mainTaskTheme ?? 'General'}").
AI generation mode: "$generationMode".

$modeSpecificInstructions

Provide the output as a single, valid JSON object with one key: "newSubquests".
"newSubquests" should be an array of sub-quest objects (approx $numSubquests). Each sub-quest object MUST have:
- name: string (concise name)
- isCountable: boolean
- targetCount: number (if isCountable, otherwise 0 or 1)
- subSubTasksData: array of sub-subtask objects. Each sub-subtask object must have:
  - name: string (concise name)
  - isCountable: boolean
  - targetCount: number (if isCountable, otherwise 0 or 1)

Example JSON:
{
  "newSubquests": [
    {
      "name": "Understand Chapter 1 Concepts",
      "isCountable": false,
      "targetCount": 0,
      "subSubTasksData": [
        { "name": "Read pages 1-10", "isCountable": true, "targetCount": 10 },
        { "name": "Summarize key points", "isCountable": false, "targetCount": 1 }
      ]
    }
  ]
}
Create actionable, distinct sub-quests and steps. Ensure names are clear.
If user input is vague for $numSubquests, generate fewer, meaningful ones.
Return ONLY the JSON object, no markdown or comments. NO TRAILING COMMAS.
""";
    try {
      final Map<String, dynamic> rawData = await _makeAICall(
        prompt: prompt,
        modelName: modelName,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog,
      );
      final List<Map<String, dynamic>> newSubquests =
          (rawData['newSubquests'] as List?)
                  ?.map((sq) => sq as Map<String, dynamic>)
                  .toList() ??
              [];

      bool isValid = newSubquests.every((sq) =>
          sq['name'] is String &&
          sq['isCountable'] is bool &&
          sq['targetCount'] is num &&
          sq['subSubTasksData'] is List &&
          (sq['subSubTasksData'] as List).every((sss) =>
              sss['name'] is String &&
              sss['isCountable'] is bool &&
              sss['targetCount'] is num));

      if (!isValid) {
        onLog(
            "<span style=\"color:var(--fh-accent-orange);\">AI subquest response malformed.</span>");
        if (kDebugMode) {
          print("[AIService] Malformed subquest data: $newSubquests");
        }
        throw Exception("AI subquest response malformed.");
      }
      onLog(
          "AI subquest generation successful. Parsed ${newSubquests.length} subquests.");
      return newSubquests;
    } catch (e) {
      onLog(
          "<span style=\"color:var(--fh-accent-red);\">AI Call failed for generateAISubquests: ${e.toString()}</span>");
      if (kDebugMode) {
        print("[AIService] generateAISubquests caught error: $e");
      }
      rethrow;
    }
  }

  Future<String> getChatbotResponse({
    required String modelName,
    required ChatbotMemory memory,
    required String userMessage,
    required int currentApiKeyIndex,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    onLog("Attempting to get chatbot response...");

    final conversationHistoryString = memory.conversationHistory
        .map((msg) =>
            "${msg.sender == MessageSender.user ? 'User' : 'Bot'}: ${msg.text}")
        .join('\n');

    String emotionLogSummary = "No emotion logs available for the past week.";
    if (memory.dailyCompletedGoals
        .any((goal) => goal.contains("Emotion logged:"))) {
      emotionLogSummary =
          "Emotion logs from the past week are available. Ask for a summary if interested.";
    }

    String checkpointLogSummary =
        "No checkpoint logs available for the past week.";
    List<String> recentCheckpoints = memory.dailyCompletedGoals
        .where((goal) => goal.toLowerCase().contains("completed checkpoint"))
        .take(5)
        .toList();
    if (recentCheckpoints.isNotEmpty) {
      checkpointLogSummary =
          "Recently completed checkpoints:\n${recentCheckpoints.join('\n')}";
    }

    final String prompt = """
You are Arcane Advisor, a helpful AI assistant integrated into a gamified task management app.
Your user is interacting with you through a chat interface.

Your knowledge includes:
1.  Conversation History (most recent first):
$conversationHistoryString

2.  Last Weekly Summary (if available):
${memory.lastWeeklySummary ?? "No weekly summary available for last week."}

3.  Recently Completed Goals/Tasks (if available):
${memory.dailyCompletedGoals.isNotEmpty ? memory.dailyCompletedGoals.join('\n') : "No specific completed goals logged recently."}
    (This may include emotion logs and checkpoint completions with timestamps if logged by the system.)

4.  User's Explicitly Remembered Items:
${memory.userRememberedItems.isNotEmpty ? memory.userRememberedItems.join('\n') : "Nothing specific noted by the user to remember."}

5.  Emotion Log Summary:
$emotionLogSummary

6.  Checkpoint Log Summary:
$checkpointLogSummary

User's current message: "$userMessage"

Based on all this information, provide a concise, helpful, and encouraging response.
If the user asks to "Remember X", acknowledge it and state that you will remember "X". Do not include "X" in your response beyond the acknowledgement, as the system will store it separately.
If the user asks to "Forget last" or "Forget everything", acknowledge the action. The system handles the memory modification.
If the user asks about their progress, summaries, emotion trends, or checkpoint completions, use the provided information.
Keep responses relatively short and conversational.
Do not use markdown in your primary text response.

DYNAMIC UI REQUEST (Optional):
If you think a visual representation would be helpful (e.g., a graph of emotion logs, task progress), you can request it.
To request dynamic UI, end your text response with a special JSON string on a new line:
UI_REQUEST:{"type":"graph","data":{"graphType":"emotion_trend_bar","title":"Emotion Trend Past 7 Days","source":"emotion_logs"}}
Valid 'type' values: "graph".
Valid 'graphType' for "graph": "emotion_trend_bar" (shows daily average emotion as bars for last 7 days).
'source' can be "emotion_logs".
The system will attempt to render this if possible. If not requesting UI, omit the UI_REQUEST line.
Example: "Here is your summary. Would you like to see a graph? \\nUI_REQUEST:{\\"type\\":\\"graph\\",\\"data\\":{\\"graphType\\":\\"emotion_trend_bar\\",\\"title\\":\\"Emotions This Week\\",\\"source\\":\\"emotion_logs\\"}}"
Only request UI if it makes sense for the conversation and the data is likely available (e.g., emotion logs).
"""
        .trim();

    if (geminiApiKeys.isEmpty ||
        geminiApiKeys.every((key) => key.startsWith('YOUR_GEMINI_API_KEY'))) {
      const errorMsg = "No valid Gemini API keys found. Chatbot cannot respond.";
      onLog(
          "<span style=\"color:var(--fh-accent-red);\">Error: Chatbot failed (No API Key).</span>");
      return "I'm currently unable to process requests due to a configuration issue. Please check the API keys.";
    }
    if (modelName.isEmpty) {
      const errorMsg = "AI model name not configured. Chatbot cannot respond.";
      onLog(
          "<span style=\"color:var(--fh-accent-red);\">Error: Chatbot failed (Model Name not configured).</span>");
      return "I'm currently unable to process requests due to a model configuration issue.";
    }

    if (kDebugMode) {
      print("[AIService - Chatbot] Prompt:\n$prompt");
    }

    for (int i = 0; i < geminiApiKeys.length; i++) {
      final int keyAttemptIndex =
          (currentApiKeyIndex + i) % geminiApiKeys.length;
      final String apiKey = geminiApiKeys[keyAttemptIndex];

      if (apiKey.startsWith('YOUR_GEMINI_API_KEY')) {
        onLog(
            "<span style=\"color:var(--fh-accent-orange);\">Skipping invalid API key for chatbot at index $keyAttemptIndex.</span>");
        continue;
      }

      try {
        onLog(
            "Chatbot trying API key index $keyAttemptIndex for model $modelName...");
        final model = genai.GenerativeModel(model: modelName, apiKey: apiKey);
        final response =
            await model.generateContent([genai.Content.text(prompt)]);

        String? rawResponseText = response.text;
        if (rawResponseText == null || rawResponseText.trim().isEmpty) {
          throw Exception("Chatbot AI response was empty or null.");
        }

        if (kDebugMode) {
          print(
              "[AIService - Chatbot] Raw AI Response (Key Index $keyAttemptIndex):\n$rawResponseText");
        }
        onLog(
            "<span style=\"color:var(--fh-accent-green);\">Chatbot successfully processed response with API key index $keyAttemptIndex.</span>");
        onNewApiKeyIndex(keyAttemptIndex);
        return rawResponseText.trim();
      } catch (e) {
        String errorDetail = e.toString();
        if (e is genai.GenerativeAIException &&
            e.message.contains("USER_LOCATION_INVALID")) {
          errorDetail =
              "Geographic location restriction. This API key may not be usable in your current region.";
        } else if (errorDetail.contains("API key not valid")) {
          errorDetail = "API key not valid. Please check your configuration.";
        } else if (errorDetail.contains("quota")) {
          errorDetail = "API quota exceeded for this key.";
        } else if (errorDetail
            .contains("Candidate was blocked due to SAFETY")) {
          errorDetail = "AI response blocked due to safety settings. Try rephrasing.";
        }
        onLog(
            "<span style=\"color:var(--fh-accent-red);\">Chatbot Error with API key index $keyAttemptIndex: $errorDetail</span>");
        if (i == geminiApiKeys.length - 1) {
          return "I'm having trouble connecting to my core functions right now. Please try again later. (Error: $errorDetail)";
        }
      }
    }
    return "I seem to be experiencing technical difficulties. Please check back soon.";
  }
}