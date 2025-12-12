// lib/src/widgets/task_navigation_drawer.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/models/task_models.dart';

class TaskNavigationDrawer extends StatefulWidget {
  const TaskNavigationDrawer({super.key});

  @override
  State<TaskNavigationDrawer> createState() => _TaskNavigationDrawerState();
}

class _TaskNavigationDrawerState extends State<TaskNavigationDrawer> {
  final _newTaskNameController = TextEditingController();
  final _newTaskDescController = TextEditingController();
  final _editTaskNameController = TextEditingController();
  final _editTaskDescController = TextEditingController();

  String _dialogSelectedTheme = 'tech';
  String _dialogSelectedColorHex =
      AppTheme.fhAccentTealFixed.value.toRadixString(16).toUpperCase();

  final List<Map<String, dynamic>> _availableThemes = [
    {
      'name': 'tech',
      'icon': MdiIcons.memory,
      'color': AppTheme.fhAccentTealFixed
    },
    {
      'name': 'knowledge',
      'icon': MdiIcons.bookOpenPageVariantOutline,
      'color': AppTheme.fhAccentPurple
    },
    {
      'name': 'learning',
      'icon': MdiIcons.schoolOutline,
      'color': AppTheme.fhAccentOrange
    },
    {
      'name': 'discipline',
      'icon': MdiIcons.karate,
      'color': AppTheme.fhAccentRed
    },
    {
      'name': 'order',
      'icon': MdiIcons.playlistCheck,
      'color': AppTheme.fhAccentGreen
    },
    {
      'name': 'health',
      'icon': MdiIcons.heartPulse,
      'color': const Color(0xFF58D68D)
    },
    {
      'name': 'finance',
      'icon': MdiIcons.cashMultiple,
      'color': const Color(0xFFF1C40F)
    },
    {
      'name': 'creative',
      'icon': MdiIcons.paletteOutline,
      'color': const Color(0xFFEC7063)
    },
    {
      'name': 'exploration',
      'icon': MdiIcons.mapSearchOutline,
      'color': const Color(0xFF5DADE2)
    },
    {
      'name': 'social',
      'icon': MdiIcons.accountGroupOutline,
      'color': const Color(0xFFE59866)
    },
    {
      'name': 'nature',
      'icon': MdiIcons.treeOutline,
      'color': const Color(0xFF2ECC71)
    },
    {
      'name': 'general',
      'icon': MdiIcons.targetAccount,
      'color': AppTheme.fhTextSecondary
    },
  ];

  Color _getColorForTheme(String themeName) {
    return _availableThemes.firstWhere((t) => t['name'] == themeName,
        orElse: () => {'color': AppTheme.fhAccentTealFixed})['color'] as Color;
  }

  @override
  void dispose() {
    _newTaskNameController.dispose();
    _newTaskDescController.dispose();
    _editTaskNameController.dispose();
    _editTaskDescController.dispose();
    super.dispose();
  }

  IconData _getThemeIcon(String? themeName) {
    return _availableThemes.firstWhere((t) => t['name'] == themeName,
        orElse: () => _availableThemes.last)['icon'] as IconData;
  }

  void _showAddTaskDialog(BuildContext context, AppProvider appProvider) {
    _newTaskNameController.clear();
    _newTaskDescController.clear();
    _dialogSelectedTheme = 'tech';
    _dialogSelectedColorHex = _getColorForTheme(_dialogSelectedTheme)
        .value
        .toRadixString(16)
        .toUpperCase();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
          return AlertDialog(
            backgroundColor: AppTheme.fhBgMedium,
            title: const Text('Add New Mission',
                style: TextStyle(color: AppTheme.fhAccentRed)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                      controller: _newTaskNameController,
                      decoration:
                          const InputDecoration(labelText: 'Mission Name')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _newTaskDescController,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 2),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Theme'),
                    dropdownColor: AppTheme.fhBgLight,
                    initialValue: _dialogSelectedTheme,
                    items: _availableThemes
                        .map((themeMap) => DropdownMenuItem<String>(
                            value: themeMap['name'] as String,
                            child: Row(
                              children: [
                                Icon(_getThemeIcon(themeMap['name'] as String),
                                    size: 18,
                                    color: themeMap['color'] as Color),
                                const SizedBox(width: 8),
                                Text(themeMap['name'] as String),
                              ],
                            )))
                        .toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setStateDialog(() {
                          _dialogSelectedTheme = newValue;
                          _dialogSelectedColorHex = _getColorForTheme(newValue)
                              .value
                              .toRadixString(16)
                              .toUpperCase();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text("Select Theme Color:",
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _availableThemes.map((themeMap) {
                      Color color = themeMap['color'] as Color;
                      String colorHex =
                          color.value.toRadixString(16).toUpperCase();
                      bool isSelectedColor =
                          _dialogSelectedColorHex == colorHex;

                      return GestureDetector(
                        onTap: () => setStateDialog(
                            () => _dialogSelectedColorHex = colorHex),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                            border: isSelectedColor
                                ? Border.all(color: Colors.white, width: 2)
                                : Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1),
                          ),
                          child: isSelectedColor
                              ? Icon(MdiIcons.check,
                                  color: ThemeData.estimateBrightnessForColor(
                                              color) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                  size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop()),
              ElevatedButton(
                child: const Text('Add Mission'),
                onPressed: () {
                  if (_newTaskNameController.text.isNotEmpty) {
                    appProvider.addMainTask(
                      name: _newTaskNameController.text,
                      description: _newTaskDescController.text,
                      theme: _dialogSelectedTheme,
                      colorHex: _dialogSelectedColorHex,
                    );
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  void _showEditTaskDialog(
      BuildContext context, AppProvider appProvider, MainTask taskToEdit) {
    _editTaskNameController.text = taskToEdit.name;
    _editTaskDescController.text = taskToEdit.description;
    _dialogSelectedTheme = taskToEdit.theme;
    _dialogSelectedColorHex = taskToEdit.colorHex;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
          return AlertDialog(
            backgroundColor: AppTheme.fhBgMedium,
            title: const Text('Edit Mission',
                style: TextStyle(color: AppTheme.fhAccentRed)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                      controller: _editTaskNameController,
                      decoration:
                          const InputDecoration(labelText: 'Mission Name')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _editTaskDescController,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 2),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Theme'),
                      dropdownColor: AppTheme.fhBgLight,
                      initialValue: _dialogSelectedTheme,
                      items: _availableThemes
                          .map((themeMap) => DropdownMenuItem<String>(
                              value: themeMap['name'] as String,
                              child: Row(
                                children: [
                                  Icon(
                                      _getThemeIcon(themeMap['name'] as String),
                                      size: 18,
                                      color: themeMap['color'] as Color),
                                  const SizedBox(width: 8),
                                  Text(themeMap['name'] as String),
                                ],
                              )))
                          .toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setStateDialog(() {
                            _dialogSelectedTheme = newValue;
                            _dialogSelectedColorHex =
                                _getColorForTheme(newValue)
                                    .value
                                    .toRadixString(16)
                                    .toUpperCase();
                          });
                        }
                      }),
                  const SizedBox(height: 16),
                  Text("Select Theme Color:",
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _availableThemes.map((themeMap) {
                      Color color = themeMap['color'] as Color;
                      String colorHex =
                          color.value.toRadixString(16).toUpperCase();
                      bool isSelectedColor =
                          _dialogSelectedColorHex == colorHex;

                      return GestureDetector(
                        onTap: () => setStateDialog(
                            () => _dialogSelectedColorHex = colorHex),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                            border: isSelectedColor
                                ? Border.all(color: Colors.white, width: 2)
                                : Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1),
                          ),
                          child: isSelectedColor
                              ? Icon(MdiIcons.check,
                                  color: ThemeData.estimateBrightnessForColor(
                                              color) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                  size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop()),
              ElevatedButton(
                child: const Text('Save Changes'),
                onPressed: () {
                  if (_editTaskNameController.text.isNotEmpty) {
                    appProvider.editMainTask(
                      taskToEdit.id,
                      name: _editTaskNameController.text,
                      description: _editTaskDescController.text,
                      theme: _dialogSelectedTheme,
                      colorHex: _dialogSelectedColorHex,
                    );
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: AppTheme.fhBgDark,
      child: Column(
        children: [
          AppBar(
            title: Text('MISSIONS',
                style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.fhTextPrimary, letterSpacing: 1)),
            automaticallyImplyLeading: false,
            backgroundColor: AppTheme.fhBgMedium,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(MdiIcons.plusCircleOutline,
                    color: AppTheme.fhAccentTeal),
                onPressed: () => _showAddTaskDialog(context, appProvider),
                tooltip: 'Add New Mission',
              ),
            ],
          ),
          Expanded(
            child: appProvider.mainTasks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No missions available. Add a new one to begin.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.fhTextSecondary,
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: appProvider.mainTasks.length,
                    itemBuilder: (context, index) {
                      final task = appProvider.mainTasks[index];
                      final isSelected = appProvider.selectedTaskId == task.id;
                      final taskColor = Color(int.parse("0x${task.colorHex}"));

                      return Material(
                        color: isSelected
                            ? taskColor.withValues(alpha: 0.25)
                            : Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            _getThemeIcon(task.theme),
                            color: isSelected
                                ? taskColor
                                : AppTheme.fhTextSecondary,
                            size: 22,
                          ),
                          title: Text(
                            task.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isSelected
                                  ? taskColor
                                  : AppTheme.fhTextPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: Icon(MdiIcons.pencilOutline,
                                size: 18,
                                color: AppTheme.fhTextSecondary
                                    .withValues(alpha: 0.7)),
                            onPressed: () =>
                                _showEditTaskDialog(context, appProvider, task),
                            tooltip: 'Edit Mission',
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                            constraints: const BoxConstraints(),
                          ),
                          selected: isSelected,
                          onTap: () {
                            appProvider.setSelectedTaskId(task.id);
                            if (MediaQuery.of(context).size.width < 900) {
                              Navigator.pop(context);
                            }
                          },
                          selectedTileColor: taskColor.withValues(alpha: 0.15),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
