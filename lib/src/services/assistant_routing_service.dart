import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents an external AI assistant application installed on the host device.
class InstalledAssistant {
  final String package;
  final String label;

  const InstalledAssistant({
    required this.package,
    required this.label,
  });

  @override
  String toString() => '$label ($package)';
}

/// Represents an application installed on the host device.
class InstalledAppInfo {
  final String package;
  final String label;
  final bool isSystem;
  final bool isLaunchable;

  const InstalledAppInfo({
    required this.package,
    required this.label,
    this.isSystem = false,
    this.isLaunchable = true,
  });

  factory InstalledAppInfo.fromMap(Map<dynamic, dynamic> map) {
    return InstalledAppInfo(
      package: map['package'] as String? ?? '',
      label: map['label'] as String? ?? '',
      isSystem: map['isSystem'] as bool? ?? false,
      isLaunchable: map['isLaunchable'] as bool? ?? true,
    );
  }

  @override
  String toString() => '$label ($package)';
}

/// Represents an Activity component declared inside an Android application.
class AppActivityInfo {
  final String name;
  final String label;
  final bool exported;
  final bool isVoiceOrAssist;

  const AppActivityInfo({
    required this.name,
    required this.label,
    this.exported = true,
    this.isVoiceOrAssist = false,
  });

  factory AppActivityInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppActivityInfo(
      name: map['name'] as String? ?? '',
      label: map['label'] as String? ?? '',
      exported: map['exported'] as bool? ?? true,
      isVoiceOrAssist: map['isVoiceOrAssist'] as bool? ?? false,
    );
  }

  String get simpleName => name.contains('.') ? name.split('.').last : name;
  String get shortName => simpleName;

  @override
  String toString() => '$label ($name)';
}

/// Service managing discovery and routing to installed voice assistant applications.
class AssistantRoutingService {
  AssistantRoutingService._();
  static final AssistantRoutingService instance = AssistantRoutingService._();

  static const MethodChannel _channel = MethodChannel('arcane/assistant');

  /// Queries the Android OS for all installed applications that declare an
  /// Assistant or Voice manifest intent filter.
  Future<List<InstalledAssistant>> getInstalledAssistants() async {
    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>('getInstalledAssistants');
      if (rawList == null) return const [];

      final results = <InstalledAssistant>[];
      for (final item in rawList) {
        if (item is Map) {
          final pkg = item['package'] as String? ?? '';
          final label = item['label'] as String? ?? pkg;
          if (pkg.isNotEmpty) {
            results.add(InstalledAssistant(package: pkg, label: label));
          }
        }
      }
      return results;
    } catch (e) {
      debugPrint('[AssistantRoutingService] Error querying installed assistants: $e');
      return const [];
    }
  }

  /// Queries all applications installed on the device.
  Future<List<InstalledAppInfo>> getAllInstalledApps() async {
    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>('getAllInstalledApps');
      if (rawList == null) return const [];

      final results = <InstalledAppInfo>[];
      for (final item in rawList) {
        if (item is Map) {
          results.add(InstalledAppInfo.fromMap(item));
        }
      }
      return results;
    } catch (e) {
      debugPrint('[AssistantRoutingService] Error querying all installed apps: $e');
      return const [];
    }
  }

  /// Queries all Activities declared by the specified application package.
  Future<List<AppActivityInfo>> getAppActivities(String package) async {
    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>('getAppActivities', {
        'package': package,
      });
      if (rawList == null) return const [];

      final results = <AppActivityInfo>[];
      for (final item in rawList) {
        if (item is Map) {
          results.add(AppActivityInfo.fromMap(item));
        }
      }
      return results;
    } catch (e) {
      debugPrint('[AssistantRoutingService] Error querying app activities for $package: $e');
      return const [];
    }
  }

  /// Launches an external assistant application directly into voice/mic listening mode.
  Future<bool> launchVoiceMode(String package, {String? activity}) async {
    try {
      final success = await _channel.invokeMethod<bool>('launchAssistantPackage', {
        'package': package,
        if (activity != null && activity.isNotEmpty) 'activity': activity,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('[AssistantRoutingService] Error launching assistant $package: $e');
      return false;
    }
  }

  /// Explicitly routes audio communication to connected Bluetooth devices.
  Future<bool> routeBluetoothAudio(bool enable) async {
    try {
      final success = await _channel.invokeMethod<bool>('routeAudioToBluetooth', {
        'enable': enable,
      });
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Launches an application package.
  Future<bool> launchPackage(String package) async {
    try {
      final success = await _channel.invokeMethod<bool>('launchPackage', {
        'package': package,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('[AssistantRoutingService] Error launching package $package: $e');
      return false;
    }
  }

  /// Launches a system intent action (phone, messages, camera, clock, settings, gallery).
  Future<bool> launchIntentAction(String action) async {
    try {
      final success = await _channel.invokeMethod<bool>('launchIntentAction', {
        'action': action,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('[AssistantRoutingService] Error launching action $action: $e');
      return false;
    }
  }

  /// Fetches PNG bytes for an installed app's icon.
  Future<Uint8List?> getAppIcon(String package) async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'package': package,
      });
      return bytes;
    } catch (e) {
      return null;
    }
  }

  /// Checks whether Arcane has permission to draw overlays (SYSTEM_ALERT_WINDOW).
  Future<bool> canDrawOverlays() async {
    try {
      final res = await _channel.invokeMethod<bool>('canDrawOverlays');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Opens the system settings screen for "Display over other apps" permission.
  Future<bool> openOverlaySettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openOverlaySettings');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Gets the current mic tap calibration method ('reticle', 'touch_sensor', 'auto_detect', 'manual_coords').
  Future<String> getCalibrationMethod() async {
    try {
      final res = await _channel.invokeMethod<String>('getCalibrationMethod');
      return res ?? 'reticle';
    } catch (e) {
      return 'reticle';
    }
  }

  /// Sets the preferred mic tap calibration method.
  Future<bool> setCalibrationMethod(String method) async {
    try {
      final res = await _channel.invokeMethod<bool>('setCalibrationMethod', {
        'method': method,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Gets the preferred overlay window type ('auto', 'application', 'accessibility').
  Future<String> getOverlayWindowType() async {
    try {
      final res = await _channel.invokeMethod<String>('getOverlayWindowType');
      return res ?? 'auto';
    } catch (e) {
      return 'auto';
    }
  }

  /// Sets the preferred overlay window type ('auto', 'application', 'accessibility').
  Future<bool> setOverlayWindowType(String type) async {
    try {
      final res = await _channel.invokeMethod<bool>('setOverlayWindowType', {
        'type': type,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Sets manual normalized screen coordinates (xRatio: 0.0 - 1.0, yRatio: 0.0 - 1.0).
  Future<bool> setManualCoordinates(String package, double xRatio, double yRatio) async {
    try {
      final res = await _channel.invokeMethod<bool>('setManualCoordinates', {
        'package': package,
        'xRatio': xRatio,
        'yRatio': yRatio,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Starts first-time tap recording for an external assistant package.
  Future<bool> startRecordingTap(String package, {String? method}) async {
    try {
      final success = await _channel.invokeMethod<bool>('startRecordingTap', {
        'package': package,
        if (method != null) 'method': method,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('[AssistantRoutingService] Error starting tap recording: $e');
      return false;
    }
  }

  /// Checks if a package has a recorded auto-tap signature.
  Future<bool> hasRecordedTap(String package) async {
    try {
      final has = await _channel.invokeMethod<bool>('hasRecordedTap', {
        'package': package,
      });
      return has ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Clears recorded auto-tap signature for a package.
  Future<bool> clearRecordedTap(String package) async {
    try {
      final success = await _channel.invokeMethod<bool>('clearRecordedTap', {
        'package': package,
      });
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Retrieves details of recorded auto-tap for a package.
  Future<Map<String, dynamic>?> getRecordedTapInfo(String package) async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getRecordedTapInfo', {
        'package': package,
      });
      return raw == null ? null : Map<String, dynamic>.from(raw);
    } catch (e) {
      return null;
    }
  }

  /// Gets floating Nora overlay status.
  Future<Map<String, dynamic>> getNoraBubbleStatus() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getNoraBubbleStatus');
      return raw == null ? const {} : Map<String, dynamic>.from(raw);
    } catch (e) {
      return const {};
    }
  }

  /// Enables or disables floating Nora overlay.
  Future<bool> setNoraBubbleEnabled(bool enabled) async {
    try {
      final success = await _channel.invokeMethod<bool>('setNoraBubbleEnabled', {
        'enabled': enabled,
      });
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Enables or disables using floating Nora for watch / Bluetooth triggers.
  Future<bool> setNoraWatchFloating(bool enabled) async {
    try {
      final success = await _channel.invokeMethod<bool>('setNoraWatchFloating', {
        'enabled': enabled,
      });
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Summons floating Nora HUD and begins hands-free listening immediately.
  Future<bool> summonFloatingNora() async {
    try {
      final success = await _channel.invokeMethod<bool>('summonFloatingNora');
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Starts lock screen unlock gesture calibration session:
  /// Locks the device, turns screen back on, captures unlock motion (e.g. swipe up),
  /// and saves it automatically when the device is unlocked.
  Future<bool> startRecordingUnlockGesture() async {
    try {
      final success = await _channel.invokeMethod<bool>('startRecordingUnlockGesture');
      return success ?? false;
    } catch (e) {
      debugPrint('[AssistantRoutingService] Error starting unlock gesture calibration: $e');
      return false;
    }
  }

  /// Tests the recorded unlock gesture by locking device, waking up, and dispatching gesture.
  Future<bool> testUnlockGesture() async {
    try {
      final success = await _channel.invokeMethod<bool>('testUnlockGesture');
      return success ?? false;
    } catch (e) {
      debugPrint('[AssistantRoutingService] Error testing unlock gesture: $e');
      return false;
    }
  }

  /// Clears the recorded lock screen unlock gesture.
  Future<bool> clearUnlockGesture() async {
    try {
      final success = await _channel.invokeMethod<bool>('clearUnlockGesture');
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Retrieves the recorded lock screen unlock gesture info.
  Future<Map<String, dynamic>?> getUnlockGestureInfo() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getUnlockGestureInfo');
      return raw == null ? null : Map<String, dynamic>.from(raw);
    } catch (e) {
      return null;
    }
  }

  /// Checks if a lock screen unlock gesture is recorded.
  Future<bool> hasUnlockGesture() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasUnlockGesture');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }
}
