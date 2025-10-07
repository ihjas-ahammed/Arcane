// lib/src/widgets/player_stats_drawer.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
// import 'package:arcane/src/utils/constants.dart'; // No longer needed for basePlayerGameStats

class PlayerStatsDrawer extends StatelessWidget {
  const PlayerStatsDrawer({super.key});

  Widget _buildStatDisplay(BuildContext context, String icon, String name,
      String value, // Changed iconEmoji to icon (MDI name or emoji string)
      {String? buffValue,
      Color? buffColor,
      String? description,
      double? progressPercent}) {
    final theme = Theme.of(context);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    Widget iconWidget;
    if (icon.length == 1 || icon.length == 2) {
      // Assume emoji if 1 or 2 chars
      iconWidget = Text(icon,
          style: TextStyle(
              fontSize: 20,
              color: (gameProvider.getSelectedTask()?.taskColor ??
                      AppTheme.fhAccentTealFixed)
                  .withOpacity(0.9)));
    } else {
      // Assume MDI icon name if longer
      final iconData = MdiIcons.fromString(icon.replaceAll('mdi-', '')) ??
          MdiIcons.helpCircleOutline;
      iconWidget = Icon(iconData,
          size: 20,
          color: (gameProvider.getSelectedTask()?.taskColor ??
                  AppTheme.fhAccentTealFixed)
              .withOpacity(0.9));
    }

    // Valorant style stat display
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              iconWidget, // Use the determined icon widget
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.fhTextSecondary,
                      fontWeight: FontWeight.w600, // Bolder label
                      letterSpacing: 1),
                ),
              ),
              if (buffValue != null)
                Text(
                  buffValue,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: buffColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12), // Larger buff text
                ),
              const SizedBox(width: 6),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                    // Use bodyLarge for stat value
                    color: AppTheme.fhTextPrimary,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (progressPercent != null &&
              name.toUpperCase() != 'VITALITY' &&
              name.toUpperCase() != 'XP CALC MOD') // Updated condition
            Padding(
              padding: const EdgeInsets.only(
                  top: 5.0, left: 32 + 12), // Align with text after icon
              child: SizedBox(
                  height: 6, // Thicker progress bar
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progressPercent.clamp(0.0, 1.0),
                      backgroundColor: AppTheme.fhBorderColor.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          (gameProvider.getSelectedTask()?.taskColor ??
                                  AppTheme.fhAccentTealFixed)
                              .withOpacity(0.7)),
                    ),
                  )),
            ),
          if (gameProvider.settings.descriptionsVisible &&
              description != null &&
              description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 32 + 12),
              child: Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppTheme.fhTextSecondary.withOpacity(0.7),
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(
          bottom: 8.0,
          top: 20.0,
          left: 16.0,
          right: 16.0), // Increased top padding
      child: Row(
        children: [
          Icon(icon,
              color: AppTheme.fhAccentRed, size: 20), // Use primary accent
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(), // Uppercase titles
            style: theme.textTheme.headlineSmall?.copyWith(
                // Use headlineSmall
                color: AppTheme.fhTextPrimary, // Brighter title
                letterSpacing: 0.8,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEquippedItemRow(BuildContext context, ThemeData theme,
      String label, Map<String, dynamic>? itemDetails, VoidCallback onUnequip) {
    final String name = itemDetails?['name'] ?? 'Empty Slot';
    final String iconStr = itemDetails?['icon'] ?? '➖'; // MDI name or emoji
    final bool isEquipped = itemDetails?['uniqueId'] != null;

    Widget iconWidget;
    if (iconStr.length == 1 || iconStr.length == 2) {
      iconWidget = Text(iconStr, style: const TextStyle(fontSize: 18));
    } else {
      final iconData = MdiIcons.fromString(iconStr.replaceAll('mdi-', '')) ??
          MdiIcons.minusCircleOutline;
      iconWidget = Icon(iconData, size: 18);
    }

    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.0),
      child: Row(
        children: [
          SizedBox(
            width: 70, // Consistent width for label
            child: Text('$label:',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.fhTextSecondary.withOpacity(0.8),
                    fontSize: 13)),
          ),
          iconWidget, // Use the determined icon widget
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: isEquipped
                    ? (gameProvider.getSelectedTask()?.taskColor ??
                        AppTheme
                            .fhAccentTealFixed) // Brighter for equipped items
                    : AppTheme.fhTextSecondary.withOpacity(0.6),
                fontStyle: isEquipped ? FontStyle.normal : FontStyle.italic,
                fontWeight: isEquipped ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isEquipped)
            OutlinedButton(
              onPressed: onUnequip,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                textStyle: TextStyle(
                    fontSize: 10, // Smaller text for button
                    fontFamily: AppTheme.fontBody, // Use body font
                    fontWeight: FontWeight.bold),
                foregroundColor: AppTheme.fhAccentOrange, // Orange for unequip
                side: BorderSide(
                    color: AppTheme.fhAccentOrange.withOpacity(0.7), width: 1),
                minimumSize: const Size(0, 26), // Slightly taller button
              ),
              child: const Text('UNEQUIP'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final theme = Theme.of(context);
    print(
        "[PlayerStatsDrawer] Building drawer. Player HP: ${gameProvider.currentGame.playerCurrentHp}");

    final playerMaxHp = gameProvider.playerGameStats['vitality']!.value;
    final playerCurrentHp = gameProvider.currentGame.playerCurrentHp;
    final hpPercent =
        playerMaxHp > 0 ? (playerCurrentHp / playerMaxHp).clamp(0.0, 1.0) : 0.0;
    Color hpBarColor;
    if (hpPercent * 100 > 60) {
      hpBarColor = AppTheme.fhAccentGreen;
    } else if (hpPercent * 100 > 30) {
      hpBarColor = AppTheme.fhAccentOrange;
    } else {
      hpBarColor = AppTheme.fhAccentRed;
    }

    final Map<String, dynamic> equippedItemsDetails = {};
    gameProvider.equippedItems.forEach((slot, uniqueId) {
      if (uniqueId != null) {
        final owned = gameProvider.getArtifactByUniqueId(uniqueId);
        if (owned != null) {
          final template =
              gameProvider.getArtifactTemplateById(owned.templateId);
          if (template != null) {
            equippedItemsDetails[slot] = {
              'name':
                  '${template.name} Lvl ${owned.currentLevel}', // Include level
              'icon': template.icon,
              'uniqueId': owned.uniqueId,
            };
          } else {
            equippedItemsDetails[slot] = {
              'name': 'Unknown Item',
              'icon': MdiIcons.helpRhombusOutline.codePoint.toString(),
              'uniqueId': uniqueId
            }; // Default icon
          }
        } else {
          equippedItemsDetails[slot] = {
            'name': 'Error Loading',
            'icon': MdiIcons.alertCircleOutline.codePoint.toString(),
            'uniqueId': uniqueId
          }; // Default icon
        }
      } else {
        equippedItemsDetails[slot] = {
          'name': 'Empty Slot',
          'icon': '➖',
          'uniqueId': null
        };
      }
    });

    final unequippedGear = gameProvider.artifacts.where((ownedArt) {
      final template =
          gameProvider.getArtifactTemplateById(ownedArt.templateId);
      return template != null &&
          template.type != 'powerup' &&
          !gameProvider.equippedItems.values.contains(ownedArt.uniqueId);
    }).toList();

    return Drawer(
      backgroundColor: AppTheme.fhBgDark, // Darker drawer background
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Container(
            // Header Section
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 16, 16, 16),
            decoration: BoxDecoration(
                color: AppTheme.fhBgMedium, // Slightly lighter header
                border: Border(
                    bottom: BorderSide(
                        color: AppTheme.fhBorderColor.withOpacity(0.5),
                        width: 1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    gameProvider.currentUser?.displayName ??
                        "Adventurer", // Display Name
                    style: theme.textTheme.displaySmall
                        ?.copyWith(color: AppTheme.fhAccentRed)),
                const SizedBox(height: 4),
                Text('LEVEL ${gameProvider.romanize(gameProvider.playerLevel)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppTheme.fhTextSecondary, letterSpacing: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      Icon(MdiIcons.starShootingOutline,
                          color: AppTheme.fhAccentGold, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${gameProvider.currentLevelXPProgress.toStringAsFixed(0)} / ${gameProvider.xpNeededForNextLevel.toStringAsFixed(0)} XP',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppTheme.fhTextSecondary),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  // XP Bar
                  height: 8, // Thicker XP Bar
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (gameProvider.xpProgressPercent / 100)
                          .clamp(0.0, 1.0),
                      backgroundColor: AppTheme.fhBorderColor.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.fhAccentGold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  // HP Bar
                  children: <Widget>[
                    Icon(MdiIcons.heartPulse, size: 18, color: hpBarColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: hpPercent,
                            backgroundColor:
                                AppTheme.fhBorderColor.withOpacity(0.3),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(hpBarColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${playerCurrentHp.toStringAsFixed(0)} / ${playerMaxHp.toStringAsFixed(0)} HP',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.fhTextPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildSectionTitle(theme, MdiIcons.swordCross, 'Equipped Gear'),
          _buildEquippedItemRow(
              context,
              theme,
              'Weapon',
              equippedItemsDetails['weapon'],
              () => gameProvider.unequipArtifact('weapon')),
          _buildEquippedItemRow(
              context,
              theme,
              'Armor',
              equippedItemsDetails['armor'],
              () => gameProvider.unequipArtifact('armor')),
          _buildEquippedItemRow(
              context,
              theme,
              'Talisman',
              equippedItemsDetails['talisman'],
              () => gameProvider.unequipArtifact('talisman')),
          _buildSectionTitle(
              theme, MdiIcons.treasureChestOutline, 'Inventory (Gear)'),
          if (unequippedGear.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 15.0, horizontal: 16.0),
              child: Center(
                  child: Text('No gear in inventory.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppTheme.fhTextSecondary.withOpacity(0.7)))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: unequippedGear.length,
              itemBuilder: (context, index) {
                final ownedArt = unequippedGear[index];
                final template =
                    gameProvider.getArtifactTemplateById(ownedArt.templateId);
                if (template == null) return const SizedBox.shrink();

                Widget itemIconWidget;
                if (template.icon.length == 1 || template.icon.length == 2) {
                  itemIconWidget =
                      Text(template.icon, style: const TextStyle(fontSize: 18));
                } else {
                  final iconData = MdiIcons.fromString(
                          template.icon.replaceAll('mdi-', '')) ??
                      MdiIcons.treasureChest;
                  itemIconWidget = Icon(iconData, size: 18);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 2.0, horizontal: 16.0),
                  child: Material(
                    color:
                        AppTheme.fhBgMedium.withOpacity(0.7), // Item background
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      onTap: () =>
                          gameProvider.equipArtifact(ownedArt.uniqueId),
                      borderRadius: BorderRadius.circular(4),
                      hoverColor: (gameProvider.getSelectedTask()?.taskColor ??
                              AppTheme.fhAccentTealFixed)
                          .withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 8.0),
                        child: Row(
                          children: [
                            itemIconWidget,
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${template.name} (Lvl ${ownedArt.currentLevel})',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.fhTextPrimary,
                                    fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  gameProvider.equipArtifact(ownedArt.uniqueId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (gameProvider
                                        .getSelectedTask()
                                        ?.taskColor ??
                                    AppTheme
                                        .fhAccentTealFixed), // Accent for equip
                                foregroundColor: AppTheme.fhBgDark,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                textStyle: TextStyle(
                                    fontSize: 10,
                                    fontFamily: AppTheme.fontBody,
                                    fontWeight: FontWeight.bold),
                                minimumSize:
                                    const Size(0, 28), // Slightly taller button
                                elevation: 1,
                              ),
                              child: const Text('EQUIP'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          _buildSectionTitle(theme, MdiIcons.starFourPointsOutline, 'Runes'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 16.0),
            child: Center(
                child: Text("Rune system not yet active.",
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.fhTextDisabled))),
          ),
          _buildSectionTitle(theme, MdiIcons.chartLineVariant, 'Player Stats'),
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: gameProvider.playerGameStats.entries.map((entry) {
              final stat = entry.value;
              // Hide internal bonusXPMod, show XP CALC MOD instead if it's the one used for display
              if (stat.name == 'bonusXPMod') return const SizedBox.shrink();

              final buffValue = stat.value - stat.base;
              String statValDisplay =
                  stat.value.toStringAsFixed(0); // Default display

              if (stat.name == 'LUCK' ||
                  stat.name == 'COOLDOWN' ||
                  stat.name == 'XP CALC MOD') {
                statValDisplay =
                    '${(stat.value * (stat.name == 'XP CALC MOD' ? 100 : 1)).toStringAsFixed(0)}%';
              }

              String? buffDisplay;
              Color? buffColorVal;
              if (buffValue != 0) {
                String buffValueStr = (stat.name == 'LUCK' ||
                        stat.name == 'COOLDOWN' ||
                        stat.name == 'XP CALC MOD')
                    ? '${(buffValue * (stat.name == 'XP CALC MOD' ? 100 : 1)).toStringAsFixed(0)}%'
                    : buffValue.toStringAsFixed(0);
                buffDisplay = '${buffValue > 0 ? '+' : ''}$buffValueStr';
                buffColorVal = buffValue > 0
                    ? AppTheme.fhAccentGreen
                    : AppTheme.fhAccentRed;
              }

              double progress = 0.0;
              if (stat.name != 'VITALITY' && stat.name != 'XP CALC MOD') {
                double typicalMax =
                    100 + (gameProvider.playerLevel - 1) * 2.0;
                if (stat.name == 'STRENGTH' ||
                    stat.name == 'RUNIC' ||
                    stat.name == 'DEFENSE') {
                  typicalMax = 50 + (gameProvider.playerLevel * 2.0);
                } else if (stat.name == 'LUCK' || stat.name == 'COOLDOWN') {
                  typicalMax = 100.0;
                }
                progress = (stat.value.abs() / typicalMax).clamp(0.0, 1.0);
              }

              return _buildStatDisplay(
                context,
                stat.icon, // Pass the MDI name or emoji string
                stat.name,
                statValDisplay,
                buffValue: buffDisplay,
                buffColor: buffColorVal,
                description: stat.description,
                progressPercent:
                    (stat.name != 'VITALITY' && stat.name != 'XP CALC MOD')
                        ? progress
                        : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
