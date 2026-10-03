import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/jwe_panel.dart';
import 'package:missions/src/services/data_export_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class DataRecoveryScreen extends StatefulWidget {
  const DataRecoveryScreen({super.key});

  @override
  State<DataRecoveryScreen> createState() => _DataRecoveryScreenState();
}

class _DataRecoveryScreenState extends State<DataRecoveryScreen> {
  List<File> _backupFiles =[];
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
      if (!kIsWeb) {
        final docsDir = await getApplicationDocumentsDirectory();
        final backupDir = Directory('${docsDir.path}/backups');
        if (await backupDir.exists()) {
          final files = backupDir.listSync().whereType<File>().toList();
          files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
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

  Future<void> _createLocalBackup() async {
    final provider = context.read<AppProvider>();
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      if (!await backupDir.exists()) await backupDir.create(recursive: true);

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${backupDir.path}/manual_backup_$timestamp.json');

      final data = provider.getAppStateAsMap();
      
      await file.writeAsString(jsonEncode(data));
      
      _loadBackups();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Local backup created successfully.")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error creating backup: $e")));
    }
  }

  Future<void> _restoreBackup(File file) async {
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text("RESTORE BACKUP", style: TextStyle(color: JweTheme.textWhite, fontWeight: FontWeight.bold)),
        content: Text(
          "How would you like to restore this backup?\n\n• MERGE: Combines all reflection logs, task history, and launcher settings with your current data (safe, zero data loss).\n• REPLACE: Completely replaces current data with the backup snapshot.",
          style: TextStyle(color: JweTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text("Cancel", style: TextStyle(color: JweTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            child: Text("Replace All", style: TextStyle(color: JweTheme.accentRed)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentCyan,
              foregroundColor: JweTheme.onAccent,
            ),
            onPressed: () => Navigator.pop(ctx, 'merge'),
            child: Text("MERGE (Recommended)", style: TextStyle(color: JweTheme.onAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (mode != null && mounted) {
      try {
        final report = await context.read<AppProvider>().restoreFromLocalSnapshot(file, merge: mode == 'merge');
        if (mounted) {
          if (mode == 'merge' && report != null) {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: JweTheme.panel,
                title: Row(
                  children: [
                    Icon(MdiIcons.checkDecagram, color: JweTheme.accentCyan, size: 22),
                    const SizedBox(width: 8),
                    Text("BACKUP MERGED", style: TextStyle(color: JweTheme.textWhite, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Text("• ${report.summary}", style: TextStyle(color: JweTheme.textWhite, height: 1.4, fontSize: 13)),
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentCyan, foregroundColor: JweTheme.onAccent),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text("DISMISS", style: TextStyle(color: JweTheme.onAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Backup restored successfully."),
            ));
          }
          if (mounted) Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error restoring backup: $e")));
        }
      }
    }
  }

  Future<void> _deleteBackup(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title:  Text("Delete Backup?", style: TextStyle(color: JweTheme.textWhite)),
        content:  Text("This action cannot be undone.", style: TextStyle(color: JweTheme.textMuted)),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child:  Text("Cancel", style: TextStyle(color: JweTheme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child:  Text("Delete", style: TextStyle(color: JweTheme.accentRed))),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Export initiated.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: $e")));
      }
    }
  }

  /// 1-Tap Merge Import: Non-destructively merges an older JSON export/backup
  /// with current data, restoring historical reflections and missing tasks without replacing recent logs.
  Future<void> _mergeImportData() async {
    try {
      final importedData = await _exportService.importJson();
      if (importedData != null && mounted) {
        final report = context.read<AppProvider>().mergeAppStateFromMap(importedData);
        await context.read<AppProvider>().forceLocalBackup();

        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: JweTheme.panel,
              title: Row(
                children: [
                  Icon(MdiIcons.checkDecagram, color: JweTheme.accentCyan, size: 22),
                  const SizedBox(width: 8),
                  Text("MERGE COMPLETE", style: TextStyle(color: JweTheme.textWhite, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "• ${report.summary}",
                      style: TextStyle(color: JweTheme.textWhite, height: 1.4, fontSize: 13),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: JweTheme.accentCyan,
                    foregroundColor: JweTheme.onAccent,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("DISMISS", style: TextStyle(color: JweTheme.onAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Merge import failed: $e")));
      }
    }
  }

  Future<void> _importData() async {
    try {
      final importedData = await _exportService.importJson();
      if (importedData != null && mounted) {
        final mode = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: JweTheme.panel,
            title: Text("IMPORT DATA", style: TextStyle(color: JweTheme.textWhite, fontWeight: FontWeight.bold)),
            content: Text(
              "How would you like to import this data file?\n\n• MERGE: Combines all older reflection logs, task history, and launcher settings non-destructively without overwriting recent entries.\n• REPLACE: Completely replaces current database with the imported file.",
              style: TextStyle(color: JweTheme.textMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text("Cancel", style: TextStyle(color: JweTheme.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'replace'),
                child: Text("Replace All", style: TextStyle(color: JweTheme.accentRed)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: JweTheme.accentCyan,
                  foregroundColor: JweTheme.onAccent,
                ),
                onPressed: () => Navigator.pop(ctx, 'merge'),
                child: Text("MERGE (Recommended)", style: TextStyle(color: JweTheme.onAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (mode != null && mounted) {
          if (mode == 'merge') {
            final report = context.read<AppProvider>().mergeAppStateFromMap(importedData);
            await context.read<AppProvider>().forceLocalBackup();
            if (mounted) {
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: JweTheme.panel,
                  title: Row(
                    children: [
                      Icon(MdiIcons.checkDecagram, color: JweTheme.accentCyan, size: 22),
                      const SizedBox(width: 8),
                      Text("MERGE COMPLETE", style: TextStyle(color: JweTheme.textWhite, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Text("• ${report.summary}", style: TextStyle(color: JweTheme.textWhite, height: 1.4, fontSize: 13)),
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JweTheme.accentCyan,
                        foregroundColor: JweTheme.onAccent,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("DISMISS", style: TextStyle(color: JweTheme.onAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }
          } else {
            context.read<AppProvider>().loadAppStateFromMap(importedData);
            await context.read<AppProvider>().forceLocalBackup();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Data imported successfully."),
              ));
            }
          }
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        title: Text("DATA ARCHIVE & RECOVERY", style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: JweTheme.bgBase,
        iconTheme:  IconThemeData(color: JweTheme.accentCyan),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:[
                  JwePanel(
                    title: "EXTERNAL EXPORT / IMPORT",
                    accentColor: JweTheme.accentCyan,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _mergeImportData,
                          icon: Icon(MdiIcons.sourceMerge, size: 20, color: JweTheme.onAccent),
                          label: Text("MERGE IMPORT (PRESERVE RECENT)", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: JweTheme.onAccent, letterSpacing: 1.2)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: JweTheme.accentCyan,
                            foregroundColor: JweTheme.onAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Non-destructively merges an older JSON export or backup into current data. Restores older reflection logs, missing days, and launcher settings without touching what you added in the last few days.",
                          style: TextStyle(color: JweTheme.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _exportData,
                                icon: Icon(MdiIcons.fileExportOutline, size: 18),
                                label: Text("EXPORT JSON", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: JweTheme.textWhite,
                                  side: BorderSide(color: JweTheme.border),
                                  shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _importData,
                                icon: Icon(MdiIcons.fileImportOutline, size: 18),
                                label: Text("RESTORE ALL", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: JweTheme.accentRed,
                                  side: BorderSide(color: JweTheme.accentRed.withValues(alpha: 0.5)),
                                  shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  JwePanel(
                    title: "LOCAL DEVICE CACHE",
                    accentColor: JweTheme.textWhite,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children:[
                        ElevatedButton.icon(
                          onPressed: _createLocalBackup,
                          icon: Icon(MdiIcons.harddiskPlus, size: 18),
                          label: Text("CREATE LOCAL BACKUP", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: JweTheme.onAccent)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: JweTheme.textWhite,
                            foregroundColor: JweTheme.onAccent,
                            shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                           Center(child: CircularProgressIndicator(color: JweTheme.textWhite))
                        else if (_backupFiles.isEmpty)
                           Text("No local backups found.", style: TextStyle(color: JweTheme.textMuted))
                        else
                          ..._backupFiles.map((file) {
                            final date = file.lastModifiedSync();
                            final size = file.lengthSync();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: JweTheme.border.withValues(alpha: 0.3),
                                border:  Border(left: BorderSide(color: JweTheme.textMuted, width: 2))
                              ),
                              child: Row(
                                children:[
                                  Icon(MdiIcons.fileClockOutline, color: JweTheme.textMuted, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children:[
                                        Text(DateFormat('yyyy-MM-dd HH:mm').format(date), style:  TextStyle(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text("${(size / 1024).toStringAsFixed(1)} KB", style:  TextStyle(color: JweTheme.textMuted, fontSize: 12)),
                                      ]
                                    )
                                  ),
                                  IconButton(icon:  Icon(Icons.restore, color: JweTheme.textWhite), onPressed: () => _restoreBackup(file)),
                                  IconButton(icon:  Icon(Icons.delete, color: JweTheme.accentRed), onPressed: () => _deleteBackup(file)),
                                ]
                              )
                            );
                          })
                      ]
                    )
                  )
                ]
              )
            )
          )
        )
      ));
  }
}