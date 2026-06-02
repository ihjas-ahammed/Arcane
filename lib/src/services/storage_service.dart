import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_dart/firebase_dart.dart' as fd;
import 'package:firedart/firedart.dart' as firedart;

const String _userCollection = 'users';
const String _userSubcollectionDocId = 'data';
const String _gameStateDocId = 'gameState';

const String _docTasks = 'tasks';
const String _docSettings = 'settings';
const String _docFinance = 'finance';
const String _docHealth = 'health';

/// Cross-platform cloud storage facade. The factory constructor selects the
/// concrete impl: FlutterFire on Android/iOS/web/macOS/Windows, and a pair
/// of pure-Dart clients (firebase_dart for RTDB, firedart for Firestore) on
/// Linux. Consumers keep calling `StorageService()` and never see the split.
abstract class StorageService {
  factory StorageService() => (!kIsWeb && Platform.isLinux)
      ? _LinuxStorageService()
      : _FlutterFireStorageService();

  Future<Map<String, dynamic>?> getUserData(String userId);
  Future<int> getLastModified(String userId);
  Future<void> setLastModified(String userId, int timestamp);
  Stream<int> watchLastModified(String userId);
  Future<bool> saveTasks(String userId, Map<String, dynamic> data);
  Future<bool> saveSettings(String userId, Map<String, dynamic> data);
  Future<bool> saveFinance(String userId, Map<String, dynamic> data);
  Future<bool> saveHealth(String userId, Map<String, dynamic> data);
  Future<bool> saveHistory(String userId, Map<String, dynamic> data);
  Future<bool> saveReflections(String userId, Map<String, dynamic> data);
  Future<bool> deleteUserData(String userId);
  Future<bool> saveDailyData(
      String userId, String date, String type, Map<String, dynamic> data);
  Future<Map<String, Map<String, dynamic>>> fetchRecentDailyData(
      String userId, int days);
  Future<bool> saveWeeklyReport(
      String userId, String date, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> fetchWeeklyReports(String userId);
}

// Shared helper — collapses the RTDB chunk JSON back into one flat state map.
Map<String, dynamic> _parseRtdbData(Map<dynamic, dynamic> raw) {
  Map<String, dynamic> fullData = {};
  if (raw[_docSettings] is String) {
    fullData.addAll(jsonDecode(raw[_docSettings] as String));
  }
  if (raw[_docTasks] is String) {
    fullData.addAll(jsonDecode(raw[_docTasks] as String));
  }
  if (raw[_docFinance] is String) {
    fullData.addAll(jsonDecode(raw[_docFinance] as String));
  }
  if (raw[_docHealth] is String) {
    fullData.addAll(jsonDecode(raw[_docHealth] as String));
  }

  if (raw['history'] != null) {
    if (raw['history'] is String) {
      fullData.addAll(jsonDecode(raw['history'] as String));
    } else if (raw['history'] is Map) {
      Map<String, dynamic> history = {};
      (raw['history'] as Map).forEach((date, jsonStr) {
        history[date.toString()] = jsonDecode(jsonStr.toString());
      });
      fullData['completedByDay'] = history;
    }
  }

  if (raw['reflections'] != null) {
    if (raw['reflections'] is String) {
      fullData.addAll(jsonDecode(raw['reflections'] as String));
    } else if (raw['reflections'] is Map) {
      List<dynamic> reflections = [];
      (raw['reflections'] as Map).forEach((id, jsonStr) {
        reflections.add(jsonDecode(jsonStr.toString()));
      });
      fullData['reflectionLogs'] = reflections;
    }
  }

  return fullData;
}

// ─────────────────────────────────────────────────────────────────────────
// FlutterFire-backed impl (Android, iOS, web, macOS, Windows).
// Identical behavior to the pre-refactor StorageService.
// ─────────────────────────────────────────────────────────────────────────
class _FlutterFireStorageService implements StorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  DatabaseReference _rtdbRef(String userId, String chunk) =>
      _rtdb.ref('users/$userId/data/$chunk');

  @override
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final baseRef = _rtdb.ref('users/$userId/data');

      final settingsSnap = await baseRef.child(_docSettings).get();
      final tasksSnap = await baseRef.child(_docTasks).get();
      final financeSnap = await baseRef.child(_docFinance).get();
      final healthSnap = await baseRef.child(_docHealth).get();

      final historySnap =
          await baseRef.child('history').orderByKey().limitToLast(365).get();
      final reflectionsSnap = await baseRef.child('reflections').get();

      Map<dynamic, dynamic> rawData = {};

      if (settingsSnap.exists) rawData[_docSettings] = settingsSnap.value;
      if (tasksSnap.exists) rawData[_docTasks] = tasksSnap.value;
      if (financeSnap.exists) rawData[_docFinance] = financeSnap.value;
      if (healthSnap.exists) rawData[_docHealth] = healthSnap.value;
      if (historySnap.exists) rawData['history'] = historySnap.value;
      if (reflectionsSnap.exists) rawData['reflections'] = reflectionsSnap.value;

      if (rawData.isNotEmpty) {
        return _parseRtdbData(rawData);
      } else {
        return null;
      }
    } catch (e, stack) {
      debugPrint('[StorageService.getUserData] $e\n$stack');
      return null;
    }
  }

  @override
  Future<int> getLastModified(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final snap = await _rtdb.ref('users/$userId/lastModified').get();
      return (snap.value as num?)?.toInt() ?? 0;
    } catch (e, stack) {
      debugPrint('[StorageService.getLastModified] $e\n$stack');
      return 0;
    }
  }

  @override
  Future<void> setLastModified(String userId, int timestamp) async {
    if (userId.isEmpty) return;
    await _rtdb.ref('users/$userId/lastModified').set(timestamp);
  }

  @override
  Stream<int> watchLastModified(String userId) {
    if (userId.isEmpty) return const Stream.empty();
    return _rtdb.ref('users/$userId/lastModified').onValue.map((event) {
      return (event.snapshot.value as num?)?.toInt() ?? 0;
    });
  }

  @override
  Future<bool> saveTasks(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docTasks, data);
  @override
  Future<bool> saveSettings(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docSettings, data);
  @override
  Future<bool> saveFinance(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docFinance, data);
  @override
  Future<bool> saveHealth(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docHealth, data);

  Future<bool> _saveChunkToRTDB(
      String userId, String chunk, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      await _rtdbRef(userId, chunk).set(jsonEncode(data));
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService._saveChunkToRTDB:$chunk] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> saveHistory(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final history = data['completedByDay'] as Map<String, dynamic>? ?? {};
      final Map<String, dynamic> updates = {};
      history.forEach((date, dayData) {
        updates[date] = jsonEncode(dayData);
      });
      await _rtdb.ref('users/$userId/data/history').update(updates);
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveHistory] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> saveReflections(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final logs = data['reflectionLogs'] as List<dynamic>? ?? [];
      final Map<String, dynamic> updates = {};
      for (var log in logs) {
        updates[log['id']] = jsonEncode(log);
      }
      await _rtdb.ref('users/$userId/data/reflections').set(updates);
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveReflections] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> deleteUserData(String userId) async {
    if (userId.isEmpty) return false;
    try {
      await _rtdb.ref('users/$userId').remove();

      final batch = _firestore.batch();
      batch.delete(_firestore
          .collection(_userCollection)
          .doc(userId)
          .collection(_userSubcollectionDocId)
          .doc(_gameStateDocId));
      batch.delete(_firestore
          .collection(_userCollection)
          .doc(userId)
          .collection(_userSubcollectionDocId)
          .doc('base_state'));
      await batch.commit();

      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.deleteUserData] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> saveDailyData(String userId, String date, String type,
      Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      await _firestore
          .collection(_userCollection)
          .doc(userId)
          .collection('daily')
          .doc(date)
          .set({
        type: data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveDailyData] $e\n$stack');
      return false;
    }
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchRecentDailyData(
      String userId, int days) async {
    if (userId.isEmpty) return {};
    try {
      final Map<String, Map<String, dynamic>> result = {};
      final snap = await _firestore
          .collection(_userCollection)
          .doc(userId)
          .collection('daily')
          .get();

      final docs = snap.docs.toList()
        ..sort((a, b) => b.id.compareTo(a.id));

      for (var doc in docs.take(days)) {
        result[doc.id] = doc.data();
      }
      return result;
    } catch (e, stack) {
      debugPrint('[StorageService.fetchRecentDailyData] $e\n$stack');
      return {};
    }
  }

  @override
  Future<bool> saveWeeklyReport(
      String userId, String date, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      await _firestore
          .collection(_userCollection)
          .doc(userId)
          .collection('weekly')
          .doc(date)
          .set({
        'report': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveWeeklyReport] $e\n$stack');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchWeeklyReports(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snap = await _firestore
          .collection(_userCollection)
          .doc(userId)
          .collection('weekly')
          .orderBy('updatedAt', descending: true)
          .get();

      return snap.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e, stack) {
      debugPrint('[StorageService.fetchWeeklyReports] $e\n$stack');
      return [];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Linux impl: firebase_dart for RTDB, firedart for Firestore.
// `firedart`'s Firestore lacks `FieldPath.documentId` ordering and batch
// writes, so a few queries fetch-then-sort in Dart or run as sequential
// deletes. Server-timestamp writes use a client-side timestamp instead.
// ─────────────────────────────────────────────────────────────────────────
class _LinuxStorageService implements StorageService {
  fd.FirebaseDatabase get _rtdb => fd.FirebaseDatabase(app: fd.Firebase.app());
  firedart.Firestore get _firestore => firedart.Firestore.instance;

  fd.DatabaseReference _rtdbRef(String userId, String chunk) =>
      _rtdb.reference().child('users/$userId/data/$chunk');

  @override
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final baseRef = _rtdb.reference().child('users/$userId/data');

      final settingsSnap = await baseRef.child(_docSettings).once();
      final tasksSnap = await baseRef.child(_docTasks).once();
      final financeSnap = await baseRef.child(_docFinance).once();
      final healthSnap = await baseRef.child(_docHealth).once();
      final historySnap = await baseRef
          .child('history')
          .orderByKey()
          .limitToLast(365)
          .once();
      final reflectionsSnap = await baseRef.child('reflections').once();

      Map<dynamic, dynamic> rawData = {};
      if (settingsSnap.value != null) rawData[_docSettings] = settingsSnap.value;
      if (tasksSnap.value != null) rawData[_docTasks] = tasksSnap.value;
      if (financeSnap.value != null) rawData[_docFinance] = financeSnap.value;
      if (healthSnap.value != null) rawData[_docHealth] = healthSnap.value;
      if (historySnap.value != null) rawData['history'] = historySnap.value;
      if (reflectionsSnap.value != null) {
        rawData['reflections'] = reflectionsSnap.value;
      }

      if (rawData.isNotEmpty) return _parseRtdbData(rawData);
      return null;
    } catch (e, stack) {
      debugPrint('[StorageService.getUserData/linux] $e\n$stack');
      return null;
    }
  }

  @override
  Future<int> getLastModified(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final snap =
          await _rtdb.reference().child('users/$userId/lastModified').once();
      return (snap.value as num?)?.toInt() ?? 0;
    } catch (e, stack) {
      debugPrint('[StorageService.getLastModified/linux] $e\n$stack');
      return 0;
    }
  }

  @override
  Future<void> setLastModified(String userId, int timestamp) async {
    if (userId.isEmpty) return;
    await _rtdb.reference().child('users/$userId/lastModified').set(timestamp);
  }

  @override
  Stream<int> watchLastModified(String userId) {
    if (userId.isEmpty) return const Stream.empty();
    return _rtdb
        .reference()
        .child('users/$userId/lastModified')
        .onValue
        .map((event) => (event.snapshot.value as num?)?.toInt() ?? 0);
  }

  @override
  Future<bool> saveTasks(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docTasks, data);
  @override
  Future<bool> saveSettings(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docSettings, data);
  @override
  Future<bool> saveFinance(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docFinance, data);
  @override
  Future<bool> saveHealth(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docHealth, data);

  Future<bool> _saveChunkToRTDB(
      String userId, String chunk, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      await _rtdbRef(userId, chunk).set(jsonEncode(data));
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService._saveChunkToRTDB:$chunk/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> saveHistory(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final history = data['completedByDay'] as Map<String, dynamic>? ?? {};
      final Map<String, dynamic> updates = {};
      history.forEach((date, dayData) {
        updates[date] = jsonEncode(dayData);
      });
      await _rtdb
          .reference()
          .child('users/$userId/data/history')
          .update(updates);
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveHistory/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> saveReflections(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final logs = data['reflectionLogs'] as List<dynamic>? ?? [];
      final Map<String, dynamic> updates = {};
      for (var log in logs) {
        updates[log['id']] = jsonEncode(log);
      }
      await _rtdb
          .reference()
          .child('users/$userId/data/reflections')
          .set(updates);
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveReflections/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> deleteUserData(String userId) async {
    if (userId.isEmpty) return false;
    try {
      await _rtdb.reference().child('users/$userId').remove();

      // firedart has no batch writes; delete sequentially.
      try {
        await _firestore
            .collection('$_userCollection/$userId/$_userSubcollectionDocId')
            .document(_gameStateDocId)
            .delete();
      } catch (_) {}
      try {
        await _firestore
            .collection('$_userCollection/$userId/$_userSubcollectionDocId')
            .document('base_state')
            .delete();
      } catch (_) {}

      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.deleteUserData/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> saveDailyData(String userId, String date, String type,
      Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final docRef = _firestore
          .collection('$_userCollection/$userId/daily')
          .document(date);

      // Manual merge: read existing, overlay, write back.
      Map<String, dynamic> existing = {};
      try {
        final snap = await docRef.get();
        existing = Map<String, dynamic>.from(snap.map);
      } catch (_) {}

      existing[type] = data;
      existing['updatedAt'] = DateTime.now().toUtc().toIso8601String();

      await docRef.set(existing);
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveDailyData/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchRecentDailyData(
      String userId, int days) async {
    if (userId.isEmpty) return {};
    try {
      // firedart's Query doesn't expose FieldPath.documentId ordering; fetch
      // everything and sort by document id (date string) in Dart.
      final docs = await _firestore
          .collection('$_userCollection/$userId/daily')
          .get();

      final entries = docs.toList()
        ..sort((a, b) => b.id.compareTo(a.id)); // descending date

      final Map<String, Map<String, dynamic>> result = {};
      for (final doc in entries.take(days)) {
        result[doc.id] = Map<String, dynamic>.from(doc.map);
      }
      return result;
    } catch (e, stack) {
      debugPrint('[StorageService.fetchRecentDailyData/linux] $e\n$stack');
      return {};
    }
  }

  @override
  Future<bool> saveWeeklyReport(
      String userId, String date, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final docRef = _firestore
          .collection('$_userCollection/$userId/weekly')
          .document(date);

      Map<String, dynamic> existing = {};
      try {
        final snap = await docRef.get();
        existing = Map<String, dynamic>.from(snap.map);
      } catch (_) {}

      existing['report'] = data;
      existing['updatedAt'] = DateTime.now().toUtc().toIso8601String();

      await docRef.set(existing);
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveWeeklyReport/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchWeeklyReports(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final docs = await _firestore
          .collection('$_userCollection/$userId/weekly')
          .get();

      final entries = docs.toList()
        ..sort((a, b) {
          final aTs = (a.map['updatedAt'] ?? '').toString();
          final bTs = (b.map['updatedAt'] ?? '').toString();
          return bTs.compareTo(aTs);
        });

      return entries
          .map((doc) => {
                'id': doc.id,
                ...Map<String, dynamic>.from(doc.map),
              })
          .toList();
    } catch (e, stack) {
      debugPrint('[StorageService.fetchWeeklyReports/linux] $e\n$stack');
      return [];
    }
  }
}
