import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:missions/src/services/state_database.dart';

// Top-level function for isolate
String _encodeJson(Map<String, dynamic> data) => jsonEncode(data);
Map<String, dynamic> _decodeJson(String json) => jsonDecode(json);
Map<String, String> _encodeCollections(Map<String, dynamic> data) =>
    {for (final e in data.entries) e.key: jsonEncode(e.value)};
Map<String, dynamic> _decodeCollections(Map<String, String> rows) =>
    {for (final e in rows.entries) e.key: jsonDecode(e.value)};

/// A local save could not be read or written. [details] holds the raw error and stack trace so
/// the user can copy it.
class LocalStateException implements Exception {
  const LocalStateException(this.message, this.details);

  final String message;
  final String details;

  @override
  String toString() => '$message\n\n$details';
}

class LocalStorageService {
  /// Last JSON text written per collection, so a save only rewrites collections that changed.
  static final Map<String, Map<String, String>> _lastWritten = {};
  static final Map<String, String> _lastDailyBackupDay = {};

  /// Saves run one at a time (across all instances). Overlapping saves used to share the same
  /// .tmp file: one save's rename would move the other's data, the second rename then failed
  /// ("Cannot rename file"), and an older snapshot could land after a newer one.
  static Future<void> _saveQueue = Future.value();

  Future<File> _localFile(String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/arcane_local_cache_$userId.json');
  }

  Future<File> _backupFile(String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/arcane_local_cache_$userId.bak');
  }

  Future<Directory> _backupDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final dir = Directory('${directory.path}/backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> saveState(String userId, Map<String, dynamic> state) {
    final run = _saveQueue.then((_) => _saveStateNow(userId, state));
    _saveQueue = run.catchError((_) {});
    return run;
  }

  Future<void> _saveStateNow(String userId, Map<String, dynamic> state) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = jsonEncode(state);
        await prefs.setString('arcane_local_cache_$userId', jsonString);
        return;
      }
      final encoded = await compute(_encodeCollections, state);
      final previous = _lastWritten[userId] ?? const <String, String>{};
      final changes = <String, String?>{};
      for (final e in encoded.entries) {
        if (previous[e.key] != e.value) changes[e.key] = e.value;
      }
      for (final key in previous.keys) {
        if (!encoded.containsKey(key)) changes[key] = null;
      }
      if (changes.isNotEmpty) {
        await StateDatabase.instance.writeCollections(userId, changes);
        _lastWritten[userId] = encoded;
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (_lastDailyBackupDay[userId] != today) {
        await performDailyBackup(userId, state);
        _lastDailyBackupDay[userId] = today;
      }
    } catch (e) {
      debugPrint("LocalStorage Save Error: $e");
      // Surface the failure so the caller can retry: a swallowed error here is silent data loss.
      rethrow;
    }
  }

  /// Automatically creates a daily snapshot for [userId] (one per calendar day)
  /// and automatically prunes any snapshots beyond the 7 most recent days.
  Future<void> performDailyBackup(
    String userId,
    Map<String, dynamic> state, {
    String? precomputedJson,
  }) async {
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      if (kIsWeb) {
        await _performWebDailyBackup(userId, state, todayStr, precomputedJson);
        return;
      }

      final backupDir = await _backupDirectory();
      final backupFile = File('${backupDir.path}/daily_backup_${userId}_$todayStr.json');
      final String jsonString = precomputedJson ?? await compute(_encodeJson, state);

      if (await backupFile.exists()) {
        final existingLength = await backupFile.length();
        if (existingLength > 0) {
          // Guard against replacing a healthy snapshot with an empty or drastically shrunken one (< 70%)
          if (jsonString.length < (existingLength * 0.7)) {
            debugPrint("[LocalStorageService] Preserving existing daily backup: incoming payload (${jsonString.length} bytes) is substantially smaller than current snapshot ($existingLength bytes)");
            return;
          }
        }
      }

      final tempFile = File('${backupFile.path}.tmp');
      await tempFile.writeAsString(jsonString, flush: true);
      await tempFile.rename(backupFile.path);
      debugPrint("[LocalStorageService] Auto daily backup updated: ${backupFile.path}");

      // Prune backups beyond the 7 most recent days
      await _pruneDailyBackups(backupDir, userId);
    } catch (e) {
      debugPrint("[LocalStorageService] Auto daily backup failed: $e");
    }
  }

  Future<void> _pruneDailyBackups(Directory backupDir, String userId) async {
    try {
      final prefix = 'daily_backup_${userId}_';
      final entities = await backupDir.list().toList();
      final files = entities.whereType<File>().where((f) {
        final name = f.uri.pathSegments.last;
        return name.startsWith(prefix) && name.endsWith('.json');
      }).toList();

      // Sort descending by filename (ISO date string YYYY-MM-DD sorts chronologically)
      files.sort((a, b) => b.uri.pathSegments.last.compareTo(a.uri.pathSegments.last));

      // Keep up to 7 days of recovery data
      if (files.length > 7) {
        for (int i = 7; i < files.length; i++) {
          try {
            await files[i].delete();
            debugPrint("[LocalStorageService] Pruned daily backup beyond 7 days: ${files[i].path}");
          } catch (e) {
            debugPrint("[LocalStorageService] Error pruning old backup: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("[LocalStorageService] _pruneDailyBackups error: $e");
    }
  }

  Future<void> _performWebDailyBackup(
    String userId,
    Map<String, dynamic> state,
    String todayStr,
    String? precomputedJson,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'arcane_daily_backup_${userId}_$todayStr';
    final String jsonString = precomputedJson ?? jsonEncode(state);

    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) {
      if (jsonString.length < (existing.length * 0.7)) {
        debugPrint("[LocalStorageService/web] Preserving existing daily backup: incoming payload is smaller than current");
        return;
      }
    }

    await prefs.setString(key, jsonString);

    final datesKey = 'arcane_daily_backup_dates_$userId';
    final dates = prefs.getStringList(datesKey) ?? <String>[];
    if (!dates.contains(todayStr)) {
      dates.add(todayStr);
      dates.sort((a, b) => b.compareTo(a)); // Newest first
      while (dates.length > 7) {
        final oldest = dates.removeLast();
        await prefs.remove('arcane_daily_backup_${userId}_$oldest');
      }
      await prefs.setStringList(datesKey, dates);
    }
  }

  Future<File?> getLatestDailyBackup(String userId) async {
    if (kIsWeb) return null;
    try {
      final backupDir = await _backupDirectory();
      final prefix = 'daily_backup_${userId}_';
      final files = (await backupDir.list().toList()).whereType<File>().where((f) {
        final name = f.uri.pathSegments.last;
        return name.startsWith(prefix) && name.endsWith('.json');
      }).toList();
      if (files.isEmpty) return null;
      files.sort((a, b) => b.uri.pathSegments.last.compareTo(a.uri.pathSegments.last));
      return files.first;
    } catch (_) {
      return null;
    }
  }

  Future<List<File>> getDailyBackupFiles(String userId) async {
    if (kIsWeb) return [];
    try {
      final backupDir = await _backupDirectory();
      final prefix = 'daily_backup_${userId}_';
      final files = (await backupDir.list().toList()).whereType<File>().where((f) {
        final name = f.uri.pathSegments.last;
        return name.startsWith(prefix) && name.endsWith('.json');
      }).toList();
      files.sort((a, b) => b.uri.pathSegments.last.compareTo(a.uri.pathSegments.last));
      return files;
    } catch (_) {
      return [];
    }
  }

  /// Loads the saved state for [userId]. Returns null only when nothing is saved yet.
  ///
  /// Read or parse failures throw [LocalStateException]. There is deliberately no fallback to
  /// the older .bak file, the daily backups, or the cloud: those can be hours old, and loading
  /// them silently is what replaced recent data. The caller shows the error so it can be fixed.
  Future<Map<String, dynamic>?> loadState(String userId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final contents = prefs.getString('arcane_local_cache_$userId');
      if (contents == null || contents.isEmpty) return null;
      return _decodeOrThrow(contents, 'browser cache');
    }

    Map<String, String> rows;
    try {
      rows = await StateDatabase.instance.readCollections(userId);
    } catch (e, stack) {
      throw LocalStateException('The local database could not be read.', '$e\n$stack');
    }
    if (rows.isNotEmpty) {
      _lastWritten[userId] = rows;
      try {
        return await compute(_decodeCollections, rows);
      } catch (e, stack) {
        throw LocalStateException('A collection in the local database is not valid JSON.', '$e\n$stack');
      }
    }

    final file = await _localFile(userId);
    if (!await file.exists()) return null;
    final String contents;
    try {
      contents = await file.readAsString();
    } catch (e, stack) {
      throw LocalStateException('The JSON cache file could not be read: ${file.path}', '$e\n$stack');
    }
    final legacy = await _decodeOrThrow(contents, file.path);
    await importStateIntoDatabase(userId, legacy);
    return legacy;
  }

  Future<Map<String, dynamic>> _decodeOrThrow(String text, String source) async {
    if (text.trim().isEmpty) {
      throw LocalStateException('The JSON file is empty.', source);
    }
    try {
      return await compute(_decodeJson, text);
    } catch (e, stack) {
      throw LocalStateException('The JSON file could not be parsed ($source).', '$e\n$stack');
    }
  }

  /// Replaces everything stored for [userId] with [data]. Used on first launch after the SQLite
  /// switch, and by "Load JSON into database". The previous rows are copied to backups/ first.
  /// If the stored copy does not read back identically, the new rows are removed again and
  /// [LocalStateException] is thrown.
  Future<void> importStateIntoDatabase(String userId, Map<String, dynamic> data) async {
    final encoded = await compute(_encodeCollections, data);
    try {
      final backups = await _backupDirectory();
      final previous = await StateDatabase.instance.readCollections(userId);
      if (previous.isNotEmpty) {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final preserved = File('${backups.path}/before_import_${userId}_$stamp.json');
        final previousJson = '{${previous.entries.map((e) => '"${e.key}":${e.value}').join(',')}}';
        await preserved.writeAsString(previousJson, flush: true);
      }
      await StateDatabase.instance.replaceUser(userId, encoded);
      final verified = await StateDatabase.instance.readCollections(userId);
      if (!mapEquals(verified, encoded)) {
        throw StateError('stored copy does not match the imported data');
      }
      _lastWritten[userId] = verified;
      debugPrint("[LocalStorageService] Imported ${encoded.length} collections into the local database");
    } catch (e, stack) {
      await StateDatabase.instance.deleteUser(userId);
      _lastWritten.remove(userId);
      throw LocalStateException('Importing the data into the local database failed.', '$e\n$stack');
    }
  }

  Future<void> clearState(String userId) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('arcane_local_cache_$userId');
        return;
      }
      _lastWritten.remove(userId);
      await StateDatabase.instance.deleteUser(userId);
      final file = await _localFile(userId);
      if (await file.exists()) {
        await file.delete();
      }
      final backup = await _backupFile(userId);
      if (await backup.exists()) {
        await backup.delete();
      }
    } catch (e) {
      debugPrint("LocalStorage Clear Error: $e");
    }
  }
}