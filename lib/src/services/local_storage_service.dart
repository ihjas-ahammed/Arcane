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

  Future<void> saveState(String userId, Map<String, dynamic> state) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = jsonEncode(state);
        await prefs.setString('arcane_local_cache_$userId', jsonString);
        return;
      }
      final file = await _localFile(userId);
      // Offload heavy JSON serialization to a background isolate
      final jsonString = await compute(_encodeJson, state);
      await file.writeAsString(jsonString, flush: true);
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
        final contents = await file.readAsString();
        if (contents.isEmpty) return null;
        // Offload parsing to background isolate
        return await compute(_decodeJson, contents);
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