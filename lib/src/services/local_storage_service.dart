import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Top-level function for isolate
String _encodeJson(Map<String, dynamic> data) => jsonEncode(data);
Map<String, dynamic> _decodeJson(String json) => jsonDecode(json);

class LocalStorageService {
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
      final file = await _localFile(userId);
      final backup = await _backupFile(userId);
      final tempFile = File('${file.path}.tmp');

      // Offload heavy JSON serialization to a background isolate
      final jsonString = await compute(_encodeJson, state);

      // 1. Atomic write: write complete data to .tmp and flush to disk
      await tempFile.writeAsString(jsonString, flush: true);

      // 2. Rotate previous valid cache into .bak for disaster recovery
      if (await file.exists()) {
        try {
          await file.copy(backup.path);
        } catch (_) {}
      }

      // 3. Atomically replace the destination file
      await tempFile.rename(file.path);
    } catch (e) {
      debugPrint("LocalStorage Save Error: $e");
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

  Future<Map<String, dynamic>?> loadState(String userId) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final contents = prefs.getString('arcane_local_cache_$userId');
        if (contents == null || contents.isEmpty) return null;
        return jsonDecode(contents);
      }
      final file = await _localFile(userId);
      if (await file.exists()) {
        try {
          final contents = await file.readAsString();
          if (contents.isNotEmpty) {
            return await compute(_decodeJson, contents);
          }
        } catch (e) {
          debugPrint("LocalStorage Primary Load Error: $e — Attempting backup recovery");
        }
      }

      // Fallback 1: If primary file is missing or corrupted, attempt recovery from .bak
      final backup = await _backupFile(userId);
      if (await backup.exists()) {
        try {
          final bakContents = await backup.readAsString();
          if (bakContents.isNotEmpty) {
            final data = await compute(_decodeJson, bakContents);
            debugPrint("Successfully recovered state from backup!");
            // Restore primary from backup
            try {
              await backup.copy(file.path);
            } catch (_) {}
            return data;
          }
        } catch (bakError) {
          debugPrint("LocalStorage Backup Recovery Error: $bakError");
        }
      }

      // Fallback 2: If primary and .bak are missing or corrupt, attempt recovery from latest daily backup
      final dailyBackup = await getLatestDailyBackup(userId);
      if (dailyBackup != null && await dailyBackup.exists()) {
        try {
          final dailyContents = await dailyBackup.readAsString();
          if (dailyContents.isNotEmpty) {
            final data = await compute(_decodeJson, dailyContents);
            debugPrint("Successfully recovered state from daily backup (${dailyBackup.path})!");
            try {
              await dailyBackup.copy(file.path);
            } catch (_) {}
            return data;
          }
        } catch (dailyError) {
          debugPrint("LocalStorage Daily Backup Recovery Error: $dailyError");
        }
      }
    } catch (e) {
      debugPrint("LocalStorage Load Error: $e");
    }
    return null;
  }

  Future<void> clearState(String userId) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('arcane_local_cache_$userId');
        return;
      }
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