import 'package:intl/intl.dart';
import 'package:missions/src/providers/app_provider.dart';

enum NapWindowStatus {
  activeNow,
  upcoming,
  recalibrated,
  tomorrowScheduled,
  completedToday,
  windowPassed,
}

class SleepAdvisorData {
  /// Start of optimal power nap window
  final DateTime napWindowStart;

  /// End of optimal power nap window
  final DateTime napWindowEnd;

  /// Recommended duration in minutes (20-25 mins per NASA/sleep research)
  final int napDurationMinutes;

  /// Status of the nap window relative to current time
  final NapWindowStatus napStatus;

  /// Research-backed explanation for this nap recommendation
  final String napReasoning;

  /// Next recommended bedtime (sleep onset)
  final DateTime nextBedtime;

  /// Projected wake time tomorrow morning
  final DateTime nextWakeTime;

  /// Recommended time to start dimming lights and winding down
  final DateTime windDownTime;

  /// Number of 90-minute sleep cycles targeted (usually 5 = 7.5h)
  final int targetSleepCycles;

  /// Daily average sleep minutes over the lookback period (up to 7 days)
  final int avgWeeklySleepMinutes;

  /// Estimated weekly sleep debt in minutes (0 if none)
  final int weeklySleepDebtMinutes;

  /// Number of days with sleep records in the past week
  final int recordedDaysCount;

  /// Research-backed explanation for bedtime recommendation
  final String bedtimeReasoning;

  /// True if calculated from real past sleep data, false if default baseline
  final bool fromHistory;

  /// User's habitual / median wake minute of day (0-1439)
  final int habitualWakeMinute;

  /// User's habitual / median bedtime minute of day (0-1439)
  final int habitualBedMinute;

  /// True if bedtime was dynamically adjusted because primary cycle window was missed
  final bool isBedtimeRecalibrated;

  /// The original 5-cycle bedtime that was missed (if recalibrated)
  final DateTime? missedBedtime;

  const SleepAdvisorData({
    required this.napWindowStart,
    required this.napWindowEnd,
    required this.napDurationMinutes,
    required this.napStatus,
    required this.napReasoning,
    required this.nextBedtime,
    required this.nextWakeTime,
    required this.windDownTime,
    required this.targetSleepCycles,
    required this.avgWeeklySleepMinutes,
    required this.weeklySleepDebtMinutes,
    required this.recordedDaysCount,
    required this.bedtimeReasoning,
    required this.fromHistory,
    required this.habitualWakeMinute,
    required this.habitualBedMinute,
    this.isBedtimeRecalibrated = false,
    this.missedBedtime,
  });
}

class SleepAdvisorHelper {
  static const int _fallbackWakeHour = 7; // 07:00 AM
  static const int _fallbackSleepHour = 23; // 11:00 PM
  static const int _lookbackDays = 7;
  static const int _cycleMinutes = 90; // Ultradian sleep cycle
  static const int _latencyMinutes = 15; // Average sleep onset latency

  /// Computes science-backed power nap and next sleep recommendations
  /// based on the user's sleep telemetry up to 7 days before [refDate].
  ///
  /// Guaranteed to NEVER show a time in the past when viewing today.
  /// When a window is missed, it recalibrates dynamically using
  /// ultradian sleep architecture (90m cycles) and Borbély's Two-Process Model.
  static SleepAdvisorData calculate(AppProvider provider, DateTime refDate, {DateTime? currentTime}) {
    final now = currentTime ?? DateTime.now();
    final today = DateTime(refDate.year, refDate.month, refDate.day);
    final isViewingToday = refDate.year == now.year &&
        refDate.month == now.month &&
        refDate.day == now.day;

    // 1. Gather sleep records over past 7 days
    final wakeMinutes = <int>[];
    final bedMinutes = <int>[];
    final sleepDurations = <int>[];
    bool hasNapToday = false;
    int? todayNapDuration;
    int? todayWakeMinute;

    for (int i = 0; i < _lookbackDays; i++) {
      final day = today.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      final log = provider.healthLogs[dateKey];
      if (log == null || log.sleepLogs.isEmpty) continue;

      int dayTotalSleep = 0;
      for (final s in log.sleepLogs) {
        dayTotalSleep += s.durationMinutes;

        // Check if a nap was already logged today
        if (i == 0 && isViewingToday && s.isNap) {
          hasNapToday = true;
          todayNapDuration = s.durationMinutes;
        }

        // Night sleep detection: not a nap, duration >= 90 mins, and morning wake or evening start
        final isMorningWake = s.endTime.hour >= 4 && s.endTime.hour <= 13;
        final isEveningStart = s.startTime.hour >= 20 || s.startTime.hour <= 4;
        final isNightSleep = !s.isNap && (isMorningWake || isEveningStart) && s.durationMinutes >= 90;
        if (isNightSleep) {
          final wakeMin = s.endTime.hour * 60 + s.endTime.minute;
          final bedMin = s.startTime.hour * 60 + s.startTime.minute;

          wakeMinutes.add(wakeMin);
          bedMinutes.add(bedMin);

          if (i == 0 && todayWakeMinute == null && isMorningWake) {
            todayWakeMinute = wakeMin;
          }
        }
      }

      if (dayTotalSleep > 0) {
        sleepDurations.add(dayTotalSleep);
      }
    }

    final fromHistory = wakeMinutes.isNotEmpty;
    final int medianWake = fromHistory ? _median(wakeMinutes) : _fallbackWakeHour * 60;

    // Circular midnight offsets for bedtime (-720..+719)
    final bedOffsets = bedMinutes.map(_normalizeToMidnightOffset).toList();
    final int medianBedOffset = fromHistory
        ? _median(bedOffsets)
        : _normalizeToMidnightOffset(_fallbackSleepHour * 60);
    final int medianBed = _fromMidnightOffset(medianBedOffset);

    // 2. Sleep debt calculations
    final avgSleepMinutes = sleepDurations.isNotEmpty
        ? (sleepDurations.reduce((a, b) => a + b) / sleepDurations.length).round()
        : 450; // 7.5h baseline
    const targetDailyMinutes = 465; // 7.75h (5 cycles + 15m latency)
    final dailyDeficit = (targetDailyMinutes - avgSleepMinutes).clamp(0, 180);
    final weeklySleepDebt = dailyDeficit * (sleepDurations.isEmpty ? 1 : sleepDurations.length);

    // 3. Determine Target Wake Time
    DateTime targetWakeTime;
    if (isViewingToday) {
      final morningWakeLimit = today.add(Duration(minutes: medianWake));
      if (now.isBefore(morningWakeLimit) && todayWakeMinute == null) {
        // Late night / early morning: user is awake before morning wake time,
        // so their next target is waking THIS morning
        targetWakeTime = morningWakeLimit;
      } else {
        // Normal daytime/evening: user will wake TOMORROW morning
        final tomorrow = today.add(const Duration(days: 1));
        targetWakeTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, medianWake ~/ 60, medianWake % 60);
      }
    } else {
      final tomorrow = today.add(const Duration(days: 1));
      targetWakeTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, medianWake ~/ 60, medianWake % 60);
    }

    // 4. Calculate Bedtime & Dynamic Recalibration if Window Missed
    int primaryMinutesBeforeWake = (5 * _cycleMinutes) + _latencyMinutes;
    if (dailyDeficit >= 45) {
      primaryMinutesBeforeWake += 15;
    }

    DateTime idealBedtime = targetWakeTime.subtract(Duration(minutes: primaryMinutesBeforeWake));

    if (fromHistory) {
      final targetBedOffset = _normalizeToMidnightOffset(idealBedtime.hour * 60 + idealBedtime.minute);
      final offsetDiff = medianBedOffset - targetBedOffset;
      if (offsetDiff.abs() > 45) {
        final shift = offsetDiff.clamp(-30, 30);
        final adjustedOffset = targetBedOffset + shift;
        final adjustedMinute = _fromMidnightOffset(adjustedOffset);
        if (adjustedMinute >= 720) {
          idealBedtime = DateTime(targetWakeTime.year, targetWakeTime.month, targetWakeTime.day - 1, adjustedMinute ~/ 60, adjustedMinute % 60);
        } else {
          idealBedtime = DateTime(targetWakeTime.year, targetWakeTime.month, targetWakeTime.day, adjustedMinute ~/ 60, adjustedMinute % 60);
        }
      }
    }

    // Safety bounds
    final earliestBed = targetWakeTime.subtract(const Duration(hours: 12));
    final latestBed = targetWakeTime.subtract(const Duration(hours: 3));
    if (idealBedtime.isBefore(earliestBed)) idealBedtime = earliestBed;
    if (idealBedtime.isAfter(latestBed)) idealBedtime = latestBed;

    DateTime nextBedtime = idealBedtime;
    int targetSleepCycles = 5;
    bool isBedtimeRecalibrated = false;
    DateTime? missedBedtime;
    String bedtimeReasoning;

    if (isViewingToday && now.isAfter(idealBedtime)) {
      // Primary 5-cycle bedtime window HAS PASSED!
      // Step down through viable ultradian cycles so user doesn't wake mid-cycle
      missedBedtime = idealBedtime;
      isBedtimeRecalibrated = true;

      bool gateFound = false;
      for (final cycles in [4, 3, 2]) {
        final gateMinutes = (cycles * _cycleMinutes) + _latencyMinutes;
        final gateBedtime = targetWakeTime.subtract(Duration(minutes: gateMinutes));
        if (now.isBefore(gateBedtime)) {
          nextBedtime = gateBedtime;
          targetSleepCycles = cycles;
          gateFound = true;
          break;
        }
      }

      if (gateFound) {
        final durationHours = (targetSleepCycles * 1.5).toStringAsFixed(1);
        bedtimeReasoning = targetSleepCycles == 4
            ? "5-cycle window (${_formatTimeOfDay(idealBedtime)}) passed. Recalibrated to 4 complete 90m cycles (${durationHours}h) waking at ${_formatTimeOfDay(targetWakeTime)}. Prevents waking during Stage 3 slow-wave sleep."
            : targetSleepCycles == 3
                ? "4-cycle window passed. Recalibrated to 3 complete cycles (${durationHours}h) waking at ${_formatTimeOfDay(targetWakeTime)}. Aligns sleep onset with early morning core temperature nadir."
                : "Late-night core sleep anchor: 2 complete cycles (${durationHours}h) before ${_formatTimeOfDay(targetWakeTime)} wake. Prevents sleep inertia by completing full ultradian cycles.";
      } else {
        // Less than 2 cycles left before targetWakeTime
        final gate1Minutes = (1 * _cycleMinutes) + _latencyMinutes; // 105 mins
        final gate1 = targetWakeTime.subtract(Duration(minutes: gate1Minutes));
        if (now.isBefore(gate1)) {
          nextBedtime = gate1;
          targetSleepCycles = 1;
          bedtimeReasoning = "Emergency 90m ultradian cycle anchor: Sleep 90 minutes (+15m latency) to complete one cycle before ${_formatTimeOfDay(targetWakeTime)}. Prevents waking mid-cycle.";
        } else if (now.isBefore(targetWakeTime)) {
          // Under 90m before wake: shift wake time forward by 3 complete cycles
          nextBedtime = now.add(const Duration(minutes: 15));
          targetWakeTime = nextBedtime.add(const Duration(minutes: 3 * _cycleMinutes));
          targetSleepCycles = 3;
          bedtimeReasoning = "Immediate recovery recalibration: Under 90m to morning wake. Wake time shifted to ${_formatTimeOfDay(targetWakeTime)} (3 full cycles, 4.5h) to safeguard neurocognitive recovery.";
        } else {
          // Morning has passed, schedule tonight's 5-cycle sleep
          final tomorrow = today.add(const Duration(days: 1));
          targetWakeTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, medianWake ~/ 60, medianWake % 60);
          nextBedtime = targetWakeTime.subtract(Duration(minutes: 5 * _cycleMinutes + _latencyMinutes));
          targetSleepCycles = 5;
          isBedtimeRecalibrated = false;
          bedtimeReasoning = "Targets 5 complete 90m sleep cycles (7.5h + 15m latency) tonight, aligned with your habitual wake schedule.";
        }
      }
    } else {
      bedtimeReasoning = dailyDeficit > 30
          ? "Targets 5 complete 90m sleep cycles. Adjusted 15m earlier to replenish ~${formatMinutes(weeklySleepDebt)} weekly sleep debt."
          : "Targets 5 complete 90m sleep cycles (7.5h + 15m latency) aligned with your habitual wake schedule (${_formatTimeOfDay(targetWakeTime)}).";
    }

    DateTime windDown = nextBedtime.subtract(const Duration(minutes: 45));
    if (isViewingToday && now.isAfter(windDown)) {
      windDown = now;
    }

    // 5. Calculate Power Nap Window & Dynamic Recalibration
    final int effectiveWakeMinute = todayWakeMinute ?? medianWake;
    final effectiveWakeTime = today.add(Duration(minutes: effectiveWakeMinute));

    // Circadian alertness dip: ~7.25h post-wake
    DateTime primaryNapStart = effectiveWakeTime.add(const Duration(hours: 7, minutes: 15));

    // Safety constraint: Never nap later than 16:00 (4:00 PM) for primary schedule
    final maxNapStart = DateTime(today.year, today.month, today.day, 16, 0);
    if (primaryNapStart.isAfter(maxNapStart)) {
      primaryNapStart = maxNapStart;
    }
    final minNapStart = DateTime(today.year, today.month, today.day, 12, 30);
    if (primaryNapStart.isBefore(minNapStart)) {
      primaryNapStart = minNapStart;
    }

    // Afternoon cutoff:
    // Must end at least 6.5h before tonight's bedtime and no later than 16:30 (4:30 PM)
    final maxNapEndByBedtime = nextBedtime.subtract(const Duration(hours: 6, minutes: 30));
    final absoluteMaxNapEnd = DateTime(today.year, today.month, today.day, 16, 30);
    final DateTime napCutoff = maxNapEndByBedtime.isBefore(absoluteMaxNapEnd)
        ? (maxNapEndByBedtime.isAfter(minNapStart) ? maxNapEndByBedtime : absoluteMaxNapEnd)
        : absoluteMaxNapEnd;

    DateTime primaryNapEnd = primaryNapStart.add(const Duration(minutes: 30));
    if (primaryNapEnd.isAfter(napCutoff)) {
      primaryNapEnd = napCutoff;
      if (primaryNapEnd.difference(primaryNapStart).inMinutes < 20) {
        primaryNapStart = primaryNapEnd.subtract(const Duration(minutes: 20));
      }
    }

    DateTime napWindowStart;
    DateTime napWindowEnd;
    const napDurationMinutes = 20; // 20 min NASA standard avoids SWS sleep inertia
    NapWindowStatus napStatus;
    String napReasoning;

    // Tomorrow's nap window for when today's window is closed or completed
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowWake = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, medianWake ~/ 60, medianWake % 60);
    DateTime tomorrowNapStart = tomorrowWake.add(const Duration(hours: 7, minutes: 15));
    if (tomorrowNapStart.hour < 12 || (tomorrowNapStart.hour == 12 && tomorrowNapStart.minute < 30)) {
      tomorrowNapStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 12, 30);
    }
    final maxTomorrowNapStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 16, 0);
    if (tomorrowNapStart.isAfter(maxTomorrowNapStart)) {
      tomorrowNapStart = maxTomorrowNapStart;
    }
    final tomorrowNapEnd = tomorrowNapStart.add(const Duration(minutes: 30));

    if (hasNapToday) {
      napStatus = NapWindowStatus.completedToday;
      napWindowStart = tomorrowNapStart;
      napWindowEnd = tomorrowNapEnd;
      napReasoning = todayNapDuration != null
          ? "Power nap logged today (${todayNapDuration}m). Further daytime sleep would blunt homeostatic sleep pressure (adenosine) needed for tonight. Next power nap: tomorrow ${_formatTimeOfDay(tomorrowNapStart)}."
          : "Power nap logged today. Further daytime sleep would blunt tonight's sleep drive. Next power nap: tomorrow ${_formatTimeOfDay(tomorrowNapStart)}.";
    } else if (isViewingToday) {
      if (now.isBefore(primaryNapStart)) {
        napStatus = NapWindowStatus.upcoming;
        napWindowStart = primaryNapStart;
        napWindowEnd = primaryNapEnd;
        napReasoning = fromHistory
            ? "Timed 7.2h post-wake (${_formatTimeOfDay(effectiveWakeTime)}) during the natural circadian alertness dip. Capped before 4:00 PM to protect nighttime sleep drive."
            : "Circadian baseline: Scheduled 7h post-wake during the physiological post-lunch dip. Keeps sleep light to eliminate sleep inertia.";
      } else if (now.isAfter(primaryNapStart) && now.isBefore(primaryNapEnd)) {
        napStatus = NapWindowStatus.activeNow;
        napWindowStart = primaryNapStart;
        napWindowEnd = primaryNapEnd;
        napReasoning = "Circadian alertness dip window is ACTIVE now. A 20-minute power nap restores cognitive speed, working memory, and vigilance without slow-wave sleep inertia.";
      } else {
        // Primary window has passed! Check if we can still take an opportunistic nap before cutoff
        final minSafeWindowEnd = now.add(const Duration(minutes: 25)); // 5m prep + 20m nap
        if (minSafeWindowEnd.isBefore(napCutoff) || minSafeWindowEnd.isAtSameMomentAs(napCutoff)) {
          napStatus = NapWindowStatus.recalibrated;
          napWindowStart = now.add(const Duration(minutes: 5));
          napWindowEnd = napWindowStart.add(const Duration(minutes: 20));
          napReasoning = "Primary circadian window missed. Recalibrated opportunistic power nap: 20m nap before the ${_formatTimeOfDay(napCutoff)} cutoff clears accumulated midday adenosine without delaying tonight's melatonin onset.";
        } else {
          // Afternoon cutoff passed! Today's nap window is closed to protect tonight's sleep drive
          napStatus = NapWindowStatus.tomorrowScheduled;
          napWindowStart = tomorrowNapStart;
          napWindowEnd = tomorrowNapEnd;
          napReasoning = "Today's nap window closed (within 6.5h of bedtime / past ${_formatTimeOfDay(napCutoff)}) to protect homeostatic sleep drive for tonight. Next optimal power nap scheduled for tomorrow.";
        }
      }
    } else {
      // Historical or future date
      if (today.isBefore(DateTime(now.year, now.month, now.day))) {
        napStatus = NapWindowStatus.windowPassed;
      } else {
        napStatus = NapWindowStatus.upcoming;
      }
      napWindowStart = primaryNapStart;
      napWindowEnd = primaryNapEnd;
      napReasoning = "Scheduled 7.2h post-wake during the physiological circadian alertness dip.";
    }

    return SleepAdvisorData(
      napWindowStart: napWindowStart,
      napWindowEnd: napWindowEnd,
      napDurationMinutes: napDurationMinutes,
      napStatus: napStatus,
      napReasoning: napReasoning,
      nextBedtime: nextBedtime,
      nextWakeTime: targetWakeTime,
      windDownTime: windDown,
      targetSleepCycles: targetSleepCycles,
      avgWeeklySleepMinutes: avgSleepMinutes,
      weeklySleepDebtMinutes: weeklySleepDebt,
      recordedDaysCount: sleepDurations.length,
      bedtimeReasoning: bedtimeReasoning,
      fromHistory: fromHistory,
      habitualWakeMinute: medianWake,
      habitualBedMinute: medianBed,
      isBedtimeRecalibrated: isBedtimeRecalibrated,
      missedBedtime: missedBedtime,
    );
  }

  static int _normalizeToMidnightOffset(int minuteOfDay) {
    return minuteOfDay >= 720 ? minuteOfDay - 1440 : minuteOfDay;
  }

  static int _fromMidnightOffset(int offset) {
    return (offset % 1440 + 1440) % 1440;
  }

  static int _median(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  static String _formatTimeOfDay(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $period';
  }

  static String formatMinutes(int mins) {
    if (mins <= 0) return '0m';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
