// lib/src/widgets/ui/artifact_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/models/game_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ArtifactCardWidget extends StatelessWidget {
  final ArtifactTemplate template;
  final OwnedArtifact? ownedArtifact;
  final Widget? actionSection;
  final int? cost;

  const ArtifactCardWidget({
    super.key,
    required this.template,
    this.ownedArtifact,
    this.actionSection,
    this.cost,
  });

  Map<String, IconData> get _statIcons => {
        'att': MdiIcons.sword,
        'def': MdiIcons.shieldOutline,
        'health': MdiIcons.heartFlash,
        'runic': MdiIcons.fireAlert,
        'luck': MdiIcons.cloverOutline,
        'cooldown': MdiIcons.clockFast,
        'bonusXPMod': MdiIcons.schoolOutline,
        'direct_damage': MdiIcons.laserPointer,
        'heal_player': MdiIcons.bottleTonicPlusOutline,
        'uses': MdiIcons.repeatVariant,
      };

  Widget _buildStatsList(BuildContext context,
      ArtifactTemplate effectiveTemplate, OwnedArtifact? currentOwned) {
    final theme = Theme.of(context);
    final List<Widget> statWidgets = [];
    final Color dynamicAccent =
        Provider.of<GameProvider>(context, listen: false)
                .getSelectedTask()
                ?.taskColor ??
            Theme.of(context).colorScheme.secondary;

    Widget statChip(IconData icon, String value, Color color,
        {bool isBright = false}) {
      final Color textColor =
          isBright ? AppTheme.fhBgDark : AppTheme.fhTextPrimary;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
            color: isBright
                ? color.withOpacity(0.85)
                : AppTheme.fhBgDark.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.5), width: 0.5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color: isBright ? AppTheme.fhBgDark.withOpacity(0.8) : color),
            const SizedBox(width: 4),
            Text(value,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (effectiveTemplate.type == 'powerup') {
      if (effectiveTemplate.effectType == 'direct_damage' &&
          effectiveTemplate.effectValue != null &&
          effectiveTemplate.effectValue! > 0) {
        statWidgets.add(statChip(_statIcons['direct_damage']!,
            '${effectiveTemplate.effectValue}', AppTheme.fhAccentRed,
            isBright: true));
      }
      if (effectiveTemplate.effectType == 'heal_player' &&
          effectiveTemplate.effectValue != null &&
          effectiveTemplate.effectValue! > 0) {
        statWidgets.add(statChip(_statIcons['heal_player']!,
            '+${effectiveTemplate.effectValue} HP', AppTheme.fhAccentGreen,
            isBright: true));
      }
      final usesValue = currentOwned?.uses ?? template.uses;
      if (usesValue != null) {
        statWidgets.add(statChip(
            _statIcons['uses']!, '$usesValue Uses', AppTheme.fhTextSecondary));
      }
    } else {
      // Use dynamicAccent for primary stats if applicable, or specific colors for others
      if (effectiveTemplate.baseAtt != null && effectiveTemplate.baseAtt! > 0) {
        statWidgets.add(statChip(_statIcons['att']!,
            '+${effectiveTemplate.baseAtt}', AppTheme.fhAccentOrange));
      }
      if (effectiveTemplate.baseDef != null && effectiveTemplate.baseDef! > 0) {
        statWidgets.add(statChip(_statIcons['def']!,
            '+${effectiveTemplate.baseDef}', dynamicAccent));
      }
      if (effectiveTemplate.baseHealth != null &&
          effectiveTemplate.baseHealth! > 0) {
        statWidgets.add(statChip(_statIcons['health']!,
            '+${effectiveTemplate.baseHealth}', AppTheme.fhAccentGreen));
      }
      if (effectiveTemplate.baseRunic != null &&
          effectiveTemplate.baseRunic! > 0) {
        statWidgets.add(statChip(_statIcons['runic']!,
            '+${effectiveTemplate.baseRunic}', AppTheme.fhAccentPurple));
      }
      if (effectiveTemplate.baseLuck != null && effectiveTemplate.baseLuck! > 0) {
        statWidgets.add(statChip(_statIcons['luck']!,
            '+${effectiveTemplate.baseLuck}%', dynamicAccent));
      }
      if (effectiveTemplate.baseCooldown != null &&
          effectiveTemplate.baseCooldown! > 0) {
        statWidgets.add(statChip(
            _statIcons['cooldown']!,
            '-${effectiveTemplate.baseCooldown}% CD',
            AppTheme.fhTextSecondary));
      }
      if (effectiveTemplate.bonusXPMod != null &&
          effectiveTemplate.bonusXPMod! > 0) {
        statWidgets.add(statChip(
            _statIcons['bonusXPMod']!,
            '+${(effectiveTemplate.bonusXPMod! * 100).toStringAsFixed(0)}% XP',
            AppTheme.fhAccentGreen));
      }
    }

    if (statWidgets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          template.type == 'powerup'
              ? "Single-use tactical item."
              : "No direct combat bonuses.",
          style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: AppTheme.fhTextSecondary.withOpacity(0.7),
              fontSize: 10),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Wrap(
        spacing: 6.0,
        runSpacing: 4.0,
        children: statWidgets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final ArtifactTemplate displayTemplate = ownedArtifact != null
        ? gameProvider.getArtifactEffectiveStats(ownedArtifact!)
        : template;

    final Color dynamicAccent = gameProvider.getSelectedTask()?.taskColor ??
        theme.colorScheme.secondary;
    final Color cardTitleColor = dynamicAccent;
    final Color cardTextColorOnAccent =
        ThemeData.estimateBrightnessForColor(dynamicAccent) == Brightness.dark
            ? AppTheme.fhTextPrimary
            : AppTheme.fhBgDark;

    Color borderColor = AppTheme.fhBorderColor.withOpacity(0.5);
    if (ownedArtifact != null) {
      borderColor = dynamicAccent.withOpacity(0.7);
    } else if (cost != null && gameProvider.coins >= cost!) {
      borderColor = dynamicAccent.withOpacity(0.5);
    }

    Widget itemIcon;
    if (displayTemplate.icon.length == 1 || displayTemplate.icon.length == 2) {
      itemIcon = Text(displayTemplate.icon,
          style: const TextStyle(fontSize: 32)); // Larger icon
    } else {
      final iconData =
          MdiIcons.fromString(displayTemplate.icon.replaceAll('mdi-', '')) ??
              MdiIcons.treasureChest;
      itemIcon = Icon(iconData, size: 32, color: AppTheme.fhTextSecondary);
    }

    return Card(
      elevation: 0,
      color: AppTheme.fhBgLight.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6.0),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment
              .spaceBetween, // Ensure action button is at bottom
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50, // Fixed size for icon container
                      height: 50,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: AppTheme.fhBgDark.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4)),
                      child: Center(child: itemIcon),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTemplate.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontFamily: AppTheme.fontDisplay,
                                color: cardTitleColor, // Dynamic color
                                fontWeight: FontWeight.bold,
                                fontSize: 15), // Slightly larger title
                            maxLines: 2, // Allow two lines for name
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (ownedArtifact != null &&
                              displayTemplate.type != 'powerup' &&
                              displayTemplate.maxLevel != null)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                  color: cardTitleColor.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(3)),
                              child: Text(
                                'LEVEL ${ownedArtifact!.currentLevel} / ${displayTemplate.maxLevel}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: cardTextColorOnAccent,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    fontSize: 9),
                              ),
                            )
                          else
                            Text(
                              displayTemplate.type.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color:
                                      AppTheme.fhTextSecondary.withOpacity(0.8),
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (displayTemplate.theme != null) ...[
                  Row(
                    children: [
                      Icon(MdiIcons.paletteSwatchOutline,
                          size: 12,
                          color: AppTheme.fhTextSecondary.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text("System Alignment: ${displayTemplate.theme!}",
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.fhTextSecondary.withOpacity(0.7),
                              fontSize: 10,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  displayTemplate.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.fhTextSecondary.withOpacity(0.9),
                      fontStyle: FontStyle.italic,
                      fontSize: 11,
                      height: 1.3),
                  maxLines: 3, // Allow more lines for description
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _buildStatsList(context, displayTemplate, ownedArtifact),
              ],
            ),
            if (actionSection != null) ...[
              const Spacer(), // Push action to bottom if there's space
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Divider(
                    color: AppTheme.fhBorderColor.withOpacity(0.3),
                    height: 1,
                    thickness: 0.5),
              ),
              Padding(
                padding:
                    const EdgeInsets.only(top: 6.0), // Add padding above action
                child: actionSection!,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
