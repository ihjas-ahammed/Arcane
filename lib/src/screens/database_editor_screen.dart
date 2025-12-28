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

  // ... (Keep existing helper methods: _saveChanges, _exportJson, _importJson, _ensureStringMap) ...
  // Re-implementing briefly for context completeness
  
  void _saveChanges() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (!_localData.containsKey('mainTasks')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Invalid State")));
      return;
    }
    try {
      provider.loadAppStateFromMap(_localData);
      await provider.manuallySaveToCloud();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Database synced.")));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _exportJson() async {
     // ... (standard export logic)
     final jsonStr = jsonEncode(_localData);
     if (kIsWeb) {
        final bytes = utf8.encode(jsonStr);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = 'arcane_backup.json';
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
     } else {
        // Mobile fallback
        // ...
     }
  }

  Future<void> _importJson() async {
    // ... (standard import logic)
  }

  Map<String, dynamic> _ensureStringMap(Map map) {
    final Map<String, dynamic> newMap = {};
    map.forEach((key, value) {
      if (value is Map) {
        newMap[key.toString()] = _ensureStringMap(value);
      } else if (value is List) {
        newMap[key.toString()] = value.map((e) => e is Map ? _ensureStringMap(e) : e).toList();
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
      body: SafeArea(
        child: Column(
          children: [
            // Valorant Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.fhTextPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "SYSTEM DATABASE", 
                      style: const TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: AppTheme.fhTextPrimary
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(MdiIcons.upload, color: AppTheme.fhAccentTeal),
                    tooltip: "EXPORT",
                    onPressed: _exportJson,
                  ),
                  IconButton(
                    icon: Icon(MdiIcons.download, color: AppTheme.fhAccentTeal),
                    tooltip: "IMPORT",
                    onPressed: _importJson,
                  ),
                  IconButton(
                    icon: const Icon(Icons.save, color: AppTheme.fhAccentRed),
                    tooltip: "COMMIT",
                    onPressed: _saveChanges,
                  ),
                ],
              ),
            ),

            // Editor Area (Terminal Style)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: AppTheme.fhBorderColor),
                ),
                child: _localData.isEmpty
                  ? const Center(child: Text("NO DATA", style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: 'RobotoMono')))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: JsonEditorWidget(
                        label: "APP_STATE_ROOT",
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}