import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/settings/sections/settings_section_card.dart';

class UiAndProgressSettingsSection extends StatelessWidget {
  final AppProvider appProvider;
  final ThemeData theme;

  const UiAndProgressSettingsSection({
    super.key,
    required this.appProvider,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = appProvider.getSelectedTask()?.taskColor ??
        AppTheme.fhAccentTealFixed;

    return Column(
      children: [
        // Weekly Progress
        SettingsSectionCard(
          icon: MdiIcons.calendarWeek,
          title: 'Weekly Progress',
          children: [
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Start Day of the Week',
                prefixIcon: Icon(MdiIcons.calendarStartOutline, size: 20),
              ),
              dropdownColor: AppTheme.fhBgMedium,
              initialValue: appProvider.settings.startOfWeek,
              items: const [
                DropdownMenuItem(value: 1, child: Text('Monday')),
                DropdownMenuItem(value: 2, child: Text('Tuesday')),
                DropdownMenuItem(value: 3, child: Text('Wednesday')),
                DropdownMenuItem(value: 4, child: Text('Thursday')),
                DropdownMenuItem(value: 5, child: Text('Friday')),
                DropdownMenuItem(value: 6, child: Text('Saturday')),
                DropdownMenuItem(value: 7, child: Text('Sunday')),
              ],
              onChanged: (value) {
                if (value != null) {
                  appProvider.setSettings(
                    appProvider.settings..startOfWeek = value,
                  );
                }
              },
            ),
          ],
        ),

        // User Interface Config
        SettingsSectionCard(
          icon: MdiIcons.eyeSettingsOutline,
          title: 'User Interface Config',
          children: [
            SwitchListTile.adaptive(
              title: const Text('Verbose Data Display'),
              subtitle: const Text(
                'Show detailed descriptions for stats and items throughout the interface.',
              ),
              value: appProvider.settings.descriptionsVisible,
              onChanged: (value) => appProvider.setSettings(
                appProvider.settings..descriptionsVisible = value,
              ),
              activeTrackColor: activeColor,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile.adaptive(
              title: const Text('Checkable Day Planner Widget'),
              subtitle: const Text(
                'Show the top 5 day planner tasks on the homescreen widget instead of the running task.',
              ),
              value: appProvider.settings.dayPlannerWidgetCheckable,
              onChanged: (value) => appProvider.setSettings(
                appProvider.settings..dayPlannerWidgetCheckable = value,
              ),
              activeTrackColor: activeColor,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }
}
