// lib/src/widgets/views/park_view.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/game_models.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

enum _ParkSubView {
  menu,
  parkOverview,
  construction,
  fossilCenter,
  hatchery,
  enclosures,
  ownedBuildingsManagement
}

class ParkView extends StatefulWidget {
  const ParkView({super.key});

  @override
  State<ParkView> createState() => _ParkViewState();
}

class _ParkViewState extends State<ParkView> {
  _ParkSubView _currentSubView = _ParkSubView.menu;
  String? _selectedOwnedDinoId;

  Widget _buildMenuButton(BuildContext context,
      {required IconData icon,
      required String label,
      required _ParkSubView subView,
      required Color color}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      color: AppTheme.fhBgMedium,
      child: InkWell(
        onTap: () => setState(() => _currentSubView = subView),
        borderRadius: BorderRadius.circular(4.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: AppTheme.fhTextPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubViewAppBar(
      BuildContext context, String title, Color dynamicAccent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(MdiIcons.arrowLeftCircleOutline,
                color: dynamicAccent, size: 28),
            onPressed: () =>
                setState(() => _currentSubView = _ParkSubView.menu),
            tooltip: "Back to Park Menu",
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: AppTheme.fhTextPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final theme = Theme.of(context);
    final Color dynamicAccent = gameProvider.getSelectedTask()?.taskColor ??
        theme.colorScheme.secondary;

    if (_currentSubView == _ParkSubView.menu) {
      return _buildParkMenu(context, gameProvider, dynamicAccent);
    }

    Widget currentViewWidget;
    String viewTitle = "";

    switch (_currentSubView) {
      case _ParkSubView.construction:
        viewTitle = "Construction Blueprints";
        currentViewWidget =
            _buildConstructionView(context, gameProvider, dynamicAccent);
        break;
      case _ParkSubView.ownedBuildingsManagement:
        viewTitle = "Park Infrastructure";
        currentViewWidget =
            _buildOwnedBuildingsSection(context, gameProvider, dynamicAccent);
        break;
      case _ParkSubView.fossilCenter:
        viewTitle = "Expedition Center";
        currentViewWidget =
            _buildFossilCenterSection(context, gameProvider, dynamicAccent);
        break;
      case _ParkSubView.hatchery:
        viewTitle = "Hammond Creation Lab";
        currentViewWidget =
            _buildHatcherySection(context, gameProvider, dynamicAccent);
        break;
      case _ParkSubView.enclosures:
        viewTitle = "Dinosaur Paddocks";
        currentViewWidget =
            _buildEnclosuresSection(context, gameProvider, dynamicAccent);
        break;
      default: // menu handled above
        currentViewWidget =
            const Center(child: Text("Section not implemented."));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubViewAppBar(context, viewTitle, dynamicAccent),
          SingleChildScrollView(
            child: Column(
              children: [
                _buildParkStatsCard(context, gameProvider, dynamicAccent),
                const SizedBox(height: 16),
                _buildParkActionsCard(context, gameProvider, dynamicAccent),
              ],
            ),
          ),
          currentViewWidget,
          if (_selectedOwnedDinoId != null &&
              _currentSubView == _ParkSubView.enclosures)
            _buildOwnedDinosaurDetails(
                context, gameProvider, dynamicAccent, _selectedOwnedDinoId!),
        ],
      ),
    );
  }

  Widget _buildParkMenu(
      BuildContext context, GameProvider gameProvider, Color dynamicAccent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(MdiIcons.island, color: dynamicAccent, size: 36),
                const SizedBox(width: 12),
                Text("Isla Nublar Dynamics",
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(color: AppTheme.fhTextPrimary)),
              ],
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                _buildParkStatsCard(context, gameProvider, dynamicAccent),
                const SizedBox(height: 16),
                _buildParkActionsCard(context, gameProvider, dynamicAccent),
              ],
            ),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3,
            children: [
              _buildMenuButton(context,
                  icon: MdiIcons.hardHat,
                  label: "Construction",
                  subView: _ParkSubView.construction,
                  color: AppTheme.fhAccentOrange),
              _buildMenuButton(context,
                  icon: MdiIcons.officeBuildingCogOutline,
                  label: "Manage Infrastructure",
                  subView: _ParkSubView.ownedBuildingsManagement,
                  color: AppTheme.fhAccentTeal),
              _buildMenuButton(context,
                  icon: MdiIcons.compassRose,
                  label: "Expedition Center",
                  subView: _ParkSubView.fossilCenter,
                  color: AppTheme.fhAccentGold),
              _buildMenuButton(context,
                  icon: MdiIcons.dna,
                  label: "Creation Lab",
                  subView: _ParkSubView.hatchery,
                  color: AppTheme.fhAccentPurple),
              _buildMenuButton(context,
                  icon: MdiIcons.fence,
                  label: "Paddocks",
                  subView: _ParkSubView.enclosures,
                  color: AppTheme.fhAccentGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionalPlaceholder(
      ThemeData theme, String message, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      color: AppTheme.fhBgMedium.withOpacity(0.7),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 32, color: AppTheme.fhTextSecondary.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppTheme.fhTextSecondary.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 20.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.fhTextSecondary, size: 20),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }

  Widget _buildParkStatsCard(
      BuildContext context, GameProvider gameProvider, Color dynamicAccent) {
    final theme = Theme.of(context);
    final parkManager = gameProvider.parkManager;
    final int starRating =
        (parkManager.parkRating / (MAX_PARK_RATING_FOR_STARS / 5.0))
            .round()
            .clamp(0, 5);

    return Card(
      color: AppTheme.fhBgMedium,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Removed title from here as it's in the sub-view app bar
            _buildStatRow(theme, MdiIcons.starCircleOutline, "Park Rating:",
                parkManager.parkRating.toString(), AppTheme.fhAccentGold),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.trophyOutline,
                          size: 18, color: AppTheme.fhTextSecondary),
                      const SizedBox(width: 8),
                      Text("Appeal:",
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.fhTextSecondary)),
                    ],
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < starRating
                            ? MdiIcons.star
                            : MdiIcons.starOutline,
                        color: AppTheme.fhAccentGold,
                        size: 22,
                      );
                    }),
                  ),
                ],
              ),
            ),
            _buildStatRow(
                theme,
                MdiIcons.cash,
                "Park Funds:",
                "\$${parkManager.parkDollars.toStringAsFixed(0)}",
                AppTheme.fhAccentGreen),
            _buildStatRow(
                theme,
                MdiIcons.lightningBoltOutline,
                "Player Energy (Park Use):",
                "${gameProvider.playerEnergy.toStringAsFixed(0)} / ${gameProvider.calculatedMaxEnergy.toStringAsFixed(0)}",
                AppTheme.fhAccentTealFixed),
            _buildStatRow(
              theme,
              MdiIcons.powerPlugOutline,
              "Total Power:",
              "${parkManager.currentPowerGenerated} / ${parkManager.currentPowerConsumed}",
              parkManager.currentPowerGenerated >=
                      parkManager.currentPowerConsumed
                  ? AppTheme.fhAccentGreen
                  : AppTheme.fhAccentOrange,
            ),
            _buildStatRow(
                theme,
                MdiIcons.arrowUpCircleOutline,
                "Income / Min:",
                "\$${parkManager.incomePerMinuteDollars}",
                AppTheme.fhAccentGreen),
            _buildStatRow(
                theme,
                MdiIcons.arrowDownCircleOutline,
                "Costs / Min:",
                "\$${parkManager.operationalCostPerMinuteDollars}",
                AppTheme.fhAccentRed),
            const SizedBox(height: 8),
            SizedBox(
              height: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: gameProvider.calculatedMaxEnergy > 0
                      ? (gameProvider.playerEnergy /
                          gameProvider.calculatedMaxEnergy)
                      : 0,
                  backgroundColor: AppTheme.fhBorderColor.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.fhAccentTealFixed.withOpacity(0.7)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkActionsCard(
      BuildContext context, GameProvider gameProvider, Color dynamicAccent) {
    final theme = Theme.of(context);
    final Color buttonTextColor =
        ThemeData.estimateBrightnessForColor(dynamicAccent) == Brightness.dark
            ? AppTheme.fhTextPrimary
            : AppTheme.fhBgDark;

    return Card(
      color: AppTheme.fhBgMedium,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: Icon(MdiIcons.runFast, size: 18),
              label: Text("Fast Forward 1 Min ($SKIP_MINUTE_ENERGY_COST⚡)"),
              onPressed: gameProvider.playerEnergy >= SKIP_MINUTE_ENERGY_COST
                  ? () => gameProvider.skipOneMinute()
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: dynamicAccent,
                foregroundColor: buttonTextColor,
                disabledBackgroundColor: AppTheme.fhBgDark.withOpacity(0.5),
                disabledForegroundColor:
                    AppTheme.fhTextSecondary.withOpacity(0.5),
              ),
            ),
            if (gameProvider.playerEnergy < SKIP_MINUTE_ENERGY_COST)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Not enough energy to fast forward.",
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppTheme.fhAccentOrange),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(ThemeData theme, IconData icon, String label,
      String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.fhTextSecondary),
              const SizedBox(width: 8),
              Text(label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppTheme.fhTextSecondary)),
            ],
          ),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: valueColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildConstructionView(
      BuildContext context, GameProvider gameProvider, Color dynamicAccent) {
    final theme = Theme.of(context);
    final allTemplates = gameProvider.buildingTemplatesList;

    Map<String, List<BuildingTemplate>> categorizedTemplates = {
      "Enclosures": allTemplates.where((t) => t.type == "enclosure").toList(),
      "Operations": allTemplates
          .where((t) => ["fossil_center", "hatchery", "research_outpost"]
              .contains(t.type))
          .toList(),
      "Guest Facilities": allTemplates
          .where((t) => ["visitor_center", "amenity_shop"].contains(t.type))
          .toList(),
      "Feeders": allTemplates.where((t) => t.type == "food_station").toList(),
      "Power": allTemplates.where((t) => t.type == "power_plant").toList(),
    };

    categorizedTemplates.removeWhere((key, value) => value.isEmpty);

    if (allTemplates.isEmpty) {
      return const Center(
          child: Text("No building blueprints available.",
              style: TextStyle(fontStyle: FontStyle.italic)));
    }

    // --- MODIFICATION START ---
    // Replace ListView with Column if this view is part of a larger scrollable area
    return Column(
      // Was: ListView
      children: categorizedTemplates.entries.map((entry) {
        String categoryName = entry.key;
        List<BuildingTemplate> templatesInCategory = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(theme, categoryName,
                MdiIcons.formatListChecks), // Generic icon for category
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                childAspectRatio: 1.2, // Adjusted for better info display
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: templatesInCategory.length,
              itemBuilder: (ctx, index) {
                final template = templatesInCategory[index];
                final canAfford = gameProvider.canAffordBuilding(template);
                final Color buttonTextColor =
                    ThemeData.estimateBrightnessForColor(dynamicAccent) ==
                            Brightness.dark
                        ? AppTheme.fhTextPrimary
                        : AppTheme.fhBgDark;
                return Card(
                  color: AppTheme.fhBgLight,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                                MdiIcons.fromString(template.icon) ??
                                    MdiIcons.domain,
                                size: 28,
                                color: dynamicAccent),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                              template.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600), // Bolder title
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Cost: \$${template.costDollars}",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.fhTextSecondary)),
                            if (template.sizeX != null &&
                                template.sizeY != null)
                              Text("Size: ${template.sizeX}x${template.sizeY}",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.fhTextSecondary)),
                            if (template.incomePerMinuteDollars != null &&
                                template.incomePerMinuteDollars! > 0)
                              Text(
                                  "Income: \$${template.incomePerMinuteDollars}/min",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.fhAccentGreen)),
                            if (template.operationalCostPerMinuteDollars !=
                                    null &&
                                template.operationalCostPerMinuteDollars! > 0)
                              Text(
                                  "Upkeep: \$${template.operationalCostPerMinuteDollars}/min",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.fhAccentOrange)),
                            if (template.parkRatingBoost != null &&
                                template.parkRatingBoost! > 0)
                              Text("Rating: +${template.parkRatingBoost}",
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.fhAccentGold)),
                            if (template.capacity != null)
                              Text("Capacity: ${template.capacity}",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.fhTextSecondary)),
                            if (template.powerRequired != null &&
                                template.powerRequired! > 0)
                              Text("Power Req: ${template.powerRequired}",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.fhAccentOrange)),
                            if (template.powerOutput != null &&
                                template.powerOutput! > 0)
                              Text("Power Gen: ${template.powerOutput}",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.fhAccentGreen)),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(MdiIcons.hammerScrewdriver, size: 16),
                            label: const Text("CONSTRUCT"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: canAfford
                                    ? dynamicAccent
                                    : AppTheme.fhTextDisabled,
                                foregroundColor: buttonTextColor,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10), // Increased padding
                                textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.bold)), // Bolder text
                            onPressed: canAfford
                                ? () => gameProvider
                                    .buyAndPlaceBuilding(template.id)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20), // Space between categories
          ],
        );
      }).toList(),
    );
    // --- MODIFICATION END ---
  }

  Widget _buildOwnedBuildingsSection(
      BuildContext context, GameProvider gameProvider, Color dynamicAccent) {
    final theme = Theme.of(context);
    final ownedBuildings = gameProvider.ownedBuildings;

    if (ownedBuildings.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Text("No structures built yet.",
            style: TextStyle(fontStyle: FontStyle.italic)),
      ));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ownedBuildings.length,
      itemBuilder: (ctx, index) {
        final owned = ownedBuildings[index];
        final template = gameProvider.buildingTemplatesList.firstWhere(
            (t) => t.id == owned.templateId,
            orElse: () => BuildingTemplate(
                id: 'unknown',
                name: 'Unknown Building',
                type: 'unknown',
                costDollars: 0,
                icon: 'mdi-help-rhombus'));

        String statusText = owned.isOperational ? 'Online' : 'Offline';
        Color statusColor = owned.isOperational
            ? AppTheme.fhAccentGreen
            : AppTheme.fhAccentOrange;
        String tooltipAction =
            owned.isOperational ? "Take Offline" : "Bring Online";

        if (!owned.isOperational && (template.powerRequired ?? 0) > 0) {
          int totalPowerGenerated =
              gameProvider.parkManager.currentPowerGenerated;
          int totalPowerConsumedExcludingThis =
              gameProvider.parkManager.currentPowerConsumed -
                  (owned.isOperational ? (template.powerRequired ?? 0) : 0);

          if (totalPowerGenerated <
              totalPowerConsumedExcludingThis + (template.powerRequired ?? 0)) {
            statusText = 'Offline - No Power';
            statusColor = AppTheme.fhAccentRed;
            tooltipAction = "Needs Power";
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: AppTheme.fhBgLight,
          child: ListTile(
            leading: Icon(MdiIcons.fromString(template.icon) ?? MdiIcons.domain,
                color: dynamicAccent),
            title: Text(template.name, style: theme.textTheme.titleMedium),
            subtitle: Text(
                "Type: ${template.type.replaceAll('_', ' ').toUpperCase()} - Status: $statusText",
                style: theme.textTheme.bodySmall?.copyWith(color: statusColor)),
            trailing: Wrap(
              spacing: 0,
              children: [
                IconButton(
                  icon: Icon(
                      owned.isOperational
                          ? MdiIcons.powerPlugOffOutline
                          : MdiIcons.powerPlugOutline,
                      size: 20,
                      color: AppTheme.fhTextSecondary),
                  tooltip: tooltipAction,
                  onPressed: () => gameProvider
                      .toggleBuildingOperationalStatus(owned.uniqueId),
                ),
                IconButton(
                  icon: Icon(MdiIcons.deleteOutline,
                      size: 20, color: AppTheme.fhAccentRed),
                  tooltip: "Demolish",
                  onPressed: () => gameProvider.sellBuilding(owned.uniqueId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFossilCenterSection(
      BuildContext context, GameProvider gameProvider, Color dynamicAccent) {
    final theme = Theme.of(context);
    final availableSpeciesForExcavation = gameProvider.dinosaurSpeciesList
        .where((species) =>
            gameProvider.playerLevel >= species.minPlayerLevelToUnlock)
        .toList();

    final fossilRecords =
        gameProvider.fossilRecords; // Using the local GameProvider instance

    final bool fossilCenterOperational = gameProvider.ownedBuildings.any((b) {
      final template = gameProvider.buildingTemplatesList
          .firstWhereOrNull((t) => t.id == b.templateId);
      return template?.type == "fossil_center" && b.isOperational;
    });

    if (!fossilCenterOperational) {
      return _buildConditionalPlaceholder(
          theme,
          "Build and operate an Expedition Center to start fossil hunts.",
          MdiIcons.compassOffOutline);
    }
    if (availableSpeciesForExcavation.isEmpty) {
      return const Center(
          child: Text(
              "No dinosaur species currently available for excavation at your level.",
              style: TextStyle(fontStyle: FontStyle.italic)));
    }

    return Card(
      color: AppTheme.fhBgMedium,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (availableSpeciesForExcavation.isEmpty)
              const Text("No active fossil expeditions. Start discovering!",
                  style: TextStyle(fontStyle: FontStyle.italic)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: availableSpeciesForExcavation.length,
              itemBuilder: (ctx, index) {
                final species = availableSpeciesForExcavation[index];
                final record = fossilRecords
                        .firstWhereOrNull((fr) => fr.speciesId == species.id) ??
                    FossilRecord(
                        speciesId:
                            species.id); // Handle if record doesn't exist yet

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(MdiIcons.fromString(species.icon) ?? MdiIcons.bone,
                          size: 24, color: dynamicAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(species.name,
                                style: theme.textTheme.titleMedium),
                            LinearProgressIndicator(
                              value: record.excavationProgress / 100,
                              backgroundColor:
                                  AppTheme.fhBorderColor.withOpacity(0.3),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(dynamicAccent),
                            ),
                            Text(
                                "Genome: ${record.excavationProgress.toStringAsFixed(1)}% ${record.isGenomeComplete ? '(Complete)' : ''}",
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: dynamicAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            textStyle: const TextStyle(fontSize: 10)),
                        onPressed: record.isGenomeComplete ||
                                gameProvider.playerEnergy <
                                    species.fossilExcavationEnergyCost
                            ? null
                            : () => gameProvider.excavateFossil(species.id),
                        child: Text(record.isGenomeComplete
                            ? "COMPLETE"
                            : "EXCAVATE (${species.fossilExcavationEnergyCost}⚡)"),
                      ),
                    ],
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHatcherySection(
      BuildContext context, GameProvider gameProvider, Color dynamicAccent) {
    final theme = Theme.of(context);

    final bool hatcheryOperational = gameProvider.ownedBuildings.any((b) {
      final template = gameProvider.buildingTemplatesList
          .firstWhereOrNull((t) => t.id == b.templateId);
      return template?.type == "hatchery" && b.isOperational;
    });

    if (!hatcheryOperational) {
      return _buildConditionalPlaceholder(
          theme,
          "Build and operate a Hammond Creation Lab to incubate dinosaurs.",
          MdiIcons.eggOffOutline);
    }

    final completableFossils = gameProvider.fossilRecords.where((fr) {
      final species = gameProvider.dinosaurSpeciesList
          .firstWhereOrNull((s) => s.id == fr.speciesId);
      return species != null &&
          gameProvider.playerLevel >= species.minPlayerLevelToUnlock &&
          fr.isGenomeComplete &&
          !gameProvider.ownedDinosaurs.any((od) =>
              od.speciesId == fr.speciesId && od.name.contains("(Incubating)"));
    }).toList();

    final incubatingDinos = gameProvider.ownedDinosaurs
        .where((d) => d.name.contains("(Incubating)"))
        .toList();

    return Card(
      color: AppTheme.fhBgMedium,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (completableFossils.isEmpty && incubatingDinos.isEmpty)
              const Center(
                  child: Text(
                      "No complete genomes ready for incubation or none currently incubating. Keep excavating!",
                      style: TextStyle(fontStyle: FontStyle.italic))),
            if (completableFossils.isNotEmpty) ...[
              Text("Ready for Incubation:",
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: dynamicAccent)),
              const SizedBox(height: 8),
            ],
            ...completableFossils.map((record) {
              final species = gameProvider.dinosaurSpeciesList
                  .firstWhereOrNull((s) => s.id == record.speciesId);
              if (species == null) return const SizedBox.shrink();
              final canAffordIncubation =
                  gameProvider.parkManager.parkDollars >=
                          species.incubationCostDollars &&
                      gameProvider.playerEnergy >= incubationEnergyCost;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                        MdiIcons.fromString(species.icon) ??
                            MdiIcons.eggOutline,
                        size: 24,
                        color: dynamicAccent),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text("${species.name} Genome Ready",
                            style: theme.textTheme.titleMedium)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: dynamicAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          textStyle: const TextStyle(fontSize: 10)),
                      onPressed: canAffordIncubation
                          ? () => gameProvider.incubateDinosaur(species.id)
                          : null,
                      child: Text(canAffordIncubation
                          ? "INCUBATE (\$${species.incubationCostDollars}, $incubationEnergyCost⚡)"
                          : "CAN'T AFFORD"),
                    ),
                  ],
                ),
              );
            }),
            if (incubatingDinos.isNotEmpty) ...[
              const Divider(height: 20),
              Text("Currently Incubating:",
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: dynamicAccent)),
              const SizedBox(height: 8),
            ],
            ...incubatingDinos.map((dino) {
              final species = gameProvider.dinosaurSpeciesList
                  .firstWhereOrNull((s) => s.id == dino.speciesId);
              final double incubationProgress =
                  (dino.age / baseIncubationDuration.toDouble())
                      .clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                            MdiIcons.fromString(species?.icon ?? "") ??
                                MdiIcons.timerSand,
                            color: dynamicAccent,
                            size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(species?.name ?? "Dinosaur",
                                style: theme.textTheme.titleMedium)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: incubationProgress,
                      backgroundColor: AppTheme.fhBorderColor.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          dynamicAccent.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                        "Progress: ${(incubationProgress * 100).toStringAsFixed(0)}% (Time: ${dino.age}/$baseIncubationDuration units)",
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEnclosuresSection(
      BuildContext context, GameProvider gameProvider, Color dynamicAccent) {
    final theme = Theme.of(context);
    final enclosures = gameProvider.ownedBuildings.where((b) {
      final template = gameProvider.buildingTemplatesList
          .firstWhereOrNull((t) => t.id == b.templateId);
      return template?.type == "enclosure" && b.isOperational;
    }).toList();

    if (enclosures.isEmpty) {
      return _buildConditionalPlaceholder(
          theme,
          "Build and operate Enclosures to house your dinosaurs.",
          MdiIcons.fence);
    }

    final hatchedDinosaursNotInEnclosures =
        gameProvider.ownedDinosaurs.where((dino) {
      return !gameProvider.ownedBuildings.any((building) =>
              building.dinosaurUniqueIds.contains(dino.uniqueId)) &&
          !dino.name.contains("(Incubating)");
    }).toList();

    return ListView(
      // Changed to ListView for better scrolling if many enclosures
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // Parent handles scrolling
      children: [
        ...enclosures.map((enclosure) {
          final template = gameProvider.buildingTemplatesList
              .firstWhereOrNull((t) => t.id == enclosure.templateId)!;
          final dinosaursInEnclosure = gameProvider.ownedDinosaurs
              .where((d) => enclosure.dinosaurUniqueIds.contains(d.uniqueId))
              .toList();
          final foodStation = gameProvider.ownedBuildings.firstWhereOrNull((b) {
            final foodTemplate = gameProvider.buildingTemplatesList
                .firstWhereOrNull((t) => t.id == b.templateId);
            // This is a simplified assumption: any operational food station can feed any enclosure.
            // A more complex system might link specific feeders to enclosures.
            return foodTemplate?.type == "food_station" && b.isOperational;
          });

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            color: AppTheme.fhBgMedium,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.name,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: dynamicAccent)),
                  Text(
                      "Capacity: ${dinosaursInEnclosure.length} / ${template.capacity ?? 'N/A'}",
                      style: theme.textTheme.bodySmall),
                  if (foodStation != null)
                    Text(
                        "Food Level in Park: ${foodStation.currentFoodLevel ?? 0} / $enclosureBaseFoodCapacity",
                        style: theme.textTheme.bodySmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (foodStation != null)
                        ElevatedButton.icon(
                          icon: Icon(MdiIcons.foodAppleOutline, size: 16),
                          label: Text("Add Food ($feedDinoEnergyCost⚡)",
                              style: const TextStyle(fontSize: 10)),
                          onPressed:
                              gameProvider.playerEnergy >= feedDinoEnergyCost
                                  ? () => gameProvider.feedDinosaursInEnclosure(
                                      enclosure.uniqueId, 50)
                                  : null,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: dynamicAccent,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8)),
                        ),
                      if (hatchedDinosaursNotInEnclosures.isNotEmpty &&
                          (template.capacity == null ||
                              dinosaursInEnclosure.length < template.capacity!))
                        PopupMenuButton<String>(
                            onSelected: (dinoUniqueId) =>
                                gameProvider.addDinosaurToEnclosure(
                                    dinoUniqueId, enclosure.uniqueId),
                            enabled: enclosure.isOperational,
                            itemBuilder: (BuildContext context) {
                              return hatchedDinosaursNotInEnclosures
                                  .map((dino) {
                                final species = gameProvider.dinosaurSpeciesList
                                    .firstWhereOrNull(
                                        (s) => s.id == dino.speciesId);
                                return PopupMenuItem<String>(
                                  value: dino.uniqueId,
                                  child: Text(species?.name ?? dino.name),
                                );
                              }).toList();
                            },
                            child: ElevatedButton.icon(
                              icon: Icon(MdiIcons.plusBoxOutline, size: 16),
                              label: Text("Add Dino",
                                  style: const TextStyle(fontSize: 10)),
                              onPressed: enclosure.isOperational ? null : () {},
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: enclosure.isOperational
                                      ? dynamicAccent
                                      : AppTheme.fhTextDisabled,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8)),
                            )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (dinosaursInEnclosure.isEmpty)
                    const Text("This enclosure is empty.",
                        style: TextStyle(fontStyle: FontStyle.italic)),
                  ...dinosaursInEnclosure.map((dino) {
                    final species = gameProvider.dinosaurSpeciesList
                        .firstWhereOrNull((s) => s.id == dino.speciesId);
                    return ListTile(
                      leading: Icon(
                          MdiIcons.fromString(species?.icon ?? "") ??
                              MdiIcons.paw,
                          color: dynamicAccent),
                      title: Text(dino.name),
                      subtitle: Text(
                          "${species?.name ?? "Dinosaur"} - Comfort: ${dino.currentComfort.toStringAsFixed(0)}% Food: ${dino.currentFood.toStringAsFixed(0)}%"),
                      onTap: () {
                        setState(() {
                          _selectedOwnedDinoId = dino.uniqueId;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOwnedDinosaurDetails(BuildContext context,
      GameProvider gameProvider, Color dynamicAccent, String dinoUniqueId) {
    final theme = Theme.of(context);
    final ownedDino = gameProvider.ownedDinosaurs
        .firstWhereOrNull((d) => d.uniqueId == dinoUniqueId);
    if (ownedDino == null) return const SizedBox.shrink();
    final species = gameProvider.dinosaurSpeciesList
        .firstWhereOrNull((s) => s.id == ownedDino.speciesId);
    if (species == null) return const SizedBox.shrink();

    return Dialog(
      backgroundColor: AppTheme.fhBgMedium,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ownedDino.name,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(color: dynamicAccent)),
                  IconButton(
                      icon: Icon(MdiIcons.closeCircleOutline,
                          color: AppTheme.fhTextSecondary),
                      onPressed: () =>
                          setState(() => _selectedOwnedDinoId = null))
                ],
              ),
              Text("Species: ${species.name}",
                  style: theme.textTheme.titleMedium),
              const Divider(height: 20),
              _buildStatRow(
                  theme,
                  MdiIcons.heartPulse,
                  "Health:",
                  "${ownedDino.currentHealth.toStringAsFixed(0)}%",
                  ownedDino.currentHealth > 60
                      ? AppTheme.fhAccentGreen
                      : (ownedDino.currentHealth > 30
                          ? AppTheme.fhAccentOrange
                          : AppTheme.fhAccentRed)),
              _buildStatRow(
                  theme,
                  MdiIcons.emoticonHappyOutline,
                  "Comfort:",
                  "${ownedDino.currentComfort.toStringAsFixed(0)}%",
                  ownedDino.currentComfort > species.comfortThreshold * 100
                      ? AppTheme.fhAccentGreen
                      : AppTheme.fhAccentOrange),
              _buildStatRow(
                  theme,
                  MdiIcons.foodDrumstickOutline,
                  "Food:",
                  "${ownedDino.currentFood.toStringAsFixed(0)}%",
                  ownedDino.currentFood > 50
                      ? AppTheme.fhAccentGreen
                      : (ownedDino.currentFood > 20
                          ? AppTheme.fhAccentOrange
                          : AppTheme.fhAccentRed)),
              _buildStatRow(theme, MdiIcons.cakeVariantOutline, "Age:",
                  "${ownedDino.age} days", AppTheme.fhTextSecondary),
              _buildStatRow(theme, MdiIcons.scaleBalance, "Diet:", species.diet,
                  AppTheme.fhTextSecondary),
              const SizedBox(height: 10),
              Text("Needs:", style: theme.textTheme.titleSmall),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "- Social Group: ${species.socialNeedsMin}-${species.socialNeedsMax}",
                        style: theme.textTheme.bodySmall),
                    Text("- Paddock Size: ${species.enclosureSizeNeeds} units",
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(species.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppTheme.fhTextSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
