// lib/src/providers/actions/item_actions.dart
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:arcane/src/models/game_models.dart';
import 'package:arcane/src/theme/app_theme.dart'; // For colors in log
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:collection/collection.dart'; // For firstWhereOrNull

class ItemActions {
  final GameProvider _provider;

  ItemActions(this._provider);

  OwnedArtifact? getArtifactByUniqueId(String uniqueId) {
    return _provider.artifacts
        .firstWhereOrNull((art) => art.uniqueId == uniqueId);
  }

  ArtifactTemplate? getArtifactTemplateById(String templateId) {
    return _provider.artifactTemplatesList
        .firstWhereOrNull((tmpl) => tmpl.id == templateId);
  }

  ArtifactTemplate getArtifactEffectiveStats(OwnedArtifact ownedArtifact) {
    final template = _provider.artifactTemplatesList
        .firstWhereOrNull((t) => t.id == ownedArtifact.templateId);
    if (template == null) {
      return ArtifactTemplate(
          id: '',
          name: 'Unknown Artifact',
          type: '',
          description: '',
          cost: 0,
          icon: '❓');
    }

    final level = ownedArtifact.currentLevel;

    int currentAtt = template.baseAtt ?? 0;
    int currentRunic = template.baseRunic ?? 0;
    int currentDef = template.baseDef ?? 0;
    int currentHealth = template.baseHealth ?? 0;
    int currentLuck = template.baseLuck ?? 0;
    int currentCooldown = template.baseCooldown ?? 0;
    double currentBonusXPMod = template.bonusXPMod ?? 0.0;

    if (template.type != 'powerup' &&
        level > 1 &&
        template.upgradeBonus != null) {
      template.upgradeBonus!.forEach((key, bonusPerLevel) {
        final totalBonusForStat =
            bonusPerLevel * (level - 1); // Generic for integer bonuses
        final doubleTotalBonusForStat = bonusPerLevel.toDouble() *
            (level - 1); // Generic for double bonuses

        switch (key) {
          case 'att':
            currentAtt += totalBonusForStat;
            break;
          case 'runic':
            currentRunic += totalBonusForStat;
            break;
          case 'def':
            currentDef += totalBonusForStat;
            break;
          case 'health':
            currentHealth += totalBonusForStat;
            break;
          case 'luck':
            currentLuck += totalBonusForStat;
            break;
          case 'cooldown':
            currentCooldown += totalBonusForStat;
            break;
          // If bonusPerLevel for bonusXPMod is already a decimal (e.g., 0.01 for 1%),
          // then direct multiplication is correct.
          case 'bonusXPMod':
            currentBonusXPMod += doubleTotalBonusForStat;
            break;
        }
      });
    }

    return ArtifactTemplate(
      id: template.id,
      name: template.name,
      type: template.type,
      theme: template.theme,
      description: template.description,
      cost: template.cost,
      icon: template.icon,
      baseAtt: currentAtt,
      baseRunic: currentRunic,
      baseDef: currentDef,
      baseHealth: currentHealth,
      baseLuck: currentLuck,
      baseCooldown: currentCooldown,
      bonusXPMod: currentBonusXPMod,
      upgradeBonus: template.upgradeBonus,
      maxLevel: template.maxLevel,
      effectType: template.effectType,
      effectValue: template.effectValue,
      uses: template.type == 'powerup' ? ownedArtifact.uses : template.uses,
    );
  }

  void buyArtifact(String templateId) {
    final template = _provider.artifactTemplatesList
        .firstWhereOrNull((t) => t.id == templateId);
    if (template == null || _provider.coins < template.cost) return;

    final newArtifactInstance = OwnedArtifact(
      uniqueId:
          'artuid_${DateTime.now().millisecondsSinceEpoch}_${template.id.hashCode}',
      templateId: template.id,
      currentLevel: 1,
      uses: template.type == 'powerup' ? template.uses ?? 1 : null,
    );
    _provider.setProviderState(
      coins: _provider.coins - template.cost,
      artifacts: [..._provider.artifacts, newArtifactInstance],
    );
  }

  bool upgradeArtifact(String uniqueId) {
    final ownedArtifact =
        _provider.artifacts.firstWhereOrNull((a) => a.uniqueId == uniqueId);
    final template = ownedArtifact != null
        ? _provider.artifactTemplatesList
            .firstWhereOrNull((t) => t.id == ownedArtifact.templateId)
        : null;

    if (template == null ||
        ownedArtifact == null ||
        template.type == 'powerup' ||
        ownedArtifact.currentLevel >= (template.maxLevel ?? 1)) {
      return false;
    }

    final upgradeCost = (template.cost *
            blacksmithUpgradeCostMultiplier *
            (helper.xpLevelMultiplierPow(1.2, ownedArtifact.currentLevel - 1)))
        .floor();
    if (_provider.coins < upgradeCost) return false;

    final newArtifacts = _provider.artifacts.map((art) {
      if (art.uniqueId == uniqueId) {
        return OwnedArtifact(
            uniqueId: art.uniqueId,
            templateId: art.templateId,
            currentLevel: art.currentLevel + 1,
            uses: art.uses);
      }
      return art;
    }).toList();
    _provider.setProviderState(
        coins: _provider.coins - upgradeCost, artifacts: newArtifacts);
    return true;
  }

  bool sellArtifact(String uniqueId) {
    final artifactToSell =
        _provider.artifacts.firstWhereOrNull((a) => a.uniqueId == uniqueId);
    final template = artifactToSell != null
        ? _provider.artifactTemplatesList
            .firstWhereOrNull((t) => t.id == artifactToSell.templateId)
        : null;
    if (template == null || artifactToSell == null) return false;

    double sellMultiplier = 1.0;
    if (template.type == 'powerup' &&
        template.uses != null &&
        template.uses! > 0 &&
        artifactToSell.uses != null) {
      sellMultiplier = (artifactToSell.uses! / template.uses!);
    }
    final int sellPrice =
        (template.cost * artifactSellPercentage * sellMultiplier).floor();

    final newArtifacts =
        _provider.artifacts.where((art) => art.uniqueId != uniqueId).toList();
    Map<String, String?> newEquippedItems = Map.from(_provider.equippedItems);
    bool unequipped = false;
    newEquippedItems.forEach((slot, itemId) {
      if (itemId == uniqueId) {
        newEquippedItems[slot] = null;
        unequipped = true;
      }
    });

    final newLog = List<String>.from(_provider.currentGame.log)
      ..add(
          "<span style=\"color:${AppTheme.fhAccentOrange.value.toRadixString(16).substring(2)}\">${template.name} sold for $sellPrice Ø.</span>");

    _provider.setProviderState(
        coins: _provider.coins + sellPrice,
        artifacts: newArtifacts,
        equippedItems: unequipped ? newEquippedItems : _provider.equippedItems,
        currentGame: CurrentGame(
          enemy: _provider.currentGame.enemy,
          playerCurrentHp: _provider.currentGame.playerCurrentHp,
          log: newLog,
        ));
    return true;
  }

  void equipArtifact(String uniqueId) {
    final ownedArtifact =
        _provider.artifacts.firstWhereOrNull((a) => a.uniqueId == uniqueId);
    final template = ownedArtifact != null
        ? _provider.artifactTemplatesList
            .firstWhereOrNull((t) => t.id == ownedArtifact.templateId)
        : null;
    if (template == null || ownedArtifact == null || template.type == 'powerup') {
      return;
    }

    final newEquippedItems = Map<String, String?>.from(_provider.equippedItems);
    newEquippedItems[template.type] = uniqueId;
    _provider.setProviderState(equippedItems: newEquippedItems);
  }

  void unequipArtifact(String slot) {
    final newEquippedItems = Map<String, String?>.from(_provider.equippedItems);
    newEquippedItems[slot] = null;
    _provider.setProviderState(equippedItems: newEquippedItems);
  }
}
