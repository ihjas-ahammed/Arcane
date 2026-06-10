import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'package:missions/src/widgets/atoms/valorant_timer_text.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:provider/provider.dart';

class AnimatedHudBar extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final Color color;

  const AnimatedHudBar({super.key, required this.progress, required this.color});

  @override
  State<AnimatedHudBar> createState() => _AnimatedHudBarState();
}

class _AnimatedHudBarState extends State<AnimatedHudBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.progress.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final filledWidth = totalWidth * pct;

        return Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0x1AA8B3C7),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              // Filled progress
              if (filledWidth > 0)
                Container(
                  width: filledWidth,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.55),
                        blurRadius: 6,
                      )
                    ],
                  ),
                ),
              // Shining light moving across the filled part
              if (filledWidth > 0)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: pct,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-2.0 + _controller.value * 4.0, 0.0),
                                  end: Alignment(0.0 + _controller.value * 4.0, 0.0),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.05),
                                    Colors.white.withValues(alpha: 0.35),
                                    Colors.white.withValues(alpha: 0.05),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                                ),
                              ),
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
      },
    );
  }
}

class TaskHeaderCard extends StatelessWidget {
  final MainTask task;

  const TaskHeaderCard({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    
    // Resolve live task to get updated phoenixSubTaskId
    MainTask currentTask = task;
    try {
      currentTask = provider.mainTasks.firstWhere((t) => t.id == task.id);
    } catch (_) {}

    final String? phxId = currentTask.phoenixSubTaskId;
    SubTask? phxSub;
    if (phxId != null) {
      phxSub = currentTask.subTasks.firstWhereOrNull((st) => st.id == phxId && !st.completed && !st.isDeleted);
    }

    final accent = currentTask.taskColor;

    if (phxSub == null) {
      // ── "Anoint your Agent Phoenix" Prompt ───────────────────
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: HudPanel(
          clip: HudClip.both,
          accent: accent.withValues(alpha: 0.5),
          allBrackets: false,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(MdiIcons.fire, size: 18, color: JweTheme.textMuted.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Text(
                    'NO MAIN FOCUS',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Designate a primary operational highlight for ${currentTask.name.toUpperCase()}. Tap the 🔥 icon on any active task below to anoint it.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: JweTheme.textMuted.withValues(alpha: 0.7),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 300.ms);
    }

    // ── Dedicated Agent Phoenix Card ────────────────────────
    final timerState = provider.activeTimers[phxSub.id];
    final isRunning = timerState?.isRunning ?? false;

    final displayBaseTime = isRunning
        ? TaskCalculations.getHistoricalTodaySeconds(phxSub)
        : TaskCalculations.getTodaySeconds(phxSub, timerState);

    final hours = (displayBaseTime / 3600).floor();
    final minutes = ((displayBaseTime / 60) % 60).floor();
    final timeDisplay = '${hours}H ${minutes.toString().padLeft(2, '0')}M';

    final hierarchical = phxSub.calculateProgress();

    SubSubTask? findFirstUncompleted(List<SubSubTask> list) {
      for (final item in list) {
        if (item.type != 'info' && !item.completed) {
          final child = findFirstUncompleted(item.substeps);
          if (child != null) return child;
          return item;
        }
      }
      return null;
    }

    final nextCp = findFirstUncompleted(phxSub.subSubTasks);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: HudPanel(
        clip: HudClip.both,
        accent: JweTheme.accentAmber,
        allBrackets: true,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: JweTheme.accentAmber.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  const HudDot(tone: HudTone.amber, size: 5),
                  const SizedBox(width: 8),
                  Text(
                    '🔥 CURRENT FOCUS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: JweTheme.accentAmber,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isRunning ? 'ENGAGED' : 'STANDBY',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8,
                      color: isRunning ? JweTheme.accentAmber : JweTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Subtask Name, Description, Telemetry Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phxSub.name.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.saira(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: JweTheme.textWhite,
                            height: 1.15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (phxSub.description.trim().isNotEmpty || phxSub.why.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(width: 1.5, height: 24, color: JweTheme.accentAmber.withValues(alpha: 0.35)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  phxSub.description.trim().isNotEmpty ? phxSub.description : phxSub.why,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: JweTheme.textMid,
                                    fontSize: 11,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        
                        // Animated progress bar
                        AnimatedHudBar(
                          progress: hierarchical,
                          color: JweTheme.accentAmber,
                        ),
                        const SizedBox(height: 8),

                        // Telemetry Row
                        Row(
                          children: [
                            Text(
                              'SESSION: ',
                              style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: JweTheme.textMuted, fontWeight: FontWeight.w700),
                            ),
                            ValorantTimerText(
                              isRunning: isRunning,
                              startTime: timerState?.startTime,
                              accumulatedTime: displayBaseTime,
                              style: GoogleFonts.jetBrainsMono(
                                color: isRunning ? JweTheme.accentAmber : JweTheme.textMid,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'PROGRESS: ',
                              style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: JweTheme.textMuted, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${(hierarchical * 100).round()}%',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.accentAmber,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Engage Button
                  GestureDetector(
                    onTap: () {
                      if (isRunning) {
                        provider.timerActions.pauseTimer(phxSub!.id);
                        provider.timerActions.logTimerAndReset(phxSub.id);
                      } else {
                        provider.timerActions.startTimer(phxSub!.id, 'subtask', currentTask.id);
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isRunning ? JweTheme.accentAmber.withValues(alpha: 0.15) : Colors.transparent,
                        border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isRunning ? MdiIcons.pause : MdiIcons.play,
                            size: 20,
                            color: JweTheme.accentAmber,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isRunning ? 'HALT' : 'ENGAGE',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8,
                              color: JweTheme.accentAmber,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Check Next Button (Full Width at the bottom)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (nextCp != null) {
                  provider.taskActions.completeSubSubtask(currentTask.id, phxSub!.id, nextCp.id);
                } else {
                  provider.taskActions.completeSubtask(currentTask.id, phxSub!.id);
                }
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: JweTheme.accentAmber.withValues(alpha: 0.08),
                  border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      MdiIcons.checkBold,
                      size: 14,
                      color: JweTheme.accentAmber,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        nextCp != null
                            ? 'CHECK NEXT: ${nextCp.name.toUpperCase()}'
                            : 'COMPLETE PROTOCOL HIGHLIGHT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          color: JweTheme.accentAmber,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }
}
