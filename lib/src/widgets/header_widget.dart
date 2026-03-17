import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final String currentViewLabel;
  final VoidCallback? onOpenPersona; 
  final Widget? customAction; 

  const HeaderWidget(
      {super.key, required this.currentViewLabel, this.onOpenPersona, this.customAction});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 900;
    
    return AppBar(
      backgroundColor: AppTheme.fhBgDeepDark,
      automaticallyImplyLeading: !isLargeScreen,
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
              child: Icon(MdiIcons.shieldCrownOutline, color: AppTheme.fhAccentRed),
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
          Flexible(
            child: Text(
              currentViewLabel.toUpperCase(),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppTheme.fhTextPrimary,
                letterSpacing: 2.0,
                fontFamily: AppTheme.fontDisplay,
                fontWeight: FontWeight.w900,
                fontSize: 16, 
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: <Widget>[
        if (appProvider.loadingTaskName != null || appProvider.isSyncing) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: JweTheme.accentCyan.withOpacity(0.1),
              border: Border.all(color: JweTheme.accentCyan, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(JweTheme.accentCyan),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  appProvider.loadingTaskName != null ? "AI PROCESSING" : "SYNCING",
                  style: const TextStyle(
                    color: JweTheme.accentCyan,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'RobotoMono'
                  ),
                )
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],

        if (customAction != null)
          customAction!,

        // Persona / Virtues Button
        IconButton(
          icon: Icon(MdiIcons.shieldAccount, color: AppTheme.fhTextSecondary, size: 20),
          onPressed: onOpenPersona,
          tooltip: 'ARMORY',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}