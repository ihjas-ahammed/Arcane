import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/task_calculations.dart';

class DayPlanHomeWidget extends StatelessWidget {
  final List<ResolvedDayPlanItem> tasks;
  final String capacity;
  final double progress;

  const DayPlanHomeWidget({
    super.key,
    required this.tasks,
    this.capacity = '',
    this.progress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final bgPanel = JweTheme.isLight ? JweTheme.panel : const Color(0xFF0D1426);
    final accentCyan = JweTheme.accentCyan;
    final accentAmber = JweTheme.accentAmber;
    final textWhite = JweTheme.textWhite;
    final textMuted = JweTheme.textMuted;
    final bgDeep = JweTheme.onAccent;

    final count = tasks.length;
    final primaryTitle = count > 0 ? tasks[0].name.toUpperCase() : "NO MISSIONS PLANNED";
    final nextText = count > 1
        ? "${tasks[1].name.toUpperCase()}${count > 2 ? ' (+${count - 2} MORE)' : ''}"
        : (count == 1 ? "FINAL MISSION IN QUEUE" : "QUEUE MISSIONS IN TODAY PLANNER");

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgPanel,
          border: Border.all(color: accentCyan, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: accentCyan.withValues(alpha: JweTheme.isLight ? 0.08 : 0.05),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    count > 0 ? "[ DAY PLAN // 0$count ACTIVE ]" : "[ DAY PLAN // STANDBY ]",
                    style: TextStyle(
                      color: accentCyan,
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (capacity.isNotEmpty)
                  Text(
                    "CAP $capacity",
                    style: TextStyle(
                      color: textMuted,
                      fontFamily: 'monospace',
                      fontSize: 9.5,
                      letterSpacing: 1.0,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            // Main Hero Item
            Text(
              primaryTitle,
              style: TextStyle(
                color: textWhite,
                fontSize: 19,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Next / Subtitle Row
            Row(
              children: [
                if (count > 0) ...[
                  Text(
                    "NEXT: ",
                    style: TextStyle(
                      color: textMuted,
                      fontFamily: 'monospace',
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    nextText,
                    style: TextStyle(
                      color: accentCyan,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count > 0)
                  Text(
                    "$count MISSIONS",
                    style: TextStyle(
                      color: accentAmber,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: count > 0 ? progress.clamp(0.0, 1.0) : 0.0,
                backgroundColor: textMuted.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(accentCyan),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 10),
            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  flex: 12,
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: accentAmber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "OPEN PLAN",
                      style: TextStyle(
                        color: bgDeep,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 9,
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        border: Border.all(color: accentCyan, width: 1.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "CHECK",
                        style: TextStyle(
                          color: accentCyan,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 9,
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        border: Border.all(color: accentAmber, width: 1.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "ENGAGE",
                        style: TextStyle(
                          color: accentAmber,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
