import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

Future<void> showManualPredictionDialog({
  required BuildContext context,
  required AppProvider provider,
  required DateTime selectedDate,
  required Function(TimelineEntry) onAddPrediction,
}) async {
  final now = DateTime.now();
  final isToday = selectedDate.year == now.year &&
      selectedDate.month == now.month &&
      selectedDate.day == now.day;

  if (!isToday) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Predictions only available for today.")),
    );
    return;
  }

  final activeMainTasks = provider.mainTasks.where((t) => !t.isDeleted && t.isActive).toList();
  MainTask? selectedMainTask = activeMainTasks.isNotEmpty ? activeMainTasks.first : null;
  final activityCtrl = TextEditingController();
  TimeOfDay selectedStartTime = TimeOfDay.now();
  int selectedDurationMinutes = 30;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) {
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          title: Row(
            children: [
              Icon(MdiIcons.crystalBall, color: JweTheme.accentCyan, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'MANUAL PREDICTED EVENT',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELECT TASK / PROTOCOL',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<MainTask>(
                  initialValue: selectedMainTask,
                  dropdownColor: JweTheme.panel,
                  items: activeMainTasks.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name, style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                  )).toList(),
                  onChanged: (val) => setModalState(() => selectedMainTask = val),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: JweTheme.bgCanvas,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'PREDICTED ACTIVITY NAME',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: activityCtrl,
                  style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Focus Session',
                    hintStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: JweTheme.bgCanvas,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'START TIME',
                            style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: selectedStartTime,
                                builder: (context, child) => Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: JweTheme.pickerScheme(accent: JweTheme.accentCyan, surface: JweTheme.panel),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (time != null) setModalState(() => selectedStartTime = time);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: JweTheme.bgCanvas,
                                border: Border.all(color: JweTheme.lineSoft),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                selectedStartTime.format(context),
                                style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DURATION (MINS)',
                            style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: selectedDurationMinutes,
                            dropdownColor: JweTheme.panel,
                            items: const [15, 25, 30, 45, 60, 90, 120].map((d) => DropdownMenuItem(
                              value: d,
                              child: Text('${d}m', style: TextStyle(color: Colors.white, fontSize: 13)),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedDurationMinutes = val);
                            },
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              filled: true,
                              fillColor: JweTheme.bgCanvas,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final title = activityCtrl.text.trim().isNotEmpty
                    ? activityCtrl.text.trim()
                    : (selectedMainTask?.name ?? 'Manual Event');
                final cur = DateTime.now();
                final start = DateTime(cur.year, cur.month, cur.day, selectedStartTime.hour, selectedStartTime.minute);
                final end = start.add(Duration(minutes: selectedDurationMinutes));

                final entry = TimelineEntry(
                  id: "pred_manual_${DateTime.now().millisecondsSinceEpoch}",
                  startTime: start,
                  endTime: end,
                  title: title,
                  subtitle: selectedMainTask?.name ?? 'Manual Prediction',
                  color: selectedMainTask?.taskColor ?? JweTheme.accentCyan,
                  isPredicted: true,
                  isEditable: true,
                );

                onAddPrediction(entry);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manual predicted event added to schedule!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentCyan, foregroundColor: JweTheme.bgBase),
              child: const Text('ADD PREDICTION'),
            ),
          ],
        );
      },
    ),
  );
}
