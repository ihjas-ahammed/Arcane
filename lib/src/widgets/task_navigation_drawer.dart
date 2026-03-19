import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/dialogs/color_selector_dialog.dart';
import 'package:arcane/src/widgets/ui/jwe_compact_task_card.dart';
import 'package:arcane/src/widgets/dialogs/jwe_task_options_dialog.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TaskNavigationDrawer extends StatefulWidget {
  const TaskNavigationDrawer({super.key});

  @override
  State<TaskNavigationDrawer> createState() => _TaskNavigationDrawerState();
}

class _TaskNavigationDrawerState extends State<TaskNavigationDrawer> {
  final _newTaskNameController = TextEditingController();
  final _newTaskDescController = TextEditingController();

  String _dialogSelectedTheme = 'tech';
  // ignore: deprecated_member_use
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
    // ignore: deprecated_member_use
    _dialogSelectedColorHex = _getColorForTheme(_dialogSelectedTheme).value.toRadixString(16).toUpperCase().substring(2);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
          final currentColor = Color(int.parse("0xFF$_dialogSelectedColorHex"));

          return AlertDialog(
            title: const Text('NEW PROTOCOL'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(controller: _newTaskNameController, decoration: const InputDecoration(labelText: 'CODENAME')),
                  const SizedBox(height: 12),
                  TextField(controller: _newTaskDescController, decoration: const InputDecoration(labelText: 'BRIEFING'), maxLines: 2),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'CLASS'),
                    dropdownColor: AppTheme.fhBgDark,
                    // ignore: deprecated_member_use
                    value: _dialogSelectedTheme,
                    items: _availableThemes.map((themeMap) => DropdownMenuItem(
                      value: themeMap['name'] as String,
                      child: Text((themeMap['name'] as String).toUpperCase(), style: const TextStyle(fontFamily: AppTheme.fontDisplay))
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() {
                          _dialogSelectedTheme = val;
                          // ignore: deprecated_member_use
                          _dialogSelectedColorHex = _getColorForTheme(val).value.toRadixString(16).toUpperCase().substring(2);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text("CLASS COLOR", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ColorSelectorDialog(
                          selectedColor: currentColor,
                          onColorSelected: (color) {
                            setStateDialog(() {
                              // ignore: deprecated_member_use
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
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Center(child: Text("TAP TO CHANGE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10))),
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(child: const Text('ABORT'), onPressed: () => Navigator.pop(dialogContext)),
              ValorantButton(
                label: 'INITIALIZE',
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
    
    return Container(
      width: 300,
      color: AppTheme.fhBgDeepDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PROTOCOLS", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.fhTextSecondary)),
                const SizedBox(height: 4),
                Text("SELECT MISSION PROFILE", style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 2.0)),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (activeTasks.isNotEmpty) ...[
                  ...activeTasks.map((task) {
                    final isSelected = appProvider.selectedTaskId == task.id;
                    final color = task.taskColor;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ValorantCard(
                        isSelected: isSelected,
                        borderColor: isSelected ? color : null,
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
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: isSelected ? color.withValues(alpha: 0.2) : Colors.black26,
                                border: Border.all(color: isSelected ? color : Colors.transparent),
                              ),
                              child: Icon(_getThemeIcon(task.theme), color: isSelected ? color : AppTheme.fhTextSecondary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.name.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontDisplay,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: isSelected ? AppTheme.fhTextPrimary : AppTheme.fhTextSecondary,
                                      letterSpacing: 1.0,
                                    ),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    task.theme.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10, 
                                      color: isSelected ? color : AppTheme.fhTextDisabled,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w600
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
                
                if (inactiveTasks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: Text("INACTIVE ARCHIVE", style: TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 10)),
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
                  }).toList(),
                ]
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ValorantButton(
              label: "NEW AGENT",
              icon: MdiIcons.plus,
              isPrimary: false,
              onPressed: () => _showAddTaskDialog(context, appProvider),
            ),
          )
        ],
      ),
    );
  }
}