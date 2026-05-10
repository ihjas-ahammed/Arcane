import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:missions/src/widgets/valorant/valorant_dropdown.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

class LinkSubmissionSheet extends StatefulWidget {
  final String? initialMainTaskId;
  final String? initialProjectId;
  final String? initialStepId;

  const LinkSubmissionSheet({
    super.key,
    this.initialMainTaskId,
    this.initialProjectId,
    this.initialStepId,
  });

  @override
  State<LinkSubmissionSheet> createState() => _LinkSubmissionSheetState();
}

class _LinkSubmissionSheetState extends State<LinkSubmissionSheet> {
  String? _selectedMainTaskId;
  String? _selectedProjectId;
  String? _selectedStepId;
  String? _selectedTargetMainTaskId;
  String? _selectedTargetSubTaskId;
  String? _selectedTargetCheckpointId;

  String _mode = 'promote';
  String _targetType = 'subtask';
  String _promotionType = 'new_subtask'; // 'new_subtask' or 'new_checkpoint'
  String? _promotionParentSubTaskId;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);

    if (widget.initialMainTaskId != null) {
      _selectedMainTaskId = widget.initialMainTaskId;
      _selectedProjectId = widget.initialProjectId;
      _selectedStepId = widget.initialStepId;
      _selectedTargetMainTaskId = widget.initialMainTaskId; // Default target to source mission (Agent)
    } else {
      _selectedMainTaskId = provider.selectedTaskId;
      _selectedTargetMainTaskId = provider.selectedTaskId;
    }
  }

  // Helper to flatten steps for display/selection
  List<ProjectStep> _getAllSteps(Project project) {
    List<ProjectStep> all = [];
    void traverse(List<ProjectStep> steps) {
      for (var s in steps) {
        all.add(s);
        traverse(s.substeps);
      }
    }
    traverse(project.steps);
    return all;
  }

  // Helper to find step recursively (for execution)
  ProjectStep? _findStepRecursive(List<ProjectStep> steps, String id) {
    for (var s in steps) {
      if (s.id == id) return s;
      final found = _findStepRecursive(s.substeps, id);
      if (found != null) return found;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    final MainTask? sourceTask = provider.mainTasks.firstWhereOrNull((t) => t.id == _selectedMainTaskId);
    final projects = sourceTask?.projects ?? [];
    final selectedProject = projects.firstWhereOrNull((p) => p.id == _selectedProjectId);

    // Flatten steps if project selected
    final List<ProjectStep> displaySteps = selectedProject != null ? _getAllSteps(selectedProject) : [];

    final MainTask? targetTask = provider.mainTasks.firstWhereOrNull((t) => t.id == _selectedTargetMainTaskId);

    // Filter available SubTasks (only incomplete and non-deleted)
    final List<SubTask> availableSubTasks = targetTask?.subTasks.where((s) => !s.completed && !s.isDeleted).toList() ?? [];

    List<SubSubTask> availableCheckpoints = [];
    if (_selectedTargetSubTaskId != null) {
      final st = availableSubTasks.firstWhereOrNull((s) => s.id == _selectedTargetSubTaskId);
      if (st != null) {
        // Filter Checkpoints (only incomplete)
        availableCheckpoints = st.subSubTasks.where((c) => !c.completed).toList();
      }
    }

    return Container(
      color: AppTheme.fhBgDeepDark,
      height: MediaQuery.of(context).size.height * 0.9,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("LINK PROTOCOL", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary)),
              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Source Selection (If not fixed)
                      if (widget.initialStepId == null) ...[
                        ValorantDropdown<String>(
                          label: "SOURCE MISSION",
                          value: _selectedMainTaskId,
                          items: provider.mainTasks.where((t) => !t.isDeleted).map((t) => DropdownMenuItem(value: t.id, child: Text(t.name.toUpperCase()))).toList(),
                          onChanged: (val) => setState(() { _selectedMainTaskId = val; _selectedProjectId = null; _selectedStepId = null; }),
                        ),
                        const SizedBox(height: 16),
                        if (_selectedMainTaskId != null)
                          ValorantDropdown<String>(
                            label: "SOURCE PROJECT",
                            value: _selectedProjectId,
                            items: projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.title.toUpperCase()))).toList(),
                            onChanged: (val) => setState(() { _selectedProjectId = val; _selectedStepId = null; }),
                          ),

                        const SizedBox(height: 16),
                        if (selectedProject != null) ...[
                           const Text("SELECT STEP", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 8),
                           Container(
                             height: 150,
                             decoration: BoxDecoration(border: Border.all(color: AppTheme.fhBorderColor)),
                             child: ListView.builder(
                               itemCount: displaySteps.length,
                               itemBuilder: (context, index) {
                                 final step = displaySteps[index];
                                 final isSel = _selectedStepId == step.id;
                                 return ListTile(
                                   title: Text(step.title, style: TextStyle(color: isSel ? AppTheme.fhAccentPurple : AppTheme.fhTextPrimary)),
                                   selected: isSel,
                                   tileColor: isSel ? AppTheme.fhAccentPurple.withValues(alpha: 0.1) : null,
                                   trailing: isSel ? Icon(MdiIcons.checkBold, color: AppTheme.fhAccentPurple, size: 16) : null,
                                   onTap: () => setState(() => _selectedStepId = step.id),
                                 );
                               },
                             ),
                           )
                        ],
                        const SizedBox(height: 24),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 16),
                      ] else ...[
                        // Fixed Source Display
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppTheme.fhBgDark, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Icon(MdiIcons.sourceBranch, color: AppTheme.fhAccentPurple),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("LINKING SOURCE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                  Text(
                                    _findStepRecursive(selectedProject?.steps ?? [], _selectedStepId ?? '')?.title ?? "Unknown Step",
                                    style: TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold)
                                  )
                                ],
                              ))
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 2. Action Mode
                      Row(
                        children: [
                          _buildModeBtn("CREATE NEW", 'promote'),
                          const SizedBox(width: 16),
                          _buildModeBtn("LINK EXISTING", 'link'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Target Selection Area (Common: Target Mission/Agent)
                      ValorantDropdown<String>(
                        label: "TARGET MISSION",
                        value: _selectedTargetMainTaskId,
                        items: provider.mainTasks.where((t) => !t.isDeleted).map((t) => DropdownMenuItem(value: t.id, child: Text(t.name.toUpperCase()))).toList(),
                        onChanged: (val) => setState(() {
                          _selectedTargetMainTaskId = val;
                          _selectedTargetSubTaskId = null;
                          _selectedTargetCheckpointId = null;
                          _promotionParentSubTaskId = null; // Reset promotion parent too if mission changes
                        }),
                      ),
                      const SizedBox(height: 16),

                      if (_mode == 'link') ...[
                        if (_selectedTargetMainTaskId != null)
                          ValorantDropdown<String>(
                            label: "TARGET SUB-MISSION",
                            value: _selectedTargetSubTaskId,
                            items: availableSubTasks.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name.toUpperCase()))).toList(),
                            onChanged: (val) => setState(() { _selectedTargetSubTaskId = val; _selectedTargetCheckpointId = null; }),
                          ),

                        if (_selectedTargetSubTaskId != null) ...[
                          const SizedBox(height: 16),
                          Row(children: [
                            Checkbox(
                              value: _targetType == 'checkpoint',
                              activeColor: AppTheme.fhAccentPurple,
                              onChanged: (val) => setState(() {
                                _targetType = val == true ? 'checkpoint' : 'subtask';
                                if (_targetType == 'subtask') _selectedTargetCheckpointId = null;
                              }),
                            ),
                            const Text("Link to Checkpoint", style: TextStyle(color: AppTheme.fhTextPrimary)),
                          ]),
                          if (_targetType == 'checkpoint') ...[
                            if (availableCheckpoints.isNotEmpty)
                              ValorantDropdown<String>(
                                label: "TARGET CHECKPOINT",
                                value: _selectedTargetCheckpointId,
                                items: availableCheckpoints.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                                onChanged: (val) => setState(() => _selectedTargetCheckpointId = val),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text("No incomplete checkpoints available.", style: TextStyle(color: AppTheme.fhAccentRed, fontSize: 12)),
                              )
                          ]
                        ]
                      ] else ...[
                        // Mode 'promote'
                        const Text("PROMOTION TYPE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text("New Sub-Mission", style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13)),
                                value: 'new_subtask',
                                groupValue: _promotionType,
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppTheme.fhAccentPurple,
                                onChanged: (val) => setState(() => _promotionType = val!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text("New Checkpoint", style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13)),
                                value: 'new_checkpoint',
                                groupValue: _promotionType,
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppTheme.fhAccentPurple,
                                onChanged: (val) => setState(() => _promotionType = val!),
                              ),
                            ),
                          ],
                        ),

                        if (_promotionType == 'new_checkpoint') ...[
                          const SizedBox(height: 16),
                          ValorantDropdown<String>(
                            label: "PARENT SUB-MISSION",
                            value: _promotionParentSubTaskId,
                            items: availableSubTasks.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name.toUpperCase()))).toList(),
                            onChanged: (val) => setState(() => _promotionParentSubTaskId = val),
                          ),
                        ]
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(child: ValorantButton(label: "CANCEL", isPrimary: false, onPressed: () => Navigator.pop(context))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ValorantButton(
                      label: "EXECUTE",
                      isPrimary: true,
                      onPressed: () {
                        if (_selectedProjectId != null && _selectedStepId != null && selectedProject != null) {
                          // Recursive find to handle substeps
                          final step = _findStepRecursive(selectedProject.steps, _selectedStepId!);

                          if (step == null) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Step not found.")));
                             return;
                          }

                          if (_mode == 'promote') {
                            if (_selectedTargetMainTaskId == null) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select Target Mission.")));
                               return;
                            }

                            if (_promotionType == 'new_subtask') {
                              provider.projectActions.promoteStepToSubmission(_selectedTargetMainTaskId!, step);
                            } else {
                              if (_promotionParentSubTaskId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a parent sub-mission.")));
                                return;
                              }
                              provider.projectActions.promoteStepToCheckpoint(_selectedTargetMainTaskId!, _promotionParentSubTaskId!, step);
                            }
                          } else {
                            if (_selectedTargetMainTaskId != null && _selectedTargetSubTaskId != null) {
                              final targetId = _targetType == 'checkpoint' ? _selectedTargetCheckpointId : _selectedTargetSubTaskId;

                              if (targetId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a target.")));
                                return;
                              }

                              provider.projectActions.linkStepToTask(
                                _selectedMainTaskId!,
                                _selectedProjectId!,
                                _selectedStepId!,
                                targetId,
                                _targetType,
                                _selectedTargetMainTaskId!
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select target mission and sub-mission.")));
                              return;
                            }
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link Established.")));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Source step selection incomplete.")));
                        }
                      },
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeBtn(String label, String mode) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.fhAccentPurple.withValues(alpha: 0.2) : Colors.transparent,
            border: Border.all(color: isSelected ? AppTheme.fhAccentPurple : AppTheme.fhBorderColor),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: isSelected ? AppTheme.fhAccentPurple : AppTheme.fhTextSecondary, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}