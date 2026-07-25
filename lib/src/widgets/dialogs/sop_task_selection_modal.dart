import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/sop_model.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/screens/settings/sop_running_screen.dart';

class SopTaskSelectionModal extends StatefulWidget {
  final SopModel sop;

  const SopTaskSelectionModal({super.key, required this.sop});

  @override
  State<SopTaskSelectionModal> createState() => _SopTaskSelectionModalState();
}

class _SopTaskSelectionModalState extends State<SopTaskSelectionModal> {
  String? _selectedTaskCompositeId = 'none'; // Format: "none", "mainId|standalone", or "mainId|subId"
  int? _selectedDurationMinutes; // null = untimed/stopwatch
  final TextEditingController _customMinutesCtrl = TextEditingController();
  bool _isCustomDuration = false;

  final Set<String> _expandedTaskIds = {};
  String _taskSearchQuery = '';

  @override
  void dispose() {
    _customMinutesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    
    // Filter ONLY active, non-deleted main tasks
    final activeMainTasks = provider.mainTasks
        .where((t) => !t.isDeleted && t.isActive)
        .where((t) {
          if (_taskSearchQuery.trim().isEmpty) return true;
          final q = _taskSearchQuery.toLowerCase();
          return t.name.toLowerCase().contains(q) ||
              t.subTasks.any((s) => !s.isDeleted && s.isActive && !s.completed && s.name.toLowerCase().contains(q));
        })
        .toList();

    return AlertDialog(
      backgroundColor: AppTheme.fhBgMedium,
      title: Row(
        children: [
          Icon(MdiIcons.playCircleOutline, color: AppTheme.fhAccentTeal, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'START SOP SESSION',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textWhite,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SOP Preview Header
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: JweTheme.bgCanvas,
                  border: Border.all(color: JweTheme.lineSoft),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sop.title.isNotEmpty ? widget.sop.title : 'Untitled SOP',
                      style: GoogleFonts.saira(color: JweTheme.accentAmber, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (widget.sop.situation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.sop.situation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: JweTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Task Selector Section
              Text('LINK TO TASK (FOR TIMER LOGGING)', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2)),
              const SizedBox(height: 6),

              // Search Filter for Tasks
              TextField(
                onChanged: (val) => setState(() => _taskSearchQuery = val),
                style: TextStyle(color: JweTheme.textWhite, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Filter active tasks...',
                  hintStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                  prefixIcon: Icon(MdiIcons.magnify, color: JweTheme.textMuted, size: 16),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: JweTheme.bgCanvas,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                ),
              ),
              const SizedBox(height: 8),

              // Lazy Expanding Protocol Tree List
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: JweTheme.bgCanvas,
                  border: Border.all(color: JweTheme.lineSoft),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Option 1: No Task / Standalone
                    _buildTaskOptionTile(
                      compositeId: 'none',
                      title: 'No Task (Independent SOP Timer)',
                      subtitle: 'Timer runs without logging to a specific task',
                      color: JweTheme.textMuted,
                      icon: MdiIcons.clipboardOutline,
                    ),
                    Divider(color: JweTheme.lineSoft, height: 1),

                    // Active Protocols / Tasks
                    ...activeMainTasks.map((task) => _buildMainTaskLazyTile(task)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Target Timer Duration Selector
              Text('TARGET TIMER DURATION', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DurationChip(
                    label: 'Untimed',
                    selected: _selectedDurationMinutes == null && !_isCustomDuration,
                    onTap: () => setState(() {
                      _selectedDurationMinutes = null;
                      _isCustomDuration = false;
                    }),
                  ),
                  _DurationChip(
                    label: '5m',
                    selected: _selectedDurationMinutes == 5 && !_isCustomDuration,
                    onTap: () => setState(() {
                      _selectedDurationMinutes = 5;
                      _isCustomDuration = false;
                    }),
                  ),
                  _DurationChip(
                    label: '10m',
                    selected: _selectedDurationMinutes == 10 && !_isCustomDuration,
                    onTap: () => setState(() {
                      _selectedDurationMinutes = 10;
                      _isCustomDuration = false;
                    }),
                  ),
                  _DurationChip(
                    label: '15m',
                    selected: _selectedDurationMinutes == 15 && !_isCustomDuration,
                    onTap: () => setState(() {
                      _selectedDurationMinutes = 15;
                      _isCustomDuration = false;
                    }),
                  ),
                  _DurationChip(
                    label: '25m',
                    selected: _selectedDurationMinutes == 25 && !_isCustomDuration,
                    onTap: () => setState(() {
                      _selectedDurationMinutes = 25;
                      _isCustomDuration = false;
                    }),
                  ),
                  _DurationChip(
                    label: 'Custom',
                    selected: _isCustomDuration,
                    onTap: () => setState(() => _isCustomDuration = true),
                  ),
                ],
              ),
              if (_isCustomDuration) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _customMinutesCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Custom Duration (Minutes)',
                    labelStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: JweTheme.bgCanvas,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val.trim());
                    if (parsed != null && parsed > 0) {
                      setState(() => _selectedDurationMinutes = parsed);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final provider = Provider.of<AppProvider>(context, listen: false);
            final activeTasks = provider.mainTasks.where((t) => !t.isDeleted && t.isActive).toList();

            String? mainTaskId;
            String? subTaskId;
            String? taskTitle;

            if (_selectedTaskCompositeId != null && _selectedTaskCompositeId != 'none') {
              final parts = _selectedTaskCompositeId!.split('|');
              mainTaskId = parts[0];
              final mainTask = activeTasks.firstWhere((t) => t.id == mainTaskId, orElse: () => activeTasks.first);
              if (parts[1] == 'standalone') {
                subTaskId = null;
                taskTitle = mainTask.name;
              } else {
                subTaskId = parts[1];
                final sub = mainTask.subTasks.firstWhere((s) => s.id == subTaskId, orElse: () => mainTask.subTasks.first);
                taskTitle = '${mainTask.name} > ${sub.name}';
              }
            }

            final durationSecs = _selectedDurationMinutes != null ? _selectedDurationMinutes! * 60 : null;

            provider.startSopSession(
              widget.sop,
              mainTaskId: mainTaskId,
              subTaskId: subTaskId,
              taskTitle: taskTitle,
              targetDurationSeconds: durationSecs,
            );

            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SopRunningScreen()),
            );
          },
          icon: const Icon(Icons.play_arrow, size: 18),
          label: Text(
            'START SESSION',
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.fhAccentTeal,
            foregroundColor: AppTheme.fhBgDark,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskOptionTile({
    required String compositeId,
    required String title,
    String? subtitle,
    required Color color,
    IconData? icon,
  }) {
    final isSelected = _selectedTaskCompositeId == compositeId;

    return InkWell(
      onTap: () => setState(() => _selectedTaskCompositeId = compositeId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: isSelected ? AppTheme.fhAccentTeal.withValues(alpha: 0.12) : Colors.transparent,
        child: Row(
          children: [
            Radio<String>(
              value: compositeId,
              groupValue: _selectedTaskCompositeId,
              onChanged: (val) => setState(() => _selectedTaskCompositeId = val),
              activeColor: AppTheme.fhAccentTeal,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
            ] else ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? JweTheme.textWhite : JweTheme.textWhite,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    Text(
                      subtitle,
                      style: TextStyle(color: JweTheme.textMuted, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTaskLazyTile(MainTask task) {
    // Filter ONLY active, non-deleted, non-completed subtasks
    final activeSubTasks = task.subTasks
        .where((s) => !s.isDeleted && s.isActive && !s.completed)
        .toList();

    final isExpanded = _expandedTaskIds.contains(task.id);
    final compositeId = '${task.id}|standalone';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: _buildTaskOptionTile(
                  compositeId: compositeId,
                  title: task.name,
                  subtitle: activeSubTasks.isNotEmpty ? '${activeSubTasks.length} active subtasks' : 'Main Protocol',
                  color: task.taskColor,
                ),
              ),
              if (activeSubTasks.isNotEmpty)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: JweTheme.textMuted,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedTaskIds.remove(task.id);
                      } else {
                        _expandedTaskIds.add(task.id);
                      }
                    });
                  },
                  tooltip: isExpanded ? 'Collapse' : 'Expand subtasks',
                ),
            ],
          ),
        ),

        // Lazy expansion: Subtasks loaded ONLY when expanded
        if (isExpanded && activeSubTasks.isNotEmpty)
          Container(
            padding: const EdgeInsets.only(left: 28),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: task.taskColor.withValues(alpha: 0.3), width: 2)),
            ),
            child: Column(
              children: activeSubTasks.map((sub) {
                final subCompositeId = '${task.id}|${sub.id}';
                return _buildTaskOptionTile(
                  compositeId: subCompositeId,
                  title: sub.name,
                  subtitle: null,
                  color: task.taskColor,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.fhAccentTeal.withValues(alpha: 0.2) : JweTheme.bgCanvas,
          border: Border.all(color: selected ? AppTheme.fhAccentTeal : JweTheme.lineSoft),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: selected ? AppTheme.fhAccentTeal : JweTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
