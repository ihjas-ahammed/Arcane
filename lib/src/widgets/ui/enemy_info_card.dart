// lib/src/widgets/ui/enemy_info_card.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/models/game_models.dart'; // For EnemyTemplate
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/game_provider.dart';

class EnemyInfoCardWidget extends StatelessWidget {
  final EnemyTemplate enemy;
  final int playerLevel;
  final VoidCallback onStartGame;

  const EnemyInfoCardWidget({
    super.key,
    required this.enemy,
    required this.playerLevel,
    required this.onStartGame,
  });

  Map<String, dynamic> _getEnemyDifficulty(int enemyMinLevel, int pLevel) {
    final levelDiff = enemyMinLevel - pLevel;
    if (levelDiff <= -3) {
      return {
        'text': "Trivial",
        'color': AppTheme.fhAccentGreen.withOpacity(0.7)
      };
    }
    if (levelDiff <= -1) {
      return {'text': "Easy", 'color': AppTheme.fhAccentGreen};
    }
    if (levelDiff == 0) {
      return {'text': "Moderate", 'color': AppTheme.fhAccentTeal};
    }
    if (levelDiff == 1) {
      return {'text': "Challenging", 'color': AppTheme.fhAccentOrange};
    }
    return {'text': "Deadly", 'color': AppTheme.fhAccentRed, 'isBold': true};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difficulty = _getEnemyDifficulty(enemy.minPlayerLevel, playerLevel);
    final Color dynamicAccent =
        Provider.of<GameProvider>(context, listen: false)
                .getSelectedTask()
                ?.taskColor ??
            theme.colorScheme.secondary;
    final Color cardTextColorOnAccent =
        ThemeData.estimateBrightnessForColor(dynamicAccent) == Brightness.dark
            ? AppTheme.fhTextPrimary
            : AppTheme.fhBgDark;

    // Placeholder for enemy icon/image. Using MDI icon for now.
    IconData enemyVisualIcon = MdiIcons.skullCrossbonesOutline;
    if (enemy.theme == 'nature') enemyVisualIcon = MdiIcons.treeOutline;
    if (enemy.theme == 'ancient') enemyVisualIcon = MdiIcons.templeHinduOutline;
    if (enemy.theme == 'tech') enemyVisualIcon = MdiIcons.robotOutline;

    return Card(
      elevation: 0,
      color: AppTheme.fhBgLight.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6.0),
        side: BorderSide(
            color: AppTheme.fhBorderColor.withOpacity(0.7), width: 1),
      ),
      child: InkWell(
        onTap: onStartGame,
        borderRadius: BorderRadius.circular(6.0),
        hoverColor: dynamicAccent.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: AppTheme.fhBgDark.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4)),
                        child: Center(
                            child: Icon(enemyVisualIcon,
                                size: 30,
                                color:
                                    AppTheme.fhTextSecondary.withOpacity(0.7))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              enemy.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontFamily: AppTheme.fontDisplay,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.fhTextPrimary,
                                  fontSize: 15),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (enemy.theme != null)
                              Text(
                                "${enemy.theme!.toUpperCase()} ENTITY",
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.fhAccentPurple
                                        .withOpacity(0.8),
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                    fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                          child: _StatChip(
                              icon: MdiIcons.heartOutline,
                              value: enemy.health.toString(),
                              color: AppTheme.fhAccentGreen)),
                      Flexible(
                          child: _StatChip(
                              icon: MdiIcons.sword,
                              value: enemy.attack.toString(),
                              color: AppTheme.fhAccentOrange)),
                      Flexible(
                          child: _StatChip(
                              icon: MdiIcons.shieldOutline,
                              value: enemy.defense.toString(),
                              color: AppTheme.fhAccentTeal)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    enemy.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.fhTextSecondary.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                        fontSize: 11,
                        height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: (difficulty['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color:
                                (difficulty['color'] as Color).withOpacity(0.5),
                            width: 0.5)),
                    child: Text(
                      "Threat Level: ${difficulty['text'] as String}",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: difficulty['color'] as Color,
                        fontWeight: (difficulty['isBold'] as bool? ?? false)
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(), // Push button to bottom
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: ElevatedButton(
                  onPressed: onStartGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dynamicAccent,
                    foregroundColor: cardTextColorOnAccent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 12,
                        fontFamily: AppTheme.fontBody,
                        fontWeight: FontWeight.bold),
                  ),
                  child: const Text(
                    'ENGAGE TARGET',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatChip(
      {required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color.withOpacity(0.8)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: AppTheme.fhTextPrimary.withOpacity(0.9),
                fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
