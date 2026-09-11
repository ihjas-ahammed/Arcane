import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/active_session_timer_display.dart';

class SubmissionTimerCard extends StatelessWidget {
  final bool isRunning;
  final Color activeAccent;
  final ActiveTimerInfo? timerState;
  final double todaySeconds;
  final VoidCallback onToggleTimer;

  const SubmissionTimerCard({
    super.key,
    required this.isRunning,
    required this.activeAccent,
    required this.timerState,
    required this.todaySeconds,
    required this.onToggleTimer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        border: Border(
          left: BorderSide(
            color: isRunning ? JweTheme.accentRed : activeAccent,
            width: 3,
          ),
          top: BorderSide(color: JweTheme.border),
          right: BorderSide(color: JweTheme.border),
          bottom: BorderSide(color: JweTheme.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRunning ? "CURRENT SESSION" : "TODAY'S LOG",
                  style: TextStyle(
                    color: isRunning ? JweTheme.accentRed : JweTheme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 4),
                ActiveSessionTimerDisplay(
                  isRunning: isRunning,
                  startTime: timerState?.startTime,
                  totalTodaySeconds: todaySeconds,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onToggleTimer,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isRunning
                    ? JweTheme.accentRed.withValues(alpha: 0.12)
                    : activeAccent.withValues(alpha: 0.12),
                border: Border.all(
                  color: isRunning ? JweTheme.accentRed : activeAccent,
                  width: 2,
                ),
              ),
              child: Icon(
                isRunning ? MdiIcons.stop : MdiIcons.play,
                color: isRunning ? JweTheme.accentRed : activeAccent,
                size: 28,
              ),
            ),
          ).animate(key: ValueKey(isRunning)).fadeIn(duration: 200.ms),
        ],
      ),
    );
  }
}
