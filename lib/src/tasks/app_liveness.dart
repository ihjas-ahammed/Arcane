import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Lets the background engine tell whether the app is running. The app writes its process id and
/// a timestamp to a small file every 30 seconds. It counts as running only while that process still
/// exists and the timestamp is recent, so a killed app hands taps over at once.
///
/// If the process is killed the file stops being refreshed and goes stale after [_staleAfter], so
/// taps are handled in the background from then on.
class AppLiveness {
  AppLiveness._();

  static const _fileName = 'arcane_app_heartbeat.txt';
  static const _every = Duration(seconds: 30);
  static const _staleAfter = Duration(seconds: 90);

  static Timer? _timer;

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Called once at app start. Beats now and then every [_every].
  static void start() {
    unawaited(_beat());
    _timer ??= Timer.periodic(_every, (_) => unawaited(_beat()));
  }

  /// Called on a clean shutdown so the background engine can act at once.
  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {/* nothing to clean up */}
  }

  static Future<void> _beat() async {
    try {
      final f = await _file();
      await f.writeAsString('$pid ${DateTime.now().millisecondsSinceEpoch}',
          flush: true);
    } catch (_) {/* a missed beat only delays the handover */}
  }

  /// True when the app beat recently. Errors count as "not running", so a tap is never dropped
  /// because the file could not be read.
  static Future<bool> isAppRunning() async {
    try {
      final f = await _file();
      if (!await f.exists()) return false;
      final parts = (await f.readAsString()).trim().split(' ');
      if (parts.length != 2) return false;
      final owner = int.tryParse(parts[0]);
      final beat = int.tryParse(parts[1]);
      if (owner == null || beat == null) return false;
      // That process is gone (the app was killed): not running.
      if (!Directory('/proc/$owner').existsSync()) return false;
      return DateTime.now().millisecondsSinceEpoch - beat <
          _staleAfter.inMilliseconds;
    } catch (_) {
      return false;
    }
  }
}
