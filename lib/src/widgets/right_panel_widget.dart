// lib/src/widgets/right_panel_widget.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
// import 'package:arcane/src/utils/constants.dart'; // Removed unused import
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/models/game_models.dart'; // Ensured models are imported for OwnedArtifact, ArtifactTemplate

class RightPanelWidget extends StatelessWidget {
  const RightPanelWidget({super.key});

  Widget _buildStatDisplay(
      BuildContext context, String iconEmoji, String name, String value,
      {String? buffValue,
      Color? buffColor,
      String? description,
      double? progressPercent}) {
    final theme = Theme.of(context);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(iconEmoji,
                  style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.fhTextSecondary.withAlpha(
                          (0.8 * 255).round()))), // Fixed withOpacity
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name.toUpperCase(),
                  style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: AppTheme.fontDisplay,
                      color: AppTheme.fhTextPrimary,
                      fontSize: 13,
                      letterSpacing: 0.5),
                ),
              ),
              if (buffValue != null)
                Text(
                  buffValue,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: buffColor, fontWeight: FontWeight.bold),
                ),
              const SizedBox(width: 4),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.fhTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ],
          ),
          if (progressPercent != null &&
              name.toUpperCase() != 'VITALITY' &&
              name.toUpperCase() != 'XP CALC MOD' && // Updated condition
              name.toUpperCase() !=
                  'XP BONUS') // Check if this is the display name for bonusXPMod
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 30),
              child: SizedBox(
                  height: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressPercent.clamp(0.0, 1.0),
                      backgroundColor: AppTheme.fhBgLight
                          .withAlpha((0.5 * 255).round()), // Fixed withOpacity
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.fhAccentOrange),
                    ),
                  )),
            ),
          if (gameProvider.settings.descriptionsVisible &&
              description != null &&
              description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 30),
              child: Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color:
                        AppTheme.fhTextSecondary.withAlpha((0.8 * 255).round()),
                    fontStyle: FontStyle.italic), // Fixed withOpacity
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final theme = Theme.of(context);
    // print("[RightPanelWidget] Building RightPanelWidget"); // DEBUG

    final playerMaxHp = gameProvider.playerGameStats['vitality']!.value;
    final playerCurrentHp = gameProvider.currentGame.playerCurrentHp;
    final hpPercent = playerMaxHp > 0 ? (playerCurrentHp / playerMaxHp) : 0.0;
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
        final owned = gameProvider.artifacts.firstWhere(
            (art) => art.uniqueId == uniqueId,
            orElse: () =>
                OwnedArtifact(uniqueId: '', templateId: '', currentLevel: 0));
        if (owned.uniqueId.isNotEmpty) {
          final template = gameProvider.artifactTemplatesList.firstWhere(
              (tmpl) => tmpl.id == owned.templateId,
              orElse: () => ArtifactTemplate(
                  id: '',
                  name: '',
                  type: '',
                  description: '',
                  cost: 0,
                  icon: ''));
          if (template.id.isNotEmpty) {
            equippedItemsDetails[slot] = {
              'name': template.name,
              'icon': template.icon,
              'level': owned.currentLevel,
              'uniqueId': owned.uniqueId,
            };
          } else {
            equippedItemsDetails[slot] = {
              'name': 'Unknown Item',
              'icon': '❓',
              'level': 0,
              'uniqueId': uniqueId
            };
          }
        } else {
          equippedItemsDetails[slot] = {
            'name': 'Error Loading',
            'icon': '⚠️',
            'level': 0,
            'uniqueId': uniqueId
          };
        }
      } else {
        equippedItemsDetails[slot] = {
          'name': 'None',
          'icon': '➖',
          'level': null,
          'uniqueId': null
        };
      }
    });

    final unequippedArtifacts = gameProvider.artifacts
        .where((ownedArt) =>
            !gameProvider.equippedItems.values.contains(ownedArt.uniqueId) &&
            (gameProvider.artifactTemplatesList
                    .firstWhere((t) => t.id == ownedArt.templateId,
                        orElse: () => ArtifactTemplate(
                            id: '',
                            name: '',
                            type: '',
                            description: '',
                            cost: 0,
                            icon: ''))
                    .type !=
                'powerup'))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'VIT',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: AppTheme.fontDisplay,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: hpPercent,
                        backgroundColor: AppTheme.fhBgLight.withAlpha(
                            (0.5 * 255).round()), // Fixed withOpacity
                        valueColor: AlwaysStoppedAnimation<Color>(hpBarColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${playerCurrentHp.toStringAsFixed(0)} / ${playerMaxHp.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppTheme.fhTextPrimary),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (gameProvider.getSelectedTask()?.taskColor ??
                        AppTheme.fhAccentTealFixed),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    gameProvider.romanize(gameProvider.playerLevel),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.fhBgDark, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildSectionTitle(
                gameProvider, theme, MdiIcons.hanger, 'Equipped Gear'),
            _buildEquippedItemRow(
                gameProvider,
                theme,
                'Weapon',
                equippedItemsDetails['weapon'],
                () => gameProvider.unequipArtifact('weapon')),
            _buildEquippedItemRow(
                gameProvider,
                theme,
                'Armor',
                equippedItemsDetails['armor'],
                () => gameProvider.unequipArtifact('armor')),
            _buildEquippedItemRow(
                gameProvider,
                theme,
                'Talisman',
                equippedItemsDetails['talisman'],
                () => gameProvider.unequipArtifact('talisman')),
            const Divider(height: 24),
            _buildSectionTitle(gameProvider, theme, MdiIcons.bagPersonalOutline,
                'Backpack (Gear)'),
            unequippedArtifacts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                        child: Text('Backpack is empty of gear.',
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: AppTheme.fhTextSecondary))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: unequippedArtifacts.length,
                    itemBuilder: (context, index) {
                      final ownedArt = unequippedArtifacts[index];
                      final template = gameProvider.artifactTemplatesList
                          .firstWhere((t) => t.id == ownedArt.templateId,
                              orElse: () => ArtifactTemplate(
                                  id: '',
                                  name: '',
                                  type: '',
                                  description: '',
                                  cost: 0,
                                  icon: ''));
                      if (template.id == '') return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Material(
                          color: AppTheme.fhBgLight.withAlpha(
                              (0.5 * 255).round()), // Fixed withOpacity
                          borderRadius: BorderRadius.circular(4),
                          child: InkWell(
                            onTap: () =>
                                gameProvider.equipArtifact(ownedArt.uniqueId),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 6.0),
                              child: Row(
                                children: [
                                  Text(template.icon,
                                      style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${template.name} (Lvl ${ownedArt.currentLevel})',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: AppTheme.fhTextPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => gameProvider
                                        .equipArtifact(ownedArt.uniqueId),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      textStyle: const TextStyle(
                                          fontSize: 10,
                                          fontFamily: AppTheme.fontBody),
                                      side: BorderSide(
                                          color: AppTheme.fhAccentOrange
                                              .withAlpha((0.5 * 255).round()),
                                          width: 0.5), // Fixed withOpacity
                                      foregroundColor: (gameProvider
                                              .getSelectedTask()
                                              ?.taskColor ??
                                          AppTheme.fhAccentTealFixed),
                                      minimumSize: const Size(0, 24),
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
            const Divider(height: 24),
            _buildSectionTitle(gameProvider, theme, MdiIcons.accountStarOutline,
                'Player Stats'),
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: gameProvider.playerGameStats.entries.map((entry) {
                final stat = entry.value;
                // Hide internal bonusXPMod, show XP CALC MOD instead if it's the one used for display
                if (stat.name == 'bonusXPMod') return const SizedBox.shrink();

                final buffValue = stat.value - stat.base;
                String statValDisplay = stat.value
                    .toStringAsFixed(0); // Default to 0 decimal places

                if (stat.name == 'LUCK' ||
                    stat.name == 'COOLDOWN' ||
                    stat.name ==
                        'XP CALC MOD') { // Updated condition for display
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
                  stat.icon,
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
      GameProvider gameProvider, ThemeData theme, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon,
              color: (gameProvider.getSelectedTask()?.taskColor ??
                  AppTheme.fhAccentTealFixed),
              size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
                fontFamily: AppTheme.fontDisplay,
                color: AppTheme.fhTextSecondary,
                fontSize: 14,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEquippedItemRow(GameProvider gameProvider, ThemeData theme,
      String label, Map<String, dynamic>? itemDetails, VoidCallback onUnequip) {
    final String name = itemDetails?['name'] ?? 'None';
    final String icon = itemDetails?['icon'] ?? '➖';
    final int? level = itemDetails?['level'];
    final String? uniqueId = itemDetails?['uniqueId'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 65,
            child: Text('$label:',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.fhTextSecondary)),
          ),
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              level != null ? '$name (Lvl $level)' : name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: name == 'None'
                    ? AppTheme.fhTextSecondary.withAlpha((0.7 * 255).round())
                    : (gameProvider.getSelectedTask()?.taskColor ??
                        AppTheme
                            .fhAccentTealFixed), // Fixed withOpacity & fhAccentLightCyan
                fontStyle: name == 'None' ? FontStyle.italic : FontStyle.normal,
                fontWeight:
                    name == 'None' ? FontWeight.normal : FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (uniqueId != null)
            TextButton(
              onPressed: onUnequip,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                textStyle: const TextStyle(
                    fontSize: 10, fontFamily: AppTheme.fontBody),
                foregroundColor: AppTheme.fhAccentRed,
                minimumSize: const Size(0, 24),
                side: BorderSide(
                    color: AppTheme.fhAccentRed.withAlpha((0.5 * 255).round()),
                    width: 0.5), // Fixed withOpacity
              ),
              child: const Text('UNEQUIP'),
            ),
        ],
      ),
    );
  }
}
