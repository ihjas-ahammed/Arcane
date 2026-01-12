import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:intl/intl.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/services/data_export_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("Data Recovery"),
        backgroundColor: AppTheme.fhBgDeepDark,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
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
          const Divider(color: AppTheme.fhBorderColor),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _backupFiles.isEmpty
                    ? const Center(child: Text("No local backups found."))
                    : ListView.builder(
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
          ),
        ],
      ),
    );
  }
}
