import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/atoms/valorant_timer_text.dart';
import 'package:missions/src/utils/helpers.dart';

class DesktopFloatingTimer extends StatefulWidget {
  final VoidCallback onClose;

  const DesktopFloatingTimer({super.key, required this.onClose});

  @override
  State<DesktopFloatingTimer> createState() => _DesktopFloatingTimerState();
}

class _DesktopFloatingTimerState extends State<DesktopFloatingTimer> {
  Offset _position = const Offset(80, 80);
  bool _isMinimized = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final runningEntry = provider.activeTimers.entries
        .firstWhereOrNull((e) => e.value.isRunning && e.value.type == 'subtask');

    MainTask? activeMain;
    SubTask? activeSub;
    SubSubTask? activeCp;
    bool isRunning = false;

    if (runningEntry != null) {
      activeMain = provider.mainTasks.firstWhereOrNull((t) => t.id == runningEntry.value.mainTaskId && !t.isDeleted);
      activeSub = activeMain?.subTasks.firstWhereOrNull((s) => s.id == runningEntry.key && !s.isDeleted);
      isRunning = true;
    } else {
      final today = getTodayDateString();
      final plan = provider.taskActions.getDayPlan(today);
      if (plan.isNotEmpty) {
        final parts = plan.first.split('|');
        if (parts.length >= 2) {
          activeMain = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
          activeSub = activeMain?.subTasks.firstWhereOrNull((s) => s.id == parts[1] && !s.isDeleted);
          if (parts.length == 3 && activeSub != null) {
            activeCp = activeSub.findCheckpoint(parts[2]);
          }
        }
      }
      activeMain ??= provider.getSelectedTask();
      if (activeMain != null && activeMain.subTasks.isNotEmpty) {
        activeSub ??= activeMain.subTasks.firstWhereOrNull((s) => !s.completed && !s.isDeleted);
      }
    }

    final accent = activeMain?.taskColor ?? JweTheme.accentCyan;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        child: Material(
          color: Colors.transparent,
          elevation: 12,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isMinimized ? 250 : 340,
            decoration: BoxDecoration(
              color: AppTheme.fhBgDark.withValues(alpha: 0.95),
              border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.3))),
                  ),
                  child: Row(
                    children: [
                      Icon(MdiIcons.drag, size: 14, color: JweTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'FOCUS CLOCK',
                        style: GoogleFonts.rajdhani(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(_isMinimized ? MdiIcons.windowMaximize : MdiIcons.windowMinimize, size: 14, color: JweTheme.textMid),
                        onPressed: () => setState(() => _isMinimized = !_isMinimized),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(MdiIcons.close, size: 14, color: AppTheme.fhAccentRed),
                        onPressed: widget.onClose,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                if (_isMinimized) ...[
                  // Mini Bar Mode
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeSub?.name ?? activeMain?.name ?? 'No Active Task',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.chakraPetch(
                                  color: JweTheme.textWhite,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (activeSub != null)
                                ValorantTimerText(
                                  isRunning: isRunning,
                                  startTime: runningEntry?.value.startTime,
                                  accumulatedTime: activeSub.currentTimeSpent.toDouble(),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: isRunning ? accent : JweTheme.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (activeSub != null && activeMain != null)
                          IconButton(
                            icon: Icon(isRunning ? MdiIcons.pause : MdiIcons.play, color: accent, size: 18),
                            onPressed: () {
                              if (isRunning) {
                                provider.timerActions.pauseTimer(activeSub!.id);
                                provider.timerActions.logTimerAndReset(activeSub.id);
                              } else {
                                provider.timerActions.startTimer(activeSub!.id, 'subtask', activeMain!.id);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Full Focus Clock Widget Mode
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (activeMain != null)
                          Text(
                            activeMain.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.rajdhani(
                              color: accent.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          activeSub?.name ?? 'No Active Task',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.chakraPetch(
                            color: JweTheme.textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (activeCp != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(MdiIcons.chevronRight, size: 14, color: accent),
                              Expanded(
                                child: Text(
                                  activeCp.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textMid,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Large Digital Timer Readout
                        Center(
                          child: activeSub != null
                              ? ValorantTimerText(
                                  isRunning: isRunning,
                                  startTime: runningEntry?.value.startTime,
                                  accumulatedTime: activeSub.currentTimeSpent.toDouble(),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: isRunning ? accent : JweTheme.textWhite,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                  ),
                                )
                              : Text(
                                  '00:00:00',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textMuted,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 14),

                        // Interactive Control Buttons
                        if (activeSub != null && activeMain != null)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: Icon(isRunning ? MdiIcons.pause : MdiIcons.play, size: 16),
                                  label: Text(isRunning ? 'HALT' : 'ENGAGE'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isRunning ? accent.withValues(alpha: 0.3) : accent,
                                    foregroundColor: isRunning ? accent : JweTheme.onAccent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: () {
                                    if (isRunning) {
                                      provider.timerActions.pauseTimer(activeSub!.id);
                                      provider.timerActions.logTimerAndReset(activeSub.id);
                                    } else {
                                      provider.timerActions.startTimer(activeSub!.id, 'subtask', activeMain!.id);
                                    }
                                  },
                                ),
                              ),
                              if (activeCp != null) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.check, size: 14),
                                  label: const Text('CHECK NEXT'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: accent,
                                    side: BorderSide(color: accent.withValues(alpha: 0.5)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                  ),
                                  onPressed: () {
                                    provider.taskActions.completeSubSubtask(
                                      activeMain!.id,
                                      activeSub!.id,
                                      activeCp!.id,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
