import 'package:flutter/material.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:missions/src/widgets/valorant/valorant_card.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SubmissionSessionsScreen extends StatelessWidget {
  final MainTask parentTask;
  final SubTask subTask;

  const SubmissionSessionsScreen({
    super.key,
    required this.parentTask,
    required this.subTask,
  });

  void _handleSessionEdit(BuildContext context, AppProvider provider, TaskSession session) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SessionEditDialog(initialStart: session.startTime, initialEnd: session.endTime),
    );
    if (result != null) {
      if (result['action'] == 'delete') {
        provider.deleteSessionFromSubtask(parentTask.id, subTask.id, session.id);
      } else if (result['action'] == 'save') {
        provider.updateSessionInSubtask(parentTask.id, subTask.id, session.id, result['start'], result['end']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Live refetch
    MainTask? liveParentTask;
    SubTask? liveSubTask;
    try {
      liveParentTask = provider.mainTasks.firstWhere((t) => t.id == parentTask.id);
      liveSubTask = liveParentTask.subTasks.firstWhere((s) => s.id == subTask.id);
    } catch (e) {
      return const Scaffold(backgroundColor: AppTheme.fhBgDeepDark, body: SizedBox());
    }

    final sessions = List<TaskSession>.from(liveSubTask.sessions)..sort((a, b) => b.startTime.compareTo(a.startTime));
    final color = liveParentTask.taskColor;

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("SESSION ARCHIVES", style: TextStyle(fontFamily: AppTheme.fontDisplay, letterSpacing: 2.0)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3)))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(liveParentTask.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                Text(liveSubTask.name.toUpperCase(), style: const TextStyle(color: AppTheme.fhTextPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.history, size: 48, color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text("NO SESSIONS RECORDED", style: TextStyle(color: Colors.white24, fontFamily: AppTheme.fontDisplay, letterSpacing: 1.5, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final duration = session.endTime.difference(session.startTime);
                      final dateStr = DateFormat('MMM dd, yyyy').format(session.startTime);
                      final timeRangeStr = "${DateFormat('HH:mm').format(session.startTime)} - ${DateFormat('HH:mm').format(session.endTime)}";

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ValorantCard(
                          padding: const EdgeInsets.all(12),
                          borderColor: AppTheme.fhBorderColor.withOpacity(0.3),
                          child: Row(
                            children: [
                              Container(width: 4, height: 40, color: color.withOpacity(0.5)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(dateStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(timeRangeStr, style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontFamily: 'RobotoMono')),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    helper.formatTime(duration.inSeconds.toDouble()),
                                    style: TextStyle(fontFamily: "RobotoMono", color: color, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => _handleSessionEdit(context, provider, session),
                                    child: Icon(MdiIcons.pencilOutline, size: 16, color: AppTheme.fhTextSecondary),
                                  )
                                ],
                              ),
                            ],
                          ),
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