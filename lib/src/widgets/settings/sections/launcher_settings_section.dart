import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/views/launcher_takeover_settings.dart';
import 'package:missions/src/widgets/settings/sections/settings_section_card.dart';

/// Home-launcher options (Android only).
class LauncherSettingsSection extends StatelessWidget {
  const LauncherSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!LauncherNative.isSupported) return const SizedBox.shrink();
    return SettingsSectionCard(
      icon: MdiIcons.homeVariantOutline,
      title: 'Home Launcher',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(MdiIcons.homeImportOutline, size: 20),
          title: const Text('Set Arcane as default home app', style: TextStyle(fontSize: 14)),
          subtitle: const Text('Opens Android default-apps settings', style: TextStyle(fontSize: 12)),
          onTap: LauncherNative.openHomeSettings,
        ),
        const Divider(height: 16),
        const LauncherTakeoverSettings(),
      ],
    );
  }
}
