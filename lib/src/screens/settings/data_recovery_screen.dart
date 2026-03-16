import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:intl/intl.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/services/data_export_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class DataRecoveryScreen extends StatefulWidget {
  const DataRecoveryScreen({super.key});

  @override
  State<DataRecoveryScreen> createState() => _DataRecoveryScreenState();
}

class _DataRecoveryScreenState extends State<DataRecoveryScreen> {
  List<File> _backupFiles = [];
  bool _isLoading = true;
  final DataExportService _exportService = DataExportService();

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      if (Platform.isAndroid || Platform.isWindows) {
        final docsDir = await getApplicationDocumentsDirectory();
        final backupDir = Directory('${docsDir.path}/backups');
        if (await backupDir.exists()) {
          final files = backupDir.listSync().whereType<File>().toList();
          files.sort(
              (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          setState(() {
            _backupFiles = files;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading backups: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Restore Backup?"),
        content: const Text(
            "This will overwrite your current data with the data from this backup. Are you sure?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Restore")),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await context.read<AppProvider>().restoreFromLocalSnapshot(file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Backup restored successfully.")));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error restoring backup: $e")));
        }
      }
    }
  }

  Future<void> _deleteBackup(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Backup?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete",
                  style: TextStyle(color: AppTheme.fhAccentRed))),
        ],
      ),
    );

    if (confirm == true) {
      await file.delete();
      _loadBackups();
    }
  }

  Future<void> _exportData() async {
    try {
      final provider = context.read<AppProvider>();
      final data = provider.getAppStateAsMap();
      await _exportService.exportJson(data, 'arcane_export');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Export initiated.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Export failed: $e")));
      }
    }
  }

  Future<void> _importData() async {
    try {
      final importedData = await _exportService.importJson();
      if (importedData != null && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Import Data?"),
            content: const Text(
                "This will overwrite your current data with the imported file. Are you sure?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Import")),
            ],
          ),
        );

        if (confirm == true && mounted) {
          context.read<AppProvider>().loadAppStateFromMap(importedData);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Data imported successfully.")));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Import failed: $e")));
      }
    }
  }

  Future<void> _backupToFirestore() async {
    try {
      final provider = context.read<AppProvider>();
      await provider.forceLocalBackup(); // Auto make local backup first
      await provider.performFirestoreBackup(); // Then Firestore
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cloud Snapshot & Local Backup Secured."))
        );
        _loadBackups(); // Refresh local list
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Backup failed: $e")));
    }
  }

  Future<void> _restoreFromFirestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Restore Firestore Snapshot?"),
        content: const Text("This will overwrite your live Realtime DB state with the archived Firestore snapshot. Proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PersonInfoTheme.spideyRed),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Restore")
          ),
        ],
      )
    );
    if (confirm == true && mounted) {
       try {
         await context.read<AppProvider>().restoreFromFirestoreBackup();
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data restored from Firestore.")));
       } catch(e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Restore failed: $e")));
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("Data Recovery"),
        backgroundColor: AppTheme.fhBgDeepDark,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- CLOUD SNAPSHOT SECTION ---
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PersonInfoTheme.bgPanel,
                border: Border(left: const BorderSide(color: PersonInfoTheme.spideyRed, width: 4)),
                boxShadow: [BoxShadow(color: PersonInfoTheme.spideyCyan.withValues(alpha: 0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.cloudLockOutline, color: PersonInfoTheme.spideyRed, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        "FIRESTORE SNAPSHOT",
                        style: GoogleFonts.rajdhani(
                          color: PersonInfoTheme.spideyRed,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Primary sync runs on ultra-fast Realtime DB. Create a permanent snapshot in Firestore as a failsafe recovery point.",
                    style: TextStyle(color: PersonInfoTheme.textGrey, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ValorantButton(
                          label: "BACKUP",
                          icon: MdiIcons.cloudUploadOutline,
                          color: PersonInfoTheme.spideyCyan,
                          isPrimary: false,
                          onPressed: _backupToFirestore,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ValorantButton(
                          label: "RESTORE",
                          icon: MdiIcons.cloudDownloadOutline,
                          color: PersonInfoTheme.spideyRed,
                          isPrimary: true,
                          onPressed: _restoreFromFirestore,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
        
            // --- MANUAL EXPORT SECTION ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(MdiIcons.upload, size: 18),
                      label: const Text("EXPORT DATA"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.fhBgDark,
                        foregroundColor: AppTheme.fhTextPrimary,
                        side: BorderSide(
                            color: AppTheme.fhAccentTeal.withValues(alpha: 0.5)),
                      ),
                      onPressed: _exportData,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(MdiIcons.download, size: 18),
                      label: const Text("IMPORT DATA"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.fhBgDark,
                        foregroundColor: AppTheme.fhTextPrimary,
                        side: BorderSide(
                            color: AppTheme.fhAccentPurple.withValues(alpha: 0.5)),
                      ),
                      onPressed: _importData,
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(color: AppTheme.fhBorderColor, height: 32),
            
            // --- LOCAL BACKUPS SECTION ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "LOCAL CACHE ARCHIVES", 
                  style: TextStyle(color: AppTheme.fhTextSecondary, fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.bold, letterSpacing: 1.0)
                ),
              ),
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                : _backupFiles.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("No local backups found.")))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _backupFiles.length,
                        itemBuilder: (context, index) {
                          final file = _backupFiles[index];
                          final date = file.lastModifiedSync();
                          final size = file.lengthSync();
        
                          return ListTile(
                            leading: Icon(MdiIcons.fileClockOutline,
                                color: AppTheme.fhTextSecondary),
                            title: Text(
                              "Backup ${DateFormat('yyyy-MM-dd HH:mm').format(date)}",
                              style: const TextStyle(
                                  color: AppTheme.fhTextPrimary),
                            ),
                            subtitle: Text(
                                "${(size / 1024).toStringAsFixed(1)} KB",
                                style: const TextStyle(
                                    color: AppTheme.fhTextSecondary)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.restore),
                                  tooltip: "Restore",
                                  onPressed: () => _restoreBackup(file),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: AppTheme.fhAccentRed
                                          .withValues(alpha: 0.7)),
                                  tooltip: "Delete",
                                  onPressed: () => _deleteBackup(file),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}