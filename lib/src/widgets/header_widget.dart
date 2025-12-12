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
}
