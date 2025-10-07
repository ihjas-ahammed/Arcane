// lib/src/widgets/views/blacksmith_view.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/game_models.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/ui/artifact_card.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class BlacksmithView extends StatelessWidget {
  const BlacksmithView({super.key});

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

    final upgradableArtifacts = gameProvider.artifacts.where((art) {
      final template = gameProvider.artifactTemplatesList.firstWhere(
          (t) => t.id == art.templateId,
          orElse: () => ArtifactTemplate(
              id: '', name: '', type: '', description: '', cost: 0, icon: ''));
      return template.id.isNotEmpty;
    }).toList();

    if (upgradableArtifacts.isEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.hammerSickle, size: 48, color: dynamicAccent),
            const SizedBox(height: 16),
            Text("Hephaestus' Forge",
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: AppTheme.fontDisplay,
                    color: AppTheme
                        .fhTextPrimary)), // Use primary text color for title
            const SizedBox(height: 8),
            Text(
              "Your satchel is empty, warrior. Acquire some artifacts to enhance or sell!",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.fhTextSecondary),
            ),
          ],
        ),
      ));
    }

    int getUpgradeCost(ArtifactTemplate template, int currentLevel) {
      if (template.type == 'powerup' ||
          template.maxLevel == null ||
          currentLevel >= template.maxLevel!) {
        return 9999999; // effectively infinity
      }
      return (template.cost *
              blacksmithUpgradeCostMultiplier *
              helper.xpLevelMultiplierPow(
                  1.2, currentLevel - 1)) // Keep 1.2 for blacksmith logic
          .floor();
    }

    int getSellPrice(ArtifactTemplate template, OwnedArtifact ownedArtifact) {
      double sellMultiplier = 1.0;
      if (template.type == 'powerup' &&
          template.uses != null &&
          template.uses! > 0 &&
          ownedArtifact.uses != null) {
        sellMultiplier = (ownedArtifact.uses! / template.uses!);
      }
      return (template.cost * artifactSellPercentage * sellMultiplier).floor();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
          bottom: 16, right: 4, left: 4), // Added left padding
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(MdiIcons.hammerWrench, color: dynamicAccent, size: 32),
                const SizedBox(width: 12),
                Text(
                  "Hephaestus' Forge",
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontFamily: AppTheme.fontDisplay,
                      color: AppTheme
                          .fhTextPrimary), // Use primary text color for title
                ),
              ],
            ),
          ),
          LayoutBuilder(builder: (context, constraints) {
            int crossAxisCount = 2;
            if (constraints.maxWidth > 900) {
              crossAxisCount = 4; // Adjusted breakpoints
            } else if (constraints.maxWidth > 600)
              crossAxisCount = 3;
            else if (constraints.maxWidth < 400) crossAxisCount = 1;

            double itemWidth =
                (constraints.maxWidth - (crossAxisCount + 1) * 10) /
                    crossAxisCount; // 10 for padding
            double childAspectRatio = itemWidth /
                280; // Adjusted for potentially taller cards with more actions

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(10.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10.0,
                mainAxisSpacing: 10.0,
                childAspectRatio:
                    childAspectRatio.clamp(0.6, 0.85), // Adjusted clamp
              ),
              itemCount: upgradableArtifacts.length,
              itemBuilder: (context, index) {
                final ownedArt = upgradableArtifacts[index];
                final template = gameProvider.artifactTemplatesList.firstWhere(
                    (t) => t.id == ownedArt.templateId,
                    orElse: () => ArtifactTemplate(
                        id: '',
                        name: '',
                        type: '',
                        description: '',
                        cost: 0,
                        icon: ''));
                if (template.id == '') return const SizedBox.shrink();

                final upgradeCost =
                    getUpgradeCost(template, ownedArt.currentLevel);
                final sellPrice = getSellPrice(template, ownedArt);
                final bool canUpgrade = template.type != 'powerup' &&
                    template.maxLevel != null &&
                    ownedArt.currentLevel < template.maxLevel!;
                final bool canAffordUpgrade = gameProvider.coins >= upgradeCost;

                return ArtifactCardWidget(
                  template: template,
                  ownedArtifact: ownedArt,
                  actionSection: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (template.type != 'powerup')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0, top: 4.0),
                          child: Center(
                            // Center the sell price
                            child: Text(
                              'Sell Value: $sellPrice Ø',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color:
                                      AppTheme.fhTextSecondary.withOpacity(0.8),
                                  fontSize: 10),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          if (template.type != 'powerup' &&
                              template.maxLevel != null)
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(
                                    canUpgrade
                                        ? MdiIcons.arrowUpBoldCircleOutline
                                        : MdiIcons.checkCircleOutline,
                                    size: 14),
                                label: Text(
                                    canUpgrade
                                        ? (canAffordUpgrade
                                            ? 'UPGRADE ($upgradeCost Ø)'
                                            : '$upgradeCost Ø')
                                        : 'MAX LEVEL',
                                    style: TextStyle(fontSize: 10)),
                                onPressed: (canUpgrade && canAffordUpgrade)
                                    ? () => gameProvider
                                        .upgradeArtifact(ownedArt.uniqueId)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: dynamicAccent,
                                    foregroundColor: buttonTextColor,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 6), // Adjusted padding
                                    textStyle: const TextStyle(
                                        fontFamily: AppTheme.fontBody,
                                        fontWeight: FontWeight.bold),
                                    disabledBackgroundColor:
                                        AppTheme.fhBgDark.withOpacity(0.5),
                                    disabledForegroundColor: AppTheme
                                        .fhTextSecondary
                                        .withOpacity(0.5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(4))),
                              ),
                            ),
                          if (template.type != 'powerup' &&
                              template.maxLevel != null)
                            const SizedBox(width: 6.0), // Gap
                          if (template.type != 'powerup')
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(MdiIcons.cashMinus, size: 14),
                                label: const Text('SELL',
                                    style: TextStyle(fontSize: 10)),
                                onPressed: () => gameProvider
                                    .sellArtifact(ownedArt.uniqueId),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.fhAccentOrange,
                                    side: const BorderSide(
                                        color: AppTheme.fhAccentOrange,
                                        width: 1), // Thicker border
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 6), // Adjusted padding
                                    textStyle: const TextStyle(
                                        fontFamily: AppTheme.fontBody,
                                        fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(4))),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}
