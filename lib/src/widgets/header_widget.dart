import 'package:arcane/src/widgets/views/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
// Import Settings View

class HeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final String currentViewLabel;
  final VoidCallback? onOpenPersona; // Callback for opening end drawer

  const HeaderWidget(
      {super.key, required this.currentViewLabel, this.onOpenPersona});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 900;
    final Color currentAccentColor =
        appProvider.getSelectedTask()?.taskColor ?? theme.colorScheme.secondary;

    return AppBar(
      automaticallyImplyLeading: !isLargeScreen,
      leading: isLargeScreen
          ? Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child:
                  Icon(MdiIcons.shieldCrownOutline, color: currentAccentColor),
            )
          : null,
      title: Text(
        currentViewLabel.toUpperCase(),
        style: theme.textTheme.headlineSmall?.copyWith(
          color: AppTheme.fhTextPrimary,
          letterSpacing: 1.0,
        ),
      ),
      centerTitle: true,
      actions: <Widget>[
        // Settings Button moved here
        if (appProvider.loadingTaskName != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.fhBgDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.fhBorderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(currentAccentColor),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _getLoadingIcon(appProvider.loadingTaskName!),
                  size: 16,
                  color: AppTheme.fhTextSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],

        IconButton(
          icon: Icon(MdiIcons.cogOutline, color: AppTheme.fhTextSecondary),
          tooltip: 'Settings',
          onPressed: () {
            // Push settings screen
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text("SETTINGS")),
                        backgroundColor: AppTheme.fhBgDeepDark,
                        body: Center(
                            child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 800),
                                child: SettingsView())),
                      )),
            );
          },
        ),
        // Persona / Virtues Button
        IconButton(
          icon: Icon(MdiIcons.shieldAccount, // Or accountDetailsOutline
              color: AppTheme.fhTextSecondary),
          onPressed: onOpenPersona,
          tooltip: 'Persona & Virtues',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  IconData _getLoadingIcon(String taskName) {
    if (taskName.contains("Syncing")) return MdiIcons.cloudSync;
    if (taskName.contains("Analyzing")) return MdiIcons.brain;
    if (taskName.contains("Consulting")) return MdiIcons.robot;
    if (taskName.contains("Authenticating")) return MdiIcons.accountKey;
    return MdiIcons.loading;
  }
}
