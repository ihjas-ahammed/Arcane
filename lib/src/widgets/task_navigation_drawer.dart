import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/ui/jwe_drawer_protocol_item.dart';
import 'package:arcane/src/widgets/ui/jwe_compact_task_card.dart';
import 'package:arcane/src/widgets/dialogs/color_selector_dialog.dart';
import 'package:arcane/src/widgets/dialogs/jwe_task_options_dialog.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class TaskNavigationDrawer extends StatefulWidget {
  const TaskNavigationDrawer({super.key});

  @override
  State<TaskNavigationDrawer> createState() => _TaskNavigationDrawerState();
}

class _TaskNavigationDrawerState extends State<TaskNavigationDrawer> {
  final _newTaskNameController = TextEditingController();
  final _newTaskDescController = TextEditingController();

  String _dialogSelectedTheme = 'tech';
  String _dialogSelectedColorHex = AppTheme.fhAccentTealFixed.value.toRadixString(16).toUpperCase().substring(2);

  final List<Map<String, dynamic>> _availableThemes = [
    {'name': 'tech', 'icon': MdiIcons.memory, 'color': AppTheme.fhAccentTealFixed},
    {'name': 'knowledge', 'icon': MdiIcons.bookOpenPageVariantOutline, 'color': AppTheme.fhAccentPurple},
    {'name': 'learning', 'icon': MdiIcons.schoolOutline, 'color': AppTheme.fhAccentOrange},
    {'name': 'discipline', 'icon': MdiIcons.karate, 'color': AppTheme.fhAccentRed},
    {'name': 'order', 'icon': MdiIcons.playlistCheck, 'color': AppTheme.fhAccentGreen},
    {'name': 'health', 'icon': MdiIcons.heartPulse, 'color': const Color(0xFF58D68D)},
    {'name': 'finance', 'icon': MdiIcons.cashMultiple, 'color': const Color(0xFFF1C40F)},
    {'name': 'creative', 'icon': MdiIcons.paletteOutline, 'color': const Color(0xFFEC7063)},
    {'name': 'exploration', 'icon': MdiIcons.mapSearchOutline, 'color': const Color(0xFF5DADE2)},
    {'name': 'social', 'icon': MdiIcons.accountGroupOutline, 'color': const Color(0xFFE59866)},
    {'name': 'nature', 'icon': MdiIcons.treeOutline, 'color': const Color(0xFF2ECC71)},
    {'name': 'general', 'icon': MdiIcons.targetAccount, 'color': AppTheme.fhTextSecondary},
  ];

  Color _getColorForTheme(String themeName) {
    return _availableThemes.firstWhere((t) => t['name'] == themeName,
        orElse: () => {'color': AppTheme.fhAccentTealFixed})['color'] as Color;
  }

  IconData _getThemeIcon(String? themeName) {
    return _availableThemes.firstWhere((t) => t['name'] == themeName,
        orElse: () => _availableThemes.last)['icon'] as IconData;
  }

  @override
  void dispose() {
    _newTaskNameController.dispose();
    _newTaskDescController.dispose();
    super.dispose();
  }

  void _showAddTaskDialog(BuildContext context, AppProvider appProvider) {
    _newTaskNameController.clear();
    _newTaskDescController.clear();
    _dialogSelectedTheme = 'tech';
    _dialogSelectedColorHex = _getColorForTheme(_dialogSelectedTheme).value.toRadixString(16).toUpperCase().substring(2);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
          final currentColor = Color(int.parse("0xFF$_dialogSelectedColorHex"));

          return AlertDialog(
            backgroundColor: JweTheme.panel,
            shape: Border.all(color: JweTheme.accentCyan, width: 2),
            title: Text('NEW AGENT', style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: _newTaskNameController, 
                    style: const TextStyle(color: JweTheme.textWhite),
                    decoration: const InputDecoration(labelText: 'CODENAME', filled: true, fillColor: JweTheme.bgBase, border: OutlineInputBorder())
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newTaskDescController, 
                    maxLines: 2,
                    style: const TextStyle(color: JweTheme.textWhite),
                    decoration: const InputDecoration(labelText: 'BRIEFING', filled: true, fillColor: JweTheme.bgBase, border: OutlineInputBorder())
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'CLASS', filled: true, fillColor: JweTheme.bgBase, border: OutlineInputBorder()),
                    dropdownColor: JweTheme.panel,
                    value: _dialogSelectedTheme,
                    items: _availableThemes.map((themeMap) => DropdownMenuItem(
                      value: themeMap['name'] as String,
                      child: Text((themeMap['name'] as String).toUpperCase(), style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold))
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() {
                          _dialogSelectedTheme = val;
                          _dialogSelectedColorHex = _getColorForTheme(val).value.toRadixString(16).toUpperCase().substring(2);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text("CLASS COLOR", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ColorSelectorDialog(
                          selectedColor: currentColor,
                          onColorSelected: (color) {
                            setStateDialog(() {
                              _dialogSelectedColorHex = color.value.toRadixString(16).toUpperCase().substring(2);
                            });
                          },
                        ),
                      );
                    },
                    child: Container(
                      height: 40,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: currentColor,
                        border: Border.all(color: JweTheme.border),
                      ),
                      child: const Center(child: Text("TAP TO CHANGE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10))),
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(child: const Text('ABORT', style: TextStyle(color: JweTheme.textMuted)), onPressed: () => Navigator.pop(dialogContext)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentCyan, foregroundColor: Colors.black, shape: const BeveledRectangleBorder()),
                onPressed: () {
                  if (_newTaskNameController.text.isNotEmpty) {
                    appProvider.addMainTask(
                      name: _newTaskNameController.text,
                      description: _newTaskDescController.text,
                      theme: _dialogSelectedTheme,
                      colorHex: _dialogSelectedColorHex,
                    );
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('INITIALIZE', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    final activeTasks = appProvider.mainTasks.where((t) => t.isActive).toList();
    final inactiveTasks = appProvider.mainTasks.where((t) => !t.isActive).toList();
    
    return Drawer(
      width: 280,
      backgroundColor: JweTheme.bgBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: JweTheme.border, width: 2)),
              color: JweTheme.panel,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PROTOCOLS", 
                  style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2.0)
                ),
                const SizedBox(height: 4),
                const Text(
                  "SELECT MISSION PROFILE", 
                  style: TextStyle(color: JweTheme.textMuted, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (activeTasks.isNotEmpty) ...[
                  ...activeTasks.map((task) {
                    final isSelected = appProvider.selectedTaskId == task.id;

                    return JweDrawerProtocolItem(
                      task: task,
                      isSelected: isSelected,
                      icon: _getThemeIcon(task.theme),
                      onTap: () {
                        appProvider.setSelectedTaskId(task.id);
                        if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                      },
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => JweTaskOptionsDialog(task: task),
                        );
                      },
                    );
                  }),
                ],
                
                if (inactiveTasks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: Text(
                      "INACTIVE ARCHIVE", 
                      style: TextStyle(color: JweTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 10)
                    ),
                  ),
                  ...inactiveTasks.map((task) {
                    final isSelected = appProvider.selectedTaskId == task.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: JweCompactTaskCard(
                        task: task,
                        isSelected: isSelected,
                        onTap: () {
                          appProvider.setSelectedTaskId(task.id);
                          if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                        },
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => JweTaskOptionsDialog(task: task),
                          );
                        },
                      ),
                    );
                  }),
                ]
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              icon:  Icon(MdiIcons.plus, size: 18),
              label: Text("NEW AGENT", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              style: OutlinedButton.styleFrom(
                foregroundColor: JweTheme.accentCyan,
                side: const BorderSide(color: JweTheme.accentCyan, width: 1.5),
                shape: const BeveledRectangleBorder(),
                padding: const EdgeInsets.symmetric(vertical: 16)
              ),
              onPressed: () => _showAddTaskDialog(context, appProvider),
            ),
          )
        ],
      ),
    );
  }
}