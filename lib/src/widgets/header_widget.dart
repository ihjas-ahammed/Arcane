// lib/src/widgets/header_widget.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/screens/chatbot_screen.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final String currentViewLabel;
  const HeaderWidget({super.key, required this.currentViewLabel});

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
          : null, // Use default drawer icon on small screens
      title: Text(
        currentViewLabel.toUpperCase(),
        style: theme.textTheme.headlineSmall?.copyWith(
          color: AppTheme.fhTextPrimary,
          letterSpacing: 1.0,
        ),
      ),
      actions: <Widget>[
        IconButton(
          icon: Icon(MdiIcons.robotHappyOutline,
              color: AppTheme.fhTextSecondary),
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const ChatbotScreen()));
          },
          tooltip: 'Arcane Advisor',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}