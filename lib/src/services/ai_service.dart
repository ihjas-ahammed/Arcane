import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:arcane/src/config/api_keys.dart'; // Your API keys file
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:arcane/src/models/game_models.dart'; // For ChatbotMessage

class AIService {
  Future<Map<String, dynamic>> makeAICall({
    required String prompt,
    required int currentApiKeyIndex,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    return await _makeAICall(
        prompt: prompt,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog);
  }

  Future<Map<String, dynamic>> _makeAICall({
    required String prompt,
    required int currentApiKeyIndex,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    if (geminiApiKeys.isEmpty ||
        geminiApiKeys.every((key) => key.startsWith('YOUR_GEMINI_API_KEY'))) {
      const errorMsg =
          "No valid Gemini API keys found. Cannot generate content.";
      onLog(// Ensure string is passed
          "<span style=\"color:var(--fh-accent-red);\">Error: AI content generation failed (No API Key or invalid key).</span>");
      throw Exception(errorMsg);
    }
    if (geminiModelName.isEmpty) {
      const errorMsg =
          "GEMINI_MODEL_NAME not configured. Cannot generate content.";
      onLog(// Ensure string is passed
          "<span style=\"color:var(--fh-accent-red);\">Error: AI content generation failed (GEMINI_MODEL_NAME not configured).</span>");
      throw Exception(errorMsg);
    }

    // Log the full prompt in debug mode
    if (kDebugMode) {
      print("[AIService] AI Prompt:\n$prompt");
    }

    for (int i = 0; i < geminiApiKeys.length; i++) {
      final int keyAttemptIndex =
          (currentApiKeyIndex + i) % geminiApiKeys.length;
      final String apiKey = geminiApiKeys[keyAttemptIndex];

      if (apiKey.startsWith('YOUR_GEMINI_API_KEY')) {
        onLog(// Ensure string is passed
            "<span style=\"color:var(--fh-accent-orange);\">Skipping invalid API key at index $keyAttemptIndex.</span>");
        continue;
      }

      try {
        onLog(// Ensure string is passed
            "Trying API key index $keyAttemptIndex for model $geminiModelName...");
        final model =
            genai.GenerativeModel(model: geminiModelName, apiKey: apiKey);
        final response =
            await model.generateContent([genai.Content.text(prompt)]);

        String? rawResponseText = response.text;
        if (rawResponseText == null || rawResponseText.trim().isEmpty) {
          throw Exception("AI response was empty or null.");
        }

        // Log the raw response in debug mode
        if (kDebugMode) {
          print(
              "[AIService] Raw AI Response (Key Index $keyAttemptIndex):\n$rawResponseText");
        }
        onLog("Raw AI Response received. Attempting to parse JSON..."); // Ensure string is passed

        // More robust JSON extraction
        String jsonString = rawResponseText.trim();
        int jsonStart = jsonString.indexOf('{');
        int jsonEnd = jsonString.lastIndexOf('}');

        if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
          jsonString = jsonString.substring(jsonStart, jsonEnd + 1);
        } else {
          onLog(// Ensure string is passed
              "<span style=\"color:var(--fh-accent-red);\">Error: Could not find valid JSON object delimiters {{ ... }} in AI response.</span>");
          if (kDebugMode) {
            print(
                "[AIService] Failed to find JSON delimiters. Raw response was: $rawResponseText");
          }
          throw Exception("Could not extract JSON object from AI response.");
        }

        // Attempt to remove common non-JSON prefixes/suffixes if any (like markdown code blocks)
        // This is a secondary check if the above { } extraction wasn't perfect
        if (jsonString.startsWith("```json") && jsonString.endsWith("```")) {
          jsonString = jsonString.substring(7, jsonString.length - 3).trim();
        } else if (jsonString.startsWith("```") && jsonString.endsWith("```")) {
          jsonString = jsonString.substring(3, jsonString.length - 3).trim();
        }

        final Map<String, dynamic> generatedData = jsonDecode(jsonString);
        onNewApiKeyIndex(keyAttemptIndex);
        onLog(// Ensure string is passed
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
        onLog(// Ensure string is passed
            "<span style=\"color:var(--fh-accent-red);\">Error with API key index $keyAttemptIndex: $errorDetail</span>");
        if (i == geminiApiKeys.length - 1) {
          throw Exception("All API keys failed. Last error: $errorDetail");
        }
      }
    }
    const finalErrorMsg = "All API keys failed or were invalid.";
    onLog("<span style=\"color:var(--fh-accent-red);\">$finalErrorMsg</span>"); // Ensure string is passed
    throw Exception(finalErrorMsg);
  }

  Future<Map<String, List<Map<String, dynamic>>>> generateSpecificGameContent({
    required int levelForContent,
    required int currentApiKeyIndex,
    required Function(int) onNewApiKeyIndex,
    required List<String?>
        themes, // Themes for this specific batch, can include null for general
    required Function(String) onLog,
    String? playerStatsString, // New parameter
    String? existingEnemyIdsString,
    String? existingArtifactIdsString,
    String? existingLocationIdsString,
    int numEnemiesToGenerate = 0,
    int numArtifactsPerTheme = 0,
    int numPowerupsPerTheme = 0,
    int numLocationsToGenerate = 0,
    String? specificLocationKeyForEnemies,
  }) async {
    onLog(// Ensure string is passed
        "Attempting to generate specific game content for themes: ${themes.map((t) => t ?? 'General').join(', ')}...");

    String enemyInstructions = "";
    if (numEnemiesToGenerate > 0) {
      enemyInstructions = """
"newEnemies" should be an array of $numEnemiesToGenerate enemy objects.
- Consider these player stats for balancing: ${playerStatsString ?? "Player stats not provided, use general balancing for level $levelForContent."}. Enemies should be challenging but fair.
- Distribute these enemies among the themes [${themes.map((t) => t == null ? "null (general)" : "'$t'").join(', ')}] or focus on "$specificLocationKeyForEnemies" if provided.
Each enemy object must have:
- id: string, unique (e.g., "gen_enemy_lvl${levelForContent}_a2f5")
- name: string (e.g., "Shadow Lurker", "Arcane Golem")
- theme: string or null (one of [${themes.map((t) => t == null ? "null" : "'$t'").join(', ')}])
- locationKey: string (MUST match one of the 'id's from "newGameLocations" if generated, or "$specificLocationKeyForEnemies" if provided, or an existing one if appropriate for theme)
- minPlayerLevel: number (should be $levelForContent or slightly higher, e.g., up to ${levelForContent + 2})
- health: number (range: ${50 + levelForContent * 12} to ${80 + levelForContent * 18})
- attack: number (range: ${8 + (levelForContent * 1.8).floor()} to ${12 + (levelForContent * 2.2).floor()})
- defense: number (range: ${3 + (levelForContent * 0.6).floor()} to ${5 + (levelForContent * 1.1).floor()})
- coinReward: number (range: ${20 + levelForContent * 5} to ${50 + levelForContent * 10})
- xpReward: number (range: ${30 + levelForContent * 8} to ${70 + levelForContent * 15})
- description: string (max 100 chars)
""";
    }

    String artifactInstructions = "";
    if (numArtifactsPerTheme > 0 || numPowerupsPerTheme > 0) {
      artifactInstructions =
          "\"newArtifacts\" should be an array of artifact objects.\n";
      for (String? themeName in themes) {
        String currentThemeNameForPrompt = themeName ?? "general (null theme)";
        if (numArtifactsPerTheme > 0) {
          artifactInstructions += """
  - For the theme "$currentThemeNameForPrompt", generate $numArtifactsPerTheme of 'weapon', $numArtifactsPerTheme of 'armor', and $numArtifactsPerTheme of 'talisman' artifacts.
""";
        }
        if (numPowerupsPerTheme > 0) {
          artifactInstructions += """
  - For the theme "$currentThemeNameForPrompt", generate $numPowerupsPerTheme 'powerup' artifacts.
""";
        }
      }
      artifactInstructions += """
Each artifact object must have:
- id: string, unique (e.g., "gen_art_lvl${levelForContent}_tech_wpn_b3c8")
- name: string
- type: string ['weapon', 'armor', 'talisman', 'powerup']
- theme: string or null (MUST be the theme it was generated for, use null for general items)
- description: string (max 100 chars)
- cost: number (range: ${50 + levelForContent * 10} to ${300 + levelForContent * 25})
- icon: string (a single, relevant emoji)
- For 'weapon', 'armor', 'talisman':
    - baseAtt: number (0 if not applicable)
    - baseRunic: number (0 if not applicable)
    - baseDef: number (0 if not applicable)
    - baseHealth: number (0 if not applicable)
    - baseLuck: number (0-10, integer percentage)
    - baseCooldown: number (0-15, integer percentage)
    - bonusXPMod: number (0.0 to 0.15, decimal for percentage)
    - upgradeBonus: object (e.g., {"att": 2, "luck": 1}). Modest values.
    - maxLevel: number (3, 5, or 7)
- For 'powerup':
    - effectType: string ['direct_damage', 'heal_player']
    - effectValue: number
    - uses: number (typically 1)
    (omit baseStats, upgradeBonus, maxLevel for powerups or set to 0/null)
""";
    }

    String locationInstructions = "";
    if (numLocationsToGenerate > 0) {
      locationInstructions = """
"newGameLocations" should be an array of $numLocationsToGenerate game location objects.
Each location object must have:
- id: string, unique (e.g., "loc_dark_forest", "loc_crystal_caves_$levelForContent")
- name: string (e.g., "Whispering Woods", "Sunken Temple of Eldoria")
- description: string (short, evocative description, max 150 chars)
- minPlayerLevelToUnlock: number (Based on current level. E.g., $levelForContent, ${levelForContent + 2}, etc.)
- iconEmoji: string (a single emoji representing the location, e.g., "🌲", "🏛️", "💎")
- associatedTheme: string or null (e.g., "knowledge", "tech", or null for general, matching one of [${themes.map((t) => t == null ? "null" : "'$t'").join(', ')}])
- bossEnemyIdToUnlockNextLocation: string or null (ID of an enemy generated in "newEnemies" that, when defeated, could unlock another location. Can be null.)
""";
    }

    final String prompt = """
Generate new game content suitable for a player at level $levelForContent in a fantasy RPG.
Focus on generating content ONLY for the following themes (if applicable, or general content if a theme is null/not provided in the list): [${themes.map((t) => t == null ? "null (general)" : "'$t'").join(', ')}].
Provide the output as a single, valid JSON object.
The top-level keys should ONLY be those for which content is requested (e.g., "newEnemies", "newArtifacts", "newGameLocations").
If no enemies are requested for this batch/theme, do not include the "newEnemies" key, and so on.
Ensure there are NO trailing commas in lists or objects. All strings must be properly escaped.

IMPORTANT:
${existingEnemyIdsString != null && existingEnemyIdsString.isNotEmpty ? "- Do NOT generate enemies with IDs from this list: [$existingEnemyIdsString]." : ""}
${existingArtifactIdsString != null && existingArtifactIdsString.isNotEmpty ? "- Do NOT generate artifacts with IDs from this list: [$existingArtifactIdsString]." : ""}
${existingLocationIdsString != null && existingLocationIdsString.isNotEmpty ? "- Do NOT generate locations with IDs from this list: [$existingLocationIdsString]." : ""}
- All generated IDs and names MUST be new and unique.

$locationInstructions
$enemyInstructions
$artifactInstructions

Return ONLY the JSON object.
""";
    try {
      final Map<String, dynamic> rawData = await _makeAICall(
        prompt: prompt,
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog,
      );

      final List<Map<String, dynamic>> newEnemies =
          (rawData['newEnemies'] as List?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
      final List<Map<String, dynamic>> newArtifacts =
          (rawData['newArtifacts'] as List?)
                  ?.map((a) => a as Map<String, dynamic>)
                  .toList() ??
              [];
      final List<Map<String, dynamic>> newGameLocations =
          (rawData['newGameLocations'] as List?)
                  ?.map((loc) => loc as Map<String, dynamic>)
                  .toList() ??
              [];

      onLog(// Ensure string is passed
          "AI content generation successful for this batch. Parsed ${newEnemies.length} enemies, ${newArtifacts.length} artifacts, ${newGameLocations.length} locations.");

      return {
        'newEnemies': newEnemies,
        'newArtifacts': newArtifacts,
        'newGameLocations': newGameLocations
      };
    } catch (e) {
      onLog(// Ensure string is passed
          "<span style=\"color:var(--fh-accent-red);\">AI Call failed for generateSpecificGameContent: ${e.toString()}</span>");
      if (kDebugMode) {
        print("[AIService] generateSpecificGameContent caught error: $e");
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> generateAISubquests({
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
    onLog(// Ensure string is passed
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
        currentApiKeyIndex: currentApiKeyIndex,
        onNewApiKeyIndex: onNewApiKeyIndex,
        onLog: onLog,
      );
      final List<Map<String, dynamic>> newSubquests =
          (rawData['newSubquests'] as List?)
                  ?.map((sq) => sq as Map<String, dynamic>)
                  .toList() ??
              [];

      // Basic validation
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
        onLog(// Ensure string is passed
            "<span style=\"color:var(--fh-accent-orange);\">AI subquest response malformed.</span>");
        if (kDebugMode) {
          print("[AIService] Malformed subquest data: $newSubquests");
        }
        throw Exception("AI subquest response malformed.");
      }
      onLog(// Ensure string is passed
          "AI subquest generation successful. Parsed ${newSubquests.length} subquests.");
      return newSubquests;
    } catch (e) {
      onLog(// Ensure string is passed
          "<span style=\"color:var(--fh-accent-red);\">AI Call failed for generateAISubquests: ${e.toString()}</span>");
      if (kDebugMode) {
        print("[AIService] generateAISubquests caught error: $e");
      }
      rethrow;
    }
  }

  Future<String> getChatbotResponse({ // Return String for now, UI generation will be embedded or a separate call
    required ChatbotMemory memory,
    required String userMessage,
    required int currentApiKeyIndex,
    required Function(int) onNewApiKeyIndex,
    required Function(String) onLog,
  }) async {
    onLog("Attempting to get chatbot response...");

    final conversationHistoryString = memory.conversationHistory
        .map((msg) => "${msg.sender == MessageSender.user ? 'User' : 'Bot'}: ${msg.text}")
        .join('\n');

    // Prepare emotion log summary for the prompt
    String emotionLogSummary = "No emotion logs available for the past week.";
    if (memory.dailyCompletedGoals.any((goal) => goal.contains("Emotion logged:"))) { // Crude check if emotion logs are present via daily goals
        emotionLogSummary = "Emotion logs from the past week are available. Ask for a summary if interested.";
    } else { // Attempt to build a simple summary if GameProvider has direct access or passes it
        // This part is tricky as AIService doesn't directly access GameProvider's completedByDay.
        // For now, we'll rely on dailyCompletedGoals if they indirectly reflect emotion logs.
        // A more robust solution would involve passing a summary of emotion logs to ChatbotMemory.
        // For this iteration, we'll keep it simple.
    }


    // Prepare checkpoint log summary
    String checkpointLogSummary = "No checkpoint logs available for the past week.";
    List<String> recentCheckpoints = memory.dailyCompletedGoals
        .where((goal) => goal.toLowerCase().contains("completed checkpoint"))
        .take(5) // Take last 5 for brevity
        .toList();
    if (recentCheckpoints.isNotEmpty) {
        checkpointLogSummary = "Recently completed checkpoints:\n${recentCheckpoints.join('\n')}";
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

    // For chatbot, we don't expect JSON back, just text.
    if (geminiApiKeys.isEmpty || geminiApiKeys.every((key) => key.startsWith('YOUR_GEMINI_API_KEY'))) {
        const errorMsg = "No valid Gemini API keys found. Chatbot cannot respond.";
        onLog("<span style=\"color:var(--fh-accent-red);\">Error: Chatbot failed (No API Key).</span>");
        return "I'm currently unable to process requests due to a configuration issue. Please check the API keys.";
    }
     if (geminiModelName.isEmpty) {
      const errorMsg ="GEMINI_MODEL_NAME not configured. Chatbot cannot respond.";
      onLog("<span style=\"color:var(--fh-accent-red);\">Error: Chatbot failed (Model Name not configured).</span>");
      return "I'm currently unable to process requests due to a model configuration issue.";
    }

    if (kDebugMode) {
      print("[AIService - Chatbot] Prompt:\n$prompt");
    }

    for (int i = 0; i < geminiApiKeys.length; i++) {
      final int keyAttemptIndex = (currentApiKeyIndex + i) % geminiApiKeys.length;
      final String apiKey = geminiApiKeys[keyAttemptIndex];

      if (apiKey.startsWith('YOUR_GEMINI_API_KEY')) {
        onLog("<span style=\"color:var(--fh-accent-orange);\">Skipping invalid API key for chatbot at index $keyAttemptIndex.</span>");
        continue;
      }

      try {
        onLog("Chatbot trying API key index $keyAttemptIndex for model $geminiModelName...");
        final model = genai.GenerativeModel(model: geminiModelName, apiKey: apiKey);
        final response = await model.generateContent([genai.Content.text(prompt)]);

        String? rawResponseText = response.text;
        if (rawResponseText == null || rawResponseText.trim().isEmpty) {
          throw Exception("Chatbot AI response was empty or null.");
        }

        if (kDebugMode) {
          print("[AIService - Chatbot] Raw AI Response (Key Index $keyAttemptIndex):\n$rawResponseText");
        }
        onLog("<span style=\"color:var(--fh-accent-green);\">Chatbot successfully processed response with API key index $keyAttemptIndex.</span>");
        onNewApiKeyIndex(keyAttemptIndex);
        return rawResponseText.trim(); // The parsing of UI_REQUEST will happen in GameProvider

      } catch (e) {
        String errorDetail = e.toString();
         if (e is genai.GenerativeAIException && e.message.contains("USER_LOCATION_INVALID")) {
          errorDetail = "Geographic location restriction. This API key may not be usable in your current region.";
        } else if (errorDetail.contains("API key not valid")) {
          errorDetail = "API key not valid. Please check your configuration.";
        } else if (errorDetail.contains("quota")) {
          errorDetail = "API quota exceeded for this key.";
        } else if (errorDetail.contains("Candidate was blocked due to SAFETY")) {
          errorDetail = "AI response blocked due to safety settings. Try rephrasing.";
        }
        onLog("<span style=\"color:var(--fh-accent-red);\">Chatbot Error with API key index $keyAttemptIndex: $errorDetail</span>");
        if (i == geminiApiKeys.length - 1) {
          return "I'm having trouble connecting to my core functions right now. Please try again later. (Error: $errorDetail)";
        }
      }
    }
    return "I seem to be experiencing technical difficulties. Please check back soon.";
  }

}