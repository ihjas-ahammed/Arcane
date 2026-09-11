import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/update_service.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/dialogs/whats_new_update_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateSettingsSection extends StatelessWidget {
  final AppProvider appProvider;
  final ThemeData theme;

  const UpdateSettingsSection({
    super.key,
    required this.appProvider,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final accent = JweTheme.accentAmber;
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.cellphoneArrowDown, color: accent, size: 22),
                const SizedBox(width: 10),
                Text(
                  'System Updates & Releases',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Divider(
              height: 24,
              thickness: 0.5,
              color: AppTheme.fhBorderColor.withValues(alpha: 0.5),
            ),

            FutureBuilder<PackageInfo>(
              future: appProvider.updateService.getLocalPackageInfo(),
              builder: (context, snapshot) {
                final ver = snapshot.data?.version ?? '2026.9.5';
                final buildNum = snapshot.data?.buildNumber ?? '2126090505';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.fhBorderColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(MdiIcons.informationOutline, size: 18, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CURRENT INSTALLED BUILD',
                              style: GoogleFonts.orbitron(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppTheme.fhTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Arcane v$ver (Build #$buildNum)',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.fhTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            ElevatedButton.icon(
              icon: appProvider.isCheckingUpdate
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Icon(MdiIcons.update, size: 18),
              label: Text(
                appProvider.isCheckingUpdate
                    ? 'CHECKING GITHUB BUILDS...'
                    : 'CHECK FOR UPDATES NOW',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: appProvider.isCheckingUpdate
                  ? null
                  : () async {
                      if (UpdateService.isDebugBuild) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: JweTheme.panel,
                            content: Text(
                              'Updates are disabled on debug builds (kDebugMode).',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.accentWarn,
                              ),
                            ),
                          ),
                        );
                        return;
                      }
                      final update =
                          await appProvider.checkForAppUpdate(forceCheck: true);
                      if (!context.mounted) return;
                      final packageInfo =
                          await appProvider.updateService.getLocalPackageInfo();
                      if (!context.mounted) return;
                      if (update != null) {
                        WhatsNewUpdateDialog.show(
                          context,
                          update: update,
                          currentVersion: packageInfo.version,
                          currentBuildNumber: packageInfo.buildNumber,
                          updateService: appProvider.updateService,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: JweTheme.panel,
                            content: Text(
                              '✓ You are on the latest build (v${packageInfo.version} #${packageInfo.buildNumber})!',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.accentTeal,
                              ),
                            ),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: accent,
                foregroundColor: Colors.black,
              ),
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              icon: Icon(MdiIcons.history, size: 16, color: accent),
              label: Text(
                "VIEW WHAT'S NEW (BUILD NOTES)",
                style: GoogleFonts.orbitron(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                side: BorderSide(color: accent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final packageInfo =
                    await appProvider.updateService.getLocalPackageInfo();
                if (!context.mounted) return;
                final changelog =
                    await appProvider.updateService.getLatestChangelog();
                if (!context.mounted) return;
                WhatsNewUpdateDialog.showUpdated(
                  context,
                  currentVersion: packageInfo.version,
                  currentBuildNumber: packageInfo.buildNumber,
                  changelogMarkdown: changelog,
                  updateService: appProvider.updateService,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
