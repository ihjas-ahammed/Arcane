import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';

class ValueGenerationItemRow extends StatefulWidget {
  final Map<String, dynamic> taskData;
  final ValueChanged<Map<String, dynamic>> onUpdate;

  const ValueGenerationItemRow({
    super.key,
    required this.taskData,
    required this.onUpdate,
  });

  @override
  State<ValueGenerationItemRow> createState() => _ValueGenerationItemRowState();
}

class _ValueGenerationItemRowState extends State<ValueGenerationItemRow> {
  late bool _isSelected;
  late String _type; // 'task' or 'checkpoint'
  String? _selectedMainTaskId;
  String? _selectedParentSubTaskId;

  @override
  void initState() {
    super.initState();
    _isSelected = true;
    _type = 'task';
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Safety check for selected ID
    final initialId = provider.selectedTaskId;
    if (initialId != null && provider.mainTasks.any((t) => t.id == initialId)) {
        _selectedMainTaskId = initialId;
    } else {
        _selectedMainTaskId = provider.mainTasks.firstOrNull?.id;
    }
    
    // We do NOT call widget.onUpdate here to avoid setState during build.
    // Instead, the parent handles initial data aggregation based on defaults if needed, 
    // or we wait for user interaction. 
    // *Correction*: We need to sync initial state. We can use addPostFrameCallback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateParentData();
    });
  }

  void _updateParentData() {
    widget.onUpdate({
      'selected': _isSelected,
      'type': _type,
      'mainTaskId': _selectedMainTaskId,
      'parentSubTaskId': _selectedParentSubTaskId,
      'originalData': widget.taskData,
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final mainTasks = provider.mainTasks;
    
    List<SubTask> availableSubTasks = [];
    if (_selectedMainTaskId != null) {
      try {
        final task = mainTasks.firstWhere((t) => t.id == _selectedMainTaskId);
        availableSubTasks = task.subTasks;
      } catch (e) {
        // Handle case where task might be deleted
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border.all(color: _isSelected ? AppTheme.fhAccentTeal : AppTheme.fhBorderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Checkbox + Name
          Row(
            children: [
              Checkbox(
                value: _isSelected,
                activeColor: AppTheme.fhAccentTeal,
                checkColor: AppTheme.fhBgDeepDark,
                onChanged: (val) {
                  setState(() => _isSelected = val ?? false);
                  _updateParentData();
                },
              ),
              Expanded(
                child: Text(
                  widget.taskData['name'] ?? 'Unknown Action',
                  style: TextStyle(
                    color: _isSelected ? AppTheme.fhTextPrimary : AppTheme.fhTextDisabled,
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ],
          ),
          
          if (_isSelected) ...[
            const SizedBox(height: 8),
            // Row 2: Type + Main Task
            Row(
              children: [
                // Type Dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(
                      labelText: "TYPE",
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12, color: AppTheme.fhTextPrimary),
                    dropdownColor: AppTheme.fhBgDark,
                    items: const [
                      DropdownMenuItem(value: 'task', child: Text("SUB-MISSION")),
                      DropdownMenuItem(value: 'checkpoint', child: Text("CHECKPOINT")),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _type = val!;
                        // Reset parent subtask if switching to task
                        if (_type == 'task') _selectedParentSubTaskId = null;
                      });
                      _updateParentData();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Main Task Dropdown
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: mainTasks.any((t) => t.id == _selectedMainTaskId) ? _selectedMainTaskId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "MISSION",
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12, color: AppTheme.fhTextPrimary),
                    dropdownColor: AppTheme.fhBgDark,
                    items: mainTasks.map((t) => DropdownMenuItem(
                      value: t.id, 
                      child: Text(t.name.toUpperCase(), overflow: TextOverflow.ellipsis)
                    )).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedMainTaskId = val;
                        _selectedParentSubTaskId = null; // Reset subtask choice on mission change
                      });
                      _updateParentData();
                    },
                  ),
                ),
              ],
            ),
            
            // Row 3: Parent Subtask (Only if Checkpoint)
            if (_type == 'checkpoint') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: availableSubTasks.any((st) => st.id == _selectedParentSubTaskId) ? _selectedParentSubTaskId : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: "PARENT SUB-MISSION",
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12, color: AppTheme.fhTextPrimary),
                dropdownColor: AppTheme.fhBgDark,
                items: availableSubTasks.isEmpty 
                  ? [const DropdownMenuItem(value: null, child: Text("No Sub-Missions Available"))]
                  : availableSubTasks.map((st) => DropdownMenuItem(
                      value: st.id, 
                      child: Text(st.name, overflow: TextOverflow.ellipsis)
                    )).toList(),
                onChanged: availableSubTasks.isEmpty ? null : (val) {
                  setState(() => _selectedParentSubTaskId = val);
                  _updateParentData();
                },
              ),
            ],
          ]
        ],
      ),
    );
  }
}