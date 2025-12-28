import 'package:arcane/src/widgets/views/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
      backgroundColor: AppTheme.fhBgDeepDark,
      automaticallyImplyLeading: !isLargeScreen,
      // VALORANT Style: Minimal divider
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: AppTheme.fhBorderColor.withValues(alpha: 0.3),
          height: 1.0,
        ),
      ),
      leading: isLargeScreen
          ? Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Icon(MdiIcons.shieldCrownOutline,
                  color: AppTheme.fhAccentRed),
            )
          : Builder(
              builder: (context) => IconButton(
                icon: Icon(MdiIcons.menu, color: AppTheme.fhTextPrimary),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decorative square
          Container(
            width: 8,
            height: 8,
            color: AppTheme.fhAccentRed,
            margin: const EdgeInsets.only(right: 12),
          ),
          Text(
            currentViewLabel.toUpperCase(),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.fhTextPrimary,
              letterSpacing: 3.0,
              fontFamily: AppTheme.fontDisplay,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: <Widget>[
        // Status Indicators
        if (appProvider.loadingTaskName != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.fhBgDark,
              border: Border.all(color: AppTheme.fhAccentTeal),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.fhAccentTeal),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "PROCESSING",
                  style: TextStyle(
                      color: AppTheme.fhAccentTeal,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],

        IconButton(
          icon: Icon(MdiIcons.cogOutline, color: AppTheme.fhTextSecondary),
          tooltip: 'SYSTEM SETTINGS',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text("SETTINGS")),
                        backgroundColor: AppTheme.fhBgDeepDark,
                        body: Center(
                            child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 800),
                                child: const SettingsView())),
                      )),
            );
          },
        ),
        // Persona / Virtues Button
        IconButton(
          icon: Icon(MdiIcons.shieldAccount, color: AppTheme.fhTextSecondary),
          onPressed: onOpenPersona,
          tooltip: 'ARMORY',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}
