// lib/src/widgets/header_widget.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/screens/logbook_screen.dart';
import 'package:arcane/src/screens/settings_screen.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HeaderWidget extends StatelessWidget {
  final String currentViewLabel;
  const HeaderWidget({super.key, required this.currentViewLabel});

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 900; // Match HomeScreen breakpoint
    final Color currentAccentColor =
        gameProvider.getSelectedTask()?.taskColor ??
            theme.colorScheme.secondary;

    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: kToolbarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: <Widget>[
                if (isSmallScreen)
                  IconButton(
                    icon: Icon(MdiIcons.formatListChecks,
                        color: AppTheme.fhTextSecondary),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    tooltip: 'Missions',
                  ),
                if (!isSmallScreen)
                  Icon(MdiIcons.shieldCrownOutline,
                      color: currentAccentColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentViewLabel.toUpperCase(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppTheme.fhTextPrimary,
                      letterSpacing: 1.0,
                    ),
                    textAlign:
                        isSmallScreen ? TextAlign.start : TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: Icon(MdiIcons.bookOpenVariant,
                      color: AppTheme.fhTextSecondary),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LogbookScreen()));
                  },
                  tooltip: 'Logbook',
                ),
                IconButton(
                  icon: Icon(MdiIcons.cogOutline,
                      color: AppTheme.fhTextSecondary),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SettingsScreen()));
                  },
                  tooltip: 'Settings',
                ),
                if (isSmallScreen)
                  IconButton(
                    icon: Icon(MdiIcons.accountCircleOutline,
                        color: AppTheme.fhTextSecondary),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    tooltip: 'Profile & Stats',
                  ),
              ],
            ),
          ),
          // Stats Row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            decoration: BoxDecoration(
                color: AppTheme.fhBgDark.withOpacity(0.5),
                border: Border(
                    bottom: BorderSide(
                        color: AppTheme.fhBorderColor.withOpacity(0.3),
                        width: 1))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip(
                  theme,
                  icon: MdiIcons.circleMultipleOutline, // Coins
                  value: gameProvider.coins.toStringAsFixed(0),
                  color: AppTheme.fhAccentGold,
                ),
                const SizedBox(width: 20),
                _buildStatChip(
                  theme,
                  icon: MdiIcons.flashOutline, // Energy
                  value:
                      '${gameProvider.playerEnergy.toStringAsFixed(0)}/${gameProvider.calculatedMaxEnergy.toStringAsFixed(0)}',
                  color: gameProvider.getSelectedTask()?.taskColor ??
                      AppTheme
                          .fhAccentTealFixed, // Retain teal for energy as it's distinct
                ),
                const SizedBox(width: 20),
                _buildStatChip(
                  theme,
                  icon: MdiIcons.starShootingOutline, // XP Level
                  value:
                      'Lvl ${gameProvider.romanize(gameProvider.playerLevel)}',
                  color: currentAccentColor, // Use dynamic accent
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SizedBox(
                    height: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (gameProvider.xpProgressPercent / 100)
                            .clamp(0.0, 1.0),
                        backgroundColor:
                            AppTheme.fhBorderColor.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            currentAccentColor.withOpacity(0.7)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(ThemeData theme,
      {required IconData icon, required String value, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.fhTextPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13),
        ),
      ],
    );
  }
}
