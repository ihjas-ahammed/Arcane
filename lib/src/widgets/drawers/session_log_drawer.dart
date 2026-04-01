import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class SessionLogDrawer extends StatelessWidget {
  final MainTask parentTask;
  final SubTask subTask;

  const SessionLogDrawer({
    super.key,
    required this.parentTask,
    required this.subTask,
  });

  void _handleSessionEdit(
      BuildContext context, AppProvider provider, TaskSession session) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SessionEditDialog(
          initialStart: session.startTime, initialEnd: session.endTime),
    );
    if (result != null) {
      if (result['action'] == 'delete') {
        provider.deleteSessionFromSubtask(
            parentTask.id, subTask.id, session.id);
      } else if (result['action'] == 'save') {
        provider.updateSessionInSubtask(parentTask.id, subTask.id, session.id,
            result['start'], result['end']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    MainTask? liveParentTask;
    SubTask? liveSubTask;
    try {
      liveParentTask =
          provider.mainTasks.firstWhere((t) => t.id == parentTask.id);
      liveSubTask =
          liveParentTask.subTasks.firstWhere((s) => s.id == subTask.id);
    } catch (e) {
      return const SizedBox.shrink();
    }

    final sessions = List<TaskSession>.from(liveSubTask.sessions)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return Drawer(
      backgroundColor: AppTheme.fhBgDeepDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: AppTheme.fhBgDark,
              border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SESSION LOGS",
                  style: TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  liveSubTask.name.toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
                        Text(
                          "NO SESSIONS RECORDED",
                          style: TextStyle(
                            color: Colors.white24,
                            fontFamily: AppTheme.fontDisplay,
                            letterSpacing: 1.5,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final duration =
                          session.endTime.difference(session.startTime);
                      final dateStr =
                          DateFormat('MMM dd, yyyy').format(session.startTime);
                      final timeRangeStr =
                          "${DateFormat('h:mm a').format(session.startTime)} - ${DateFormat('h:mm a').format(session.endTime)}";

                      return Dismissible(
                        key: ValueKey(session.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppTheme.fhAccentRed,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor: AppTheme.fhBgDark,
                                title: const Text(
                                  "Confirm Delete",
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: const Text(
                                  "Are you sure you want to delete this session log?",
                                  style: TextStyle(
                                      color: AppTheme.fhTextSecondary),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text("CANCEL",
                                        style: TextStyle(
                                            color: AppTheme.fhTextSecondary)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text("DELETE",
                                        style: TextStyle(
                                            color: AppTheme.fhAccentRed)),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) {
                          provider.deleteSessionFromSubtask(
                              liveParentTask!.id, liveSubTask!.id, session.id);
                        },
                        child: InkWell(
                          onTap: () =>
                              _handleSessionEdit(context, provider, session),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: Colors.white.withOpacity(0.05))),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: liveParentTask!.taskColor
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dateStr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        timeRangeStr,
                                        style: TextStyle(
                                          color: AppTheme.fhTextSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      helper.formatTime(
                                          duration.inSeconds.toDouble()),
                                      style: TextStyle(
                                        fontFamily: "RobotoMono",
                                        color: AppTheme.fhAccentTealFixed,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Icon(MdiIcons.pencil,
                                        size: 14, color: Colors.white24),
                                  ],
                                ),
                              ],
                            ),
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
