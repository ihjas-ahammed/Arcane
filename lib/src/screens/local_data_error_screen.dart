import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/settings/backup_explorer_screen.dart';
import 'package:missions/src/services/data_export_service.dart';
import 'package:missions/src/services/local_storage_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Shown instead of the app when the saved state on this device cannot be read. Nothing is
/// loaded from the cloud or from older copies, and nothing is saved, until the user fixes it.
class LocalDataErrorScreen extends StatelessWidget {
  const LocalDataErrorScreen({super.key, required this.error});

  final LocalStateException error;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: error.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error copied")));
    }
  }

  Future<void> _loadJson(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final data = await DataExportService().importJson();
    if (data == null) return;
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Load JSON into database?"),
        content: const Text(
          "This replaces the data stored on this device with the file's contents. "
          "The current stored data is copied to backups/ first.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Load")),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await provider.importLocalJson(data);
      messenger.showSnackBar(const SnackBar(content: Text("JSON loaded into the database")));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Load failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return Scaffold(
      backgroundColor: JweTheme.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "LOCAL DATA COULD NOT BE LOADED",
                style: TextStyle(color: JweTheme.accentRed, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                "Nothing was changed or uploaded. The app will not load older copies or the cloud in its place.",
                style: TextStyle(color: JweTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Text(error.message, style: TextStyle(color: JweTheme.textWhite, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: JweTheme.panel,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: JweTheme.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      error.details.isEmpty ? error.message : error.details,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text("COPY ERROR"),
                    onPressed: () => _copy(context),
                  ),
                  OutlinedButton(onPressed: provider.retryLocalLoad, child: const Text("RETRY")),
                  OutlinedButton(onPressed: () => _loadJson(context), child: const Text("LOAD JSON INTO DATABASE")),
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BackupExplorerScreen()),
                    ),
                    child: const Text("EXPLORE BACKUPS (READ-ONLY)"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
