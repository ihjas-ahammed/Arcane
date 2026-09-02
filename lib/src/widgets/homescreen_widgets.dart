import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Flutter UI representations of the Android home-screen widgets.
/// These are rendered offscreen to PNGs using HomeWidget.renderFlutterWidget.
/// 
/// Since they are rendered to a fixed logical size (400x200), we wrap them in
/// a fixed 400x200 Container to ensure layout stability and pixel-perfect results.

import 'package:missions/src/utils/task_calculations.dart';

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
  final bool dayPlannerWidgetCheckable;
  final List<ResolvedDayPlanItem> topFiveTasks;

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
    this.dayPlannerWidgetCheckable = false,
    this.topFiveTasks = const [],
  });

  Widget _buildCheckableList(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          border: Border.all(color: AppTheme.fhAccentGold, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.fhAccentGold,
                    shape: BoxShape.rectangle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "DAY PLAN",
                  style: TextStyle(
                    color: AppTheme.fhAccentGold,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (capacity.isNotEmpty)
                  Text(
                    "CAP $capacity",
                    style:   TextStyle(
                      color: AppTheme.fhTextDisabled,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // List of top 5 tasks
            Expanded(
              child: topFiveTasks.isEmpty
                  ?   Center(
                      child: Text(
                        "NO PLAN SET",
                        style: TextStyle(
                          color: AppTheme.fhTextDisabled,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Column(
                      children: List.generate(5, (index) {
                        if (index >= topFiveTasks.length) {
                          return const SizedBox(height: 26);
                        }
                        final item = topFiveTasks[index];
                        return Container(
                          height: 26,
                          margin: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              // Task Indicator / Color bar
                              Container(
                                width: 4,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: item.color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Task details (Name & Subtitle)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        if (item.isPhoenix) ...[
                                          Icon(Icons.fireplace, size: 12, color: AppTheme.fhAccentOrange),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            item.name.toUpperCase(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: item.isPhoenix ? AppTheme.fhAccentOrange : AppTheme.fhTextPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      item.parentName.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:   TextStyle(
                                        color: AppTheme.fhTextSecondary,
                                        fontSize: 9,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Checkbox representation
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: item.isPhoenix ? AppTheme.fhAccentOrange : AppTheme.fhAccentTeal,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.transparent,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                          ),
                        );
                      }),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (dayPlannerWidgetCheckable) {
      return _buildCheckableList(context);
    }

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
            const SizedBox(height: 6),
            // Title
            Text(
              hasTask ? title.toUpperCase() : 'NO PLAN SET',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:   TextStyle(
                color: AppTheme.fhTextPrimary,
                fontFamily: AppTheme.fontDisplay,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            // Subtitle
            Text(
              hasTask ? subtitle.toUpperCase() : 'QUEUE STANDBY',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:   TextStyle(
                color: AppTheme.fhTextSecondary,
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            // Timer Area (we render the label, but leave blank space on the right
            // where the native ticking Chronometer will overlay)
            Row(
              children: [
                  Text(
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
                    style:   TextStyle(
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
              const SizedBox(height: 6),
            ],
            // Buttons Row (Visuals matching the clickable transparent areas in XML)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: hasTask
                          ? (isRunning ? AppTheme.fhAccentRed : AppTheme.fhAccentGold)
                          : AppTheme.fhAccentGold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      hasTask ? (isRunning ? "HALT SESSION" : "ENGAGE") : "OPEN PLAN",
                      style:   TextStyle(
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
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhAccentTeal, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child:   Text(
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
                  height: 34,
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
                  style:   TextStyle(
                    color: AppTheme.fhTextDisabled,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Balance
            Text(
              _fmtMoney(balance),
              style:  TextStyle(
                color: AppTheme.fhAccentGold,
                fontFamily: AppTheme.fontDisplay,
                fontSize: 28,
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
            const SizedBox(height: 6),
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
            const SizedBox(height: 8),
            // Buttons Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhAccentTeal, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child:   Text(
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
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.fhAccentRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child:   Text(
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
          style:   TextStyle(
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
                      Text(
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
                  style:   TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Text(
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
                  style:   TextStyle(
                    color: AppTheme.fhAccentTeal,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
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
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhAccentTeal, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child:   Text(
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
                  height: 32,
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

class BusHomeWidget extends StatelessWidget {
  final String origin;
  final String destination;
  final String nextTime;
  final String nextSubStop;
  final bool isOnBus;
  final int speedKmh;
  final int minutesRemaining;

  const BusHomeWidget({
    super.key,
    required this.origin,
    required this.destination,
    required this.nextTime,
    this.nextSubStop = '',
    this.isOnBus = false,
    this.speedKmh = 0,
    this.minutesRemaining = -1,
  });

  @override
  Widget build(BuildContext context) {
    // Exact colors from Android widget_colors.xml
    const bgPanel = Color(0xFF0D1426);
    const bgDeep = Color(0xFF04060E);
    const accentAmber = Color(0xFFFFB547);
    const accentCyan = Color(0xFF5FE1D8);
    const accentTeal = Color(0xFF4AF3C2);
    const textWhite = Color(0xFFEAECF3);
    const textMid = Color(0xFFA8B3C7);
    const textMuted = Color(0xFF5E6C87);

    final statusBadge = isOnBus ? "[ ON BUS // TRANSIT ACTIVE ]" : "[ BUS RADAR // STANDBY ]";
    final speedLabel = isOnBus && speedKmh > 0 ? "SPEED: $speedKmh KM/H" : "GPS: ACTIVE";
    
    // Main Time: When on bus and remaining minutes >= 0: ETA ~14M TO EDAVANNAPPARA.
    // When not on bus: simply nextTime (no "(3m)")
    final mainTimeText = isOnBus && minutesRemaining >= 0
        ? "ETA ~${minutesRemaining}M TO ${destination.toUpperCase()}"
        : nextTime;

    final subStopInfo = nextSubStop.isNotEmpty
        ? (isOnBus ? "NEXT STOP: ${nextSubStop.toUpperCase()}" : "VIA: ${nextSubStop.toUpperCase()}")
        : (minutesRemaining >= 0 ? "DEPARTS IN $minutesRemaining MIN" : "CHECK SCHEDULE");

    final borderColor = isOnBus ? accentTeal : accentAmber;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgPanel,
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    statusBadge,
                    style: TextStyle(
                      color: isOnBus ? accentTeal : accentAmber,
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  speedLabel,
                  style: const TextStyle(
                    color: textMuted,
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            // Route Name
            Text(
              "${origin.toUpperCase()} → ${destination.toUpperCase()}",
              style: const TextStyle(
                color: textMid,
                fontSize: 11,
                fontFamily: 'monospace',
                letterSpacing: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Main Time (Bright white text matching widget_text_white)
            Text(
              mainTimeText,
              style: const TextStyle(
                color: textWhite,
                fontSize: 24,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Sub-Stop / Telemetry info
            Text(
              subStopInfo,
              style: const TextStyle(
                color: accentCyan,
                fontSize: 10.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border.all(color: accentAmber, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "⇄ SWAP",
                      style: TextStyle(
                        color: accentAmber,
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: accentAmber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "TIMETABLE",
                      style: TextStyle(
                        color: bgDeep,
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
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
}
