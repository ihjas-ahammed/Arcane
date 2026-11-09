import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

String _encodeBackup(Map<String, dynamic> data) => jsonEncode(data);

/// Full JSON backups written every time a daily briefing is made.
/// Files go to /sdcard/Backups (needs All Files Access). Without it they go to the app's
/// documents folder and [lastWroteToFallback] is set so Settings can ask for the permission.
class BriefingBackupService {
  BriefingBackupService._();

  static const backupDirPath = '/sdcard/Backups';
  static const _channel = MethodChannel('arcane/storage');

  static bool lastWroteToFallback = false;

  static Future<bool> hasAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> requestAllFilesAccess() async {
    try {
      await _channel.invokeMethod<void>('requestAllFilesAccess');
    } on PlatformException catch (e) {
      debugPrint('[BriefingBackup] request failed: $e');
    } on MissingPluginException {
      debugPrint('[BriefingBackup] storage channel not available');
    }
  }

  /// Writes [state] (the full app state, the same content as a normal backup) as JSON.
  /// Returns the file written, or null if nothing could be written. Never throws.
  static Future<File?> writeFullBackup({
    required String label,
    required Map<String, dynamic> state,
  }) async {
    try {
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final name = 'arcane_full_${label}_$stamp.json';
      final json = await compute(_encodeBackup, state);

      final allowed = await hasAllFilesAccess();
      lastWroteToFallback = !allowed;
      final dir = allowed
          ? Directory(backupDirPath)
          : Directory('${(await getApplicationDocumentsDirectory()).path}/Backups');
      await dir.create(recursive: true);

      final file = File('${dir.path}/$name');
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(file.path);
      debugPrint('[BriefingBackup] wrote ${file.path} (${json.length} bytes)');
      return file;
    } catch (e) {
      debugPrint('[BriefingBackup] failed: $e');
      return null;
    }
  }
}
