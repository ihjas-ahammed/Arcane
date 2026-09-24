import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Top-level function for isolate
String _encodeJson(Map<String, dynamic> data) => jsonEncode(data);
Map<String, dynamic> _decodeJson(String json) => jsonDecode(json);

class LocalStorageService {
  Future<File> _localFile(String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/arcane_local_cache_$userId.json');
  }

  Future<File> _backupFile(String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/arcane_local_cache_$userId.bak');
  }

  Future<void> saveState(String userId, Map<String, dynamic> state) async {
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

      // Fallback: If primary file is missing or corrupted, attempt recovery from .bak
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
    } catch (e) {
      debugPrint("LocalStorage Clear Error: $e");
    }
  }
}