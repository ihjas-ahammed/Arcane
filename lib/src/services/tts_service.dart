import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service providing native Android Text-To-Speech capabilities via MethodChannel.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  static const MethodChannel _channel = MethodChannel('arcane/tts');

  /// Speaks the provided text via the native Android TTS engine.
  /// Automatically strips markdown syntax for natural voice synthesis.
  Future<bool> speak(
    String text, {
    double pitch = 1.0,
    double rate = 1.0,
  }) async {
    final cleaned = _sanitizeForSpeech(text);
    if (cleaned.trim().isEmpty) return false;

    try {
      final result = await _channel.invokeMethod<bool>('speak', {
        'text': cleaned,
        'pitch': pitch,
        'rate': rate,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('[TtsService] Error speaking text: $e');
      return false;
    }
  }

  /// Stops any ongoing speech synthesis.
  Future<bool> stop() async {
    try {
      final result = await _channel.invokeMethod<bool>('stop');
      return result ?? false;
    } catch (e) {
      debugPrint('[TtsService] Error stopping TTS: $e');
      return false;
    }
  }

  /// Checks if TTS is currently synthesizing or speaking.
  Future<bool> isSpeaking() async {
    try {
      final result = await _channel.invokeMethod<bool>('isSpeaking');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Strips markdown characters and code blocks to produce natural sounding speech.
  String _sanitizeForSpeech(String input) {
    var s = input;
    // Strip fenced code blocks ``` ... ```
    s = s.replaceAll(RegExp(r'```[\s\S]*?```'), ' code block omitted ');
    // Strip inline code `...`
    s = s.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    // Strip markdown links [text](url) -> text
    s = s.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');
    // Strip headers #, ##, etc.
    s = s.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
    // Strip bold/italics * or _
    s = s.replaceAll(RegExp(r'[*_]{1,3}'), '');
    // Strip blockquotes >
    s = s.replaceAll(RegExp(r'^\s*>\s*', multiLine: true), '');
    // Strip bullet points
    s = s.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    // Replace multiple newlines or spaces with single space
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }
}
