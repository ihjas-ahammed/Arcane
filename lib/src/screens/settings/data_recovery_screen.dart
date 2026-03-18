import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:intl/intl.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/ui/jwe_panel.dart';
import 'package:arcane/src/services/data_export_service.dart';
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
      if (Platform.isAndroid || Platform.isWindows) {
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
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      if (!await backupDir.exists()) await backupDir.create(recursive: true);
      
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${backupDir.path}/manual_backup_$timestamp.json');
      
      final provider = context.read<AppProvider>();
      final data = provider.getAppStateAsMap();
      
      await file.writeAsString(jsonEncode(data));
      
      _loadBackups();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Local backup created successfully.")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error creating backup: $e")));
    }
  }

  Future<void> _restoreBackup(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: const Text("Restore Backup?", style: TextStyle(color: JweTheme.textWhite)),
        content: const Text("This will overwrite your current data with the data from this backup. Are you sure?", style: TextStyle(color: JweTheme.textMuted)),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: JweTheme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Restore", style: TextStyle(color: JweTheme.accentCyan))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await context.read<AppProvider>().restoreFromLocalSnapshot(file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Backup restored successfully.")));
          Navigator.pop(context);
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
        title: const Text("Delete Backup?", style: TextStyle(color: JweTheme.textWhite)),
        content: const Text("This action cannot be undone.", style: TextStyle(color: JweTheme.textMuted)),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: JweTheme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: JweTheme.accentRed))),
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

  Future<void> _importData() async {
    try {
      final importedData = await _exportService.importJson();
      if (importedData != null && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: JweTheme.panel,
            title: const Text("Import Data?", style: TextStyle(color: JweTheme.textWhite)),
            content: const Text("This will overwrite your current data with the imported file. Are you sure?", style: TextStyle(color: JweTheme.textMuted)),
            actions:[
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: JweTheme.textMuted))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Import", style: TextStyle(color: JweTheme.accentCyan))),
            ],
          ),
        );

        if (confirm == true && mounted) {
          context.read<AppProvider>().loadAppStateFromMap(importedData);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data imported successfully.")));
          Navigator.pop(context);
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
        iconTheme: const IconThemeData(color: JweTheme.accentCyan),
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
                    child: Row(
                      children:[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _exportData,
                            icon: Icon(MdiIcons.fileExportOutline, size: 18),
                            label: Text("EXPORT JSON", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: JweTheme.accentCyan,
                              side: const BorderSide(color: JweTheme.accentCyan),
                              shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _importData,
                            icon: Icon(MdiIcons.fileImportOutline, size: 18),
                            label: Text("IMPORT JSON", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: JweTheme.accentCyan,
                              side: const BorderSide(color: JweTheme.accentCyan),
                              shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                            ),
                          ),
                        ),
                      ]
                    )
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
                          label: Text("CREATE LOCAL BACKUP", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.black)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: JweTheme.textWhite,
                            foregroundColor: Colors.black,
                            shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator(color: JweTheme.textWhite))
                        else if (_backupFiles.isEmpty)
                          const Text("No local backups found.", style: TextStyle(color: JweTheme.textMuted))
                        else
                          ..._backupFiles.map((file) {
                            final date = file.lastModifiedSync();
                            final size = file.lengthSync();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: JweTheme.border.withOpacity(0.3),
                                border: const Border(left: BorderSide(color: JweTheme.textMuted, width: 2))
                              ),
                              child: Row(
                                children:[
                                  Icon(MdiIcons.fileClockOutline, color: JweTheme.textMuted, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children:[
                                        Text(DateFormat('yyyy-MM-dd HH:mm').format(date), style: const TextStyle(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text("${(size / 1024).toStringAsFixed(1)} KB", style: const TextStyle(color: JweTheme.textMuted, fontSize: 12)),
                                      ]
                                    )
                                  ),
                                  IconButton(icon: const Icon(Icons.restore, color: JweTheme.textWhite), onPressed: () => _restoreBackup(file)),
                                  IconButton(icon: const Icon(Icons.delete, color: JweTheme.accentRed), onPressed: () => _deleteBackup(file)),
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