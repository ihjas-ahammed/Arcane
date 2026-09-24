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
}
