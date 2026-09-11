import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:uuid/uuid.dart';
import 'today_task_tree_builder.dart';

class TodayRoutinesView extends StatelessWidget {
  final AppProvider provider;
  final String searchQuery;
  final void Function(RoutineList routine) onAddRoutineToPlan;

  const TodayRoutinesView({
    super.key,
    required this.provider,
    required this.searchQuery,
    required this.onAddRoutineToPlan,
  });

  bool _matchesQuery(String text, String q) {
    return text.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final allRoutines = provider.routineLists;
    if (allRoutines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NO ROUTINES CREATED YET',
              style: GoogleFonts.rajdhani(
                  color: AppTheme.fhTextDisabled,
                  fontSize: 13,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => showCreateRoutineDialog(context, provider),
              icon: Icon(MdiIcons.plusBoxOutline, size: 16, color: AppTheme.fhAccentTeal),
              label: Text('CREATE ROUTINE',
                  style: TextStyle(
                      color: AppTheme.fhAccentTeal,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                side: BorderSide(color: AppTheme.fhAccentTeal.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      );
    }

    final q = searchQuery.trim().toLowerCase();
    final routines = allRoutines.where((r) {
      if (q.isEmpty) return true;
      if (_matchesQuery(r.name, q)) return true;
      for (final compoundId in r.taskIds) {
        final details = resolveRoutineItemDetails(provider, compoundId);
        if (_matchesQuery(details.title, q) ||
            _matchesQuery(details.parentPath, q)) {
          return true;
        }
      }
      return false;
    }).toList();

    if (routines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No routine matches for "$searchQuery".',
            style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => showCreateRoutineDialog(context, provider),
              icon: Icon(MdiIcons.plusBoxOutline, size: 14, color: AppTheme.fhAccentTeal),
              label: Text('CREATE ROUTINE',
                  style: TextStyle(
                      color: AppTheme.fhAccentTeal,
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                side: BorderSide(color: AppTheme.fhAccentTeal.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: routines.length,
            itemBuilder: (context, idx) {
              final routine = routines[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDeepDark,
                  border: Border.all(color: AppTheme.fhBorderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.name,
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.fhTextPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${routine.taskIds.length} items',
                            style: TextStyle(
                              color: AppTheme.fhTextDisabled,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        onAddRoutineToPlan(routine);
                        showGlobalToast('Added "${routine.name}" routine to plan');
                      },
                      child: Text('ADD ALL',
                          style: TextStyle(
                              color: AppTheme.fhAccentTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, size: 16, color: AppTheme.fhTextSecondary),
                      onPressed: () => showCreateRoutineDialog(context, provider, routine),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, size: 16, color: AppTheme.fhAccentRed),
                      onPressed: () => confirmDeleteRoutine(context, provider, routine),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

void confirmDeleteRoutine(BuildContext context, AppProvider provider, RoutineList routine) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.fhBgDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: Text('DELETE ROUTINE',
          style: GoogleFonts.rajdhani(
              color: AppTheme.fhAccentRed,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold)),
      content: Text(
        'Are you sure you want to delete the routine "${routine.name}"?',
        style: TextStyle(color: AppTheme.fhTextPrimary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('CANCEL', style: TextStyle(color: AppTheme.fhTextSecondary)),
        ),
        TextButton(
          onPressed: () {
            provider.taskActions.deleteRoutineList(routine.id);
            Navigator.pop(ctx);
            showGlobalToast('Deleted routine: ${routine.name}');
          },
          child: Text('DELETE', style: TextStyle(color: AppTheme.fhAccentRed)),
        ),
      ],
    ),
  );
}

void showCreateRoutineDialog(BuildContext context, AppProvider provider, [RoutineList? existing]) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final selectedIdsList = List<String>.from(existing?.taskIds ?? <String>[]);
  final selectedIdsSet = selectedIdsList.toSet();
  String dialogSearchQuery = '';

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, dialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.fhBgDark,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: Text(existing == null ? 'CREATE ROUTINE' : 'EDIT ROUTINE',
                style: GoogleFonts.rajdhani(
                    color: AppTheme.fhAccentTeal,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: AppTheme.fhTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'Routine Name',
                      labelStyle: TextStyle(color: AppTheme.fhTextSecondary),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.fhAccentTeal)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ROUTINE ORDER (DRAG TO REARRANGE):',
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.fhTextSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (selectedIdsList.isEmpty)
                    Container(
                      height: 100,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.fhBorderColor),
                        color: AppTheme.fhBgDeepDark,
                      ),
                      child: Text(
                        'No items selected yet. Use the selector below.',
                        style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 11),
                      ),
                    )
                  else
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.fhBorderColor),
                        color: AppTheme.fhBgDeepDark,
                      ),
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        itemCount: selectedIdsList.length,
                        onReorder: (oldIndex, newIndex) {
                          dialogState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = selectedIdsList.removeAt(oldIndex);
                            selectedIdsList.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, idx) {
                          final compoundId = selectedIdsList[idx];
                          final itemDetails = resolveRoutineItemDetails(provider, compoundId);
                          return Container(
                            key: ValueKey('selected_$compoundId'),
                            margin: const EdgeInsets.only(bottom: 2),
                            color: AppTheme.fhBgDark.withValues(alpha: 0.5),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              title: Text(
                                itemDetails.title,
                                style: TextStyle(
                                    color: AppTheme.fhTextPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                itemDetails.parentPath,
                                style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 10),
                              ),
                              leading: Icon(
                                Icons.drag_handle,
                                size: 16,
                                color: AppTheme.fhTextSecondary,
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.close, size: 14, color: AppTheme.fhAccentRed),
                                onPressed: () {
                                  dialogState(() {
                                    selectedIdsList.removeAt(idx);
                                    selectedIdsSet.remove(compoundId);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'ADD / REMOVE ITEMS:',
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.fhTextSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhBorderColor),
                      color: AppTheme.fhBgDark,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: TextField(
                            onChanged: (v) {
                              dialogState(() {
                                dialogSearchQuery = v;
                              });
                            },
                            style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Search tasks...',
                              hintStyle: TextStyle(color: AppTheme.fhTextDisabled),
                              prefixIcon: Icon(Icons.search, size: 16, color: AppTheme.fhTextSecondary),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(color: AppTheme.fhBorderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(color: AppTheme.fhAccentTeal),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            children: buildSelectableTaskTree(
                              provider: provider,
                              query: dialogSearchQuery,
                              isSelectionMode: true,
                              selectedIds: selectedIdsSet,
                              onToggleSelection: (id, isSelected) {
                                dialogState(() {
                                  if (isSelected) {
                                    selectedIdsSet.add(id);
                                    if (!selectedIdsList.contains(id)) {
                                      selectedIdsList.add(id);
                                    }
                                  } else {
                                    selectedIdsSet.remove(id);
                                    selectedIdsList.remove(id);
                                  }
                                });
                              },
                              plannedCounts: const {},
                              onAdd: (_) {},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('CANCEL', style: TextStyle(color: AppTheme.fhTextSecondary)),
              ),
              TextButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    showGlobalToast('Please enter a routine name');
                    return;
                  }
                  if (selectedIdsList.isEmpty) {
                    showGlobalToast('Please select at least one task');
                    return;
                  }

                  final routine = RoutineList(
                    id: existing?.id ?? const Uuid().v4(),
                    name: name,
                    taskIds: selectedIdsList,
                  );
                  provider.taskActions.addOrUpdateRoutineList(routine);
                  Navigator.pop(ctx);
                  showGlobalToast(existing == null ? 'Created routine: $name' : 'Updated routine: $name');
                },
                child: Text(existing == null ? 'CREATE' : 'SAVE', style: TextStyle(color: AppTheme.fhAccentTeal)),
              ),
            ],
          );
        },
      );
    },
  );
}
