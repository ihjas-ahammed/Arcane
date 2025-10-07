// lib/src/widgets/left_panel_widget.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart'; // For theme icons

class LeftPanelWidget extends StatelessWidget {
  const LeftPanelWidget({super.key});

  IconData _getThemeIcon(String? theme) {
    switch (theme) {
      case 'tech':
        return MdiIcons.memory;
      case 'knowledge':
        return MdiIcons.bookOpenPageVariantOutline;
      case 'learning':
        return MdiIcons.lightbulbOutline;
      case 'discipline':
        return MdiIcons.karate;
      case 'order':
        return MdiIcons.playlistCheck;
      default:
        return MdiIcons.briefcaseOutline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width <
        768; // Adjusted to match HomeScreen's desktop breakpoint logic

    // print("[LeftPanelWidget] Building LeftPanelWidget. Mobile: $isMobile"); // DEBUG

    // Mobile view now primarily driven by HomeScreen's SingleChildScrollView
    // Desktop View is also effectively mobile now due to HomeScreen changes.
    // So, we can unify the logic more or keep the structure for potential future re-differentiation.
    // For now, we'll keep the isMobile check but ensure it works within a scrollable context.

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(MdiIcons.swordCross,
                    color: gameProvider.getSelectedTask()?.taskColor ??
                        AppTheme.fhAccentTealFixed,
                    size: isMobile ? 24 : 28),
                const SizedBox(width: 8),
                Text('Quests',
                    style: isMobile
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineSmall
                            ?.copyWith(fontFamily: AppTheme.fontDisplay)),
              ],
            ),
            const Divider(height: 16),
            if (gameProvider.mainTasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                    child: Text('No quests available.',
                        style: TextStyle(
                            color: AppTheme.fhTextSecondary,
                            fontStyle: FontStyle.italic))),
              )
            else if (isMobile) // Horizontal scroll for icons on mobile
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: gameProvider.mainTasks.length,
                  itemBuilder: (ctx, index) {
                    final task = gameProvider.mainTasks[index];
                    final isSelected = gameProvider.selectedTaskId == task.id;
                    return Tooltip(
                      message: task.name,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InkWell(
                          onTap: () {
                            gameProvider.setSelectedTaskId(task.id);
                            gameProvider.setCurrentView('task-details');
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (gameProvider
                                          .getSelectedTask()
                                          ?.taskColor ??
                                      AppTheme.fhAccentTealFixed)
                                  : AppTheme.fhBgLight,
                              border: Border.all(
                                color: isSelected
                                    ? (gameProvider
                                            .getSelectedTask()
                                            ?.taskColor ??
                                        AppTheme.fhAccentTealFixed)
                                    : AppTheme.fhBorderColor,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getThemeIcon(task.theme),
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.fhTextSecondary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else // Vertical list for larger screens (now also part of SingleChildScrollView)
              ListView.builder(
                shrinkWrap: true, // Important for ListView in Column
                physics: const NeverScrollableScrollPhysics(), // Parent scrolls
                itemCount: gameProvider.mainTasks.length,
                itemBuilder: (context, index) {
                  final task = gameProvider.mainTasks[index];
                  final isSelected = gameProvider.selectedTaskId == task.id;
                  return Card(
                    elevation: isSelected ? 2 : 0,
                    margin: const EdgeInsets.only(bottom: 8.0),
                    color: isSelected
                        ? (gameProvider.getSelectedTask()?.taskColor ??
                                AppTheme.fhAccentTealFixed)
                            .withOpacity(0.2)
                        : AppTheme.fhBgLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.0),
                      side: BorderSide(
                        color: isSelected
                            ? (gameProvider.getSelectedTask()?.taskColor ??
                                AppTheme.fhAccentTealFixed)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        _getThemeIcon(task.theme),
                        color: isSelected
                            ? (gameProvider.getSelectedTask()?.taskColor ??
                                AppTheme.fhAccentTealFixed)
                            : AppTheme.fhTextSecondary,
                        size: 22,
                      ),
                      title: Text(
                        task.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isSelected
                              ? AppTheme.fhTextPrimary
                              : AppTheme.fhTextPrimary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Chip(
                        label: Text('🔥${task.streak}'),
                        backgroundColor: Colors.transparent,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppTheme.fhTextPrimary
                              : AppTheme.fhAccentOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      selected: isSelected,
                      onTap: () {
                        gameProvider.setSelectedTaskId(task.id);
                        gameProvider.setCurrentView('task-details');
                      },
                      selectedTileColor:
                          (gameProvider.getSelectedTask()?.taskColor ??
                                  AppTheme.fhAccentTealFixed)
                              .withOpacity(0.15),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                    ),
                  );
                },
              ),
            if (isMobile &&
                gameProvider.selectedTaskId != null &&
                gameProvider.mainTasks.isNotEmpty) ...[
              const Divider(height: 16),
              Text(
                gameProvider.getSelectedTask()?.name ?? 'Select a Quest',
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '🔥 Streak: ${gameProvider.getSelectedTask()?.streak ?? 0}',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.fhAccentOrange,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
