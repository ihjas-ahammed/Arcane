// lib/src/providers/actions/ai_generation_actions.dart
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/services/ai_service.dart';
import 'package:arcane/src/models/game_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:collection/collection.dart'; // For whereNotNull
import 'dart:math' as math_random;

class AIGenerationActions {
  final GameProvider _provider;
  final AIService _aiService = AIService();
  final math_random.Random _random = math_random.Random();



  AIGenerationActions(this._provider);

  // Helper to generate a unique ID
  String _generateUniqueId(String type, String name, String? theme, int level) {
    final namePart = name.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    final themePart = theme ?? 'general';
    return 'gen_${type}_${themePart}_${namePart}_lvl${level}_${_random.nextInt(100000)}';
  }

  // --- Programmatic Stat Generation ---
  Map<String, dynamic> _generateEnemyStats(
      String id, String name, String? theme, String description, int level, String specificLocationKey) {
    
    return {
      'id': id,
      'name': name,
      'theme': theme,
      'locationKey': specificLocationKey, // Use the provided specific location key
      'minPlayerLevel': level,
      'health': (40 + level * 10) + _random.nextInt(20 + level * 5),
      'attack': (7 + level * 1.5).toInt() + _random.nextInt(3 + level ~/ 2),
      'defense': (2 + level * 0.5).toInt() + _random.nextInt(2 + level ~/ 3),
      'coinReward': (15 + level * 4) + _random.nextInt(20 + level * 4),
      'xpReward': (25 + level * 6) + _random.nextInt(30 + level * 6),
      'description': description,
    };
  }

  Map<String, dynamic> _generateArtifactStats(String id, String name,
      String? theme, String description, String icon, String type, int level) {
    int cost = (30 + level * 10) + _random.nextInt(100 + level * 15);
    Map<String, dynamic> stats = {
      'id': id,
      'name': name,
      'type': type, // weapon, armor, talisman
      'theme': theme,
      'description': description,
      'cost': cost,
      'icon': icon,
      'maxLevel': _random.nextInt(3) + 2, // Max level 2, 3, or 4
    };

    if (type == 'weapon') {
      stats['baseAtt'] = (level * 0.2 + 1).toInt() + _random.nextInt(level ~/ 4 + 1);
      stats['baseRunic'] = (level * 0.15 + (_random.nextBool() ? 1 : 0)).toInt() + _random.nextInt(level ~/ 5 + 1);
      stats['upgradeBonus'] = {"att": 1 + _random.nextInt(level ~/ 8 + 1)};
    } else if (type == 'armor') {
      stats['baseDef'] = (level * 0.18 + 1).toInt() + _random.nextInt(level ~/ 5 + 1);
      stats['baseHealth'] = (level * 1.2 + 3).toInt() + _random.nextInt(level * 1 + 4);
      stats['upgradeBonus'] = {"def": 1 + _random.nextInt(level ~/ 8 + 1), "health": 2 + _random.nextInt(level ~/ 4 + 1)};
    } else if (type == 'talisman') {
      stats['baseLuck'] = _random.nextInt(level ~/ 2 + 2) + 1; // e.g., max 1 + 1 = 2 at L1, 1+3 = 4 at L5
      stats['baseCooldown'] = _random.nextInt(level ~/ 2 + 1);
      stats['bonusXPMod'] = _random.nextDouble() * 0.02; // Max 2%
      stats['upgradeBonus'] = _random.nextBool() ? {"luck": 1} : {"cooldown": 1};
       if (_random.nextDouble() < 0.2) { // 20% chance for talisman to also have a small baseAtt or baseRunic
        if(_random.nextBool()){
          stats['baseAtt'] = (level * 0.1).toInt() + 1;
        } else {
          stats['baseRunic'] = (level * 0.1).toInt() + 1;
        }
      }
    }
    // Ensure all numeric stat fields are present, defaulting to 0 or null
    for (var key in ['baseAtt', 'baseRunic', 'baseDef', 'baseHealth', 'baseLuck', 'baseCooldown']) {
        stats.putIfAbsent(key, () => 0);
    }
    stats.putIfAbsent('bonusXPMod', () => 0.0);


    return stats;
  }

  Map<String, dynamic> _generatePowerupStats(
      String id, String name, String? theme, String description, String icon, int level) {
    String effectType = _random.nextBool() ? 'direct_damage' : 'heal_player';
    int effectValue;
    if (effectType == 'direct_damage') {
      effectValue = (level * 3 + 10) + _random.nextInt(level * 2 + 10);
    } else {
      effectValue = (level * 2 + 8) + _random.nextInt(level * 2 + 8);
    }
    return {
      'id': id,
      'name': name,
      'type': 'powerup',
      'theme': theme,
      'description': description,
      'cost': (15 + level * 5) + _random.nextInt(30 + level * 5),
      'icon': icon,
      'effectType': effectType,
      'effectValue': effectValue,
      'uses': 1,
    };
  }

 Map<String, dynamic> _generateLocationStats(
      String id, String name, String description, String iconEmoji, String? theme, int level) {
    String? bossId;
    // If there are enemies, try to pick one as a boss. Prioritize by level and theme if possible.
    // This now needs to consider that enemies might not be generated *yet* if this location is generated first.
    // So, bossId might often be null initially and set later, or chosen from existing enemies if appropriate.
    final potentialBosses = _provider.enemyTemplatesList
            .where((e) => (e.theme == theme || theme == null) && e.minPlayerLevel >= level && e.minPlayerLevel <= level + 2)
            .toList();
    if (potentialBosses.isNotEmpty) {
        bossId = potentialBosses[_random.nextInt(potentialBosses.length)].id;
    }
    // If no suitable existing boss, it will remain null. GameProvider can later assign a newly generated enemy as boss.

    return {
      'id': id,
      'name': name,
      'description': description,
      'minPlayerLevelToUnlock': level + _random.nextInt(2), // Lvl or Lvl+1
      'iconEmoji': iconEmoji,
      'associatedTheme': theme,
      'bossEnemyIdToUnlockNextLocation': bossId, // Can be null
    };
  }


  Future<void> generateGameContent(int levelForContent,
      {bool isManual = false,
      bool isInitial = false,
      String contentType = "all",
      int numLocationsToGenerate = 0,
      int numEnemiesToGenerate = 0,
      String? specificLocationKeyForEnemies,
      }) async {
    try {
      if (_provider.isGeneratingContent && !isManual && !isInitial) {
        print("[AIActions] generateGameContent skipped, already in progress for $contentType.");
        return;
      }
      _provider.setProviderAIGlobalLoading(true,
          progress: 0.0,
          statusMessage: "Initializing AI protocol for names/icons generation ($contentType)...");

      List<String?> activeThemes = _provider.mainTasks.map((t) => t.theme).toSet().toList();
      if (activeThemes.isEmpty) activeThemes.add(null); // Ensure at least general theme for generation requests

      // Build request for AI
      List<Map<String, dynamic>> aiRequestedItems = [];
      int actualNumLocations = numLocationsToGenerate > 0 ? numLocationsToGenerate : ((contentType == "all" || contentType == "locations") ? (isInitial ? 2 : 1) : 0);
      int actualNumEnemies = numEnemiesToGenerate > 0 ? numEnemiesToGenerate : ((contentType == "all" || contentType == "enemies") ? (isInitial ? 2 : 1) : 0); // Total enemies, not per theme for simplicity here
      int numArtifactsPerSubtypePerTheme = (contentType == "all" || contentType == "artifacts") ? (isInitial ? 1 : 1) : 0;
      int numPowerupsPerTheme = (contentType == "all" || contentType == "artifacts") ? (isInitial ? 1 : 0) : 0;


      if (actualNumLocations > 0) {
         for (int i = 0; i < actualNumLocations; i++) {
            aiRequestedItems.add({"itemCategory": "location", "themeHint": activeThemes[_random.nextInt(activeThemes.length)]});
         }
      }
      if (actualNumEnemies > 0) {
        for (int i = 0; i < actualNumEnemies; i++) {
          // If specificLocationKeyForEnemies is provided, we need its theme.
          // Otherwise, pick a random theme from activeThemes.
          String? themeForEnemy;
          if (specificLocationKeyForEnemies != null) {
            final loc = _provider.gameLocationsList.firstWhereOrNull((l) => l.id == specificLocationKeyForEnemies);
            themeForEnemy = loc?.associatedTheme; // Could be null if loc theme is null
          } else {
            themeForEnemy = activeThemes[_random.nextInt(activeThemes.length)];
          }
          aiRequestedItems.add({"itemCategory": "enemy", "themeHint": themeForEnemy});
        }
      }
      if (numArtifactsPerSubtypePerTheme > 0) {
        for (var theme in activeThemes) {
          for (int i = 0; i < numArtifactsPerSubtypePerTheme; i++) {
            aiRequestedItems.add({"itemCategory": "artifact_weapon", "themeHint": theme});
            aiRequestedItems.add({"itemCategory": "artifact_armor", "themeHint": theme});
            aiRequestedItems.add({"itemCategory": "artifact_talisman", "themeHint": theme});
          }
        }
      }
      if (numPowerupsPerTheme > 0) {
        for (var theme in activeThemes) {
          for (int i = 0; i < numPowerupsPerTheme; i++) {
            aiRequestedItems.add({"itemCategory": "powerup", "themeHint": theme});
          }
        }
      }
      
      if (aiRequestedItems.isEmpty) {
         _provider.setProviderAIGlobalLoading(false, progress: 1.0, statusMessage: "No items requested for AI generation for $contentType.");
         return;
      }

      final String prompt = """
Generate creative game content. For each item in the 'requestedItems' list, provide a name, a short evocative description, a theme (from the 'themeHint' or null if 'themeHint' is null/general), and a single relevant emoji icon (for artifacts, powerups, locations).
The 'itemCategory' specifies the type of item.
Return a single JSON object with one key: "generatedItems". "generatedItems" should be an array of objects, each corresponding to a requested item.
Each object in "generatedItems" MUST have:
- "itemCategory": string (must match the category from the request)
- "name": string (creative and fitting the category and theme)
- "description": string (short, max 80 chars)
- "theme": string or null (must match or be consistent with the 'themeHint' from the request)
- "icon": string (single emoji, applicable for itemCategory 'location', 'artifact_weapon', 'artifact_armor', 'artifact_talisman', 'powerup'. For 'enemy', this can be a simple descriptive emoji or null.)

Example Request:
{ "requestedItems": [ {"itemCategory": "location", "themeHint": "nature"}, {"itemCategory": "enemy", "themeHint": "nature"} ] }

Example Response:
{
  "generatedItems": [
    { "itemCategory": "location", "name": "Verdant Grove", "description": "A lush, ancient forest.", "theme": "nature", "icon": "🌳" },
    { "itemCategory": "enemy", "name": "Grove Spider", "description": "A large, camouflaged arachnid.", "theme": "nature", "icon": "🕷️" }
  ]
}
Do NOT generate stats, costs, levels, or IDs. Only name, description, theme, and icon (where applicable).
Ensure the 'theme' in your response is the same as the 'themeHint' provided for that item, or null if the 'themeHint' was null.
Existing content IDs to avoid duplicating names for (informational only, focus on unique names):
Locations: ${_provider.gameLocationsList.map((e) => e.name).join(', ')}
Enemies: ${_provider.enemyTemplatesList.map((e) => e.name).join(', ')}
Artifacts: ${_provider.artifactTemplatesList.map((e) => e.name).join(', ')}

Request:
${({"requestedItems": aiRequestedItems})}
""";
      _provider.setProviderAIGlobalLoading(true, progress: 0.2, statusMessage: "Contacting AI for names & icons ($contentType)...");
      

      final Map<String, dynamic> aiResponse = await _aiService.makeAICall(
        prompt: prompt,
        currentApiKeyIndex: _provider.apiKeyIndex,
        onNewApiKeyIndex: _provider.setProviderApiKeyIndex,
        onLog: (log) {
          print("[AI Service Log - Content Type: $contentType]: $log");
          _logToGame(log);
        },
      );
       _provider.setProviderAIGlobalLoading(true, progress: 0.5, statusMessage: "AI response received. Processing $contentType items...");

      final List<Map<String, dynamic>> generatedAiItems =
          (aiResponse['generatedItems'] as List?)?.map((item) => item as Map<String, dynamic>).toList() ?? [];

      List<EnemyTemplate> newEnemies = [];
      List<ArtifactTemplate> newArtifacts = [];
      List<GameLocation> newLocations = [];

      for (var aiItem in generatedAiItems) {
        final String itemCategory = aiItem['itemCategory'] as String? ?? 'unknown';
        final String itemName = aiItem['name'] as String? ?? 'Unnamed';
        final String itemDescription = aiItem['description'] as String? ?? 'No description.';
        final String? itemTheme = aiItem['theme'] as String?; // Can be null
        final String itemIcon = aiItem['icon'] as String? ?? '❓';

        if (itemName == 'Unnamed' || _nameExists(itemName, itemCategory)) {
            print("[AIActions] Skipping item due to 'Unnamed' or duplicate name: $itemName (Category: $itemCategory)");
            continue; // Skip if name is default or already exists for that category
        }


        if (itemCategory == 'location') {
          final id = _generateUniqueId('loc', itemName, itemTheme, levelForContent);
          newLocations.add(GameLocation.fromJson(_generateLocationStats(id, itemName, itemDescription, itemIcon, itemTheme, levelForContent)));
        } else if (itemCategory == 'enemy') {
          final id = _generateUniqueId('enemy', itemName, itemTheme, levelForContent);
          final String locKeyForEnemy = specificLocationKeyForEnemies ?? 
                                        _provider.gameLocationsList.firstWhereOrNull((l) => l.associatedTheme == itemTheme)?.id ?? 
                                        _provider.gameLocationsList.firstOrNull?.id ?? 
                                        "default_zone_error";
          newEnemies.add(EnemyTemplate.fromJson(_generateEnemyStats(id, itemName, itemTheme, itemDescription, levelForContent, locKeyForEnemy)));
        } else if (itemCategory.startsWith('artifact_')) {
          final type = itemCategory.split('_')[1]; // weapon, armor, talisman
          final id = _generateUniqueId('art', itemName, itemTheme, levelForContent);
          newArtifacts.add(ArtifactTemplate.fromJson(_generateArtifactStats(id, itemName, itemTheme, itemDescription, itemIcon, type, levelForContent)));
        } else if (itemCategory == 'powerup') {
          final id = _generateUniqueId('pwp', itemName, itemTheme, levelForContent);
          newArtifacts.add(ArtifactTemplate.fromJson(_generatePowerupStats(id, itemName, itemTheme, itemDescription, itemIcon, levelForContent)));
        }
      }
      _provider.setProviderAIGlobalLoading(true, progress: 0.8, statusMessage: "Finalizing generated $contentType content...");

      if (newLocations.isNotEmpty) {
        _provider.setProviderState(gameLocationsList: [..._provider.gameLocationsList, ...newLocations], doPersist: false);
      }
      if (newEnemies.isNotEmpty) {
        _provider.setProviderState(enemyTemplatesList: [..._provider.enemyTemplatesList, ...newEnemies], doPersist: false);
      }
      if (newArtifacts.isNotEmpty) {
        _provider.setProviderState(artifactTemplatesList: [..._provider.artifactTemplatesList, ...newArtifacts], doPersist: false);
      }
      
      if (newLocations.isNotEmpty || newEnemies.isNotEmpty || newArtifacts.isNotEmpty) {
         _logToGame("<span style=\"color:${AppTheme.fhAccentGreen.value.toRadixString(16).substring(2)};\">AI has infused the world with new $contentType elements for level $levelForContent.</span>");
         _provider.setProviderState(doPersist: true, doNotify: true); // Trigger a single save and notify
      } else {
         _logToGame("<span style=\"color:var(--fh-accent-orange);\">AI generation for $contentType (L$levelForContent) did not yield new unique content.</span>");
      }

    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      print("[AIActions] CRITICAL ERROR in generateGameContent ($contentType): $errorMessage");
      if (kDebugMode) print("[AIActions] StackTrace for generateGameContent ($contentType) error: $stackTrace");
      _logToGame("<span style=\"color:${AppTheme.fhAccentRed.value.toRadixString(16).substring(2)};\">AI content generation for $contentType failed critically: $errorMessage</span>");
    } finally {
      _provider.setProviderAIGlobalLoading(false,
          progress: 1.0,
          statusMessage: "Content generation protocol for $contentType finished.");
    }
  }

  bool _nameExists(String name, String itemCategory) {
    if (itemCategory == 'location') {
        return _provider.gameLocationsList.any((loc) => loc.name.toLowerCase() == name.toLowerCase());
    } else if (itemCategory == 'enemy') {
        return _provider.enemyTemplatesList.any((enemy) => enemy.name.toLowerCase() == name.toLowerCase());
    } else if (itemCategory.startsWith('artifact_') || itemCategory == 'powerup') {
        return _provider.artifactTemplatesList.any((art) => art.name.toLowerCase() == name.toLowerCase());
    }
    return false;
}


  void _logToGame(String logMessage) {
    if (kDebugMode) print("[AIActions - _logToGame]: $logMessage");
    _provider.setProviderState(
        currentGame: CurrentGame(
          enemy: _provider.currentGame.enemy,
          playerCurrentHp: _provider.currentGame.playerCurrentHp,
          log: [..._provider.currentGame.log, logMessage],
          currentPlaceKey: _provider.currentGame.currentPlaceKey,
        ),
        doPersist: false, // Persisted at the end of generateGameContent or when subquests are added
        doNotify: true);
  }

  Future<void> triggerAISubquestGeneration(MainTask mainTaskForSubquests,
      String generationMode, String userInput, int numSubquests) async {
    if (_provider.isGeneratingSubquests) {
      print("[AIActions] triggerAISubquestGeneration skipped, already in progress for task '${mainTaskForSubquests.name}'.");
      return;
    }
    _provider.setProviderAISubquestLoading(true);
    print("[AIActions] Starting triggerAISubquestGeneration for task '${mainTaskForSubquests.name}'. Mode: $generationMode, User Input: '$userInput', Num Subquests: $numSubquests");

    try {
      print("[AIActions] Attempting to call _aiService.generateAISubquests for task '${mainTaskForSubquests.name}'.");
      final generatedSubquestsRaw = await _aiService.generateAISubquests(
        mainTaskName: mainTaskForSubquests.name,
        mainTaskDescription: mainTaskForSubquests.description,
        mainTaskTheme: mainTaskForSubquests.theme,
        generationMode: generationMode,
        userInput: userInput,
        numSubquests: numSubquests,
        currentApiKeyIndex: _provider.apiKeyIndex,
        onNewApiKeyIndex: (newIndex) {
          print("[AIActions] API key index updated to $newIndex during subquest gen for task '${mainTaskForSubquests.name}'.");
          _provider.setProviderApiKeyIndex(newIndex);
        },
        onLog: (log) {
          print("[AI Service Log - Subquests - Task: ${mainTaskForSubquests.name}]: $log");
          _logToGame(log);
        },
      );

      print("[AIActions] _aiService.generateAISubquests returned for task '${mainTaskForSubquests.name}'. Raw data length: ${generatedSubquestsRaw.length}");
      if (kDebugMode && generatedSubquestsRaw.isNotEmpty) {
        print("[AIActions] Raw subquest data for task '${mainTaskForSubquests.name}': $generatedSubquestsRaw");
      }

      final List<SubTask> newSubTasksForParent = [];
      for (var subquestData in generatedSubquestsRaw) {
        if (kDebugMode) print("[AIActions] Processing raw subquest data: $subquestData");
        if (subquestData is! Map<String, dynamic>) {
          print("[AIActions] Skipping invalid raw subquest data (null or not a Map): $subquestData");
          continue;
        }

        final List<Map<String, dynamic>> subSubTasksDataList =
            (subquestData['subSubTasksData'] as List<dynamic>? ?? [])
                .map((item) {
                  if (item is Map<String, dynamic>) return item;
                  print("[AIActions] Invalid sub-sub-task data item, expected Map<String, dynamic>, got ${item.runtimeType}: $item");
                  return null; 
                })
                .whereNotNull()
                .toList();

        final List<SubSubTask> currentSubSubTasks = [];
        for (int i = 0; i < subSubTasksDataList.length; i++) {
          final sssData = subSubTasksDataList[i];
          if (kDebugMode) print("[AIActions] Processing raw sub-sub-task data: $sssData");
          try {
            currentSubSubTasks.add(SubSubTask(
              id: 'ssub_${DateTime.now().millisecondsSinceEpoch}_${newSubTasksForParent.length}_$i',
              name: sssData['name'] as String? ?? 'Unnamed Sub-Sub-Task',
              isCountable: sssData['isCountable'] as bool? ?? false,
              targetCount: (sssData['isCountable'] as bool? ?? false)
                  ? (sssData['targetCount'] as int? ?? 1)
                  : 0,
            ));
          } catch (e, s) {
            print("[AIActions] Error parsing SubSubTask from data: $sssData. Error: $e. Stacktrace: $s");
          }
        }

        try {
          final newSubTask = SubTask(
            id: 'sub_${DateTime.now().millisecondsSinceEpoch}_${newSubTasksForParent.length}',
            name: subquestData['name'] as String? ?? 'Unnamed Sub-Task',
            isCountable: subquestData['isCountable'] as bool? ?? false,
            targetCount: (subquestData['isCountable'] as bool? ?? false)
                ? (subquestData['targetCount'] as int? ?? 1)
                : 0,
            subSubTasks: currentSubSubTasks,
          );
          newSubTasksForParent.add(newSubTask);
          if (kDebugMode) print("[AIActions] Created SubTask: ${newSubTask.name} with ${currentSubSubTasks.length} sub-sub-tasks.");
        } catch (e, s) {
          print("[AIActions] Error parsing SubTask from data: $subquestData. Error: $e. Stacktrace: $s");
        }
      }

      if (newSubTasksForParent.isEmpty && generatedSubquestsRaw.isNotEmpty) {
        print("[AIActions] Warning: Raw subquests were received, but no valid SubTasks could be parsed for task '${mainTaskForSubquests.name}'.");
        _logToGame("<span style=\"color:var(--fh-accent-orange);\">AI returned sub-quest data for '${mainTaskForSubquests.name}', but it could not be fully processed.</span>");
      }

      final newMainTasks = _provider.mainTasks.map((task) {
        if (task.id == mainTaskForSubquests.id) {
          return MainTask(
            id: task.id,
            name: task.name,
            description: task.description,
            theme: task.theme,
            colorHex: task.colorHex,
            streak: task.streak,
            dailyTimeSpent: task.dailyTimeSpent,
            lastWorkedDate: task.lastWorkedDate,
            subTasks: [...task.subTasks, ...newSubTasksForParent],
          );
        }
        return task;
      }).toList();

      print("[AIActions] Generated ${newSubTasksForParent.length} new valid sub-quests for task '${mainTaskForSubquests.name}'.");

      _provider.setProviderState(
          mainTasks: newMainTasks,
          currentGame: CurrentGame(
            enemy: _provider.currentGame.enemy,
            playerCurrentHp: _provider.currentGame.playerCurrentHp,
            log: [
              ..._provider.currentGame.log,
              if (newSubTasksForParent.isNotEmpty)
                "<span style=\"color:${AppTheme.fhAccentGreen.value.toRadixString(16).substring(2)};\">AI successfully generated ${newSubTasksForParent.length} new sub-quests for '${mainTaskForSubquests.name}'.</span>"
              else if (generatedSubquestsRaw.isNotEmpty) 
                "<span style=\"color:var(--fh-accent-orange);\">AI sub-quest generation for '${mainTaskForSubquests.name}' returned data, but it could not be fully processed.</span>"
              else 
                "<span style=\"color:var(--fh-accent-orange);\">AI sub-quest generation for '${mainTaskForSubquests.name}' did not yield new quests.</span>"
            ],
            currentPlaceKey: _provider.currentGame.currentPlaceKey,
          ),
          doPersist: true, 
          doNotify: true);
      print("[AIActions] Subquest state update successful for task '${mainTaskForSubquests.name}', data persisted.");
    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      print("[AIActions] CRITICAL ERROR in triggerAISubquestGeneration for task '${mainTaskForSubquests.name}': $errorMessage");
      if (kDebugMode) print("[AIActions] StackTrace for triggerAISubquestGeneration error: $stackTrace");
      _logToGame("<span style=\"color:${AppTheme.fhAccentRed.value.toRadixString(16).substring(2)};\">AI sub-quest generation for '${mainTaskForSubquests.name}' failed critically: $errorMessage</span>");
    } finally {
      _provider.setProviderAISubquestLoading(false);
      print("[AIActions] Finished triggerAISubquestGeneration for task '${mainTaskForSubquests.name}'.");
    }
  }
}