import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/timeline_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/dialogs/edit_subtask_dialog.dart';
import 'package:arcane/src/widgets/dialogs/add_session_dialog.dart';
import 'package:arcane/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:arcane/src/widgets/ui/schedule_timeline.dart';
import 'package:arcane/src/widgets/ui/valorant_ability_slot.dart';
import 'package:arcane/src/widgets/ui/valorant_list_item.dart';
import 'package:arcane/src/widgets/drawers/session_history_drawer.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class SubmissionDetailScreen extends StatefulWidget {
  final MainTask parentTask;
  final SubTask subTask;

  const SubmissionDetailScreen({
    super.key,
    required this.parentTask,
    required this.subTask,
  });

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  final TextEditingController _checkpointController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _checkpointController.dispose();
    super.dispose();
  }

  // ... [Keep existing helper methods: _getLiveSubTask, _handleAddCheckpoint, etc.]
  SubTask? _getLiveSubTask(AppProvider provider) {
    try {
      final parent = provider.mainTasks.firstWhere((t) => t.id == widget.parentTask.id);
      return parent.subTasks.firstWhere((s) => s.id == widget.subTask.id);
    } catch (e) { return null; }
  }

  void _handleAddCheckpoint(AppProvider provider) {
    if (_checkpointController.text.trim().isEmpty) return;
    provider.addSubSubtask(widget.parentTask.id, widget.subTask.id, {'name': _checkpointController.text.trim()});
    _checkpointController.clear();
  }

  Future<void> _handleEditSubtask(BuildContext context, AppProvider provider, SubTask textSubTask) async {
    final String? newName = await showDialog<String>(context: context, builder: (context) => EditSubtaskDialog(initialName: textSubTask.name));
    if (newName != null && newName.isNotEmpty) provider.updateSubtask(widget.parentTask.id, widget.subTask.id, {'name': newName});
  }

  void _showAddSessionDialog(BuildContext context, AppProvider provider) async {
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => const AddSessionDialog());
    if (result != null) provider.addSessionToSubtask(widget.parentTask.id, widget.subTask.id, result['start'], result['end']);
  }

  List<TimelineEntry> _buildTimelineEntries(AppProvider provider, String currentSubTaskId) {
    final List<TimelineEntry> entries = [];
    for (var task in provider.mainTasks) {
      for (var sub in task.subTasks) {
        for (var session in sub.sessions) {
          if (session.startTime.year == _selectedDate.year && session.startTime.month == _selectedDate.month && session.startTime.day == _selectedDate.day) {
            entries.add(TimelineEntry(id: session.id, startTime: session.startTime, endTime: session.endTime, title: sub.name, subtitle: task.name, color: task.taskColor, isEditable: sub.id == currentSubTaskId, originalObject: session));
          }
        }
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final liveSubTask = _getLiveSubTask(provider);

    if (liveSubTask == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.of(context).pop(); });
      return const SizedBox.shrink();
    }

    final timerState = provider.activeTimers[liveSubTask.id];
    final double displayTimeSeconds = timerState != null ? (timerState.isRunning ? timerState.accumulatedDisplayTime + (DateTime.now().difference(timerState.startTime).inMilliseconds / 1000) : timerState.accumulatedDisplayTime) : liveSubTask.currentTimeSpent.toDouble();
    final String formattedTime = helper.formatTime(displayTimeSeconds);
    final bool isRunning = timerState?.isRunning ?? false;
    final int completedCheckpoints = liveSubTask.subSubTasks.where((s) => s.completed).length;
    final int totalCheckpoints = liveSubTask.subSubTasks.length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.fhBgDeepDark,
      endDrawer: SessionHistoryDrawer(mainTaskId: widget.parentTask.id, subTask: liveSubTask),
      body: Stack(
        children: [
          Positioned(right: -50, top: 50, child: Opacity(opacity: 0.05, child: Icon(MdiIcons.targetVariant, size: 400, color: Colors.white))),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                        const Spacer(),
                        // New Button to open session history drawer
                        IconButton(
                          icon: Icon(MdiIcons.history, color: Colors.white70),
                          tooltip: "Manage Sessions",
                          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                        ),
                        IconButton(icon: Icon(MdiIcons.pencilOutline, color: Colors.white70), onPressed: () => _handleEditSubtask(context, provider, liveSubTask)),
                      ],
                    ),
                  ),
                  
                  // Resized header for mobile target
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.parentTask.name.toUpperCase(), style: TextStyle(color: widget.parentTask.taskColor, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12, fontFamily: AppTheme.fontDisplay)),
                        const SizedBox(height: 8),
                        Text(liveSubTask.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32, height: 1.0, fontFamily: AppTheme.fontDisplay, letterSpacing: 1.0), maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Stat Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        ValorantAbilitySlot(hotkey: "Q", label: "TIME", value: formattedTime, icon: MdiIcons.clockFast, isActive: isRunning),
                        const SizedBox(width: 16),
                        ValorantAbilitySlot(hotkey: "E", label: "STEPS", value: "$completedCheckpoints/$totalCheckpoints", icon: MdiIcons.formatListChecks, isActive: completedCheckpoints > 0 && completedCheckpoints == totalCheckpoints),
                        const SizedBox(width: 16),
                        ValorantAbilitySlot(hotkey: "X", label: "STATUS", value: liveSubTask.completed ? "DONE" : "ACTIVE", icon: liveSubTask.completed ? MdiIcons.checkAll : MdiIcons.target, isActive: liveSubTask.completed, onTap: () => provider.completeSubtask(widget.parentTask.id, liveSubTask.id)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),

                  // Timer & Tasks
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: isRunning ? [AppTheme.fhAccentRed.withOpacity(0.2), Colors.transparent] : [Colors.white.withOpacity(0.05), Colors.transparent], begin: Alignment.bottomLeft, end: Alignment.topRight),
                      border: Border(left: BorderSide(color: isRunning ? AppTheme.fhAccentRed : AppTheme.fhTextSecondary, width: 2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isRunning ? "SESSION ACTIVE" : "READY TO DEPLOY", style: TextStyle(color: isRunning ? AppTheme.fhAccentRed : AppTheme.fhTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 10)),
                            const SizedBox(height: 4),
                            Text(formattedTime, style: const TextStyle(color: Colors.white, fontSize: 32, fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        FloatingActionButton.small(
                          backgroundColor: isRunning ? AppTheme.fhAccentRed : AppTheme.fhAccentTealFixed,
                          foregroundColor: Colors.black,
                          onPressed: () {
                            if (isRunning) { provider.pauseTimer(liveSubTask.id); provider.logTimerAndReset(liveSubTask.id); }
                            else { provider.startTimer(liveSubTask.id, 'subtask', widget.parentTask.id); }
                          },
                          child: Icon(isRunning ? MdiIcons.pause : MdiIcons.play),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("TACTICAL OBJECTIVES", style: TextStyle(color: AppTheme.fhTextSecondary.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        ...liveSubTask.subSubTasks.map((sss) => ValorantListItem(title: sss.name, isCompleted: sss.completed, onToggle: () => provider.completeSubSubtask(widget.parentTask.id, liveSubTask.id, sss.id), onDelete: () => provider.deleteSubSubtask(widget.parentTask.id, liveSubTask.id, sss.id))),
                        
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1)))),
                          child: TextField(
                            controller: _checkpointController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(hintText: "+ ADD OBJECTIVE", hintStyle: TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 1.0), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12)),
                            onSubmitted: (_) => _handleAddCheckpoint(provider),
                          ),
                        ),

                        // Timeline View
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("DEPLOYMENT LOG", style: TextStyle(color: AppTheme.fhTextSecondary.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5)),
                            IconButton(icon: const Icon(Icons.add, size: 20, color: Colors.white54), onPressed: () => _showAddSessionDialog(context, provider), tooltip: "Log Manual Session"),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          color: Colors.black.withOpacity(0.2),
                          child: ScheduleTimeline(
                            entries: _buildTimelineEntries(provider, liveSubTask.id),
                            onAddSession: () => _showAddSessionDialog(context, provider),
                            onEditEntry: (entry) {
                              if (entry.originalObject is TaskSession) {
                                showDialog(context: context, builder: (ctx) => SessionEditDialog(initialStart: entry.startTime, initialEnd: entry.endTime)).then((result) {
                                  if (result != null) {
                                    if (result['action'] == 'delete') provider.deleteSessionFromSubtask(widget.parentTask.id, liveSubTask.id, (entry.originalObject as TaskSession).id);
                                    else if (result['action'] == 'save') provider.updateSessionInSubtask(widget.parentTask.id, liveSubTask.id, (entry.originalObject as TaskSession).id, result['start'], result['end']);
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}