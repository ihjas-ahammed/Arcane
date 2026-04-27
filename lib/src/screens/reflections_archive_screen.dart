import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/widgets/ui/reflection_log_card.dart';
import 'package:arcane/src/widgets/screens/reflection_editor_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ReflectionsArchiveScreen extends StatefulWidget {
  const ReflectionsArchiveScreen({super.key});

  @override
  State<ReflectionsArchiveScreen> createState() => _ReflectionsArchiveScreenState();
}

class _ReflectionsArchiveScreenState extends State<ReflectionsArchiveScreen> {
  DateTime? _filterDate;
  bool _isSelectionMode = false;
  final Set<String> _selectedLogIds = {};

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: JweTheme.accentCyan,
            onPrimary: Colors.black,
            surface: JweTheme.panel,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
    }
  }

  void _openEditor(BuildContext context, ReflectionLog? log) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReflectionEditorScreen(
          initialLog: log,
          dateStr: DateFormat('yyyy-MM-dd').format(log?.timestamp ?? DateTime.now()),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, ReflectionLog log) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedLogIds.contains(log.id)) {
          _selectedLogIds.remove(log.id);
          if (_selectedLogIds.isEmpty) {
            _isSelectionMode = false;
          }
        } else {
          _selectedLogIds.add(log.id);
        }
      });
    } else {
      _openEditor(context, log);
    }
  }

  void _handleLongPress(ReflectionLog log) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedLogIds.add(log.id);
      });
    }
  }

  void _copySelectedLogs(List<ReflectionLog> allLogs) {
    final selectedLogs = allLogs.where((l) => _selectedLogIds.contains(l.id)).toList();
    selectedLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final buffer = StringBuffer();
    for (var log in selectedLogs) {
      buffer.writeln("[${DateFormat('MMM dd, yyyy - HH:mm').format(log.timestamp)}]");
      buffer.writeln("What (Trigger): ${log.trigger}");
      buffer.writeln("How (Emotion): ${log.emotion}");
      buffer.writeln("Why (Reason): ${log.reason}");
      if (log.action.isNotEmpty) {
        buffer.writeln("Action: ${log.action}");
      }
      buffer.writeln("---");
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${selectedLogs.length} logs copied to clipboard.", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: JweTheme.accentCyan,
      ),
    );

    setState(() {
      _isSelectionMode = false;
      _selectedLogIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    
    List<ReflectionLog> logs = provider.reflectionLogs;
    if (_filterDate != null) {
      logs = logs.where((l) => 
        l.timestamp.year == _filterDate!.year && 
        l.timestamp.month == _filterDate!.month && 
        l.timestamp.day == _filterDate!.day
      ).toList();
    }
    
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        title: _isSelectionMode 
          ? Text("${_selectedLogIds.length} SELECTED", style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0))
          : Text("ARCHIVES", style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        centerTitle: true,
        backgroundColor: JweTheme.panel,
        iconTheme: const IconThemeData(color: JweTheme.accentCyan),
        leading: _isSelectionMode 
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedLogIds.clear();
              }),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
        actions: _isSelectionMode 
          ?[
              IconButton(
                icon: const Icon(Icons.copy, color: JweTheme.accentCyan),
                tooltip: "Copy Selected",
                onPressed: () => _copySelectedLogs(logs),
              ),
              IconButton(
                icon: const Icon(Icons.select_all, color: JweTheme.textMuted),
                tooltip: "Select All",
                onPressed: () {
                  setState(() {
                    _selectedLogIds.addAll(logs.map((l) => l.id));
                  });
                },
              )
            ]
          :[
              IconButton(
                icon: Icon(MdiIcons.download, color: JweTheme.textMuted),
                tooltip: "Import Data",
                onPressed: () async {
                  try {
                    await provider.importReflections();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Import successful.", style: TextStyle(color: Colors.black)), backgroundColor: JweTheme.accentCyan));
                  } catch(e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import failed: $e", style: const TextStyle(color: Colors.white)), backgroundColor: JweTheme.accentRed));
                  }
                },
              ),
              IconButton(
                icon: Icon(MdiIcons.upload, color: JweTheme.textMuted),
                tooltip: "Export Data",
                onPressed: () async {
                   try {
                    await provider.exportReflections();
                  } catch(e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: $e", style: const TextStyle(color: Colors.white)), backgroundColor: JweTheme.accentRed));
                  }
                },
              ),
            ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children:[
              // Filter Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: JweTheme.panel,
                  border: Border(bottom: BorderSide(color: JweTheme.border))
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children:[
                        Icon(MdiIcons.filterVariant, color: JweTheme.textMuted, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _filterDate != null ? DateFormat('MMM dd, yyyy').format(_filterDate!) : "ALL RECORDS",
                          style: const TextStyle(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono', fontSize: 12),
                        ),
                      ],
                    ),
                    Row(
                      children:[
                        if (_filterDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: JweTheme.accentRed),
                            onPressed: () => setState(() => _filterDate = null),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today, size: 18, color: JweTheme.accentCyan),
                          onPressed: _pickDate,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              
              Expanded(
                child: logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children:[
                            Icon(MdiIcons.folderOpenOutline, size: 48, color: JweTheme.textMuted.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            const Text("NO RECORDS FOUND.", style: TextStyle(color: JweTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ],
                        )
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final isSelected = _selectedLogIds.contains(log.id);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: GestureDetector(
                              onTap: () => _handleTap(context, log),
                              onLongPress: () => _handleLongPress(log),
                              child: ReflectionLogCard(
                                log: log,
                                isSelected: isSelected,
                              ),
                            ),
                          );
                        },
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}