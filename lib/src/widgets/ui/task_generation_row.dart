import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/task_models.dart';

class TaskGenerationRow extends StatefulWidget {
  final Map<String, dynamic> taskData;
  final List<MainTask> availableMissions;
  final String? defaultMissionId;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const TaskGenerationRow({
    super.key,
    required this.taskData,
    required this.availableMissions,
    required this.onChanged,
    this.defaultMissionId,
  });

  @override
  State<TaskGenerationRow> createState() => _TaskGenerationRowState();
}

class _TaskGenerationRowState extends State<TaskGenerationRow> {
  late bool _isSelected;
  late String _taskName;
  late String _type; // 'Task' or 'Checkpoint'
  String? _selectedMissionId;
  String? _selectedParentId;

  @override
  void initState() {
    super.initState();
    _isSelected = true;
    _taskName = widget.taskData['name'] ?? '';
    _type = 'Task';
    _selectedMissionId = widget.defaultMissionId;
    _updateState();
  }

  void _updateState() {
    widget.onChanged({
      'isSelected': _isSelected,
      'name': _taskName,
      'isCountable': widget.taskData['isCountable'],
      'targetCount': widget.taskData['targetCount'],
      'type': _type,
      'missionId': _selectedMissionId,
      'parentId': _selectedParentId,
    });
  }

  List<SubTask> _getAvailableParents() {
    if (_selectedMissionId == null) return [];
    try {
      final mission = widget.availableMissions
          .firstWhere((m) => m.id == _selectedMissionId);
      return mission.subTasks;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableParents = _getAvailableParents();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isSelected
            ? AppTheme.fhBgDark
            : AppTheme.fhBgDark.withOpacity(0.3),
        border: Border.all(
            color: _isSelected
                ? AppTheme.fhAccentTeal.withOpacity(0.5)
                : Colors.transparent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Checkbox + Name
          Row(
            children: [
              Checkbox(
                value: _isSelected,
                activeColor: AppTheme.fhAccentTeal,
                checkColor: AppTheme.fhBgDeepDark,
                onChanged: (val) {
                  setState(() => _isSelected = val ?? false);
                  _updateState();
                },
              ),
              Expanded(
                child: TextFormField(
                  initialValue: _taskName,
                  style: TextStyle(
                      color: _isSelected
                          ? AppTheme.fhTextPrimary
                          : AppTheme.fhTextDisabled,
                      decoration: _isSelected ? null : TextDecoration.lineThrough),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    _taskName = val;
                    _updateState();
                  },
                ),
              ),
            ],
          ),

          if (_isSelected) ...[
            const SizedBox(height: 8),
            // Mission Selector
            DropdownButtonFormField<String>(
              value: _selectedMissionId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: "MISSION",
                labelStyle: const TextStyle(fontSize: 10),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                filled: true,
                fillColor: AppTheme.fhBgMedium,
                border: const OutlineInputBorder(),
              ),
              items: widget.availableMissions.map((m) {
                return DropdownMenuItem(
                  value: m.id,
                  child: Text(m.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedMissionId = val;
                  _selectedParentId = null; // Reset parent if mission changes
                });
                _updateState();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Type Selector
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: InputDecoration(
                      labelText: "TYPE",
                      labelStyle: const TextStyle(fontSize: 10),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 0),
                      filled: true,
                      fillColor: AppTheme.fhBgMedium,
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Task',
                          child: Text('Task', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(
                          value: 'Checkpoint',
                          child: Text('Step',
                              style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      setState(() => _type = val!);
                      _updateState();
                    },
                  ),
                ),
                if (_type == 'Checkpoint') ...[
                  const SizedBox(width: 8),
                  // Parent Selector
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedParentId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: "PARENT SUB-MISSION",
                        labelStyle: const TextStyle(fontSize: 10),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                        filled: true,
                        fillColor: AppTheme.fhBgMedium,
                        border: const OutlineInputBorder(),
                      ),
                      items: availableParents.isEmpty
                          ? []
                          : availableParents.map((p) {
                              return DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedParentId = val);
                        _updateState();
                      },
                    ),
                  ),
                ]
              ],
            ),
          ]
        ],
      ),
    );
  }
}
