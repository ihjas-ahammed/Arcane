import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native Android Speech-To-Text (STT) service interfacing via MethodChannel.
/// Automatically records and transcribes voice input directly from Bluetooth
/// headsets or device microphones.
class SttService {
  SttService._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }
  static final SttService instance = SttService._();

  static const MethodChannel _channel = MethodChannel('arcane/stt');

  final ValueNotifier<bool> isListening = ValueNotifier<bool>(false);
  final ValueNotifier<double> currentRms = ValueNotifier<double>(0.0);
  final ValueNotifier<String> lastTranscription = ValueNotifier<String>('');

  ValueChanged<String>? _onResultCallback;
  ValueChanged<String>? _onPartialCallback;
  VoidCallback? _onListeningCallback;
  ValueChanged<String>? _onErrorCallback;

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onListening':
        final active = call.arguments as bool? ?? false;
        isListening.value = active;
        if (active) {
          _onListeningCallback?.call();
        }
        break;
      case 'onSpeechStart':
        isListening.value = true;
        break;
      case 'onSpeechEnd':
        isListening.value = false;
        break;
      case 'onRmsChanged':
        final rms = (call.arguments as num?)?.toDouble() ?? 0.0;
        currentRms.value = rms;
        break;
      case 'onPartialResult':
        final partial = call.arguments as String? ?? '';
        lastTranscription.value = partial;
        _onPartialCallback?.call(partial);
        break;
      case 'onResult':
        final result = call.arguments as String? ?? '';
        isListening.value = false;
        lastTranscription.value = result;
        _onResultCallback?.call(result);
        break;
      case 'onError':
        final err = call.arguments as String? ?? 'Recognition error';
        isListening.value = false;
        _onErrorCallback?.call(err);
        break;
      default:
        break;
    }
  }

  /// Starts listening for voice input.
  Future<bool> startListening({
    ValueChanged<String>? onResult,
    ValueChanged<String>? onPartial,
    VoidCallback? onListening,
    ValueChanged<String>? onError,
  }) async {
    _onResultCallback = onResult;
    _onPartialCallback = onPartial;
    _onListeningCallback = onListening;
    _onErrorCallback = onError;

    try {
      final success = await _channel.invokeMethod<bool>('startListening');
      return success ?? false;
    } catch (e) {
      debugPrint('[SttService] startListening error: $e');
      _onErrorCallback?.call(e.toString());
      return false;
    }
  }

  /// Stops speech recognition listening.
  Future<bool> stopListening() async {
    try {
      final success = await _channel.invokeMethod<bool>('stopListening');
      isListening.value = false;
      return success ?? false;
    } catch (e) {
      debugPrint('[SttService] stopListening error: $e');
      return false;
    }
  }

  /// Checks if microphone permission is currently granted.
  Future<bool> hasPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('hasPermission');
      return granted ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Requests microphone (and Bluetooth connect on Android 12+) permission from system.
  Future<bool> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if native speech recognition is available on this system.
  Future<bool> isAvailable() async {
    try {
      final available = await _channel.invokeMethod<bool>('isAvailable');
      return available ?? false;
    } catch (e) {
      return false;
    }
  }
}
