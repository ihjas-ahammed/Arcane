import 'package:intl/intl.dart';
import 'package:missions/src/providers/app_provider.dart';

class DayWindow {
  final DateTime wakeAt;
  final DateTime sleepAt;
  final bool fromHistory;

  DayWindow({required this.wakeAt, required this.sleepAt, required this.fromHistory});

  int minutesRemaining(DateTime now) {
    if (now.isAfter(sleepAt)) return 0;
    final from = now.isBefore(wakeAt) ? wakeAt : now;
    return sleepAt.difference(from).inMinutes;
  }

  int get totalMinutes => sleepAt.difference(wakeAt).inMinutes;
}

const int _fallbackWakeHour = 7;
const int _fallbackSleepHour = 22;
const int _minSamplesForHistory = 3;
const int _lookbackDays = 14;

DayWindow resolveDayWindow(AppProvider provider, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final samples = _collectSleepSamples(provider, now);

  if (samples.length < _minSamplesForHistory) {
    return DayWindow(
      wakeAt: today.add(Duration(hours: _fallbackWakeHour)),
      sleepAt: today.add(Duration(hours: _fallbackSleepHour)),
      fromHistory: false,
    );
  }

  final wakeMinutes = _median(samples.map((s) => s.wakeMinuteOfDay).toList());
  final sleepMinutes = _median(samples.map((s) => s.sleepMinuteOfDay).toList());

  return DayWindow(
    wakeAt: today.add(Duration(minutes: wakeMinutes)),
    sleepAt: today.add(Duration(minutes: sleepMinutes)),
    fromHistory: true,
  );
}

class _SleepSample {
  final int wakeMinuteOfDay;
  final int sleepMinuteOfDay;
  _SleepSample(this.wakeMinuteOfDay, this.sleepMinuteOfDay);
}

List<_SleepSample> _collectSleepSamples(AppProvider provider, DateTime now) {
  final samples = <_SleepSample>[];
  for (int i = 1; i <= _lookbackDays; i++) {
    final day = now.subtract(Duration(days: i));
    final key = DateFormat('yyyy-MM-dd').format(day);
    final log = provider.healthLogs[key];
    if (log == null) continue;
    for (final s in log.sleepLogs) {
      if (s.endTime.isBefore(now)) {
        samples.add(_SleepSample(
          _minuteOfDay(s.endTime),
          _minuteOfDay(s.startTime),
        ));
      }
    }
  }
  return samples;
}

int _minuteOfDay(DateTime dt) => dt.hour * 60 + dt.minute;

int _median(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return ((sorted[mid - 1] + sorted[mid]) / 2).round();
}

String formatMinutes(int mins) {
  if (mins <= 0) return '0m';
  final h = mins ~/ 60;
  final m = mins % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}
