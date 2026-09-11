import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/settings/data_recovery_screen.dart';
import 'package:missions/src/theme/app_theme.dart';

class CloudSyncSettingsSection extends StatelessWidget {
  final AppProvider appProvider;
  final ThemeData theme;

  const CloudSyncSettingsSection({
    super.key,
    required this.appProvider,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    String lastSavedString = "Not synced yet.";
    if (appProvider.lastSuccessfulSaveTimestamp != null) {
      lastSavedString =
          "Last synced: ${DateFormat('MMM d, yyyy, hh:mm:ss a').format(appProvider.lastSuccessfulSaveTimestamp!.toLocal())}";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  MdiIcons.cloudSyncOutline,
                  color: AppTheme.fhAccentTealFixed,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Cloud Synchronization',
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
            SwitchListTile.adaptive(
              title: const Text('Real-Time Sync'),
              subtitle: const Text('Automatically sync changes to cloud immediately.'),
              value: appProvider.settings.autoSaveEnabled,
              activeTrackColor: AppTheme.fhAccentTeal,
              contentPadding: EdgeInsets.zero,
              onChanged: (bool value) {
                appProvider.setSettings(
                    appProvider.settings..autoSaveEnabled = value);
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: appProvider.isSyncing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.fhTextPrimary,
                      ),
                    )
                  : Icon(MdiIcons.cloudUploadOutline, size: 18),
              label: const Text('FORCE CLOUD SYNC'),
              onPressed: appProvider.isSyncing
                  ? null
                  : () => appProvider.manuallySaveToCloud(),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: AppTheme.fhAccentTealFixed,
                foregroundColor: AppTheme.fhBgDark,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Icon(MdiIcons.cloudDownloadOutline, size: 18),
              label: const Text('RESTORE FROM CLOUD (OVERWRITE)'),
              onPressed: appProvider.isSyncing || appProvider.isManuallyLoading
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirm Restore'),
                          content: const Text(
                              'This will overwrite local data with cloud data. Continue?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('CANCEL'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('RESTORE'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) appProvider.manuallyLoadFromCloud();
                    },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: AppTheme.fhBgDark,
                foregroundColor: AppTheme.fhTextPrimary,
                side: BorderSide(color: AppTheme.fhAccentTealFixed),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: Icon(MdiIcons.backupRestore, size: 18),
              label: const Text('DATA RECOVERY & BACKUPS'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DataRecoveryScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                foregroundColor: AppTheme.fhTextPrimary,
                side: BorderSide(
                  color: AppTheme.fhTextSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                lastSavedString,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.fhTextSecondary.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
