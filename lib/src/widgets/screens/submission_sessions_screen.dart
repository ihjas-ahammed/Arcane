import 'package:flutter/material.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/dialogs/session_edit_dialog.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

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

    MainTask? liveParentTask;
    SubTask? liveSubTask;
    try {
      liveParentTask = provider.mainTasks.firstWhere((t) => t.id == parentTask.id);
      liveSubTask = liveParentTask.subTasks.firstWhere((s) => s.id == subTask.id);
    } catch (e) {
      return const Scaffold(backgroundColor: JweTheme.bgDeep, body: SizedBox());
    }

    final sessions = List<TaskSession>.from(liveSubTask.sessions)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    final color = liveParentTask.taskColor;
    final totalSeconds = sessions.fold<int>(
        0, (sum, s) => sum + s.endTime.difference(s.startTime).inSeconds);

    return Scaffold(
      backgroundColor: JweTheme.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: JweTheme.panel,
                border: Border(bottom: BorderSide(color: JweTheme.line)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(color: JweTheme.border),
                        color: JweTheme.bgBase,
                      ),
                      child: const Icon(Icons.arrow_back, color: JweTheme.textMid, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          liveParentTask.name.toUpperCase(),
                          style: TextStyle(
                              color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            liveSubTask.name.toUpperCase(),
                            style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                letterSpacing: 1.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: JweTheme.lineAmber),
                      color: JweTheme.amberSoft,
                    ),
                    child: Text(
                      "SESSION ARCHIVES",
                      style: GoogleFonts.rajdhani(
                          color: JweTheme.accentAmber,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            // ── Stats bar ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: JweTheme.bgBase,
              child: Row(
                children: [
                  _StatChip(label: "SESSIONS", value: "${sessions.length}", color: color),
                  const SizedBox(width: 12),
                  _StatChip(
                    label: "TOTAL TIME",
                    value: helper.formatTime(totalSeconds.toDouble()),
                    color: JweTheme.accentCyan,
                    mono: true,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(border: Border.all(color: JweTheme.border)),
                    child: const Text("SORTED BY DATE",
                        style: TextStyle(
                            color: JweTheme.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0)),
                  ),
                ],
              ),
            ),

            // ── Session list ─────────────────────────────────────────
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MdiIcons.history, size: 52, color: JweTheme.textMuted.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            "NO SESSIONS RECORDED",
                            style: GoogleFonts.rajdhani(
                                color: JweTheme.textMuted,
                                letterSpacing: 2.0,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Start a timer on the detail screen to log sessions",
                            style: TextStyle(color: JweTheme.textMuted, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final duration = session.endTime.difference(session.startTime);
                        final dateStr = DateFormat('EEE, MMM dd').format(session.startTime);
                        final yearStr = DateFormat('yyyy').format(session.startTime);
                        final timeRangeStr =
                            "${DateFormat('HH:mm').format(session.startTime)} — ${DateFormat('HH:mm').format(session.endTime)}";

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: JweTheme.panel,
                            border: Border(left: BorderSide(color: color, width: 3)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            dateStr.toUpperCase(),
                                            style: GoogleFonts.chakraPetch(
                                                color: JweTheme.textWhite,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(yearStr,
                                              style: const TextStyle(
                                                  color: JweTheme.textMuted, fontSize: 11)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        timeRangeStr,
                                        style: GoogleFonts.jetBrainsMono(
                                            color: JweTheme.textMid, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        border: Border.all(color: color.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        helper.formatTime(duration.inSeconds.toDouble()),
                                        style: GoogleFonts.jetBrainsMono(
                                            color: color, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => _handleSessionEdit(context, provider, session),
                                      child: Row(
                                        children: [
                                          Icon(MdiIcons.pencilOutline, size: 12, color: JweTheme.textMuted),
                                          const SizedBox(width: 3),
                                          const Text("EDIT",
                                              style: TextStyle(
                                                  color: JweTheme.textMuted,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.0)),
                                        ],
                                      ),
                                    ),
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
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool mono;

  const _StatChip({required this.label, required this.value, required this.color, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 2),
          mono
              ? Text(value,
                  style: GoogleFonts.jetBrainsMono(
                      color: color, fontWeight: FontWeight.bold, fontSize: 15))
              : Text(value,
                  style: GoogleFonts.rajdhani(
                      color: color, fontWeight: FontWeight.bold, fontSize: 20)),
        ],
      ),
    );
  }
}
