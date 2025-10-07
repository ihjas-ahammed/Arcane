// lib/src/models/game_models.dart
// import 'package:arcane/src/utils/constants.dart'; // No longer needed here for constants
import 'package:collection/collection.dart'; // For firstWhereOrNull
import 'package:flutter/material.dart'; // For Color
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/theme/app_theme.dart'; // For MdiIcons

class MainTask {
  String id;
  String name;
  String description;
  String theme;
  String colorHex; // e.g., "FF64FFDA"
  int streak;
  int dailyTimeSpent;
  String? lastWorkedDate;
  List<SubTask> subTasks;

  MainTask({
    required this.id,
    required this.name,
    required this.description,
    required this.theme,
    this.colorHex = "FF00F8F8", // Default to a vibrant cyan
    this.streak = 0,
    this.dailyTimeSpent = 0,
    this.lastWorkedDate,
    List<SubTask>? subTasks,
  }) : subTasks = subTasks ?? [];

  // Factory from MainTaskTemplate (which is now in this file)
  factory MainTask.fromTemplate(MainTaskTemplate template) {
    return MainTask(
      id: template.id,
      name: template.name,
      description: template.description,
      theme: template.theme,
      colorHex: template.colorHex,
    );
  }

  factory MainTask.fromJson(Map<String, dynamic> json) {
    return MainTask(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      theme: json['theme'] as String,
      colorHex: json['colorHex'] as String? ?? "FF00F8F8",
      streak: json['streak'] as int? ?? 0,
      dailyTimeSpent: json['dailyTimeSpent'] as int? ?? 0,
      lastWorkedDate: json['lastWorkedDate'] as String?,
      subTasks: (json['subTasks'] as List<dynamic>?)
              ?.map(
                  (stJson) => SubTask.fromJson(stJson as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'theme': theme,
      'colorHex': colorHex,
      'streak': streak,
      'dailyTimeSpent': dailyTimeSpent,
      'lastWorkedDate': lastWorkedDate,
      'subTasks': subTasks.map((st) => st.toJson()).toList(),
    };
  }

  Color get taskColor {
    try {
      return Color(int.parse("0x$colorHex"));
    } catch (e) {
      return AppTheme.fhAccentTealFixed; // Fallback color
    }
  }
}

class SubTask {
  String id;
  String name;
  bool completed;
  int currentTimeSpent; // Storing as minutes
  String? completedDate;
  bool isCountable;
  int targetCount;
  int currentCount;
  List<SubSubTask> subSubTasks;

  SubTask({
    required this.id,
    required this.name,
    this.completed = false,
    this.currentTimeSpent = 0,
    this.completedDate,
    this.isCountable = false,
    this.targetCount = 0,
    this.currentCount = 0,
    List<SubSubTask>? subSubTasks,
  }) : subSubTasks = subSubTasks ?? [];

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'] as String,
      name: json['name'] as String,
      completed: json['completed'] as bool? ?? false,
      currentTimeSpent: json['currentTimeSpent'] as int? ?? 0,
      completedDate: json['completedDate'] as String?,
      isCountable: json['isCountable'] as bool? ?? false,
      targetCount: json['targetCount'] as int? ?? 0,
      currentCount: json['currentCount'] as int? ?? 0,
      subSubTasks: (json['subSubTasks'] as List<dynamic>?)
              ?.map((sssJson) =>
                  SubSubTask.fromJson(sssJson as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'completed': completed,
      'currentTimeSpent': currentTimeSpent,
      'completedDate': completedDate,
      'isCountable': isCountable,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'subSubTasks': subSubTasks.map((sss) => sss.toJson()).toList(),
    };
  }
}

class SubSubTask {
  String id;
  String name;
  bool completed;
  bool isCountable;
  int targetCount;
  int currentCount;
  String? completionTimestamp; // NEW: For logging time of completion

  SubSubTask({
    required this.id,
    required this.name,
    this.completed = false,
    this.isCountable = false,
    this.targetCount = 0,
    this.currentCount = 0,
    this.completionTimestamp, // NEW
  });

  factory SubSubTask.fromJson(Map<String, dynamic> json) {
    return SubSubTask(
      id: json['id'] as String,
      name: json['name'] as String,
      completed: json['completed'] as bool? ?? false,
      isCountable: json['isCountable'] as bool? ?? false,
      targetCount: json['targetCount'] as int? ?? 0,
      currentCount: json['currentCount'] as int? ?? 0,
      completionTimestamp: json['completionTimestamp'] as String?, // NEW
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'completed': completed,
      'isCountable': isCountable,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'completionTimestamp': completionTimestamp, // NEW
    };
  }
}

class OwnedArtifact {
  String uniqueId;
  String templateId;
  int currentLevel;
  int? uses;

  OwnedArtifact({
    required this.uniqueId,
    required this.templateId,
    required this.currentLevel,
    this.uses,
  });

  factory OwnedArtifact.fromJson(Map<String, dynamic> json) {
    return OwnedArtifact(
      uniqueId: json['uniqueId'] as String,
      templateId: json['templateId'] as String,
      currentLevel: json['currentLevel'] as int,
      uses: json['uses'] as int?,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'uniqueId': uniqueId,
      'templateId': templateId,
      'currentLevel': currentLevel,
      'uses': uses,
    };
  }
}

class CurrentGame {
  EnemyTemplate? enemy;
  double playerCurrentHp;
  List<String> log;
  String? currentPlaceKey;

  CurrentGame({
    this.enemy,
    required this.playerCurrentHp,
    List<String>? log,
    this.currentPlaceKey,
  }) : log = log ?? [];

  factory CurrentGame.fromJson(
      Map<String, dynamic> json, List<EnemyTemplate> allEnemyTemplates) {
    EnemyTemplate? currentEnemy;
    if (json['enemy'] != null) {
      final enemyData = json['enemy'] as Map<String, dynamic>;
      currentEnemy =
          allEnemyTemplates.firstWhereOrNull((t) => t.id == enemyData['id']) ??
              EnemyTemplate.fromJson(enemyData);
    }
    return CurrentGame(
      enemy: currentEnemy,
      playerCurrentHp: (json['playerCurrentHp'] as num).toDouble(),
      log: (json['log'] as List<dynamic>?)
              ?.map((entry) => entry as String)
              .toList() ??
          [],
      currentPlaceKey: json['currentPlaceKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enemy': enemy?.toJson(),
      'playerCurrentHp': playerCurrentHp,
      'log': log,
      'currentPlaceKey': currentPlaceKey,
    };
  }
}

class GameSettings {
  bool descriptionsVisible;
  bool dailyAutoGenerateContent; // Renamed from autoGenerateContent
  int wakeupTimeHour;
  int wakeupTimeMinute;

  GameSettings({
    this.descriptionsVisible = true,
    this.dailyAutoGenerateContent = true, // Renamed
    this.wakeupTimeHour = 7,
    this.wakeupTimeMinute = 0,
  });

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      descriptionsVisible: json['descriptionsVisible'] as bool? ?? true,
      dailyAutoGenerateContent: json['dailyAutoGenerateContent'] as bool? ??
          json['autoGenerateContent'] as bool? ??
          true, // Handle legacy name
      wakeupTimeHour: json['wakeupTimeHour'] as int? ?? 7,
      wakeupTimeMinute: json['wakeupTimeMinute'] as int? ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'descriptionsVisible': descriptionsVisible,
      'dailyAutoGenerateContent': dailyAutoGenerateContent, // Renamed
      'wakeupTimeHour': wakeupTimeHour,
      'wakeupTimeMinute': wakeupTimeMinute,
    };
  }
}

class ActiveTimerInfo {
  DateTime startTime;
  double accumulatedDisplayTime; // In seconds
  bool isRunning;
  String type;
  String mainTaskId;

  ActiveTimerInfo({
    required this.startTime,
    this.accumulatedDisplayTime = 0,
    required this.isRunning,
    required this.type,
    required this.mainTaskId,
  });

  factory ActiveTimerInfo.fromJson(Map<String, dynamic> json) {
    return ActiveTimerInfo(
      startTime: DateTime.parse(json['startTime'] as String),
      accumulatedDisplayTime:
          (json['accumulatedDisplayTime'] as num? ?? 0).toDouble(),
      isRunning: json['isRunning'] as bool? ?? false,
      type: json['type'] as String? ?? 'subtask',
      mainTaskId: json['mainTaskId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'accumulatedDisplayTime': accumulatedDisplayTime,
      'isRunning': isRunning,
      'type': type,
      'mainTaskId': mainTaskId,
    };
  }
}

class PlayerStat {
  final String name;
  final String description;
  final String icon; // Can be an emoji or an MDI icon name (e.g., "mdi-sword")
  double value;
  double base;

  PlayerStat({
    required this.name,
    required this.description,
    required this.icon,
    required this.value,
    required this.base,
  });

  factory PlayerStat.fromJson(Map<String, dynamic> json) {
    double parseNumToDouble(dynamic val, double defaultValue) {
      if (val == null) return defaultValue;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? defaultValue;
      return defaultValue;
    }

    String parseString(dynamic val, String defaultValue) {
      if (val == null) return defaultValue;
      if (val is String) return val;
      return val.toString();
    }

    return PlayerStat(
      name: parseString(json['name'], 'Unknown Stat'),
      description: parseString(json['description'], 'No description.'),
      icon: parseString(
          json['icon'],
          MdiIcons.helpCircleOutline.codePoint
              .toString()), // Use MDI icon as string default
      value: parseNumToDouble(json['value'], 0.0),
      base: parseNumToDouble(json['base'], 0.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'value': value,
      'base': base,
    };
  }
}

class ArtifactTemplate {
  final String id;
  final String name;
  final String type;
  final String? theme;
  final String description;
  final int cost;
  final String icon; // Can be an emoji or an MDI icon name
  final int? baseAtt;
  final int? baseRunic;
  final int? baseDef;
  final int? baseHealth;
  final int? baseLuck;
  final int? baseCooldown;
  final double? bonusXPMod;
  final Map<String, int>? upgradeBonus;
  final int? maxLevel;
  final String? effectType;
  final int? effectValue;
  final int? uses;

  ArtifactTemplate({
    required this.id,
    required this.name,
    required this.type,
    this.theme,
    required this.description,
    required this.cost,
    required this.icon,
    this.baseAtt,
    this.baseRunic,
    this.baseDef,
    this.baseHealth,
    this.baseLuck,
    this.baseCooldown,
    this.bonusXPMod,
    this.upgradeBonus,
    this.maxLevel,
    this.effectType,
    this.effectValue,
    this.uses,
  });

  factory ArtifactTemplate.fromJson(Map<String, dynamic> json) {
    Map<String, int>? parsedUpgradeBonus;
    if (json['upgradeBonus'] != null && json['upgradeBonus'] is Map) {
      parsedUpgradeBonus = {};
      try {
        (json['upgradeBonus'] as Map<String, dynamic>).forEach((key, value) {
          if (value is num) {
            parsedUpgradeBonus![key] = value.toInt();
          } else if (value is String) {
            parsedUpgradeBonus![key] = int.tryParse(value) ?? 0;
          }
        });
      } catch (e) {/* ... */}
    }
    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return ArtifactTemplate(
      id: json['id'] as String? ??
          'unknown_id_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Unknown Artifact',
      type: json['type'] as String? ?? 'unknown',
      theme: json['theme'] as String?,
      description: json['description'] as String? ?? 'No description.',
      cost: parseInt(json['cost']) ?? 0,
      icon: json['icon'] as String? ??
          MdiIcons.treasureChest.codePoint
              .toString(), // Default to MDI icon string
      baseAtt: parseInt(json['baseAtt']),
      baseRunic: parseInt(json['baseRunic']),
      baseDef: parseInt(json['baseDef']),
      baseHealth: parseInt(json['baseHealth']),
      baseLuck: parseInt(json['baseLuck']),
      baseCooldown: parseInt(json['baseCooldown']),
      bonusXPMod: parseDouble(json['bonusXPMod']),
      upgradeBonus: parsedUpgradeBonus,
      maxLevel: parseInt(json['maxLevel']),
      effectType: json['effectType'] as String?,
      effectValue: parseInt(json['effectValue']),
      uses: parseInt(json['uses']),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'theme': theme,
      'description': description,
      'cost': cost,
      'icon': icon,
      'baseAtt': baseAtt,
      'baseRunic': baseRunic,
      'baseDef': baseDef,
      'baseHealth': baseHealth,
      'baseLuck': baseLuck,
      'baseCooldown': baseCooldown,
      'bonusXPMod': bonusXPMod,
      'upgradeBonus': upgradeBonus,
      'maxLevel': maxLevel,
      'effectType': effectType,
      'effectValue': effectValue,
      'uses': uses,
    };
  }
}

class EnemyTemplate {
  final String id;
  final String name;
  final String? theme;
  final String? locationKey;
  final int minPlayerLevel;
  final int health;
  final int attack;
  final int defense;
  int hp;
  final int coinReward;
  final int xpReward;
  final String description;

  EnemyTemplate({
    required this.id,
    required this.name,
    this.theme,
    this.locationKey,
    required this.minPlayerLevel,
    required this.health,
    required this.attack,
    required this.defense,
    int? hp,
    required this.coinReward,
    required this.xpReward,
    required this.description,
  }) : hp = hp ?? health;

  factory EnemyTemplate.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    final maxHealth = parseInt(json['health']) ?? 10;
    return EnemyTemplate(
      id: json['id'] as String? ??
          'unknown_enemy_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Nameless Foe',
      theme: json['theme'] as String?,
      locationKey: json['locationKey'] as String?,
      minPlayerLevel: parseInt(json['minPlayerLevel']) ?? 1,
      health: maxHealth,
      hp: parseInt(json['hp']) ?? maxHealth,
      attack: parseInt(json['attack']) ?? 1,
      defense: parseInt(json['defense']) ?? 0,
      coinReward: parseInt(json['coinReward']) ?? 0,
      xpReward: parseInt(json['xpReward']) ?? 0,
      description: json['description'] as String? ?? 'A mysterious enemy.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'theme': theme,
      'locationKey': locationKey,
      'minPlayerLevel': minPlayerLevel,
      'health': health,
      'hp': hp,
      'attack': attack,
      'defense': defense,
      'coinReward': coinReward,
      'xpReward': xpReward,
      'description': description,
    };
  }
}

class Rune {
  String id;
  String name;
  String description;
  String icon;
  String type;
  String effectType;
  double effectValue;
  double? effectDuration;
  String? targetStat;
  int cost;
  int? requiredLevel;

  Rune({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
    required this.effectType,
    required this.effectValue,
    this.effectDuration,
    this.targetStat,
    required this.cost,
    this.requiredLevel,
  });

  factory Rune.fromJson(Map<String, dynamic> json) {
    return Rune(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      type: json['type'] as String,
      effectType: json['effectType'] as String,
      effectValue: (json['effectValue'] as num).toDouble(),
      effectDuration: (json['effectDuration'] as num?)?.toDouble(),
      targetStat: json['targetStat'] as String?,
      cost: json['cost'] as int,
      requiredLevel: json['requiredLevel'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'type': type,
      'effectType': effectType,
      'effectValue': effectValue,
      'effectDuration': effectDuration,
      'targetStat': targetStat,
      'cost': cost,
      'requiredLevel': requiredLevel,
    };
  }
}

class OwnedRune {
  String uniqueId;
  String runeId;
  bool isActive;

  OwnedRune({
    required this.uniqueId,
    required this.runeId,
    this.isActive = false,
  });

  factory OwnedRune.fromJson(Map<String, dynamic> json) {
    return OwnedRune(
      uniqueId: json['uniqueId'] as String,
      runeId: json['runeId'] as String,
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uniqueId': uniqueId,
      'runeId': runeId,
      'isActive': isActive,
    };
  }
}

// Moved from constants.dart
class MainTaskTemplate {
  final String id;
  final String name;
  final String description;
  final String theme;
  final String colorHex;

  MainTaskTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.theme,
    this.colorHex = "FF00F8F8", // Default Cyan
  });
}

// Moved from constants.dart
class GameLocation {
  final String id; // Changed key to id for consistency
  final String name;
  final String description;
  final int minPlayerLevelToUnlock;
  final String iconEmoji; // Using specific field for emoji
  final String? associatedTheme;
  final String?
      bossEnemyIdToUnlockNextLocation; // ID of an enemy in this location
  bool isCleared; // Added field for tracking if location is cleared

  GameLocation({
    required this.id,
    required this.name,
    required this.description,
    this.minPlayerLevelToUnlock = 1,
    required this.iconEmoji,
    this.associatedTheme,
    this.bossEnemyIdToUnlockNextLocation,
    this.isCleared = false, // Default to not cleared
  });

  factory GameLocation.fromJson(Map<String, dynamic> json) {
    return GameLocation(
      id: json['id'] as String? ??
          'loc_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Unknown Area',
      description: json['description'] as String? ?? 'A mysterious place.',
      minPlayerLevelToUnlock: json['minPlayerLevelToUnlock'] as int? ?? 1,
      iconEmoji: json['iconEmoji'] as String? ?? '❓',
      associatedTheme: json['associatedTheme'] as String?,
      bossEnemyIdToUnlockNextLocation:
          json['bossEnemyIdToUnlockNextLocation'] as String?,
      isCleared: json['isCleared'] as bool? ?? false, // Load isCleared status
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'minPlayerLevelToUnlock': minPlayerLevelToUnlock,
      'iconEmoji': iconEmoji,
      'associatedTheme': associatedTheme,
      'bossEnemyIdToUnlockNextLocation': bossEnemyIdToUnlockNextLocation,
      'isCleared': isCleared, // Save isCleared status
    };
  }
}

// Park Management Models
class DinosaurSpecies {
  final String id;
  final String name;
  final String description;
  final String diet; // "carnivore" or "herbivore"
  final int incubationCostDollars; // Park currency (Dollars)
  final int fossilExcavationEnergyCost; // Player energy
  final int baseRating; // Contribution to park rating
  final double comfortThreshold; // Min comfort % to be happy
  final int socialNeedsMin; // Min number of same species
  final int socialNeedsMax; // Max number of same species
  final int enclosureSizeNeeds; // Arbitrary units (e.g., squares)
  final String icon; // Emoji or MDI icon name
  final int minPlayerLevelToUnlock;

  DinosaurSpecies({
    required this.id,
    required this.name,
    required this.description,
    required this.diet,
    required this.incubationCostDollars,
    required this.fossilExcavationEnergyCost,
    required this.baseRating,
    required this.comfortThreshold,
    required this.socialNeedsMin,
    required this.socialNeedsMax,
    required this.enclosureSizeNeeds,
    required this.icon,
    this.minPlayerLevelToUnlock = 1,
  });

  factory DinosaurSpecies.fromJson(Map<String, dynamic> json) {
    return DinosaurSpecies(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      diet: json['diet'] as String,
      incubationCostDollars: json['incubationCostDollars'] as int? ??
          json['incubationCost'] as int, // Handle legacy 'incubationCost'
      fossilExcavationEnergyCost:
          json['fossilExcavationEnergyCost'] as int? ??
              json['fossilExcavationCost']
                  as int, // Handle legacy 'fossilExcavationCost'
      baseRating: json['baseRating'] as int,
      comfortThreshold: (json['comfortThreshold'] as num).toDouble(),
      socialNeedsMin: json['socialNeedsMin'] as int,
      socialNeedsMax: json['socialNeedsMax'] as int,
      enclosureSizeNeeds: json['enclosureSizeNeeds'] as int,
      icon: json['icon'] as String,
      minPlayerLevelToUnlock: json['minPlayerLevelToUnlock'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'diet': diet,
      'incubationCostDollars': incubationCostDollars,
      'fossilExcavationEnergyCost': fossilExcavationEnergyCost,
      'baseRating': baseRating,
      'comfortThreshold': comfortThreshold,
      'socialNeedsMin': socialNeedsMin,
      'socialNeedsMax': socialNeedsMax,
      'enclosureSizeNeeds': enclosureSizeNeeds,
      'icon': icon,
      'minPlayerLevelToUnlock': minPlayerLevelToUnlock,
    };
  }
}

class BuildingTemplate {
  final String id;
  final String name;
  final String type; // e.g., "enclosure", "hatchery", "fossil_center", "food_station", "visitor_center", "power_plant"
  final int costDollars; // Park currency (Dollars)
  final String icon; // MDI icon name
  final int? capacity; // e.g., number of dinos for enclosure, incubation slots for hatchery
  final int? operationalCostPerMinuteDollars; // Park currency
  final int? incomePerMinuteDollars; // Park currency (for visitor centers, etc.)
  final int? parkRatingBoost;
  final int? sizeX; // Grid size X
  final int? sizeY; // Grid size Y
  final int? powerRequired; // Power units this building consumes when operational
  final int? powerOutput; // Power units this building generates (for power plants)

  BuildingTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.costDollars,
    required this.icon,
    this.capacity,
    this.operationalCostPerMinuteDollars,
    this.incomePerMinuteDollars,
    this.parkRatingBoost,
    this.sizeX,
    this.sizeY,
    this.powerRequired,
    this.powerOutput,
  });

  factory BuildingTemplate.fromJson(Map<String, dynamic> json) {
    return BuildingTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      costDollars: json['costDollars'] as int? ??
          json['cost'] as int, // Handle legacy 'cost'
      icon: json['icon'] as String,
      capacity: json['capacity'] as int?,
      operationalCostPerMinuteDollars:
          json['operationalCostPerMinuteDollars'] as int? ??
              json['operationalCostPerMinute'] as int?,
      incomePerMinuteDollars: json['incomePerMinuteDollars'] as int? ??
          json['incomePerMinute'] as int?,
      parkRatingBoost: json['parkRatingBoost'] as int?,
      sizeX: json['sizeX'] as int?,
      sizeY: json['sizeY'] as int?,
      powerRequired: json['powerRequired'] as int?,
      powerOutput: json['powerOutput'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'costDollars': costDollars,
      'icon': icon,
      'capacity': capacity,
      'operationalCostPerMinuteDollars': operationalCostPerMinuteDollars,
      'incomePerMinuteDollars': incomePerMinuteDollars,
      'parkRatingBoost': parkRatingBoost,
      'sizeX': sizeX,
      'sizeY': sizeY,
      'powerRequired': powerRequired,
      'powerOutput': powerOutput,
    };
  }
}

class OwnedBuilding {
  final String uniqueId;
  final String templateId;
  // GridPosition position; // Placeholder for later grid system
  List<String> dinosaurUniqueIds; // For enclosures
  int? currentFoodLevel; // For food stations (0-100)
  bool isOperational;

  OwnedBuilding({
    required this.uniqueId,
    required this.templateId,
    // required this.position,
    List<String>? dinosaurUniqueIds,
    this.currentFoodLevel,
    this.isOperational = true,
  }) : dinosaurUniqueIds = dinosaurUniqueIds ?? [];

  factory OwnedBuilding.fromJson(Map<String, dynamic> json) {
    return OwnedBuilding(
      uniqueId: json['uniqueId'] as String,
      templateId: json['templateId'] as String,
      // position: GridPosition.fromJson(json['position']),
      dinosaurUniqueIds: (json['dinosaurUniqueIds'] as List<dynamic>?)
              ?.map((id) => id as String)
              .toList() ??
          [],
      currentFoodLevel: json['currentFoodLevel'] as int?,
      isOperational: json['isOperational'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uniqueId': uniqueId,
      'templateId': templateId,
      // 'position': position.toJson(),
      'dinosaurUniqueIds': dinosaurUniqueIds,
      'currentFoodLevel': currentFoodLevel,
      'isOperational': isOperational,
    };
  }
}

class OwnedDinosaur {
  final String uniqueId;
  final String speciesId;
  String name; // Can be nicknamed by player
  double currentHealth; // 0-100
  double currentComfort; // 0-100
  double currentFood; // 0-100 (satiation)
  int age; // In game days/minutes

  OwnedDinosaur({
    required this.uniqueId,
    required this.speciesId,
    required this.name,
    this.currentHealth = 100.0,
    this.currentComfort = 75.0,
    this.currentFood = 75.0,
    this.age = 0,
  });

  factory OwnedDinosaur.fromJson(Map<String, dynamic> json) {
    return OwnedDinosaur(
      uniqueId: json['uniqueId'] as String,
      speciesId: json['speciesId'] as String,
      name: json['name'] as String,
      currentHealth: (json['currentHealth'] as num? ?? 100.0).toDouble(),
      currentComfort: (json['currentComfort'] as num? ?? 75.0).toDouble(),
      currentFood: (json['currentFood'] as num? ?? 75.0).toDouble(),
      age: json['age'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uniqueId': uniqueId,
      'speciesId': speciesId,
      'name': name,
      'currentHealth': currentHealth,
      'currentComfort': currentComfort,
      'currentFood': currentFood,
      'age': age,
    };
  }
}

class FossilRecord {
  final String speciesId;
  double excavationProgress; // 0.0 to 100.0
  bool isGenomeComplete;

  FossilRecord({
    required this.speciesId,
    this.excavationProgress = 0.0,
    this.isGenomeComplete = false,
  });

  factory FossilRecord.fromJson(Map<String, dynamic> json) {
    return FossilRecord(
      speciesId: json['speciesId'] as String,
      excavationProgress:
          (json['excavationProgress'] as num? ?? 0.0).toDouble(),
      isGenomeComplete: json['isGenomeComplete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speciesId': speciesId,
      'excavationProgress': excavationProgress,
      'isGenomeComplete': isGenomeComplete,
    };
  }
}

class ParkManager {
  int parkRating;
  double parkDollars; // New currency for park
  double parkEnergy; // Player energy for park operations
  double maxParkEnergy;
  int incomePerMinuteDollars; // Total from all income-generating buildings (Dollars)
  int operationalCostPerMinuteDollars; // Total from all buildings (Dollars)
  int currentPowerGenerated;
  int currentPowerConsumed;

  ParkManager({
    this.parkRating = 0,
    this.parkDollars = 50000, // Starting park dollars
    this.parkEnergy = 100.0, // Starting park energy, linked to player energy
    this.maxParkEnergy = 100.0,
    this.incomePerMinuteDollars = 0,
    this.operationalCostPerMinuteDollars = 0,
    this.currentPowerGenerated = 0,
    this.currentPowerConsumed = 0,
  });

  factory ParkManager.fromJson(Map<String, dynamic> json) {
    return ParkManager(
      parkRating: json['parkRating'] as int? ?? 0,
      parkDollars: (json['parkDollars'] as num? ?? 50000.0).toDouble(),
      parkEnergy: (json['parkEnergy'] as num? ?? 100.0).toDouble(),
      maxParkEnergy: (json['maxParkEnergy'] as num? ?? 100.0).toDouble(),
      incomePerMinuteDollars: json['incomePerMinuteDollars'] as int? ??
          json['incomePerMinute'] as int? ??
          0,
      operationalCostPerMinuteDollars:
          json['operationalCostPerMinuteDollars'] as int? ??
              json['operationalCostPerMinute'] as int? ??
              0,
      currentPowerGenerated: json['currentPowerGenerated'] as int? ?? 0,
      currentPowerConsumed: json['currentPowerConsumed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parkRating': parkRating,
      'parkDollars': parkDollars,
      'parkEnergy': parkEnergy,
      'maxParkEnergy': maxParkEnergy,
      'incomePerMinuteDollars': incomePerMinuteDollars,
      'operationalCostPerMinuteDollars': operationalCostPerMinuteDollars,
      'currentPowerGenerated': currentPowerGenerated,
      'currentPowerConsumed': currentPowerConsumed,
    };
  }
}

class EmotionLog {
  final DateTime timestamp;
  final int rating; // 1-5

  EmotionLog({required this.timestamp, required this.rating});

  factory EmotionLog.fromJson(Map<String, dynamic> json) {
    return EmotionLog(
      timestamp: DateTime.parse(json['timestamp'] as String),
      rating: json['rating'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'rating': rating,
    };
  }
}

// Chatbot models
enum MessageSender { user, bot }

// For AI Dynamic UI
enum DynamicUiType { graph, unknown }

class DynamicUiPayload {
  final DynamicUiType type;
  final Map<String, dynamic> data; // e.g., {'graphType': 'bar', 'title': 'Emotion Trend', 'seriesData': [...]}

  DynamicUiPayload({required this.type, required this.data});

  factory DynamicUiPayload.fromJson(Map<String, dynamic> json) {
    DynamicUiType uiType;
    try {
      uiType = DynamicUiType.values.firstWhere(
        (e) => e.toString() == 'DynamicUiType.${json['type'] as String? ?? 'unknown'}'
      );
    } catch (e) {
      uiType = DynamicUiType.unknown;
    }
    return DynamicUiPayload(
      type: uiType,
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'data': data,
    };
  }
}


class ChatbotMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final DynamicUiPayload? uiPayload; // NEW: Optional UI payload

  ChatbotMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.uiPayload, // NEW
  });

  factory ChatbotMessage.fromJson(Map<String, dynamic> json) {
    return ChatbotMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      sender: MessageSender.values
          .firstWhere((e) => e.toString() == json['sender'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      uiPayload: json['uiPayload'] != null
          ? DynamicUiPayload.fromJson(json['uiPayload'] as Map<String, dynamic>)
          : null, // NEW
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender.toString(),
      'timestamp': timestamp.toIso8601String(),
      'uiPayload': uiPayload?.toJson(), // NEW
    };
  }
}


class ChatbotMemory {
  List<ChatbotMessage> conversationHistory;
  String? lastWeeklySummary;
  List<String> dailyCompletedGoals; // List of strings, e.g., "Completed X on YYYY-MM-DD"
  List<String> userRememberedItems; // Items explicitly told to remember

  ChatbotMemory({
    List<ChatbotMessage>? conversationHistory,
    this.lastWeeklySummary,
    List<String>? dailyCompletedGoals,
    List<String>? userRememberedItems,
  })  : conversationHistory = conversationHistory ?? [],
        dailyCompletedGoals = dailyCompletedGoals ?? [],
        userRememberedItems = userRememberedItems ?? [];

  factory ChatbotMemory.fromJson(Map<String, dynamic> json) {
    return ChatbotMemory(
      conversationHistory: (json['conversationHistory'] as List<dynamic>?)
              ?.map((msgJson) =>
                  ChatbotMessage.fromJson(msgJson as Map<String, dynamic>))
              .toList() ??
          [],
      lastWeeklySummary: json['lastWeeklySummary'] as String?,
      dailyCompletedGoals: (json['dailyCompletedGoals'] as List<dynamic>?)
              ?.map((goal) => goal as String)
              .toList() ??
          [],
      userRememberedItems: (json['userRememberedItems'] as List<dynamic>?)
              ?.map((item) => item as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationHistory':
          conversationHistory.map((msg) => msg.toJson()).toList(),
      'lastWeeklySummary': lastWeeklySummary,
      'dailyCompletedGoals': dailyCompletedGoals,
      'userRememberedItems': userRememberedItems,
    };
  }
}