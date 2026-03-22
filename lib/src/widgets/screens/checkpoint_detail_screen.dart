import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/items/checkpoint_item.dart';
import 'package:arcane/src/widgets/action_plan/action_plan_why_card.dart';
import 'package:arcane/src/widgets/action_plan/action_plan_outcome_card.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class CheckpointDetailScreen extends StatefulWidget {
  final String mainTaskId;
  final String parentSubTaskId;
  final String checkpointId;

  const CheckpointDetailScreen({
    super.key,
    required this.mainTaskId,
    required this.parentSubTaskId,
    required this.checkpointId,
  });

  @override
  State<CheckpointDetailScreen> createState() => _CheckpointDetailScreenState();
}

class _CheckpointDetailScreenState extends State<CheckpointDetailScreen> {
  final TextEditingController _stepController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  String _newStepType = 'check';

  SubSubTask? _getLiveCheckpoint(AppProvider provider) {
    try {
      final parent = provider.mainTasks.firstWhere((t) => t.id == widget.mainTaskId);
      final sub = parent.subTasks.firstWhere((s) => s.id == widget.parentSubTaskId);
      
      SubSubTask? findRecursive(List<SubSubTask> list, String id) {
        for (var item in list) {
          if (item.id == id) return item;
          final found = findRecursive(item.substeps, id);
          if (found != null) return found;
        }
        return null;
      }
      return findRecursive(sub.subSubTasks, widget.checkpointId);
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final cp = _getLiveCheckpoint(provider);
      if (cp != null) {
        _titleController.text = cp.name;
      }
    });
  }

  void _saveTitle(AppProvider provider, SubSubTask cp) {
    if (_titleController.text.trim() != cp.name) {
      provider.taskActions.updateSubSubtask(
        widget.mainTaskId, widget.parentSubTaskId, cp.id,
        {'name': _titleController.text.trim()}
      );
    }
  }

  void _addSubstep(AppProvider provider, SubSubTask parentCp) {
    if (_stepController.text.trim().isEmpty) return;
    
    provider.taskActions.addSubSubtask(
      widget.mainTaskId, 
      widget.parentSubTaskId, 
      {
        'name': _stepController.text.trim(),
        'type': _newStepType,
        'isCountable': false,
      },
      parentCheckpointId: parentCp.id
    );
    _stepController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final liveCheckpoint = _getLiveCheckpoint(provider);

    if (liveCheckpoint == null) {
      return const Scaffold(backgroundColor: AppTheme.fhBgDeepDark, body: Center(child: Text("Checkpoint not found", style: TextStyle(color: AppTheme.fhTextPrimary))));
    }

    Color agentColor = AppTheme.fhAccentTeal;
    try {
      final parent = provider.mainTasks.firstWhere((t) => t.id == widget.mainTaskId);
      agentColor = parent.taskColor;
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: SafeArea(
        child: Column(
          children:[
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3))),
                color: AppTheme.fhBgDark,
              ),
              child: Row(
                children:[
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: AppTheme.fhTextSecondary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "OBJECTIVE DETAIL",
                      style: TextStyle(
                        color: agentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontFamily: AppTheme.fontDisplay
                      ),
                    ),
                  ),
                  IconButton(
                    icon:  Icon(MdiIcons.deleteOutline, color: AppTheme.fhAccentRed),
                    onPressed: () {
                      provider.taskActions.deleteSubSubtask(widget.mainTaskId, widget.parentSubTaskId, liveCheckpoint.id);
                      Navigator.pop(context);
                    },
                  )
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:[
                    // Title Input
                    TextField(
                      controller: _titleController,
                      style: GoogleFonts.chakraPetch(color: AppTheme.fhTextPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(border: InputBorder.none, hintText: "Objective Name"),
                      onSubmitted: (_) => _saveTitle(provider, liveCheckpoint),
                      onEditingComplete: () => _saveTitle(provider, liveCheckpoint),
                    ),
                    const SizedBox(height: 24),

                    // Why/What
                    ActionPlanWhyCard(
                      initialWhy: liveCheckpoint.why,
                      accentColor: agentColor,
                      onChanged: (val) => provider.taskActions.updateSubSubtask(widget.mainTaskId, widget.parentSubTaskId, liveCheckpoint.id, {'why': val}),
                    ),
                    const SizedBox(height: 16),
                    ActionPlanOutcomeCard(
                      initialWhat: liveCheckpoint.what,
                      accentColor: agentColor,
                      onChanged: (val) => provider.taskActions.updateSubSubtask(widget.mainTaskId, widget.parentSubTaskId, liveCheckpoint.id, {'what': val}),
                    ),

                    const SizedBox(height: 32),

                    // Nested Steps
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3)))
                      ),
                      child: const Text("SUB-ROUTINES (NESTED)", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    
                    if (liveCheckpoint.substeps.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text("No nested instructions.", style: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic)),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: liveCheckpoint.substeps.length,
                        onReorder: (oldIndex, newIndex) {
                          if (oldIndex < newIndex) newIndex -= 1;
                          final list = List<SubSubTask>.from(liveCheckpoint.substeps);
                          final item = list.removeAt(oldIndex);
                          list.insert(newIndex, item);
                          provider.taskActions.reorderSubSubtasksBySubset(widget.mainTaskId, widget.parentSubTaskId, list.map((e) => e.id).toList(), parentCheckpointId: liveCheckpoint.id);
                        },
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            color: Colors.transparent,
                            elevation: 5,
                            shadowColor: Colors.black,
                            child: child,
                          );
                        },
                        itemBuilder: (ctx, index) {
                          final child = liveCheckpoint.substeps[index];
                          return CheckpointItem(
                            key: ValueKey(child.id),
                            title: child.name,
                            isCompleted: child.completed,
                            type: child.type,
                            accentColor: agentColor,
                            hasSubsteps: child.substeps.isNotEmpty,
                            progress: child.calculateProgress(), // Passing correct progress manually calculated
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CheckpointDetailScreen(
                                mainTaskId: widget.mainTaskId,
                                parentSubTaskId: widget.parentSubTaskId,
                                checkpointId: child.id,
                              )));
                            },
                            onToggle: () {
                              final updates = {'completed': !child.completed};
                              provider.taskActions.updateSubSubtask(widget.mainTaskId, widget.parentSubTaskId, child.id, updates);
                            },
                            onDelete: () => provider.taskActions.deleteSubSubtask(widget.mainTaskId, widget.parentSubTaskId, child.id),
                            onDuplicate: () => provider.taskActions.duplicateSubSubtask(widget.mainTaskId, widget.parentSubTaskId, child.id),
                            onToggleType: () {
                              final newType = child.type == 'check' ? 'info' : 'check';
                              provider.taskActions.updateSubSubtask(widget.mainTaskId, widget.parentSubTaskId, child.id, {'type': newType});
                            },
                          );
                        },
                      ),

                    // Add Substep
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.fhBgDark.withOpacity(0.5),
                        border: Border.all(color: AppTheme.fhBorderColor),
                      ),
                      child: Row(
                        children:[
                          PopupMenuButton<String>(
                            icon: Icon(_newStepType == 'info' ? MdiIcons.informationOutline : MdiIcons.checkboxMarkedOutline, color: AppTheme.fhTextSecondary, size: 20),
                            onSelected: (val) => setState(() => _newStepType = val),
                            color: AppTheme.fhBgDark,
                            itemBuilder: (context) =>[
                              const PopupMenuItem(value: 'check', child: Text("Checkable", style: TextStyle(color: AppTheme.fhTextPrimary))),
                              const PopupMenuItem(value: 'info', child: Text("Info", style: TextStyle(color: AppTheme.fhTextPrimary))),
                            ],
                          ),
                          Expanded(
                            child: TextField(
                              controller: _stepController,
                              style: GoogleFonts.chakraPetch(color: AppTheme.fhTextPrimary, fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: "ADD NESTED STEP...",
                                hintStyle: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                              onSubmitted: (_) => _addSubstep(provider, liveCheckpoint),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, color: agentColor),
                            onPressed: () => _addSubstep(provider, liveCheckpoint),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}