import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static const String _fileName = 'arcane_local_cache.json';

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> saveState(Map<String, dynamic> state) async {
    try {
      final file = await _localFile;
      // Use a separate thread or async write to prevent UI jank
      // but ensure it's awaited where critical.
      final jsonString = jsonEncode(state);
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      debugPrint("LocalStorage Save Error: $e");
    }
  }

  Future<Map<String, dynamic>?> loadState() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isEmpty) return null;
        return jsonDecode(contents) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("LocalStorage Load Error: $e");
    }
    return null;
  }

  Future<void> clearState() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("LocalStorage Clear Error: $e");
    }
  }
}