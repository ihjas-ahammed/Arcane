import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Flutter UI representations of the Android home-screen widgets.
/// These are rendered offscreen to PNGs using HomeWidget.renderFlutterWidget.
/// 
/// Since they are rendered to a fixed logical size (400x200), we wrap them in
/// a fixed 400x200 Container to ensure layout stability and pixel-perfect results.

class RunningTaskHomeWidget extends StatelessWidget {
  final bool hasTask;
  final String title;
  final String subtitle;
  final bool isRunning;
  final bool isCheckpoint;
  final int accumulatedSeconds;
  final double progress; // 0..1 — mirrors the missions screen subtask progress
  final bool isPhoenix; // true when the headlined item is today's Phoenix
  final String capacity; // e.g. "2h40 / 4h30"; empty hides the readout

  const RunningTaskHomeWidget({
    super.key,
    required this.hasTask,
    required this.title,
    required this.subtitle,
    required this.isRunning,
    required this.isCheckpoint,
    required this.accumulatedSeconds,
    this.progress = 0.0,
    this.isPhoenix = false,
    this.capacity = '',
  });

  @override
  Widget build(BuildContext context) {
    // Phoenix anchors an amber identity; a live session still flips to red.
    final accentColor = isRunning
        ? AppTheme.fhAccentRed
        : (isPhoenix && hasTask ? AppTheme.fhAccentOrange : AppTheme.fhAccentGold);

    final statusLabel = !hasTask
        ? "QUEUE EMPTY"
        : (isPhoenix
            ? (isRunning ? "PHOENIX · ENGAGED" : "PHOENIX · STANDBY")
            : (isCheckpoint
                ? (isRunning ? "CHECKPOINT · ENGAGED" : "CHECKPOINT · STANDBY")
                : (isRunning ? "ACTIVE · ENGAGED" : "ACTIVE · STANDBY")));

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          border: Border.all(color: accentColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.rectangle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                if (isPhoenix && hasTask) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.fhAccentOrange.withValues(alpha: 0.14),
                      border: Border.all(
                          color: AppTheme.fhAccentOrange.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child:  Text(
                      "PHOENIX",
                      style: TextStyle(
                        color: AppTheme.fhAccentOrange,
                        fontSize: 9,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              hasTask ? title.toUpperCase() : 'NO PLAN SET',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.fhTextPrimary,
                fontFamily: AppTheme.fontDisplay,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            // Subtitle
            Text(
              hasTask ? subtitle.toUpperCase() : 'QUEUE STANDBY',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.fhTextSecondary,
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            // Timer Area (we render the label, but leave blank space on the right
            // where the native ticking Chronometer will overlay)
            Row(
              children: [
                const Text(
                  "TODAY",
                  style: TextStyle(
                    color: AppTheme.fhTextDisabled,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (hasTask && capacity.isNotEmpty)
                  Text(
                    "CAP $capacity",
                    style: const TextStyle(
                      color: AppTheme.fhTextDisabled,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            // Progress bar — only meaningful when there is a task with steps.
            if (hasTask) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: AppTheme.fhBorderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      isRunning ? AppTheme.fhAccentRed : AppTheme.fhAccentGold),
                ),
              ),
              const SizedBox(height: 10),
            ],
            // Buttons Row (Visuals matching the clickable transparent areas in XML)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasTask
                          ? (isRunning ? AppTheme.fhAccentRed : AppTheme.fhAccentGold)
                          : AppTheme.fhAccentGold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      hasTask ? (isRunning ? "HALT SESSION" : "ENGAGE") : "OPEN PLAN",
                      style: const TextStyle(
                        color: AppTheme.fhBgDeepDark,
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                // CHECK button — only when there's an active task.
                if (hasTask) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 88,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhAccentTeal, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "CHECK",
                      style: TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                Container(
                  width: 88,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: hasTask ? AppTheme.fhAccentGold : AppTheme.fhAccentGold.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    hasTask ? "FINISH" : "REFRESH",
                    style: TextStyle(
                      color: hasTask ? AppTheme.fhAccentGold : AppTheme.fhAccentGold.withValues(alpha: 0.5),
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceHomeWidget extends StatelessWidget {
  final double balance;
  final double todaySpend;
  final double monthSpend;
  final int budgetPct;

  const FinanceHomeWidget({
    super.key,
    required this.balance,
    required this.todaySpend,
    required this.monthSpend,
    required this.budgetPct,
  });

  String _fmtMoney(double val) {
    final abs = val.abs();
    final sign = val < 0 ? "-" : "";
    if (abs >= 10000000) {
      return "$sign₹${(abs / 10000000).toStringAsFixed(2)}Cr";
    } else if (abs >= 100000) {
      return "$sign₹${(abs / 100000).toStringAsFixed(2)}L";
    } else if (abs >= 1000) {
      return "$sign₹${(abs / 1000).toStringAsFixed(1)}K";
    } else {
      return "$sign₹${abs.toStringAsFixed(0)}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final clampedPct = budgetPct.clamp(0, 100);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          border: Border.all(color: AppTheme.fhAccentGold, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      color: AppTheme.fhAccentGold,
                    ),
                    const SizedBox(width: 8),
                     Text(
                      "// WALLET",
                      style: TextStyle(
                        color: AppTheme.fhAccentGold,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  DateFormat('HH:mm').format(DateTime.now()), // last updated time
                  style: const TextStyle(
                    color: AppTheme.fhTextDisabled,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Balance
            Text(
              _fmtMoney(balance),
              style:  TextStyle(
                color: AppTheme.fhAccentGold,
                fontFamily: AppTheme.fontDisplay,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // Today / MTD / Budget Columns
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCol("TODAY", _fmtMoney(todaySpend), AppTheme.fhAccentTeal),
                _buildCol("MTD", _fmtMoney(monthSpend), AppTheme.fhAccentGold),
                _buildCol("BUDGET", "$budgetPct%", AppTheme.fhAccentTeal),
              ],
            ),
            const SizedBox(height: 10),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: clampedPct / 100.0,
                minHeight: 6,
                backgroundColor: AppTheme.fhBorderColor,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.fhAccentGold),
              ),
            ),
            const SizedBox(height: 12),
            // Buttons Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhAccentTeal, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "+ INCOME",
                      style: TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.fhAccentRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "− EXPENSE",
                      style: TextStyle(
                        color: AppTheme.fhTextPrimary,
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCol(String label, String value, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.fhTextDisabled,
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valColor,
            fontFamily: AppTheme.fontDisplay,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class JournalHomeWidget extends StatelessWidget {
  final int count;
  final bool wake;
  final bool morn;
  final bool aft;
  final bool eve;
  final bool night;

  const JournalHomeWidget({
    super.key,
    required this.count,
    required this.wake,
    required this.morn,
    required this.aft,
    required this.eve,
    required this.night,
  });

  @override
  Widget build(BuildContext context) {
    final todayCount = [wake, morn, aft, eve, night].where((e) => e).length;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          border: Border.all(color: AppTheme.fhAccentTeal, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      color: AppTheme.fhAccentTeal,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "// REFLECTION LOG",
                      style: TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  "$count ${count == 1 ? 'ENTRY' : 'ENTRIES'}",
                  style: const TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "REFLECTION PROTOCOL",
                  style: TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  "$todayCount/5 COMPLETE",
                  style: const TextStyle(
                    color: AppTheme.fhAccentTeal,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress segments
            Row(
              children: [
                Expanded(child: _buildSegment("WAKE", wake)),
                const SizedBox(width: 6),
                Expanded(child: _buildSegment("MORN", morn)),
                const SizedBox(width: 6),
                Expanded(child: _buildSegment("AFT", aft)),
                const SizedBox(width: 6),
                Expanded(child: _buildSegment("EVE", eve)),
                const SizedBox(width: 6),
                Expanded(child: _buildSegment("NIGHT", night)),
              ],
            ),
            const Spacer(),
            // Buttons Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhAccentTeal, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "+ NEW LOG",
                      style: TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 100,
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.fhAccentGold, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child:  Text(
                    "ARCHIVE",
                    style: TextStyle(
                      color: AppTheme.fhAccentGold,
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(String label, bool isComplete) {
    return Column(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: isComplete ? AppTheme.fhAccentTeal : AppTheme.fhBgMedium,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isComplete ? AppTheme.fhAccentTeal : AppTheme.fhTextSecondary,
            fontSize: 9,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
