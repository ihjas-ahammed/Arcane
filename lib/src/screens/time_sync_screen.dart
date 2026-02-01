import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/time_sync_models.dart';
import 'package:arcane/src/widgets/ui/time_sync_block_card.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/valorant/valorant_text_field.dart';
import 'package:arcane/src/widgets/common/growing_text_field.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';

class TimeSyncScreen extends StatefulWidget {
  const TimeSyncScreen({super.key});

  @override
  State<TimeSyncScreen> createState() => _TimeSyncScreenState();
}

class _TimeSyncScreenState extends State<TimeSyncScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _generateSchedule(AppProvider provider, {bool smartAppend = false}) {
    // If no input, provide a generic prompt for update
    String prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      if (smartAppend) {
        prompt =
            "Update remaining schedule based on time passed. Keep it productive.";
      } else {
        // Require input for fresh start usually, but let's allow a "default day" gen
        prompt = "Plan a standard productive day.";
      }
    }

    // Add submission info context manually if desired, or assume AI has access to it via memory if implemented.
    // For now, let's append active sub-missions names to prompt for context.
    final activeMissions = provider.mainTasks
        .expand((t) => t.subTasks)
        .where((s) => !s.completed)
        .map((s) => s.name)
        .take(3)
        .join(", ");
    if (activeMissions.isNotEmpty) {
      prompt += "\nCurrent Priorities: $activeMissions";
    }

    FocusScope.of(context).unfocus();
    provider.generateTimeSync(prompt, smartAppend: smartAppend);
  }

  void _editBlock(
      BuildContext context, AppProvider provider, TimeSyncBlock block) {
    // ... [Edit Block logic same as before] ...
    final titleCtrl = TextEditingController(text: block.title);
    final descCtrl = TextEditingController(text: block.description);
    TimeOfDay startTime = TimeOfDay.fromDateTime(block.startTime);
    TimeOfDay endTime = TimeOfDay.fromDateTime(block.endTime);

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setState) {
              return AlertDialog(
                backgroundColor: AppTheme.fhBgMedium,
                title: const Text("EDIT BLOCK",
                    style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        color: AppTheme.fhTextPrimary)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "TITLE"),
                      ),
                      const SizedBox(height: 12),
                      const Text("DESCRIPTION",
                          style: TextStyle(
                              color: AppTheme.fhTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      GrowingTextField(
                          controller: descCtrl,
                          hint: "Details...",
                          minLines: 2),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                  builder: (context, child) => Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                          primary: AppTheme.fhAccentTeal,
                                          onPrimary: Colors.black,
                                          surface: AppTheme.fhBgDeepDark,
                                          onSurface: Colors.white),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null)
                                  setState(() => startTime = picked);
                              },
                              child: InputDecorator(
                                decoration:
                                    const InputDecoration(labelText: 'START'),
                                child: Text(startTime.format(context),
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                  builder: (context, child) => Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                          primary: AppTheme.fhAccentTeal,
                                          onPrimary: Colors.black,
                                          surface: AppTheme.fhBgDeepDark,
                                          onSurface: Colors.white),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null)
                                  setState(() => endTime = picked);
                              },
                              child: InputDecorator(
                                decoration:
                                    const InputDecoration(labelText: 'END'),
                                child: Text(endTime.format(context),
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      provider.deleteTimeSyncBlock(block.id);
                      Navigator.pop(ctx);
                    },
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.fhAccentRed),
                    child: const Text("DELETE"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final s = block.startTime;
                      final e = block.endTime;
                      final newStart = DateTime(s.year, s.month, s.day,
                          startTime.hour, startTime.minute);
                      DateTime newEnd = DateTime(
                          e.year, e.month, e.day, endTime.hour, endTime.minute);
                      if (newEnd.isBefore(newStart)) {
                        if (e.day != s.day) {
                          newEnd = DateTime(e.year, e.month, e.day,
                              endTime.hour, endTime.minute);
                        } else {
                          newEnd = newEnd.add(const Duration(days: 1));
                        }
                      }
                      final updated = TimeSyncBlock(
                        id: block.id,
                        startTime: newStart,
                        endTime: newEnd,
                        title: titleCtrl.text,
                        description: descCtrl.text,
                        type: block.type,
                      );
                      provider.updateTimeSyncBlock(updated);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.fhAccentTeal),
                    child: const Text("SAVE"),
                  )
                ],
              );
            }));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final schedule = provider.timeSyncSchedule;
    final isLoading = provider.loadingTaskName == "Synchronizing Chrono...";

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: AppTheme.fhBorderColor.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppTheme.fhTextPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "CHRONO SYNC",
                          style: TextStyle(
                              fontFamily: AppTheme.fontDisplay,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: AppTheme.fhTextPrimary),
                        ),
                        Text(
                          "24H PREDICTIVE SCHEDULING",
                          style: TextStyle(
                              color: AppTheme.fhAccentTeal,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0),
                        ),
                      ],
                    ),
                  ),
                  if (schedule.isNotEmpty)
                    IconButton(
                      icon: Icon(MdiIcons.refresh,
                          color: AppTheme.fhTextSecondary),
                      onPressed: () {
                        _scrollController.animateTo(0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut);
                      },
                    )
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  // Input Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.fhBgDark.withValues(alpha: 0.5),
                      border: Border.all(
                          color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("SYNC PARAMETERS",
                            style: TextStyle(
                                color: AppTheme.fhTextSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ValorantTextField(
                          controller: _promptController,
                          label: "INTENT / FOCUS",
                          hint: "Optional. e.g. 'Heavy study session'",
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ValorantButton(
                                label: isLoading
                                    ? "..."
                                    : (schedule.isEmpty ? "INIT" : "RESET ALL"),
                                isPrimary:
                                    schedule.isEmpty, // Highlight if init
                                onPressed: isLoading
                                    ? null
                                    : () => _generateSchedule(provider,
                                        smartAppend: false),
                              ),
                            ),
                            if (schedule.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: ValorantButton(
                                  label: "UPDATE",
                                  isPrimary: true,
                                  color: AppTheme.fhAccentPurple,
                                  onPressed: isLoading
                                      ? null
                                      : () => _generateSchedule(provider,
                                          smartAppend: true),
                                ),
                              ),
                            ]
                          ],
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (isLoading)
                    const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.fhAccentTeal))
                  else if (schedule.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(MdiIcons.timelineClockOutline,
                              size: 64,
                              color: AppTheme.fhTextDisabled
                                  .withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          const Text("NO ACTIVE SCHEDULE",
                              style: TextStyle(
                                  color: AppTheme.fhTextDisabled,
                                  letterSpacing: 1.5)),
                        ],
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Icon(MdiIcons.clockStart,
                            color: AppTheme.fhAccentTeal, size: 16),
                        const SizedBox(width: 8),
                        Text(
                            "TIMELINE: ${DateFormat('MMM dd').format(DateTime.now()).toUpperCase()}",
                            style: const TextStyle(
                                color: AppTheme.fhTextPrimary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        Positioned(
                          left: 27,
                          top: 0,
                          bottom: 0,
                          child: Container(
                              width: 2,
                              color: AppTheme.fhBorderColor
                                  .withValues(alpha: 0.3)),
                        ),
                        Column(
                          children: schedule.map((block) {
                            return TimeSyncBlockCard(
                              block: block,
                              onTap: () => _editBlock(context, provider, block),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Center(
                        child: Text("END OF PREDICTION",
                            style: TextStyle(
                                color: AppTheme.fhTextDisabled,
                                fontSize: 10,
                                letterSpacing: 2.0))),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
