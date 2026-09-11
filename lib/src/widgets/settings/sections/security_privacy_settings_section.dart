import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/settings/sections/settings_section_card.dart';

class SecurityPrivacySettingsSection extends StatelessWidget {
  final AppProvider appProvider;

  const SecurityPrivacySettingsSection({
    super.key,
    required this.appProvider,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      icon: MdiIcons.shieldLockOutline,
      title: 'Security, Privacy & Theme',
      children: [
        Text(
          "Nora AI Context Access",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.fhTextSecondary,
          ),
        ),
        SwitchListTile.adaptive(
          title: const Text('Access Session Logs', style: TextStyle(fontSize: 14)),
          value: appProvider.settings.noraAccessSessions,
          activeTrackColor: AppTheme.fhAccentPurple,
          contentPadding: EdgeInsets.zero,
          onChanged: (bool value) {
            appProvider.setSettings(
              appProvider.settings..noraAccessSessions = value,
            );
          },
        ),
        SwitchListTile.adaptive(
          title: const Text('Access Finance Data', style: TextStyle(fontSize: 14)),
          value: appProvider.settings.noraAccessFinance,
          activeTrackColor: AppTheme.fhAccentPurple,
          contentPadding: EdgeInsets.zero,
          onChanged: (bool value) {
            appProvider.setSettings(
              appProvider.settings..noraAccessFinance = value,
            );
          },
        ),
        const Divider(height: 32),
        Text(
          "App Theme",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.fhTextSecondary,
          ),
        ),
        SwitchListTile.adaptive(
          title: const Text('Use System Theme', style: TextStyle(fontSize: 14)),
          value: appProvider.settings.themeMode == 'system',
          activeTrackColor: AppTheme.fhAccentPurple,
          contentPadding: EdgeInsets.zero,
          onChanged: (bool value) {
            appProvider.setSettings(
              appProvider.settings..themeMode = value ? 'system' : 'dark',
            );
          },
        ),
        if (appProvider.settings.themeMode != 'system')
          SwitchListTile.adaptive(
            title: const Text('Dark Mode', style: TextStyle(fontSize: 14)),
            value: appProvider.settings.themeMode == 'dark',
            activeTrackColor: AppTheme.fhAccentPurple,
            contentPadding: EdgeInsets.zero,
            onChanged: (bool value) {
              appProvider.setSettings(
                appProvider.settings..themeMode = value ? 'dark' : 'light',
              );
            },
          ),
      ],
    );
  }
}
