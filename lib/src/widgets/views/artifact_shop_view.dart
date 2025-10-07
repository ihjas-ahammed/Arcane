// lib/src/widgets/views/artifact_shop_view.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/artifact_card.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ArtifactShopView extends StatelessWidget {
  const ArtifactShopView({super.key});

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final theme = Theme.of(context);
    final currentTask = gameProvider.getSelectedTask();
    final String? currentTaskTheme = currentTask?.theme;
    final Color dynamicAccent =
        currentTask?.taskColor ?? theme.colorScheme.secondary;
    final Color buttonTextColor =
        ThemeData.estimateBrightnessForColor(dynamicAccent) == Brightness.dark
            ? AppTheme.fhTextPrimary
            : AppTheme.fhBgDark;

    final itemsToShow = gameProvider.artifactTemplatesList.where((template) {
      final bool themeMatch = currentTaskTheme == null ||
          template.theme == null ||
          template.theme == currentTaskTheme ||
          template.theme == 'general'; // Added general theme
      return !template.type.contains("powerup_dev") && themeMatch;
    }).toList()
      ..sort((a, b) {
        if (currentTaskTheme != null) {
          final bool aIsThemed = a.theme == currentTaskTheme;
          final bool bIsThemed = b.theme == currentTaskTheme;
          if (aIsThemed && !bIsThemed) return -1;
          if (!aIsThemed && bIsThemed) return 1;
        }
        if (a.cost != b.cost) return a.cost.compareTo(b.cost);
        return a.name.compareTo(b.name);
      });

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
                Icon(MdiIcons.storefrontOutline,
                    color: dynamicAccent, size: 32),
                const SizedBox(width: 12),
                Text(
                  "Brok & Sindri's Wares",
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontFamily: AppTheme.fontDisplay,
                      color: AppTheme
                          .fhTextPrimary), // Primary text color for title
                ),
              ],
            ),
          ),
          if (itemsToShow.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                "No wares currently matching your quest's focus. Perhaps try a different quest or generate more content via Settings?",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.fhTextSecondary),
              ),
            )
          else
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
              double childAspectRatio =
                  itemWidth / 270; // Adjusted height for better card display

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(10.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 10.0,
                  childAspectRatio:
                      childAspectRatio.clamp(0.65, 0.9), // Adjusted clamp
                ),
                itemCount: itemsToShow.length,
                itemBuilder: (context, index) {
                  final template = itemsToShow[index];
                  final bool canAfford = gameProvider.coins >= template.cost;
                  final bool isOwned = template.type != 'powerup' &&
                      gameProvider.artifacts
                          .any((art) => art.templateId == template.id);

                  return ArtifactCardWidget(
                    template: template,
                    cost: template.cost,
                    actionSection: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(
                            isOwned
                                ? MdiIcons.checkCircleOutline
                                : (canAfford
                                    ? MdiIcons.cartPlus
                                    : MdiIcons.cartOff),
                            size: 16),
                        label: Text(isOwned
                            ? 'ACQUIRED'
                            : (canAfford
                                ? '${template.cost} Ø'
                                : 'Cost: ${template.cost} Ø')),
                        onPressed: (!canAfford || isOwned)
                            ? null
                            : () => gameProvider.buyArtifact(template.id),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: isOwned
                                ? AppTheme.fhBgDark.withOpacity(0.6)
                                : (canAfford
                                    ? dynamicAccent
                                    : AppTheme.fhAccentRed.withOpacity(0.7)),
                            foregroundColor: isOwned
                                ? AppTheme.fhTextSecondary.withOpacity(0.7)
                                : (canAfford
                                    ? buttonTextColor
                                    : AppTheme.fhTextPrimary),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8), // Adjusted padding
                            textStyle: const TextStyle(
                                fontSize: 11,
                                fontFamily: AppTheme.fontBody,
                                fontWeight: FontWeight.bold),
                            disabledBackgroundColor:
                                AppTheme.fhBgDark.withOpacity(0.5),
                            disabledForegroundColor:
                                AppTheme.fhTextSecondary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4))),
                      ),
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
