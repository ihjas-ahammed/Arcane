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
class LocalDataErrorScreen extends StatefulWidget {
  const LocalDataErrorScreen({super.key, required this.error});

  final LocalStateException error;

  @override
  State<LocalDataErrorScreen> createState() => _LocalDataErrorScreenState();
}

class _LocalDataErrorScreenState extends State<LocalDataErrorScreen> {
  LocalStateException get error => widget.error;
  bool _busy = false;

  /// What the last recovery action threw. A snackbar vanished before it could be read, which made
  /// a failing restore look like "the screen never goes away".
  String? _actionError;

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _actionError = null; });
    try {
      await action();
    } catch (e, stack) {
      if (mounted) setState(() => _actionError = '$label failed:\n$e\n$stack');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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

  Future<void> _startFresh(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Start fresh?'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Existing cloud backups will remain recoverable. Type DELETE to replace your active data.'),
        TextField(controller: controller, decoration: const InputDecoration(labelText: 'Type DELETE')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, controller.text == 'DELETE'), child: const Text('Start fresh'))],
    ));
    // Not disposed here: the dialog's TextField is still in its close animation and would use a disposed controller.
    final text = controller.text;
    if (confirmed != true) return;
    await _run('Start fresh', () => provider.startFreshAfterCloudConfirmation(text));
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
                provider.cloudAttachRequired ? "CLOUD DATA FOUND" : "DATA RECOVERY REQUIRED",
                style: TextStyle(color: JweTheme.accentRed, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                "Your saved records are preserved. Choose a recovery action before continuing.",
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
                      [
                        if (_actionError != null) _actionError!,
                        error.details.isEmpty ? error.message : error.details,
                      ].join('\n\n'),
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
                  if (provider.cloudAttachRequired) ...[
                    ElevatedButton(
                      onPressed: _busy ? null : () => _run('Restore', provider.restoreCloudAttachment),
                      child: Text(_busy ? 'WORKING…' : 'RESTORE / MERGE CLOUD DATA (RECOMMENDED)'),
                    ),
                    OutlinedButton(onPressed: _busy ? null : () => _startFresh(context), child: const Text('START FRESH')),
                  ],
                  ElevatedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text("COPY ERROR"),
                    onPressed: () => _copy(context),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _run('Retry', provider.retryLocalLoad),
                    child: const Text("RETRY"),
                  ),
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
