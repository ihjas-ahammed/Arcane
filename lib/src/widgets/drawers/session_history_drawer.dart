import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SessionHistoryDrawer extends StatelessWidget {
  final String mainTaskId;
  final SubTask subTask;

  const SessionHistoryDrawer({
    super.key,
    required this.mainTaskId,
    required this.subTask,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final sessions = subTask.sessions;

    return Drawer(
      width: 320,
      backgroundColor: AppTheme.fhBgDeepDark,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("SESSION LOG", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay)),
                  const SizedBox(height: 4),
                  Text(subTask.name.toUpperCase(), style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Text("NO LOGS FOUND", style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: AppTheme.fontDisplay, fontSize: 18)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final duration = session.endTime.difference(session.startTime);
                        final dateStr = DateFormat('MMM dd').format(session.startTime);
                        final timeStr = "${DateFormat('HH:mm').format(session.startTime)} - ${DateFormat('HH:mm').format(session.endTime)}";

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: ValorantCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(width: 4, height: 40, color: AppTheme.fhAccentTeal),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(dateStr.toUpperCase(), style: const TextStyle(color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold, fontSize: 10)),
                                      Text(timeStr, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: "RobotoMono")),
                                      Text("${duration.inMinutes} MIN", style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(MdiIcons.pencilOutline, size: 18, color: AppTheme.fhTextSecondary),
                                  onPressed: () async {
                                    final result = await showDialog<Map<String, dynamic>>(
                                      context: context,
                                      builder: (ctx) => SessionEditDialog(initialStart: session.startTime, initialEnd: session.endTime),
                                    );
                                    if (result != null) {
                                      if (result['action'] == 'delete') {
                                        provider.deleteSessionFromSubtask(mainTaskId, subTask.id, session.id);
                                      } else if (result['action'] == 'save') {
                                        provider.updateSessionInSubtask(mainTaskId, subTask.id, session.id, result['start'], result['end']);
                                      }
                                    }
                                  },
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}