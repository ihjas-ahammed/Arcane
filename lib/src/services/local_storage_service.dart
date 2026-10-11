import 'dart:convert';
import 'package:missions/src/services/web_state_store.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:missions/src/services/app_storage_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:missions/src/services/state_database.dart';

// Top-level function for isolate
String _encodeJson(Map<String, dynamic> data) => jsonEncode(data);
Map<String, dynamic> _decodeJson(String json) => jsonDecode(json);
String _entityKey(String key) => base64Url.encode(utf8.encode(key)).replaceAll('=', '');
Map<String, String> _encodeCollections(Map<String, dynamic> data) {
  final result = <String, String>{};
  for (final e in data.entries) {
    if (e.key == 'completedByDay' && e.value is Map) {
      final days = e.value as Map;
      final keys = days.keys.map((k) => k.toString()).toList();
      result[e.key] = jsonEncode({'_partitioned': true, 'keys': keys});
      for (final key in keys) { result['history:${_entityKey(key)}'] = jsonEncode(days[key]); }
    } else if (e.key == 'reflectionLogs' && e.value is List) {
      final logs = e.value as List;
      final keys = <String>[];
      for (var i=0; i<logs.length; i++) {
        final id = logs[i] is Map ? (logs[i]['id'] ?? 'index-$i').toString() : 'index-$i';
        if (keys.contains(id)) throw StateError('Duplicate reflection id: $id');
        keys.add(id);
        result['reflection:${_entityKey(id)}'] = jsonEncode(logs[i]);
      }
      result[e.key] = jsonEncode({'_partitioned': true, 'keys': keys});
    } else { result[e.key] = jsonEncode(e.value); }
  }
  return result;
}
Map<String, dynamic> _decodeCollections(Map<String, String> rows) {
  final result = <String, dynamic>{};
  for (final e in rows.entries) {
    if (!e.key.startsWith('history:') && !e.key.startsWith('reflection:')) result[e.key] = jsonDecode(e.value);
  }
  for (final name in ['completedByDay', 'reflectionLogs']) {
    final value = result[name];
    if (value is! Map || value['_partitioned'] != true) continue;
    final keys = List<String>.from(value['keys'] as List);
    final prefix = name == 'completedByDay' ? 'history' : 'reflection';
    final entities = <String, dynamic>{};
    for (final key in keys) {
      final json = rows['$prefix:${_entityKey(key)}'];
      if (json == null) throw StateError('Missing local $prefix record: $key');
      entities[key] = jsonDecode(json);
    }
    result[name] = name == 'completedByDay' ? entities : entities.values.toList();
  }
  return result;
}

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
  static final Map<String, DateTime> _lastDailyBackupAt = {};

  /// Saves run one at a time (across all instances). Overlapping saves used to share the same
  /// .tmp file: one save's rename would move the other's data, the second rename then failed
  /// ("Cannot rename file"), and an older snapshot could land after a newer one.
  static Future<void> _saveQueue = Future.value();
  static int _cacheGeneration = -1;

  Future<File> _localFile(String userId) async {
    final directory = await AppStoragePaths.directory();
    return File('${directory.path}/arcane_local_cache_$userId.json');
  }

  Future<File> _backupFile(String userId) async {
    final directory = await AppStoragePaths.directory();
    return File('${directory.path}/arcane_local_cache_$userId.bak');
  }

  Future<Directory> _backupDirectory() async {
    final directory = await AppStoragePaths.directory();
    final dir = Directory('${directory.path}/backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> flushPendingSaves() => _saveQueue;

  Future<File?> writeSnapshot(String userId, Map<String, dynamic> data, String reason) async {
    if (kIsWeb) {
      await WebStateStore.write('recovery_$userId', await compute(_encodeJson, data));
      return null;
    }
    final dir = await _backupDirectory();
    final file = File('${dir.path}/${reason}_${userId}_${DateTime.now().microsecondsSinceEpoch}.json');
    final json = await compute(_encodeJson, data);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(file.path);
    await _pruneNamedBackups(dir, '${reason}_${userId}_', 30);
    return file;
  }

  Future<void> saveState(String userId, Map<String, dynamic> state, {bool partial = false}) {
    final run = _saveQueue.then((_) => _saveStateNow(userId, state, partial: partial));
    _saveQueue = run.catchError((_) {});
    return run;
  }

  Future<void> _saveStateNow(String userId, Map<String, dynamic> state, {bool partial = false}) async {
    try {
      if (kIsWeb) {
        final old = await WebStateStore.read(userId);
        final payload = partial && old != null ? {...jsonDecode(old) as Map<String, dynamic>, ...state} : state;
        final jsonString = jsonEncode(payload);
        await WebStateStore.write(userId, jsonString);
        return;
      }
      if (_cacheGeneration != StateDatabase.instance.generation) {
        _lastWritten.clear(); _lastDailyBackupDay.clear(); _lastDailyBackupAt.clear();
        _cacheGeneration = StateDatabase.instance.generation;
      }
      final encoded = await compute(_encodeCollections, state);
      final previous = _lastWritten[userId] ?? await StateDatabase.instance.readCollections(userId);
      _lastWritten[userId] = previous;
      final changes = <String, String?>{};
      for (final e in encoded.entries) {
        if (previous[e.key] != e.value) changes[e.key] = e.value;
      }
      for (final key in previous.keys) {
        final replacedPartition = (state.containsKey('completedByDay') && key.startsWith('history:')) || (state.containsKey('reflectionLogs') && key.startsWith('reflection:'));
        if ((!partial || replacedPartition) && !encoded.containsKey(key)) changes[key] = null;
      }
      if (changes.isNotEmpty) {
        await StateDatabase.instance.writeCollections(userId, changes);
        final merged = partial ? {...previous, ...encoded} : encoded;
        for (final e in changes.entries) { if (e.value == null) merged.remove(e.key); }
        _lastWritten[userId] = merged;
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (_lastDailyBackupDay[userId] != today || DateTime.now().difference(_lastDailyBackupAt[userId] ?? DateTime(1970)) >= const Duration(hours: 2)) {
        final complete = partial ? await compute(_decodeCollections, _lastWritten[userId] ?? encoded) : state;
        await performDailyBackup(userId, complete);
        _lastDailyBackupDay[userId] = today;
        _lastDailyBackupAt[userId] = DateTime.now();
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

      if (kIsWeb) return;

      final backupDir = await _backupDirectory();
      final backupFile = File('${backupDir.path}/daily_backup_${userId}_$todayStr.json');
      final String jsonString = precomputedJson ?? await compute(_encodeJson, state);

      if (await backupFile.exists()) {
        final existingLength = await backupFile.length();
        if (existingLength > 0) {
          // Guard against replacing a healthy snapshot with an empty or drastically shrunken one (< 70%)
          if (utf8.encode(jsonString).length < (existingLength * 0.7)) {
            debugPrint("[LocalStorageService] Preserving existing daily backup: incoming payload (${jsonString.length} bytes) is substantially smaller than current snapshot ($existingLength bytes)");
            final shrunk = File('${backupFile.path}.shrunk-${now.millisecondsSinceEpoch}.json');
            final tmp = File('${shrunk.path}.tmp');
            await tmp.writeAsString(jsonString, flush: true);
            await tmp.rename(shrunk.path);
            await _pruneNamedBackups(backupDir, 'daily_backup_${userId}_', 30);
            return;
          }
        }
      }

      final tempFile = File('${backupFile.path}.tmp');
      await tempFile.writeAsString(jsonString, flush: true);
      await tempFile.rename(backupFile.path);
      debugPrint("[LocalStorageService] Auto daily backup updated: ${backupFile.path}");

      final monday = now.subtract(Duration(days: now.weekday - 1)).toIso8601String().substring(0, 10);
      final month = todayStr.substring(0, 7);
      for (final name in ['weekly_backup_${userId}_$monday.json', 'monthly_backup_${userId}_$month.json']) {
        final copy = File('${backupDir.path}/$name');
        // The period's first verified snapshot stays immutable.
        if (!await copy.exists()) {
          final tmp = File('${copy.path}.tmp');
          await tmp.writeAsString(jsonString, flush: true);
          await tmp.rename(copy.path);
        }
      }
      await _pruneDailyBackups(backupDir, userId);
      await _pruneNamedBackups(backupDir, 'weekly_backup_${userId}_', 4);
      await _pruneNamedBackups(backupDir, 'monthly_backup_${userId}_', 6);
    } catch (e) {
      debugPrint("[LocalStorageService] Auto daily backup failed: $e");
    }
  }

  Future<void> _pruneNamedBackups(Directory dir, String prefix, int keep) async {
    final files = (await dir.list().toList()).whereType<File>().where((f) => f.uri.pathSegments.last.startsWith(prefix) && f.path.endsWith('.json')).toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    for (final file in files.skip(keep)) { await file.delete(); }
  }

  Future<void> _pruneDailyBackups(Directory backupDir, String userId) async {
    try {
      final prefix = 'daily_backup_${userId}_';
      final entities = await backupDir.list().toList();
      final files = entities.whereType<File>().where((f) {
        final name = f.uri.pathSegments.last;
        return name.startsWith(prefix) && name.endsWith('.json') && !name.contains('.shrunk-');
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

  Future<File?> getLatestDailyBackup(String userId) async {
    if (kIsWeb) return null;
    try {
      final backupDir = await _backupDirectory();
      final prefix = 'daily_backup_${userId}_';
      final files = (await backupDir.list().toList()).whereType<File>().where((f) {
        final name = f.uri.pathSegments.last;
        return name.startsWith(prefix) && name.endsWith('.json') && !name.contains('.shrunk-');
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
        return name.startsWith(prefix) && name.endsWith('.json') && !name.contains('.shrunk-');
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
    await flushPendingSaves();
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final saved = await WebStateStore.read(userId);
      final contents = saved ?? prefs.getString('arcane_local_cache_$userId');
      if (contents == null || contents.isEmpty) return null;
      final state = await _decodeOrThrow(contents, 'browser cache');
      if (saved == null) await WebStateStore.write(userId, contents);
      return state;
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
  /// Read-back verification runs inside the transaction; failure rolls back the replacement.
  Future<void> importStateIntoDatabase(String userId, Map<String, dynamic> data) {
    final run = _saveQueue.then((_) => _importStateNow(userId, data));
    _saveQueue = run.catchError((_) {});
    return run;
  }

  Future<void> _importStateNow(String userId, Map<String, dynamic> data) async {
    if (kIsWeb) {
      final old = await WebStateStore.read(userId);
      if (old != null) await WebStateStore.write('recovery_$userId', old);
      final encoded = await compute(_encodeJson, data);
      await WebStateStore.write(userId, encoded);
      if (await WebStateStore.read(userId) != encoded) throw StateError('Browser import verification failed');
      return;
    }
    final encoded = await compute(_encodeCollections, data);
    try {
      final backups = await _backupDirectory();
      final previous = await StateDatabase.instance.readCollections(userId);
      if (previous.isNotEmpty) {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final preserved = File('${backups.path}/before_import_${userId}_$stamp.json');
        final previousJson = await compute(_encodeJson, await compute(_decodeCollections, previous));
        final tmp = File('${preserved.path}.tmp');
        await tmp.writeAsString(previousJson, flush: true);
        await tmp.rename(preserved.path);
      }
      await StateDatabase.instance.replaceUser(userId, encoded);
      // replaceUser verifies before committing. Cleanup failure must never turn
      // an already-committed import into a reported replacement failure.
      _lastWritten[userId] = encoded;
      try {
        await _pruneNamedBackups(backups, 'before_import_${userId}_', 30);
        final legacy = await _localFile(userId);
        if (await legacy.exists()) {
          await legacy.rename('${legacy.path}.migrated-${DateTime.now().microsecondsSinceEpoch}');
        }
      } catch (e) { debugPrint('Import cleanup deferred; original recovery files remain: $e'); }
      debugPrint("[LocalStorageService] Imported ${encoded.length} collections into the local database");
    } catch (e, stack) {
      // replaceUser verifies inside its transaction; a failure preserves the old rows.
      throw LocalStateException('Importing the data into the local database failed.', '$e\n$stack');
    }
  }

  Future<void> clearState(String userId) {
    final run = _saveQueue.then((_) => _clearStateNow(userId));
    _saveQueue = run.catchError((_) {});
    return run;
  }

  Future<void> _clearStateNow(String userId) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await WebStateStore.remove(userId);
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
      rethrow;
    }
  }
}
