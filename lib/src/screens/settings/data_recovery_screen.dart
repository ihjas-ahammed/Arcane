import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:intl/intl.dart';

class DataRecoveryScreen extends StatefulWidget {
  const DataRecoveryScreen({super.key});

  @override
  State<DataRecoveryScreen> createState() => _DataRecoveryScreenState();
}

class _DataRecoveryScreenState extends State<DataRecoveryScreen> {
  List<File> _backupFiles = [];
  bool _isLoading = true;

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
          // Sort by modification time desc
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
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Recovery"),
      ),
      body: _isLoading
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
                      leading: const Icon(Icons.restore_page),
                      title: Text(
                          "Backup ${DateFormat('yyyy-MM-dd HH:mm').format(date)}"),
                      subtitle: Text("${(size / 1024).toStringAsFixed(1)} KB"),
                      trailing: IconButton(
                        icon: const Icon(Icons.restore),
                        onPressed: () => _restoreBackup(file),
                      ),
                    );
                  },
                ),
    );
  }
}
