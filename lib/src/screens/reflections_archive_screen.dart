import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/widgets/ui/reflection_log_card.dart';
import 'package:arcane/src/widgets/screens/reflection_editor_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';

class ReflectionsArchiveScreen extends StatefulWidget {
  const ReflectionsArchiveScreen({super.key});

  @override
  State<ReflectionsArchiveScreen> createState() => _ReflectionsArchiveScreenState();
}

class _ReflectionsArchiveScreenState extends State<ReflectionsArchiveScreen> {
  DateTime? _filterDate;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.fhAccentPurple,
            onPrimary: Colors.white,
            surface: AppTheme.fhBgDark,
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
    
    // Sort newest first
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("ARCHIVES", style: TextStyle(color: AppTheme.fhAccentPurple, letterSpacing: 2.0)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(MdiIcons.download, color: AppTheme.fhAccentTeal),
            tooltip: "Import Data",
            onPressed: () async {
              try {
                await provider.importReflections();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Import successful.")));
              } catch(e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import failed: $e")));
              }
            },
          ),
          IconButton(
            icon: Icon(MdiIcons.upload, color: AppTheme.fhAccentTeal),
            tooltip: "Export Data",
            onPressed: () async {
               try {
                await provider.exportReflections();
              } catch(e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: $e")));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.fhBgDark,
              border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.5)))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.filterVariant, color: AppTheme.fhTextSecondary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _filterDate != null ? DateFormat('MMM dd, yyyy').format(_filterDate!) : "ALL RECORDS",
                      style: const TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_filterDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _filterDate = null),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, size: 18),
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
                ? const Center(child: Text("NO RECORDS FOUND.", style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: AppTheme.fontDisplay, fontSize: 18)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          onTap: () => _openEditor(context, log),
                          child: Stack(
                            children: [
                              ReflectionLogCard(log: log),
                              Positioned(
                                right: 12,
                                top: 12,
                                child: Text(
                                  DateFormat('MMM dd\nHH:mm').format(log.timestamp),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontFamily: 'RobotoMono'),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}