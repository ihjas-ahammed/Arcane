import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:missions/src/models/health_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/widget_action_router.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/task_calculations.dart';

/// Protocol that holds daily routines; its tasks are not offered as workout time sources.
const String _routineProtocolId = 'build_routine';

void showActivityDialog(BuildContext context, AppProvider provider, String dateStr) {
  final distanceController = TextEditingController(text: "0.0");
  final workoutController = TextEditingController(text: "0");
  String? linkedTaskName;

  // Every selectable task (subtask) of every protocol except Routine. Tasks with time tracked
  // that day come first. Inactive, deleted and archived tasks are hidden.
  final target = DateTime.tryParse(dateStr) ?? DateTime.now();
  final linkableTasks = <(String, String, int)>[
    for (final m in provider.mainTasks)
      if (m.isPickable && m.id != _routineProtocolId)
        for (final sub in m.subTasks)
          if (sub.isPickable)
            (
              '${m.id}|${sub.id}',
              '${m.name} › ${sub.name}',
              TaskCalculations.getSubtaskSecondsForDay(sub, target, provider.mainTasks) ~/ 60,
            ),
  ]..sort((a, b) => (b.$3 > 0 ? 1 : 0).compareTo(a.$3 > 0 ? 1 : 0));

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: JweTheme.panel,
        scrollable: true,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: JweTheme.accentTeal, width: 2),
          borderRadius: BorderRadius.zero,
        ),
        title: Text(
          'LOG PHYSICAL ACTIVITY',
          style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: distanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'WALK DISTANCE (KM)',
                labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentTeal)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: workoutController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'WORKOUT DURATION (MINUTES)',
                labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentTeal)),
              ),
            ),
            const SizedBox(height: 14),
            if (linkableTasks.isEmpty) ...[
              Text(
                'No tasks available to copy time from.',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9.5, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  WidgetActionRouter.instance.tabRequest.value = 0;
                },
                icon: Icon(MdiIcons.targetAccount, size: 14, color: JweTheme.accentCyan),
                label: Text(
                  'GO TO TASKS TO TRACK TIME',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Icon(MdiIcons.linkVariant, color: JweTheme.accentCyan, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    'COPY TIME FROM WORKOUT TASK',
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: JweTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: linkedTaskName,
                    dropdownColor: JweTheme.panel,
                    hint: Text('Select a task…', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 12)),
                    icon: Icon(MdiIcons.chevronDown, color: JweTheme.textMuted),
                    items: [
                      for (final r in linkableTasks)
                        DropdownMenuItem(
                          value: r.$1,
                          child: Text(
                            '${r.$2}  ·  ${r.$3}m',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      final match = linkableTasks.firstWhereOrNull((r) => r.$1 == id);
                      if (match == null) return;
                      setDialogState(() {
                        linkedTaskName = id;
                        workoutController.text = match.$3.toString();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  WidgetActionRouter.instance.tabRequest.value = 0;
                },
                icon: Icon(MdiIcons.targetAccount, size: 14, color: JweTheme.accentCyan),
                label: Text(
                  'GO TO TASKS TO TRACK TIME',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ABORT', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentTeal,
              foregroundColor: JweTheme.onAccent,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () {
              final dist = double.tryParse(distanceController.text) ?? 0.0;
              final mins = int.tryParse(workoutController.text) ?? 0;
              if (dist > 0 || mins > 0) {
                provider.addActivityLog(
                  dateStr,
                  ActivityLog(
                    id: const Uuid().v4(),
                    walkDistanceKm: dist,
                    workoutMinutes: mins,
                    timestamp: DateTime.now(),
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            child: Text('LOG', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}
