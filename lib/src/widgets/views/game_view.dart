// lib/src/widgets/views/game_view.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/game_models.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:arcane/src/widgets/ui/enemy_info_card.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

class GameView extends StatefulWidget {
  const GameView({super.key});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  String? _selectedLocationId;
  bool _zoneClearedDialogShown = false;

  @override
  void initState() {
    super.initState();
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    print("[GameView] initState called.");

    _initializeSelectedLocation(gameProvider);
    gameProvider.addListener(_handleProviderChange);
    print(
        "[GameView] Final _selectedLocationId in initState: $_selectedLocationId");
  }

  void _handleProviderChange() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (!mounted) return;

    // Check if current selected location is cleared
    if (_selectedLocationId != null &&
        gameProvider.clearedLocationIds.contains(_selectedLocationId!) &&
        !_zoneClearedDialogShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showZoneClearedDialog(gameProvider, _selectedLocationId!);
          _zoneClearedDialogShown =
              true; // Prevent multiple dialogs for same clear
          // Attempt to switch to a new location
          final availableUnclearedLocations = gameProvider.gameLocationsList
              .where((loc) =>
                  gameProvider.isLocationUnlocked(loc.id) &&
                  !gameProvider.clearedLocationIds.contains(loc.id))
              .toList();
          setState(() {
            _selectedLocationId = availableUnclearedLocations.isNotEmpty
                ? availableUnclearedLocations.first.id
                : null;
          });
          if (_selectedLocationId != null) {
            gameProvider.setProviderState(
                currentGame: CurrentGame(
                  playerCurrentHp: gameProvider.currentGame.playerCurrentHp,
                  log: gameProvider.currentGame.log,
                  currentPlaceKey: _selectedLocationId,
                ),
                doPersist: false);
          } else {
             // If no new location could be selected, ensure currentPlaceKey is also nullified if it was the cleared one
            if (gameProvider.currentGame.currentPlaceKey != null && gameProvider.clearedLocationIds.contains(gameProvider.currentGame.currentPlaceKey!)) {
                 gameProvider.setProviderState(
                    currentGame: CurrentGame(
                      playerCurrentHp: gameProvider.currentGame.playerCurrentHp,
                      log: gameProvider.currentGame.log,
                      currentPlaceKey: null,
                    ),
                    doPersist: false);
            }
          }
        }
      });
    } else if (_selectedLocationId != null &&
        !gameProvider.clearedLocationIds.contains(_selectedLocationId!)) {
      // Reset if location becomes uncleared (e.g. daily reset)
      _zoneClearedDialogShown = false;
    }

    // Re-evaluate selected location if it becomes invalid (e.g. due to external changes)
    final availableLocations = gameProvider.gameLocationsList
        .where((loc) =>
            gameProvider.isLocationUnlocked(loc.id) &&
            !gameProvider.clearedLocationIds.contains(loc.id))
        .toList();

    if (_selectedLocationId != null &&
        !availableLocations.any((loc) => loc.id == _selectedLocationId)) {
      // Current selection is no longer valid or is cleared
      _initializeSelectedLocation(gameProvider);
    } else if (_selectedLocationId == null && availableLocations.isNotEmpty) {
      // No selection, but locations are available
      _initializeSelectedLocation(gameProvider);
    }
  }

  void _initializeSelectedLocation(GameProvider gameProvider) {
    final availableLocations = gameProvider.gameLocationsList
        .where((loc) =>
            gameProvider.isLocationUnlocked(loc.id) &&
            !gameProvider.clearedLocationIds.contains(loc.id))
        .toList();
    print(
        "[GameView] _initializeSelectedLocation: Available unlocked & uncleared locations: ${availableLocations.map((l) => l.name).join(', ')}");

    String? newSelectedLocationId;
    if (gameProvider.currentGame.currentPlaceKey != null &&
        availableLocations
            .any((l) => l.id == gameProvider.currentGame.currentPlaceKey)) {
      newSelectedLocationId = gameProvider.currentGame.currentPlaceKey;
    } else if (availableLocations.isNotEmpty) {
      newSelectedLocationId = availableLocations.first.id;
    }
    // If no available uncleared locations, newSelectedLocationId will be null

    if (mounted) {
      setState(() {
        _selectedLocationId = newSelectedLocationId;
      });
    } else {
      _selectedLocationId = newSelectedLocationId;
    }

    if (newSelectedLocationId != null && // Use newSelectedLocationId for the check as _selectedLocationId might not be updated yet by setState
        gameProvider.currentGame.currentPlaceKey != newSelectedLocationId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print(
              "[GameView] Updating provider with selectedLocationId in _initializeSelectedLocation: $newSelectedLocationId");
          gameProvider.setProviderState(
              currentGame: CurrentGame(
                enemy: gameProvider.currentGame.enemy, // Preserve enemy if one exists (though unlikely if changing place key)
                playerCurrentHp: gameProvider.currentGame.playerCurrentHp,
                log: gameProvider.currentGame.log,
                currentPlaceKey: newSelectedLocationId,
              ),
              doPersist: false);
        }
      });
    } else if (newSelectedLocationId == null && gameProvider.currentGame.currentPlaceKey != null) {
       // If no location is selected (e.g. all cleared/locked) ensure provider reflects this
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print(
              "[GameView] Updating provider, no selected location, clearing currentPlaceKey.");
          gameProvider.setProviderState(
              currentGame: CurrentGame(
                enemy: gameProvider.currentGame.enemy,
                playerCurrentHp: gameProvider.currentGame.playerCurrentHp,
                log: gameProvider.currentGame.log,
                currentPlaceKey: null,
              ),
              doPersist: false);
        }
      });
    }
  }

  Future<void> _showZoneClearedDialog(
      GameProvider gameProvider, String clearedLocationId) async {
    final clearedLocation = gameProvider.gameLocationsList
        .firstWhereOrNull((loc) => loc.id == clearedLocationId);
    if (clearedLocation == null) return;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(MdiIcons.partyPopper,
                  color: AppTheme.fhAccentGold, size: 28),
              const SizedBox(width: 10),
              Text('Zone Pacified!',
                  style: TextStyle(color: AppTheme.fhAccentGold)),
            ],
          ),
          content: Text(
              'Congratulations! You have pacified all threats in ${clearedLocation.name}. This zone is now safe.'),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('Awesome!'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    Provider.of<GameProvider>(context, listen: false)
        .removeListener(_handleProviderChange);
    super.dispose();
  }

  Widget _renderCharacterStats(BuildContext context, dynamic character,
      bool isPlayer, GameProvider gameProvider) {
    final theme = Theme.of(context);
    final Color dynamicAccent = gameProvider.getSelectedTask()?.taskColor ??
        theme.colorScheme.secondary;
    final double maxHp = isPlayer
        ? gameProvider.playerGameStats['vitality']!.value
        : (character as EnemyTemplate).health.toDouble();
    double currentHp;

    String characterName = "Your Stats";
    String? description;
    int attackStat = 0;
    int defenseStat = 0;
    List<Widget> runeEffectsDisplay = [];

    if (isPlayer) {
      currentHp = gameProvider.currentGame.playerCurrentHp;
      characterName = gameProvider.currentUser?.displayName ?? "Adventurer";
      attackStat = gameProvider.playerGameStats['strength']!.value.toInt();
      defenseStat = gameProvider.playerGameStats['defense']!.value.toInt();
    } else if (character is EnemyTemplate) {
      characterName = character.name;
      description = character.description;
      attackStat = character.attack;
      defenseStat = character.defense;
      if (gameProvider.currentGame.enemy != null &&
          gameProvider.currentGame.enemy!.id == character.id) {
        currentHp = gameProvider.currentGame.enemy!.hp.toDouble();
      } else {
        currentHp = character.hp.toDouble();
      }
    } else {
      currentHp = 0;
    }

    final double hpPercent = maxHp > 0 ? (currentHp / maxHp) : 0.0;
    Color hpBarColor;
    if (hpPercent * 100 > 60) {
      hpBarColor = AppTheme.fhAccentGreen;
    } else if (hpPercent * 100 > 30) {
      hpBarColor = AppTheme.fhAccentOrange;
    } else {
      hpBarColor = AppTheme.fhAccentRed;
    }

    return Card(
      elevation: 1,
      color: AppTheme.fhBgMedium.withOpacity(0.7),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              characterName,
              style: theme.textTheme.titleLarge?.copyWith(
                  color: isPlayer ? dynamicAccent : AppTheme.fhAccentRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 17),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SizedBox(
                height: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: hpPercent,
                    backgroundColor: AppTheme.fhBgDark,
                    valueColor: AlwaysStoppedAnimation<Color>(hpBarColor),
                  ),
                )),
            const SizedBox(height: 6),
            Text(
                'HP: ${currentHp.toStringAsFixed(0)} / ${maxHp.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.fhTextSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(MdiIcons.sword,
                    size: 14, color: AppTheme.fhAccentOrange.withOpacity(0.8)),
                Text(' ATK: $attackStat  ',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
                Icon(MdiIcons.shield,
                    size: 14,
                    color: AppTheme.fhAccentTealFixed.withOpacity(
                        0.8)), // Use fixed teal for clarity
                Text(' DEF: $defenseStat',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
              ],
            ),
            if (isPlayer && runeEffectsDisplay.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: runeEffectsDisplay),
            ],
            if (!isPlayer && description != null && description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Tooltip(
                message: description,
                preferBelow: false,
                child: Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppTheme.fhTextSecondary.withOpacity(0.7),
                      fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildLocationList(BuildContext context, GameProvider gameProvider) {
    
    final availableLocations = gameProvider.gameLocationsList
        .where((loc) => gameProvider.isLocationUnlocked(loc.id))
        .toList()
      ..sort((a, b) =>
          a.minPlayerLevelToUnlock.compareTo(b.minPlayerLevelToUnlock));

    if (availableLocations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
            child: Text(
                "No combat zones accessible at your current level or all zones pacified.",
                textAlign: TextAlign.center)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(), // Parent SingleChildScrollView handles scroll
      itemCount: availableLocations.length,
      itemBuilder: (context, index) {
        final location = availableLocations[index];
        final isSelected = _selectedLocationId == location.id;
        final isCleared =
            gameProvider.clearedLocationIds.contains(location.id);
        final Color tileColor = isSelected
            ? (gameProvider.getSelectedTask()?.taskColor ??
                    AppTheme.fhAccentTealFixed)
                .withOpacity(0.2)
            : AppTheme.fhBgLight;
        final Color borderColor = isSelected
            ? (gameProvider.getSelectedTask()?.taskColor ??
                AppTheme.fhAccentTealFixed)
            : AppTheme.fhBorderColor.withOpacity(0.5);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: tileColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: borderColor, width: isSelected ? 1.5 : 1),
          ),
          child: ListTile(
            leading: Text(location.iconEmoji,
                style: const TextStyle(fontSize: 24)),
            title: Text(location.name,
                style:
                    TextStyle(fontWeight: isSelected ? FontWeight.bold : null)),
            subtitle: Text(
              isCleared
                  ? "Zone Pacified"
                  : "Lvl ${location.minPlayerLevelToUnlock}+",
              style: TextStyle(
                  color: isCleared
                      ? AppTheme.fhAccentGreen
                      : AppTheme.fhTextSecondary,
                  fontSize: 11),
            ),
            trailing: isCleared
                ? Icon(MdiIcons.shieldCheckOutline,
                    color: AppTheme.fhAccentGreen)
                : Icon(MdiIcons.chevronRight, color: AppTheme.fhTextSecondary),
            onTap: isCleared
                ? null
                : () {
                    if (_selectedLocationId != location.id) {
                      print(
                          "[GameView] Location selected from list: ${location.name}");
                      setState(() {
                        _selectedLocationId = location.id;
                        _zoneClearedDialogShown = false;
                      });
                      gameProvider.setProviderState(
                          currentGame: CurrentGame(
                            playerCurrentHp:
                                gameProvider.currentGame.playerCurrentHp,
                            log: gameProvider.currentGame.log,
                            currentPlaceKey: location.id,
                            enemy:
                                null // Clear current enemy when changing location
                            ),
                          doPersist: false);
                    }
                  },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final theme = Theme.of(context);
    final Color dynamicAccent = gameProvider.getSelectedTask()?.taskColor ??
        theme.colorScheme.secondary;
    final Color buttonTextColor =
        ThemeData.estimateBrightnessForColor(dynamicAccent) == Brightness.dark
            ? AppTheme.fhTextPrimary
            : AppTheme.fhBgDark;

    print(
        "[GameView] build called. SelectedLocationId: $_selectedLocationId, currentPlaceKey from provider: ${gameProvider.currentGame.currentPlaceKey}");

    final List<EnemyTemplate> availableEnemies = _selectedLocationId != null
        ? (gameProvider.enemyTemplatesList
            .where((enemyTmpl) =>
                enemyTmpl.locationKey == _selectedLocationId &&
                gameProvider.playerLevel >= enemyTmpl.minPlayerLevel &&
                !gameProvider.defeatedEnemyIds.contains(enemyTmpl.id))
            .toList()
          ..sort((a, b) {
            int lvlCompare = a.minPlayerLevel.compareTo(b.minPlayerLevel);
            if (lvlCompare != 0) return lvlCompare;
            return a.name.compareTo(b.name);
          }))
        : [];

    final ownedPowerUps = gameProvider.artifacts
        .map((ownedArt) {
          final template =
              gameProvider.getArtifactTemplateById(ownedArt.templateId);
          return (template != null &&
                  template.type == 'powerup' &&
                  (ownedArt.uses ?? 0) > 0)
              ? {'owned': ownedArt, 'template': template}
              : null;
        })
        .where((item) => item != null)
        .cast<Map<String, dynamic>>()
        .toList();

    GameLocation? displayedLocation;
    if (_selectedLocationId != null) {
      displayedLocation = gameProvider.gameLocationsList
          .firstWhereOrNull((loc) => loc.id == _selectedLocationId);
    }

    // Fallback for displayedLocation title if _selectedLocationId is null but there are discoverable locations.
    // This doesn't change _selectedLocationId, just what's shown in the title if nothing is strictly selected.
    if (displayedLocation == null) {
        final anyUnlocked = gameProvider.gameLocationsList
            .firstWhereOrNull((loc) => gameProvider.isLocationUnlocked(loc.id) && !gameProvider.clearedLocationIds.contains(loc.id));
        if (anyUnlocked != null) {
            // Do not set displayedLocation here if _selectedLocationId is meant to be the source of truth for "current selection"
            // The title logic will handle `displayedLocation?.name ?? "No Zone Selected"`
        } else {
            final anyLocationAtAll = gameProvider.gameLocationsList.firstOrNull;
            if(anyLocationAtAll != null && _selectedLocationId == null && gameProvider.gameLocationsList.where((loc) => gameProvider.isLocationUnlocked(loc.id)).isEmpty) {
                // If no location is selected and no locations are unlocked,
                // we might show a generic name or the first game location if it makes sense.
                // For now, "No Zone Selected" is fine.
            }
        }
    }


    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16, right: 4, left: 4),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(displayedLocation?.iconEmoji ?? '🗺️',
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Text(
                  displayedLocation?.name ?? "No Zone Selected",
                  style: theme.textTheme.displaySmall?.copyWith(
                      color: AppTheme.fhTextPrimary,
                      fontSize: 24), // Slightly smaller title
                ),
              ],
            ),
          ),
          if (gameProvider.currentGame.enemy == null)
            Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 8.0),
                child: _buildLocationList(context, gameProvider)),
          
          if (gameProvider.currentGame.enemy == null &&
              _selectedLocationId != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text('Choose Your Opponent:',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: AppTheme.fhTextPrimary, fontSize: 20)),
            ),
            if (gameProvider.clearedLocationIds.contains(_selectedLocationId!))
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(MdiIcons.shieldCheckOutline,
                        color: AppTheme.fhAccentGreen, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      "${displayedLocation?.name ?? 'This zone'} has been pacified!",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: AppTheme.fhAccentGreen),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "No threats remain here. Explore other zones.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppTheme.fhTextSecondary),
                    ),
                  ],
                ),
              )
            else if (availableEnemies.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  // _selectedLocationId is guaranteed non-null here by the outer if condition.
                  // So, the "Please select a combat zone." part of a ternary is not needed.
                  "No suitable opponents found in ${displayedLocation?.name ?? 'this zone'} for your current level (${gameProvider.playerLevel}). Try another zone or await new threats.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppTheme.fhTextSecondary),
                ),
              )
            else
              LayoutBuilder(builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 900
                    ? 3
                    : (constraints.maxWidth > 600 ? 2 : 1); // Adjusted counts
                double itemWidth =
                    (constraints.maxWidth - (crossAxisCount + 1) * 10) /
                        crossAxisCount;
                double childAspectRatio =
                    itemWidth / 260; // Adjusted for new card height

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(10),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10.0,
                    mainAxisSpacing: 10.0,
                    childAspectRatio:
                        childAspectRatio.clamp(0.8, 1.1), // Adjusted clamp
                  ),
                  itemCount: availableEnemies.length,
                  itemBuilder: (context, index) {
                    final enemyTmpl = availableEnemies[index];
                    return EnemyInfoCardWidget(
                      enemy: enemyTmpl,
                      playerLevel: gameProvider.playerLevel,
                      onStartGame: () => gameProvider.startGame(enemyTmpl.id),
                    );
                  },
                );
              })
          ] else if (gameProvider.currentGame.enemy == null && _selectedLocationId == null) ...[
            // This block explicitly handles the case where no enemy is selected AND no location is selected.
            // _buildLocationList already shows "No combat zones accessible..." if availableLocations is empty.
            // If a user *could* select a location but hasn't, this space could prompt them.
            // For now, if _buildLocationList handles empty states, this might not need much more,
            // unless a specific message for "please select a zone from above" is desired.
            if (gameProvider.gameLocationsList.where((loc) => gameProvider.isLocationUnlocked(loc.id)).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                child: Text(
                  "Select a combat zone from the list above to see available opponents.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.fhTextSecondary),
                ),
              )
            // If no locations are unlocked/available at all, _buildLocationList covers this.

          ] else if (gameProvider.currentGame.enemy != null) ...[ // Enemy is present
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _renderCharacterStats(context,
                          gameProvider.playerGameStats, true, gameProvider)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _renderCharacterStats(
                          context,
                          gameProvider.currentGame.enemy!,
                          false,
                          gameProvider)),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton.icon(
                icon: Icon(MdiIcons.sword, size: 20),
                label: Text('ATTACK! (${energyPerAttack.toInt()}⚡)'),
                onPressed: gameProvider.playerEnergy < energyPerAttack
                    ? null
                    : gameProvider.handleFight,
                style: ElevatedButton.styleFrom(
                  backgroundColor: dynamicAccent,
                  foregroundColor: buttonTextColor,
                  minimumSize: const Size(double.infinity, 52),
                  textStyle: theme.textTheme.labelLarge
                      ?.copyWith(color: buttonTextColor),
                ),
              ),
            ),
            if (gameProvider.playerEnergy < energyPerAttack)
              Text('Not enough energy! Complete sub-quests.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppTheme.fhAccentOrange)),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: OutlinedButton(
                onPressed: gameProvider.forfeitMatch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.fhAccentOrange,
                  side: const BorderSide(
                      color: AppTheme.fhAccentOrange, width: 1),
                  minimumSize: const Size(double.infinity, 44),
                  textStyle: theme.textTheme.labelMedium
                      ?.copyWith(color: AppTheme.fhAccentOrange),
                ),
                child: const Text('Forfeit Match (-10% Ø, 0⚡)'),
              ),
            ),
            if (ownedPowerUps.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                child: Text('Power-ups:',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: AppTheme.fhTextSecondary)),
              ),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: ownedPowerUps.map((powerUpData) {
                  final OwnedArtifact owned =
                      powerUpData['owned'] as OwnedArtifact;
                  final ArtifactTemplate template =
                      powerUpData['template'] as ArtifactTemplate;

                  Widget powerUpIcon;
                  if (template.icon.length == 1 || template.icon.length == 2) {
                    powerUpIcon = Text(template.icon,
                        style: const TextStyle(fontSize: 22));
                  } else {
                    powerUpIcon = Icon(
                        MdiIcons.fromString(
                                template.icon.replaceAll('mdi-', '')) ??
                            MdiIcons.flashAlert,
                        size: 22);
                  }

                  return Tooltip(
                    message:
                        '${template.name}: ${template.description} (Uses: ${owned.uses})',
                    child: OutlinedButton(
                      onPressed: () => gameProvider.usePowerUp(owned.uniqueId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.fhAccentPurple,
                        side: const BorderSide(
                            color: AppTheme.fhAccentPurple, width: 1),
                        padding: const EdgeInsets.all(10),
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      child: powerUpIcon,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Combat Log:',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: AppTheme.fhTextSecondary)),
          ),
          const SizedBox(height: 8),
          Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppTheme.fhBgMedium.withOpacity(0.6),
              border:
                  Border.all(color: AppTheme.fhBorderColor.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: gameProvider.currentGame.log.isEmpty
                ? Text('No actions yet...',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.fhTextSecondary.withOpacity(0.7)))
                : ListView.builder(
                    reverse: true,
                    itemCount: gameProvider.currentGame.log.length,
                    itemBuilder: (context, index) {
                      final entry =
                          gameProvider.currentGame.log.reversed.toList()[index];
                      Color entryColor = AppTheme.fhTextSecondary;
                      String cleanEntry =
                          entry.replaceAll(RegExp(r'<span[^>]*>|<\/span>'), "");

                      final colorMatch =
                          RegExp(r'color:#([0-9a-fA-F]{6})').firstMatch(entry);
                      if (colorMatch != null) {
                        try {
                          entryColor = Color(
                              int.parse('FF${colorMatch.group(1)}', radix: 16));
                        } catch (e) {/* fallback */}
                      } else if (entry.contains('var(--fh-accent-green)')) {
                        entryColor = AppTheme.fhAccentGreen;
                      } else if (entry.contains('var(--fh-accent-red)')) {
                        entryColor = AppTheme.fhAccentRed;
                      } else if (entry.contains('var(--fh-accent-orange)')) {
                        entryColor = AppTheme.fhAccentOrange;
                      } else if (entry.contains('var(--fh-accent-purple)')) {
                        entryColor = AppTheme.fhAccentPurple;
                      } else if (entry.contains('font-weight:bold')) {
                        entryColor = AppTheme.fhTextPrimary;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(
                          cleanEntry,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: entryColor, height: 1.4),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}