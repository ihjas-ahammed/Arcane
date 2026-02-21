import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/schedule/schedule_timeline.dart';
import 'package:arcane/src/widgets/schedule/protocol_control_panel.dart';
import 'package:arcane/src/widgets/schedule/schedule_hero_widget.dart';
import 'package:arcane/src/widgets/dialogs/add_session_dialog.dart';
import 'package:arcane/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:arcane/src/models/timeline_models.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/utils/time_validation_helper.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:collection/collection.dart';

class ScheduleView extends StatefulWidget {
  const ScheduleView({super.key});

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  DateTime _selectedDate = DateTime.now();
  List<TimelineEntry> _predictedEntries = [];
  bool _isPredicting = false;

  // --- Date Control ---
  void _shiftDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      // Clear predictions on date change to avoid confusion (or keep if specific logic)
      _predictedEntries.clear(); 
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.fhAccentTeal,
            onPrimary: Colors.black,
            surface: AppTheme.fhBgDark,
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: AppTheme.fhBgDeepDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _predictedEntries.clear();
      });
    }
  }

  // --- Hero Data ---
  Map<String, dynamic> _getHeroStats(AppProvider provider) {
    // 1. Latest Task
    String latest = "NONE";
    DateTime? lastTime;
    
    // 2. Most Spent Today
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dayData = provider.completedByDay[todayStr];
    String mostName = "NONE";
    int mostSeconds = 0;

    // Check sessions for latest
    for(var t in provider.mainTasks) {
      for(var s in t.subTasks) {
        for(var sess in s.sessions) {
          if (lastTime == null || sess.endTime.isAfter(lastTime)) {
            lastTime = sess.endTime;
            latest = s.name;
          }
        }
      }
    }

    if (dayData != null && dayData['taskTimes'] != null) {
      final times = dayData['taskTimes'] as Map<String, dynamic>;
      times.forEach((tid, secs) {
        final t = provider.mainTasks.firstWhereOrNull((mt) => mt.id == tid);
        if (t != null && (secs as int) > mostSeconds) {
          mostSeconds = secs;
          mostName = t.name;
        }
      });
    }

    return {
      'latest': latest,
      'mostName': mostName,
      'mostTime': mostSeconds,
    };
  }

  // --- Prediction ---
  Future<void> _handlePredictSchedule(BuildContext context, AppProvider provider) async {
    // Only predict for today
    if (!_isSameDay(_selectedDate, DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Predictions only available for today.")));
      return;
    }

    setState(() => _isPredicting = true);

    try {
      final newEntries = await provider.scheduleActions.predictSchedule();
      
      setState(() {
        _predictedEntries = newEntries;
      });

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Prediction failed: $e")));
    } finally {
      if (mounted) setState(() => _isPredicting = false);
    }
  }

  // --- Entries Merging ---
  List<TimelineEntry> _buildEntries(AppProvider provider) {
    final List<TimelineEntry> entries = [];
    final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // 1. Real Sessions
    for (var task in provider.mainTasks) {
      for (var sub in task.subTasks) {
        for (var session in sub.sessions) {
          if (session.startTime.isBefore(dayEnd) && session.endTime.isAfter(dayStart)) {
            DateTime displayStart = session.startTime.isBefore(dayStart) ? dayStart : session.startTime;
            DateTime displayEnd = session.endTime.isAfter(dayEnd) ? dayEnd : session.endTime;

            entries.add(TimelineEntry(
              id: session.id,
              startTime: displayStart,
              endTime: displayEnd,
              title: sub.name,
              subtitle: task.name,
              color: task.taskColor,
              isEditable: true,
              originalObject: session,
            ));
          }
        }
      }
    }

    // 2. Predicted Sessions (Filter overlaps)
    for (var pred in _predictedEntries) {
      // Check for overlap with REAL sessions
      bool overlaps = false;
      for (var real in entries) {
        if (pred.startTime.isBefore(real.endTime) && pred.endTime.isAfter(real.startTime)) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) {
        entries.add(pred);
      }
    }

    return entries;
  }

  // --- Handlers ---
  void _openProtocolControl(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ProtocolControlPanel(
          protocols: provider.mainTasks,
          selectedProtocolId: provider.selectedTaskId,
          onSelect: (id) => provider.setSelectedTaskId(id),
          onAdd: () => _showAddProtocolDialog(context, provider),
          onEdit: (updatedTask) {
            provider.editMainTask(
              updatedTask.id,
              name: updatedTask.name,
              description: updatedTask.description,
              theme: updatedTask.theme,
              colorHex: updatedTask.colorHex,
            );
          },
        ),
      ),
    );
  }

  void _showAddProtocolDialog(BuildContext context, AppProvider provider) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgMedium,
        title: const Text("NEW PROTOCOL"),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: "NAME"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                provider.addMainTask(
                  name: nameCtrl.text,
                  description: "New Protocol",
                  theme: "general",
                  colorHex: "FF00F8F8" 
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text("CREATE"),
          )
        ],
      )
    );
  }

  void _handleAddSession(BuildContext context, AppProvider provider) async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (ctx) => const AddSessionDialog(),
    );

    if (result != null && mounted) {
      final start = result['start']!;
      final end = result['end']!;
      _showTaskSelectorAndAdd(context, provider, start, end);
    }
  }

  void _showTaskSelectorAndAdd(BuildContext context, AppProvider provider, DateTime start, DateTime end) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.fhBgMedium,
          title: const Text("SELECT MISSION"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: provider.mainTasks.length,
              itemBuilder: (context, index) {
                final task = provider.mainTasks[index];
                // Filter incomplete subtasks
                final activeSubtasks = task.subTasks.where((s) => !s.completed).toList();
                
                if (activeSubtasks.isEmpty) return const SizedBox.shrink();

                return ExpansionTile(
                  title: Text(task.name, style: TextStyle(color: task.taskColor, fontWeight: FontWeight.bold)),
                  children: activeSubtasks.map((sub) {
                    return ListTile(
                      title: Text(sub.name, style: const TextStyle(color: AppTheme.fhTextPrimary)),
                      onTap: () {
                        provider.addSessionToSubtask(task.id, sub.id, start, end);
                        Navigator.pop(ctx);
                        // On successful add, check overlaps with predictions (auto-handled by rebuild)
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        );
      }
    );
  }

  void _handleEditEntry(BuildContext context, AppProvider provider, TimelineEntry entry) async {
    if (entry.isPredicted) {
      // Handle predicted entry tap (Convert or Delete)
      _handlePredictedEntryTap(context, provider, entry);
      return;
    }

    if (entry.originalObject is! TaskSession) return;
    final session = entry.originalObject as TaskSession;
    
    // ... (Existing edit logic)
    String? mainTaskId;
    String? subTaskId;
    
    for (var m in provider.mainTasks) {
      for (var s in m.subTasks) {
        if (s.sessions.any((sess) => sess.id == session.id)) {
          mainTaskId = m.id;
          subTaskId = s.id;
          break;
        }
      }
      if (mainTaskId != null) break;
    }

    if (mainTaskId == null || subTaskId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SessionEditDialog(
        initialStart: session.startTime,
        initialEnd: session.endTime,
      ),
    );

    if (result != null) {
      if (result['action'] == 'delete') {
        provider.deleteSessionFromSubtask(mainTaskId, subTaskId, session.id);
      } else if (result['action'] == 'save') {
        provider.updateSessionInSubtask(mainTaskId, subTaskId, session.id, result['start'], result['end']);
      }
    }
  }

  void _handlePredictedEntryTap(BuildContext context, AppProvider provider, TimelineEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.title),
        content: const Text("This is a predicted session. Would you like to confirm it (log it) or remove it?"),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _predictedEntries.removeWhere((e) => e.id == entry.id);
              });
              Navigator.pop(ctx);
            }, 
            child: const Text("REMOVE", style: TextStyle(color: AppTheme.fhAccentRed))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Trigger Add Session flow pre-filled
              _showTaskSelectorAndAdd(context, provider, entry.startTime, entry.endTime);
            }, 
            child: const Text("LOG REAL SESSION")
          )
        ],
      )
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final entries = _buildEntries(provider);
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final heroStats = _getHeroStats(provider);

    return Column(
      children: [
        // HERO SECTION
        ScheduleHeroWidget(
          latestTaskName: heroStats['latest'],
          mostSpentTaskName: heroStats['mostName'],
          mostSpentTimeSeconds: heroStats['mostTime'],
        ),

        // CONTROLS
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark,
            border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppTheme.fhTextSecondary),
                    onPressed: () => _shiftDate(-1),
                  ),
                  InkWell(
                    onTap: () => _pickDate(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isToday ? "TODAY" : DateFormat('EEEE').format(_selectedDate).toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.fhAccentTeal,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd').format(_selectedDate).toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.fhTextPrimary,
                            fontFamily: AppTheme.fontDisplay,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppTheme.fhTextSecondary),
                    onPressed: () => _shiftDate(1),
                  ),
                ],
              ),
              Row(
                children: [
                  if (isToday)
                    IconButton(
                      icon: _isPredicting 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fhAccentPurple))
                        : Icon(MdiIcons.crystalBall, color: AppTheme.fhAccentPurple),
                      tooltip: "PREDICT SCHEDULE",
                      onPressed: _isPredicting ? null : () => _handlePredictSchedule(context, provider),
                    ),
                  IconButton(
                    icon: Icon(MdiIcons.console, color: AppTheme.fhAccentRed),
                    tooltip: "PROTOCOL CONTROL",
                    onPressed: () => _openProtocolControl(context, provider),
                  ),
                ],
              )
            ],
          ),
        ),

        Expanded(
          child: Stack(
            children: [
              ScheduleTimeline(
                entries: entries,
                onAddSession: () => _handleAddSession(context, provider),
                onEditEntry: (entry) => _handleEditEntry(context, provider, entry),
                initialScrollOffset: 0,
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: FloatingActionButton(
                  backgroundColor: AppTheme.fhAccentRed,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.add),
                  onPressed: () => _handleAddSession(context, provider),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}