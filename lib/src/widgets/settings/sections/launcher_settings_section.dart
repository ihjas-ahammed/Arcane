import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/views/launcher_fullscreen_setting.dart';
import 'package:missions/src/screens/launcher/views/launcher_sheets.dart' show showLauncherSettings;
import 'package:missions/src/screens/launcher/views/launcher_takeover_settings.dart';
import 'package:missions/src/screens/launcher/views/launcher_task_bubble_settings.dart';
import 'package:missions/src/widgets/settings/sections/settings_section_card.dart';

/// Home-launcher options (Android only): making Arcane the default home app
/// (or, on ROMs like MIUI/HyperOS that refuse that, the takeover fallback),
/// plus a shortcut into the full launcher customization sheet (icon pack,
/// dock, widgets, hidden apps) that's otherwise only reachable by long-press
/// on the launcher's own home screen.
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
        const Divider(height: 16),
        const LauncherFullscreenSetting(),
        const Divider(height: 16),
        const LauncherTaskBubbleSettings(),
        const Divider(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(MdiIcons.tuneVariant, size: 20),
          title: const Text('Customize launcher', style: TextStyle(fontSize: 14)),
          subtitle: const Text('Icon pack, dock, home-screen widgets & hidden apps', style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => showLauncherSettings(context),
        ),
      ],
    );
  }
}
