import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/screens/finance/finance_dashboard_screen.dart';

class HeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final String currentViewLabel;
  final VoidCallback? onOpenPersona; 

  const HeaderWidget(
      {super.key, required this.currentViewLabel, this.onOpenPersona});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 900;
    
    final double balance = appProvider.financeActions.currentBalance;

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
                fontSize: 16, // Adjusted size
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: <Widget>[
        if (appProvider.loadingTaskName != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.fhAccentTeal),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Balance Widget
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Center(
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceDashboardScreen())),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDark,
                  border: Border.all(color: AppTheme.fhAccentTeal.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(MdiIcons.currencyInr, size: 14, color: AppTheme.fhAccentTeal),
                    const SizedBox(width: 2),
                    Text(
                      balance.toStringAsFixed(0), 
                      style: const TextStyle(
                        color: AppTheme.fhAccentTeal, 
                        fontFamily: 'RobotoMono', 
                        fontWeight: FontWeight.bold, 
                        fontSize: 12
                      )
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

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