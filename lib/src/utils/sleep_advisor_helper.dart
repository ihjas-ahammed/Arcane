import 'package:intl/intl.dart';
import 'package:missions/src/providers/app_provider.dart';

enum NapWindowStatus {
  activeNow,
  upcoming,
  windowPassed,
  completedToday,
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
  static SleepAdvisorData calculate(AppProvider provider, DateTime refDate) {
    final now = DateTime.now();
    final today = DateTime(refDate.year, refDate.month, refDate.day);
    final isViewingToday = refDate.year == now.year &&
        refDate.month == now.month &&
        refDate.day == now.day;

    // 1. Gather sleep records over past 7 days
    final wakeMinutes = <int>[];
    final bedMinutes = <int>[];
    final sleepDurations = <int>[];
    bool hasNapToday = false;
    int? todayWakeMinute;

    for (int i = 0; i < _lookbackDays; i++) {
      final day = today.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      final log = provider.healthLogs[dateKey];
      if (log == null || log.sleepLogs.isEmpty) continue;

      int dayTotalSleep = 0;
      for (final s in log.sleepLogs) {
        dayTotalSleep += s.durationMinutes;

        // Check if a nap was already logged today (< 120m between 10am and 6pm)
        if (i == 0 && isViewingToday) {
          if (s.durationMinutes > 10 && s.durationMinutes < 120 && s.startTime.hour >= 10 && s.startTime.hour <= 18) {
            hasNapToday = true;
          }
        }

        // Night sleep detection: ends in morning (4am-1pm) or starts in evening/night (8pm-4am), and >= 90 mins
        final isMorningWake = s.endTime.hour >= 4 && s.endTime.hour <= 13;
        final isEveningStart = s.startTime.hour >= 20 || s.startTime.hour <= 4;
        final isNightSleep = (isMorningWake || isEveningStart) && s.durationMinutes >= 90;
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

    // Use circular midnight offsets for bedtime:
    // times between 12:00 PM - 23:59 map to -720..-1; 00:00 - 11:59 map to 0..+719
    final bedOffsets = bedMinutes.map(_normalizeToMidnightOffset).toList();
    final int medianBedOffset = fromHistory
        ? _median(bedOffsets)
        : _normalizeToMidnightOffset(_fallbackSleepHour * 60);
    final int medianBed = _fromMidnightOffset(medianBedOffset);

    // Wake time for the reference day (use actual today's wake if logged, else median)
    final int effectiveWakeMinute = todayWakeMinute ?? medianWake;
    final effectiveWakeTime = today.add(Duration(minutes: effectiveWakeMinute));

    // 2. Calculate Power Nap Window
    // Sleep research: The circadian alertness dip (post-lunch dip) occurs ~7 to 7.5 hours
    // after waking.
    DateTime napStart = effectiveWakeTime.add(const Duration(hours: 7, minutes: 15));

    // Safety constraint: Never nap later than 16:00 (4:00 PM) or within 6.5h of bedtime,
    // to preserve homeostatic sleep pressure (adenosine) for nighttime sleep onset.
    final maxNapStart = DateTime(today.year, today.month, today.day, 16, 0);
    if (napStart.isAfter(maxNapStart)) {
      napStart = maxNapStart;
    }
    // Don't suggest earlier than 12:30 PM as circadian temperature drop rarely begins before noon.
    final minNapStart = DateTime(today.year, today.month, today.day, 12, 30);
    if (napStart.isBefore(minNapStart)) {
      napStart = minNapStart;
    }

    final napEnd = napStart.add(const Duration(minutes: 30));
    const napDurationMinutes = 20; // 20-25m avoids Stage 3 slow-wave sleep inertia

    // Determine Nap Status
    NapWindowStatus napStatus;
    if (hasNapToday) {
      napStatus = NapWindowStatus.completedToday;
    } else if (isViewingToday) {
      if (now.isAfter(napEnd)) {
        napStatus = NapWindowStatus.windowPassed;
      } else if (now.isAfter(napStart) && now.isBefore(napEnd)) {
        napStatus = NapWindowStatus.activeNow;
      } else {
        napStatus = NapWindowStatus.upcoming;
      }
    } else {
      napStatus = NapWindowStatus.upcoming;
    }

    // 3. Calculate 7-Day Sleep Averages & Sleep Debt
    final avgSleepMinutes = sleepDurations.isNotEmpty
        ? (sleepDurations.reduce((a, b) => a + b) / sleepDurations.length).round()
        : 450; // 7.5h baseline
    const targetDailyMinutes = 465; // 7.75h (5 cycles + 15m latency)
    final dailyDeficit = (targetDailyMinutes - avgSleepMinutes).clamp(0, 180);
    final weeklySleepDebt = dailyDeficit * (sleepDurations.isEmpty ? 1 : sleepDurations.length);

    // 4. Calculate Next Bedtime
    // Target waking tomorrow around habitual wake time
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowWake = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, medianWake ~/ 60, medianWake % 60);

    // 5 full 90-min cycles (450m) + 15m latency = 465 minutes before wake
    int targetMinutesBeforeWake = (5 * _cycleMinutes) + _latencyMinutes;

    // If moderate to severe sleep debt, suggest an extra 20m window earlier
    if (dailyDeficit >= 45) {
      targetMinutesBeforeWake += 20;
    }

    // Compute ideal bedtime directly backwards from tomorrow's wake time
    DateTime nextBedtime = tomorrowWake.subtract(Duration(minutes: targetMinutesBeforeWake));

    // Consistency alignment: if user's habitual bedtime diverges significantly from
    // 5-cycle target, gently shift (max 30m) towards habitual for circadian entrainment
    if (fromHistory) {
      final targetBedOffset = _normalizeToMidnightOffset(nextBedtime.hour * 60 + nextBedtime.minute);
      final offsetDiff = medianBedOffset - targetBedOffset;
      if (offsetDiff.abs() > 45) {
        // Shift gently towards habitual bedtime by at most 30 minutes
        final shift = offsetDiff.clamp(-30, 30);
        final adjustedOffset = targetBedOffset + shift;
        final adjustedMinute = _fromMidnightOffset(adjustedOffset);
        if (adjustedMinute >= 720) {
          nextBedtime = DateTime(today.year, today.month, today.day, adjustedMinute ~/ 60, adjustedMinute % 60);
        } else {
          nextBedtime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, adjustedMinute ~/ 60, adjustedMinute % 60);
        }
      }
    }

    // Safety bounds: Bedtime must strictly be in the evening/night before wake:
    // At earliest 8:00 PM tonight, at latest 4 hours before wake time tomorrow.
    final earliestBed = DateTime(today.year, today.month, today.day, 20, 0);
    final latestBed = tomorrowWake.subtract(const Duration(hours: 4));
    if (nextBedtime.isBefore(earliestBed)) {
      nextBedtime = earliestBed;
    } else if (nextBedtime.isAfter(latestBed)) {
      nextBedtime = latestBed;
    }

    final windDown = nextBedtime.subtract(const Duration(minutes: 45));

    // Reasoning texts
    final String napReasoning = fromHistory
        ? "Timed 7.2h post-wake (${_formatTimeOfDay(effectiveWakeTime)}) during the natural circadian alertness dip. Capped before 4:00 PM to protect nighttime sleep drive."
        : "Circadian baseline: Scheduled 7h post-wake during the physiological post-lunch dip. Keeps sleep light to eliminate sleep inertia.";

    final String bedtimeReasoning = dailyDeficit > 30
        ? "Targets 5 complete 90m sleep cycles. Adjusted 20m earlier to replenish ~${formatMinutes(weeklySleepDebt)} weekly sleep debt."
        : "Targets 5 complete 90m sleep cycles (7.5h + 15m latency) aligned with your habitual wake schedule.";

    return SleepAdvisorData(
      napWindowStart: napStart,
      napWindowEnd: napEnd,
      napDurationMinutes: napDurationMinutes,
      napStatus: napStatus,
      napReasoning: napReasoning,
      nextBedtime: nextBedtime,
      nextWakeTime: tomorrowWake,
      windDownTime: windDown,
      targetSleepCycles: 5,
      avgWeeklySleepMinutes: avgSleepMinutes,
      weeklySleepDebtMinutes: weeklySleepDebt,
      recordedDaysCount: sleepDurations.length,
      bedtimeReasoning: bedtimeReasoning,
      fromHistory: fromHistory,
      habitualWakeMinute: medianWake,
      habitualBedMinute: medianBed,
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
