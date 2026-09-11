import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/onboarding/app_tour_screen.dart';
import 'package:missions/src/screens/settings/bus_network_editor_screen.dart';
import 'package:missions/src/screens/settings/homescreen_widgets_preview_screen.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/settings/sections/settings_section_card.dart';

class DiagnosticsAndToolsSection extends StatelessWidget {
  final AppProvider appProvider;
  final ThemeData theme;

  const DiagnosticsAndToolsSection({
    super.key,
    required this.appProvider,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 8. DIAGNOSTICS & ONBOARDING
        SettingsSectionCard(
          icon: MdiIcons.tools,
          title: 'System Diagnostics',
          children: [
            Text(
              'Use these tools to repair data inconsistencies or replay tutorials.',
              style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: Icon(MdiIcons.databaseSyncOutline, size: 18),
              label: const Text('RECALIBRATE TIME LOGS'),
              onPressed: () async {
                try {
                  await appProvider.recalibrateTimeLogs();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Time logs successfully recalibrated from session history.',
                        ),
                        backgroundColor: AppTheme.fhAccentGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Recalibration failed: $e'),
                        backgroundColor: AppTheme.fhAccentRed,
                      ),
                    );
                  }
                }
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                foregroundColor: AppTheme.fhAccentOrange,
                side: BorderSide(
                  color: AppTheme.fhAccentOrange.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: Icon(MdiIcons.presentationPlay, size: 18),
              label: const Text('REPLAY SYSTEM TOUR'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppTourScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                foregroundColor: AppTheme.fhAccentTeal,
                side: BorderSide(
                  color: AppTheme.fhAccentTeal.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),

        // 8.5 ANDROID HOMESCREEN WIDGETS STUDIO
        SettingsSectionCard(
          icon: MdiIcons.widgetsOutline,
          title: 'Homescreen Widgets Studio',
          children: [
            Text(
              'Preview and calibrate all native Android home-screen widgets (Bus Radar, Active Task, Finance Liquid, and Journal Cadence).',
              style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Icon(MdiIcons.eyeOutline, size: 18),
              label: const Text('OPEN WIDGETS PREVIEW & TEST STUDIO'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HomescreenWidgetsPreviewScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: AppTheme.fhAccentGold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),

        // 8.6 TRANSIT DATA & SUB-STOPS EDITOR
        SettingsSectionCard(
          icon: MdiIcons.busStopCovered,
          title: 'Transit Network & Sub-Stops Data',
          children: [
            Text(
              'Manually edit routes, add intermediate sub-stops, reorder stop sequences, calibrate distances, and manage bus departure timetables.',
              style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Icon(MdiIcons.mapMarkerPath, size: 18),
              label: const Text('OPEN TRANSIT DATA EDITOR'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BusNetworkEditorScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: AppTheme.fhAccentTealFixed,
                foregroundColor: AppTheme.fhBgDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
