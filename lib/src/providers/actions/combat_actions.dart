// lib/src/providers/actions/combat_actions.dart
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:arcane/src/models/game_models.dart';
import 'package:arcane/src/theme/app_theme.dart'; // For colors in log
import 'dart:math';
import 'package:collection/collection.dart'; // For firstWhereOrNull

class CombatActions {
  final GameProvider _provider;

  CombatActions(this._provider);

  void startGame(String enemyId) {
    final enemyTemplate =
        _provider.enemyTemplatesList.firstWhereOrNull((e) => e.id == enemyId);
    if (enemyTemplate == null) return;

    final newGame = CurrentGame(
      enemy: EnemyTemplate(
          // Create a mutable copy for combat
          id: enemyTemplate.id,
          name: enemyTemplate.name,
          theme: enemyTemplate.theme,
          locationKey: enemyTemplate.locationKey,
          minPlayerLevel: enemyTemplate.minPlayerLevel,
          health: enemyTemplate.health,
          attack: enemyTemplate.attack,
          defense: enemyTemplate.defense,
          coinReward: enemyTemplate.coinReward,
          xpReward: enemyTemplate.xpReward,
          description: enemyTemplate.description,
          hp: enemyTemplate.health // Start with full HP
          ),
      playerCurrentHp: _provider.playerGameStats['vitality']!.value,
      log: [
        "<span style=\"font-weight:bold;\">You encounter ${enemyTemplate.name}!</span> ${enemyTemplate.description}"
      ],
      currentPlaceKey: _provider.currentGame.currentPlaceKey,
    );

    _provider.setProviderState(currentGame: newGame);
  }

  void handleFight() {
    if (_provider.currentGame.enemy == null ||
        _provider.playerEnergy < energyPerAttack) {
      if (_provider.playerEnergy < energyPerAttack &&
          _provider.currentGame.enemy != null) {
        _provider.setProviderState(
            currentGame: CurrentGame(
          enemy: _provider.currentGame.enemy,
          playerCurrentHp: _provider.currentGame.playerCurrentHp,
          log: [
            ..._provider.currentGame.log,
            "<span style=\"color:${AppTheme.fhAccentRed.value.toRadixString(16).substring(2)};\">Not enough energy!</span>"
          ],
          currentPlaceKey: _provider.currentGame.currentPlaceKey,
        ));
      }
      return;
    }

    final currentEnemy =
        _provider.currentGame.enemy!; // This is already a mutable copy
    final playerStats = _provider.playerGameStats;
    final currentLog = List<String>.from(_provider.currentGame.log);

    int playerDamage = max(
        1,
        (playerStats['strength']!.value +
                (playerStats['runic']!.value / 2).floor() -
                currentEnemy.defense)
            .toInt());
    currentEnemy.hp =
        max(0, currentEnemy.hp - playerDamage); // Mutate the current enemy's HP

    currentLog.add(
        "You hit ${currentEnemy.name} for $playerDamage damage. (${currentEnemy.name} HP: ${currentEnemy.hp})");

    final Map<String, dynamic> updatesToPersist = {
      'playerEnergy': _provider.playerEnergy - energyPerAttack,
    };

    EnemyTemplate? nextEnemyState = currentEnemy;
    String? originalLocationKey = currentEnemy.locationKey;

    if (currentEnemy.hp <= 0) {
      currentLog.add("${currentEnemy.name} defeated!");
      final double luckBonus = 1 + (playerStats['luck']!.value / 100);
      final double xpBonusFromArtifact = playerStats['bonusXPMod']?.value ?? 0;
      final double totalXPMultiplier = luckBonus * (1 + xpBonusFromArtifact);
      final int coinReward = (currentEnemy.coinReward * luckBonus).floor();
      final int xpRewardVal =
          (currentEnemy.xpReward * totalXPMultiplier).floor();
      currentLog.add("You gain $coinReward Ø and $xpRewardVal XP.");

      updatesToPersist['coins'] = _provider.coins + coinReward;
      updatesToPersist['xp'] = _provider.xp + xpRewardVal;
      updatesToPersist['defeatedEnemyIds'] = [
        ...Set<String>.from(_provider.defeatedEnemyIds)..add(currentEnemy.id)
      ].toList();
      nextEnemyState = null;
    } else {
      int enemyDamage =
          max(1, (currentEnemy.attack - playerStats['defense']!.value).toInt());
      updatesToPersist['playerCurrentHp'] =
          max(0.0, _provider.currentGame.playerCurrentHp - enemyDamage);
      currentLog.add(
          "${currentEnemy.name} hits you for $enemyDamage damage. (Your HP: ${updatesToPersist['playerCurrentHp']})");
      if (updatesToPersist['playerCurrentHp'] <= 0) {
        currentLog.add("You have been defeated! Retreat to recover.");
        nextEnemyState = null;
      }
    }

    updatesToPersist['currentGame'] = CurrentGame(
      enemy: nextEnemyState,
      playerCurrentHp: updatesToPersist['playerCurrentHp'] as double? ??
          _provider.currentGame.playerCurrentHp,
      log: currentLog,
      currentPlaceKey: _provider.currentGame.currentPlaceKey,
    );
    if (!updatesToPersist.containsKey('playerCurrentHp')) {
      (updatesToPersist['currentGame'] as CurrentGame).playerCurrentHp =
          _provider.currentGame.playerCurrentHp;
    }

    _provider.setProviderState(
        playerEnergy: updatesToPersist['playerEnergy'] as double?,
        coins: updatesToPersist['coins'] as double?,
        xp: updatesToPersist['xp'] as double?,
        defeatedEnemyIds: updatesToPersist['defeatedEnemyIds'] as List<String>?,
        currentGame: updatesToPersist['currentGame'] as CurrentGame,
        doPersist: false);

    if (nextEnemyState == null &&
        currentEnemy.hp <= 0 &&
        originalLocationKey != null) {
      checkAndClearLocationIfAllEnemiesDefeated(originalLocationKey);
    }
  }

  void usePowerUp(String uniqueId) {
    final powerUpInstance =
        _provider.artifacts.firstWhereOrNull((a) => a.uniqueId == uniqueId);
    final template = powerUpInstance != null
        ? _provider.artifactTemplatesList
            .firstWhereOrNull((t) => t.id == powerUpInstance.templateId)
        : null;

    if (template == null ||
        powerUpInstance == null ||
        template.type != 'powerup' ||
        (powerUpInstance.uses != null && powerUpInstance.uses! <= 0) ||
        _provider.currentGame.enemy == null) {
      if (_provider.currentGame.enemy == null && template != null) {
        // Added template null check
        _provider.setProviderState(
            currentGame: CurrentGame(
          enemy: _provider.currentGame.enemy,
          playerCurrentHp: _provider.currentGame.playerCurrentHp,
          log: [
            ..._provider.currentGame.log,
            "<span style=\"color:${AppTheme.fhAccentOrange.value.toRadixString(16).substring(2)};\">Can only use power-ups in combat!</span>"
          ],
          currentPlaceKey: _provider.currentGame.currentPlaceKey,
        ));
      }
      return;
    }

    final currentEnemy =
        _provider.currentGame.enemy!; // This is a mutable copy from startGame
    final playerStats = _provider.playerGameStats;
    final currentLog = List<String>.from(_provider.currentGame.log);
    final Map<String, dynamic> updatesToPersist = {};

    double playerHpAfterPowerUp = _provider.currentGame.playerCurrentHp;
    EnemyTemplate? nextEnemyState = currentEnemy;
    String? originalLocationKey = currentEnemy.locationKey;

    if (template.effectType == 'direct_damage') {
      final int damage = max(
          1, (template.effectValue ?? 0) - (currentEnemy.defense / 2).floor());
      currentEnemy.hp =
          max(0, currentEnemy.hp - damage); // Mutate current enemy
      currentLog.add(
          "<span style=\"color:${AppTheme.fhAccentPurple.value.toRadixString(16).substring(2)};\">You used ${template.name}!</span> It hits ${currentEnemy.name} for $damage damage. (${currentEnemy.name} HP: ${currentEnemy.hp})");
    } else if (template.effectType == 'heal_player') {
      playerHpAfterPowerUp = min(playerStats['vitality']!.value,
          _provider.currentGame.playerCurrentHp + (template.effectValue ?? 0));
      updatesToPersist['playerCurrentHp'] = playerHpAfterPowerUp;
      currentLog.add(
          "<span style=\"color:${AppTheme.fhAccentPurple.value.toRadixString(16).substring(2)};\">You used ${template.name}!</span> You healed for ${template.effectValue} HP. (Your HP: $playerHpAfterPowerUp)");
    }

    updatesToPersist['artifacts'] = _provider.artifacts
        .map((art) {
          if (art.uniqueId == uniqueId) {
            return OwnedArtifact(
                uniqueId: art.uniqueId,
                templateId: art.templateId,
                currentLevel: art.currentLevel,
                uses: (art.uses ?? 1) - 1);
          }
          return art;
        })
        .where((art) => art.uses == null || art.uses! > 0)
        .toList();

    if (currentEnemy.hp <= 0) {
      currentLog.add("${currentEnemy.name} defeated by the power-up!");
      final double luckBonus = 1 + (playerStats['luck']!.value / 100);
      final double xpBonusFromArtifact = playerStats['bonusXPMod']?.value ?? 0;
      final double totalXPMultiplier = luckBonus * (1 + xpBonusFromArtifact);
      final int coinReward = (currentEnemy.coinReward * luckBonus).floor();
      final int xpRewardVal =
          (currentEnemy.xpReward * totalXPMultiplier).floor();
      currentLog.add("You gain $coinReward Ø and $xpRewardVal XP.");
      updatesToPersist['coins'] = _provider.coins + coinReward;
      updatesToPersist['xp'] = _provider.xp + xpRewardVal;
      updatesToPersist['defeatedEnemyIds'] = [
        ...Set<String>.from(_provider.defeatedEnemyIds)..add(currentEnemy.id)
      ].toList();
      nextEnemyState = null;
    }

    updatesToPersist['currentGame'] = CurrentGame(
      enemy: nextEnemyState,
      playerCurrentHp: updatesToPersist['playerCurrentHp'] as double? ??
          _provider.currentGame.playerCurrentHp,
      log: currentLog,
      currentPlaceKey: _provider.currentGame.currentPlaceKey,
    );
    if (!updatesToPersist.containsKey('playerCurrentHp')) {
      (updatesToPersist['currentGame'] as CurrentGame).playerCurrentHp =
          _provider.currentGame.playerCurrentHp;
    }

    _provider.setProviderState(
        artifacts: updatesToPersist['artifacts'] as List<OwnedArtifact>?,
        coins: updatesToPersist['coins'] as double?,
        xp: updatesToPersist['xp'] as double?,
        defeatedEnemyIds: updatesToPersist['defeatedEnemyIds'] as List<String>?,
        currentGame: updatesToPersist['currentGame'] as CurrentGame,
        doPersist: false);

    if (nextEnemyState == null &&
        currentEnemy.hp <= 0 &&
        originalLocationKey != null) {
      checkAndClearLocationIfAllEnemiesDefeated(originalLocationKey);
    }
  }

  void forfeitMatch() {
    if (_provider.currentGame.enemy == null) return;
    final int coinsLost = (_provider.coins * 0.10).floor();
    final double maxHp = _provider.playerGameStats['vitality']!.value;

    _provider.setProviderState(
        coins: _provider.coins - coinsLost,
        playerEnergy: 0,
        currentGame: CurrentGame(
          playerCurrentHp: maxHp,
          enemy: null,
          log: [
            ..._provider.currentGame.log,
            "<span style=\"color:${AppTheme.fhAccentRed.value.toRadixString(16).substring(2)};\">You forfeited the match!</span> Lost $coinsLost Ø and all energy."
          ],
          currentPlaceKey: _provider.currentGame.currentPlaceKey,
        ));
  }

  void checkAndClearLocationIfAllEnemiesDefeated(String locationId) {
    final location = _provider.gameLocationsList
        .firstWhereOrNull((loc) => loc.id == locationId);
    if (location == null ||
        _provider.clearedLocationIds.contains(locationId)) {
      return; // Location not found or already cleared
    }

    // Find all enemies that *belong* to this location
    final enemiesInLocation = _provider.enemyTemplatesList
        .where((enemy) => enemy.locationKey == locationId)
        .toList();

    if (enemiesInLocation.isEmpty) {
      // No enemies defined for this location, cannot be "cleared" by defeating enemies
      // Or, if it's a non-combat zone, this logic might not apply.
      // For now, if no enemies are tied to it, we don't auto-clear it this way.
      return;
    }

    // Check if all enemies *belonging to this location* are in the defeated list
    final allDefeated = enemiesInLocation
        .every((enemy) => _provider.defeatedEnemyIds.contains(enemy.id));

    if (allDefeated) {
      _provider.markLocationAsCleared(locationId);
    }
  }
}
