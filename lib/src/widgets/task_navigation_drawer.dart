import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/jwe_drawer_protocol_item.dart';
import 'package:missions/src/widgets/ui/jwe_compact_task_card.dart';
import 'package:missions/src/widgets/dialogs/jwe_task_options_dialog.dart';
import 'package:missions/src/widgets/dialogs/add_edit_protocol_dialog.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TaskNavigationDrawer extends StatefulWidget {
  const TaskNavigationDrawer({super.key});

  @override
  State<TaskNavigationDrawer> createState() => _TaskNavigationDrawerState();
}

class _TaskNavigationDrawerState extends State<TaskNavigationDrawer> {

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

  IconData _getThemeIcon(String? themeName) {
    return _availableThemes.firstWhere((t) => t['name'] == themeName,
        orElse: () => _availableThemes.last)['icon'] as IconData;
  }

  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return const AddEditProtocolDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    // Filter out soft-deleted tasks
    final activeTasks = appProvider.mainTasks.where((t) => t.isActive && !t.isDeleted).toList();
    final inactiveTasks = appProvider.mainTasks.where((t) => !t.isActive && !t.isDeleted).toList();
    
    return Drawer(
      width: 280,
      backgroundColor: JweTheme.bgBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: JweTheme.lineSoft, width: 1)),
              color: JweTheme.bgCanvas,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 4, height: 14, color: JweTheme.accentAmber),
                    const SizedBox(width: 10),
                    Text(
                      'AGENT REGISTRY',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 10, letterSpacing: 1.8, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      'A-NN',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'PROTOCOLS',
                  style: GoogleFonts.saira(color: JweTheme.textWhite, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 1.6),
                ),
                const SizedBox(height: 4),
                Text(
                  'SELECT OPERATIONAL VECTOR',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w600),
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
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                    child: Row(
                      children: [
                        Container(width: 4, height: 10, color: JweTheme.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          'INACTIVE ARCHIVE',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textMuted,
                            fontSize: 10,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: InkWell(
              onTap: () => _showAddTaskDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: JweTheme.lineAmber, width: 1, style: BorderStyle.solid),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(MdiIcons.plus, size: 16, color: JweTheme.accentAmber),
                    const SizedBox(width: 8),
                    Text(
                      '+ DEPLOY AGENT',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}