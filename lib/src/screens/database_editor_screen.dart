import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/json_editor_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DatabaseEditorScreen extends StatefulWidget {
  const DatabaseEditorScreen({super.key});

  @override
  State<DatabaseEditorScreen> createState() => _DatabaseEditorScreenState();
}

class _DatabaseEditorScreenState extends State<DatabaseEditorScreen> {
  Map<String, dynamic> _localData = {};
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      _localData = Map.from(provider.getAppStateAsMap());
      _isInit = false;
    }
  }

  void _saveChanges() async {
    final provider = Provider.of<AppProvider>(context, listen: false);

    // Safety check: Ensure essential keys exist
    if (!_localData.containsKey('mainTasks')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Error: 'mainTasks' key is missing! Cannot save invalid state.")),
      );
      return;
    }

    try {
      provider.loadAppStateFromMap(_localData);
      await provider.manuallySaveToCloud();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Database updated & saved successfully!",
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error saving data: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportJson() async {
    try {
      final jsonStr = jsonEncode(_localData);

      if (kIsWeb) {
        // Web: Trigger download via anchor tag
        final bytes = utf8.encode(jsonStr);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download =
              'arcane_backup_${DateTime.now().millisecondsSinceEpoch}.json';
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Download started..."),
                backgroundColor: Colors.green),
          );
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: Share file (works best across scoped storage)
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/arcane_backup.json');
        await file.writeAsString(jsonStr);

        await Share.shareXFiles([XFile(file.path)],
            text: 'Arcane Database Backup');
      } else {
        // Desktop: File Picker Save (if supported) or Output File Path Dialog (fallback)
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Backup',
          fileName: 'arcane_backup.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(jsonStr);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text("Exported to $outputFile"),
                  backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Export failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: kIsWeb, // Web needs bytes directly
      );

      if (result != null) {
        String content;
        if (kIsWeb) {
          final bytes = result.files.single.bytes;
          if (bytes == null) throw Exception("No data read from file");
          content = utf8.decode(bytes);
        } else {
          final path = result.files.single.path;
          if (path == null) throw Exception("No path returned");
          final file = File(path);
          content = await file.readAsString();
        }

        final data = jsonDecode(content);
        if (data is Map<String, dynamic>) {
          setState(() {
            _localData = data;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("JSON Loaded. Click 'Save Changes' to apply."),
                  backgroundColor: Colors.orange),
            );
          }
        } else {
          throw Exception("Invalid JSON format");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Import failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Map<String, dynamic> _ensureStringMap(Map map) {
    final Map<String, dynamic> newMap = {};
    map.forEach((key, value) {
      if (value is Map) {
        newMap[key.toString()] = _ensureStringMap(value);
      } else if (value is List) {
        newMap[key.toString()] = value.map((e) {
          if (e is Map) {
            return _ensureStringMap(e);
          } else {
            return e;
          }
        }).toList();
      } else {
        newMap[key.toString()] = value;
      }
    });
    return newMap;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("Database Editor",
            style: TextStyle(
                fontFamily: 'Tungsten', fontSize: 24, letterSpacing: 1.5)),
        backgroundColor: AppTheme.fhBgDeepDark,
        actions: [
          IconButton(
            icon: Icon(MdiIcons.upload, color: AppTheme.fhTextSecondary),
            tooltip: "Export JSON",
            onPressed: _exportJson,
          ),
          IconButton(
            icon: Icon(MdiIcons.download, color: AppTheme.fhTextSecondary),
            tooltip: "Import JSON",
            onPressed: _importJson,
          ),
          IconButton(
            icon: const Icon(Icons.save, color: AppTheme.fhAccentTeal),
            tooltip: "Save Changes",
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: _localData.isEmpty
          ? const Center(
              child: Text("No Data", style: TextStyle(color: Colors.white)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: JsonEditorWidget(
                label: "App State",
                data: _localData,
                onChanged: (newValue) {
                  if (newValue is Map) {
                    setState(() {
                      _localData = _ensureStringMap(newValue);
                    });
                  }
                },
              ),
            ),
    );
  }
}
