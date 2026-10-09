import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:missions/src/services/data_export_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Read-only look inside a backup or JSON file. The file is parsed into memory here only:
/// nothing is loaded into the app, written to the database, or saved anywhere.
class BackupExplorerScreen extends StatefulWidget {
  const BackupExplorerScreen({super.key});

  @override
  State<BackupExplorerScreen> createState() => _BackupExplorerScreenState();
}

class _BackupExplorerScreenState extends State<BackupExplorerScreen> {
  static const _previewChars = 200000;

  Map<String, dynamic>? _data;
  String _sourceName = '';
  String? _selected;
  String? _selectedText;
  List<File> _files = [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _listFiles();
  }

  Future<void> _listFiles() async {
    if (kIsWeb) return;
    final docs = await getApplicationDocumentsDirectory();
    final found = <File>[];
    for (final dir in [Directory(docs.path), Directory('${docs.path}/backups')]) {
      if (!await dir.exists()) continue;
      await for (final entity in dir.list()) {
        if (entity is File && (entity.path.endsWith('.json') || entity.path.endsWith('.bak'))) {
          found.add(entity);
        }
      }
    }
    found.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    if (mounted) setState(() => _files = found);
  }

  Future<void> _openFile(File file) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final text = await file.readAsString();
      final decoded = await compute(jsonDecode, text);
      if (decoded is! Map<String, dynamic>) throw const FormatException("The root of this file is not a JSON object.");
      _show(decoded, file.uri.pathSegments.last);
    } catch (e) {
      setState(() => _error = "Could not read ${file.uri.pathSegments.last}: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await DataExportService().importJson();
      if (data != null) _show(data, 'picked file');
    } catch (e) {
      setState(() => _error = "Could not read the file: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(Map<String, dynamic> data, String name) {
    setState(() {
      _data = data;
      _sourceName = name;
      _selected = null;
      _selectedText = null;
    });
  }

  Future<void> _select(String key) async {
    final value = _data![key];
    final text = await compute(_pretty, value);
    if (mounted) setState(() {
      _selected = key;
      _selectedText = text;
    });
  }

  static String _pretty(dynamic value) => const JsonEncoder.withIndent('  ').convert(value);

  static String _summary(dynamic value) {
    if (value is List) return '${value.length} items';
    if (value is Map) return '${value.length} entries';
    return 'value';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JweTheme.bgCanvas,
      appBar: AppBar(title: const Text("BACKUP EXPLORER")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: JweTheme.panel,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: JweTheme.accentCyan),
                ),
                child: Text(
                  "READ-ONLY PREVIEW. Nothing here is loaded into the app or written to the database.",
                  style: TextStyle(color: JweTheme.textWhite, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text("PICK JSON FILE"),
                    onPressed: _busy ? null : _pickFile,
                  ),
                  const SizedBox(width: 12),
                  if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(_error!, style: TextStyle(color: JweTheme.accentRed, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              Expanded(child: _data == null ? _buildFileList() : _buildData()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileList() {
    if (_files.isEmpty) {
      return Center(child: Text("No backup files found on this device.", style: TextStyle(color: JweTheme.textMuted)));
    }
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (_, i) {
        final file = _files[i];
        final name = file.uri.pathSegments.last;
        return ListTile(
          dense: true,
          title: Text(name, style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
          subtitle: Text(
            "${file.lastModifiedSync()}  •  ${(file.lengthSync() / 1024).toStringAsFixed(0)} KB",
            style: TextStyle(color: JweTheme.textMuted, fontSize: 11),
          ),
          onTap: _busy ? null : () => _openFile(file),
        );
      },
    );
  }

  Widget _buildData() {
    final data = _data!;
    if (_selected != null) {
      final text = _selectedText ?? '';
      final truncated = text.length > _previewChars;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text("BACK"),
                onPressed: () => setState(() {
                  _selected = null;
                  _selectedText = null;
                }),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text("COPY FULL JSON"),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied")));
                  }
                },
              ),
            ],
          ),
          if (truncated)
            Text("Showing the first $_previewChars characters. Copy gives the full value.",
                style: TextStyle(color: JweTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: JweTheme.panel,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: JweTheme.border),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  truncated ? text.substring(0, _previewChars) : text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final keys = data.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("$_sourceName • ${keys.length} collections", style: TextStyle(color: JweTheme.textWhite, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            itemCount: keys.length,
            itemBuilder: (_, i) {
              final key = keys[i];
              final value = data[key];
              return ListTile(
                dense: true,
                title: Text(key, style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                subtitle: Text(_summary(value), style: TextStyle(color: JweTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _select(key),
              );
            },
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _data = null;
            _sourceName = '';
          }),
          child: const Text("CHOOSE ANOTHER FILE"),
        ),
      ],
    );
  }
}
