import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/settings/data_recovery_screen.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/dialogs/data_restore_progress_dialog.dart';

class CloudSyncSettingsSection extends StatelessWidget {
  final AppProvider appProvider;
  final ThemeData theme;

  const CloudSyncSettingsSection({
    super.key,
    required this.appProvider,
    required this.theme,
  });

  Future<void> _reviewConflict(BuildContext context) async {
    if (appProvider.mergeConflicts.isEmpty) return;
    final conflict = appProvider.mergeConflicts.first;
    final choice = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Review ${conflict['collection']} (${appProvider.mergeConflicts.length} remaining)'),
      content: SingleChildScrollView(child: SelectableText('This device:\n${const JsonEncoder.withIndent('  ').convert(conflict['local'])}\n\nIncoming backup:\n${const JsonEncoder.withIndent('  ').convert(conflict['incoming'])}')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep this device')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Use incoming'))],
    ));
    if (choice == null) return;
    try { await appProvider.resolveMergeConflict(conflict, useIncoming: choice); }
    catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Conflict review failed: $e'))); }
  }

  Future<void> _restoreVersion(BuildContext context) async {
    try {
      final versions = await appProvider.storageService.getCloudVersions(appProvider.currentUser!.uid);
      if (!context.mounted) return;
      final selected = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => SimpleDialog(
        title: const Text('Restore from date'),
        children: versions.isEmpty ? [const Padding(padding: EdgeInsets.all(16), child: Text('No versioned backups yet.'))] : versions.map((v) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, v),
          child: Text('${DateTime.fromMillisecondsSinceEpoch((v['lastModified'] as num?)?.toInt() ?? 0).toLocal()} — ${v['lastPushedBy'] ?? 'Previous backup'}'),
        )).toList(),
      ));
      if (selected == null || !context.mounted) return;
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Replace with this backup?'),
        content: const Text('A recovery snapshot of your current data will be saved first.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore'))],
      ));
      if (confirmed != true) return;
      final snapshot = await appProvider.storageService.getUserSnapshot(appProvider.currentUser!.uid);
      final state = await appProvider.storageService.getCloudVersion(appProvider.currentUser!.uid, selected['version'] as String);
      await appProvider.replaceStateSafely(state);
      if (snapshot != null) await appProvider.persistCloudBaseline((snapshot['lastModified'] as num).toInt(), version: snapshot['version'] as String?);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dated backup restored on this device.')));
    } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e'))); }
  }

  Future<void> _confirmDeletionSync(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Confirm cloud deletions'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('This upload removes a substantial part of your saved data. Earlier versions remain recoverable. Type DELETE only if you made these deletions.'),
        TextField(controller: controller, decoration: const InputDecoration(labelText: 'Type DELETE')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, controller.text == 'DELETE'), child: const Text('Confirm deletions'))],
    ));
    controller.dispose();
    if (confirmed != true) return;
    appProvider.allowConfirmedShrink = true;
    try { await appProvider.manuallySaveToCloud(); } finally { appProvider.allowConfirmedShrink = false; }
  }

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
              title: const Text('Automatic Cloud Backup'),
              subtitle: const Text('Local changes are saved within a moment. Changed data is backed up every six hours while the app is active and after daily briefings.'),
              value: appProvider.settings.autoSaveEnabled,
              activeTrackColor: AppTheme.fhAccentTeal,
              contentPadding: EdgeInsets.zero,
              onChanged: (bool value) {
                appProvider.setSettings(
                    appProvider.settings..autoSaveEnabled = value);
              },
            ),
            if (appProvider.mergeConflicts.isNotEmpty) TextButton(onPressed: () => _reviewConflict(context), child: Text('REVIEW ${appProvider.mergeConflicts.length} CONFLICTING EDITS')),
            if (appProvider.offsiteBackupError != null) Text(appProvider.offsiteBackupError!, style: const TextStyle(color: Colors.orange)),
            if (!appProvider.settings.autoSaveEnabled) const Text('Auto-backup is OFF. Manual sync is still available.', style: TextStyle(color: Colors.orange)),
            if (appProvider.cloudSyncError != null) Text(appProvider.cloudSyncError!, style: const TextStyle(color: Colors.orange)),
            if (appProvider.cloudSyncError?.contains('30%') == true) TextButton(onPressed: () => _confirmDeletionSync(context), child: const Text('REVIEW AND CONFIRM DELETIONS')),
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
              label: const Text('RESTORE / MERGE FROM CLOUD'),
              onPressed: appProvider.isSyncing || appProvider.isManuallyLoading
                  ? null
                  : () async {
                      final mode = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: JweTheme.panel,
                          title: Text(
                            'RESTORE FROM CLOUD',
                            style: TextStyle(
                              color: JweTheme.textWhite,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Text(
                            'Choose how you want to restore data from cloud:\n\n'
                            '• MERGE (Recommended): Non-destructively merges tasks, subtasks, completed items, daily history, and reflections with your local data.\n'
                            '• REPLACE ALL: Completely replaces local database with cloud snapshot.',
                            style: TextStyle(color: JweTheme.textMuted, fontSize: 13, height: 1.4),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, null),
                              child: Text('Cancel', style: TextStyle(color: JweTheme.textMuted)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, 'replace'),
                              child: Text('Replace All', style: TextStyle(color: JweTheme.accentRed)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: JweTheme.accentCyan,
                                foregroundColor: JweTheme.onAccent,
                              ),
                              onPressed: () => Navigator.pop(ctx, 'merge'),
                              child: Text(
                                'MERGE (Recommended)',
                                style: TextStyle(color: JweTheme.onAccent, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (mode != null && context.mounted) {
                        try {
                          final report = await DataRestoreProgressDialog.run<MergeReport?>(
                            context: context,
                            title: mode == 'merge' ? "MERGING CLOUD DATA" : "RESTORING FROM CLOUD",
                            action: (reportProgress) => appProvider.restoreFromCloudWithProgress(
                              merge: mode == 'merge',
                              onProgress: reportProgress,
                            ),
                          );

                          if (context.mounted) {
                            if (mode == 'merge' && report != null) {
                              await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: JweTheme.panel,
                                  title: Row(
                                    children: [
                                      Icon(MdiIcons.checkDecagram, color: JweTheme.accentCyan, size: 22),
                                      const SizedBox(width: 8),
                                      Text(
                                        "CLOUD MERGE COMPLETE",
                                        style: TextStyle(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  content: SingleChildScrollView(
                                    child: Text(
                                      "• ${report.summary}",
                                      style: TextStyle(color: JweTheme.textWhite, height: 1.4, fontSize: 13),
                                    ),
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: JweTheme.accentCyan,
                                        foregroundColor: JweTheme.onAccent,
                                      ),
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(
                                        "DISMISS",
                                        style: TextStyle(color: JweTheme.onAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cloud data restored successfully.')),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error restoring cloud data: $e')),
                            );
                          }
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: AppTheme.fhBgDark,
                foregroundColor: AppTheme.fhTextPrimary,
                side: BorderSide(color: AppTheme.fhAccentTealFixed),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(icon: const Icon(Icons.history), label: const Text('RESTORE FROM DATE'), onPressed: () => _restoreVersion(context)),
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
                  color: appProvider.lastSuccessfulSaveTimestamp == null ? Colors.orange : DateTime.now().difference(appProvider.lastSuccessfulSaveTimestamp!).inHours >= 72 ? Colors.red : DateTime.now().difference(appProvider.lastSuccessfulSaveTimestamp!).inHours >= 24 ? Colors.orange : AppTheme.fhTextSecondary.withValues(alpha: 0.8),
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
