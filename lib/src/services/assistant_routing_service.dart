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

  /// Launches an external assistant application directly into voice/mic listening mode.
  Future<bool> launchVoiceMode(String package) async {
    try {
      final success = await _channel.invokeMethod<bool>('launchAssistantPackage', {
        'package': package,
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
