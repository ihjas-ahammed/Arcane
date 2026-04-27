import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

const String _userCollection = 'users'; 
const String _userSubcollectionDocId = 'data';
const String _gameStateDocId = 'gameState';

const String _docTasks = 'tasks';
const String _docSettings = 'settings';
const String _docFinance = 'finance';
const String _docHealth = 'health';

class StorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  // --- Realtime Database (Primary) ---

  DatabaseReference _rtdbRef(String userId, String chunk) {
    return _rtdb.ref('users/$userId/data/$chunk');
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final baseRef = _rtdb.ref('users/$userId/data');
      
      // Fetch each chunk separately to prevent OutOfMemoryError when parsing massive snapshot
      final settingsSnap = await baseRef.child(_docSettings).get();
      final tasksSnap = await baseRef.child(_docTasks).get();
      final financeSnap = await baseRef.child(_docFinance).get();
      final healthSnap = await baseRef.child(_docHealth).get();
      
      // Limit history to the last 365 days to prevent excessive memory usage
      // (saveHistory uses .update(), so older days are not overwritten/lost)
      final historySnap = await baseRef.child('history').orderByKey().limitToLast(365).get();
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
    } catch (e) {
      return null;
    }
  }

  // --- Metadata/Timestamp ---
  Future<int> getLastModified(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final snap = await _rtdb.ref('users/$userId/lastModified').get();
      return (snap.value as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> setLastModified(String userId, int timestamp) async {
    if (userId.isEmpty) return;
    await _rtdb.ref('users/$userId/lastModified').set(timestamp);
  }

  Stream<int> watchLastModified(String userId) {
    if (userId.isEmpty) return const Stream.empty();
    return _rtdb.ref('users/$userId/lastModified').onValue.map((event) {
      return (event.snapshot.value as num?)?.toInt() ?? 0;
    });
  }

  Map<String, dynamic> _parseRtdbData(Map<dynamic, dynamic> raw) {
    Map<String, dynamic> fullData = {};
    if (raw[_docSettings] is String) fullData.addAll(jsonDecode(raw[_docSettings] as String));
    if (raw[_docTasks] is String) fullData.addAll(jsonDecode(raw[_docTasks] as String));
    if (raw[_docFinance] is String) fullData.addAll(jsonDecode(raw[_docFinance] as String));
    if (raw[_docHealth] is String) fullData.addAll(jsonDecode(raw[_docHealth] as String));
    
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

  Future<bool> saveTasks(String userId, Map<String, dynamic> data) async => _saveChunkToRTDB(userId, _docTasks, data);
  Future<bool> saveSettings(String userId, Map<String, dynamic> data) async => _saveChunkToRTDB(userId, _docSettings, data);
  Future<bool> saveFinance(String userId, Map<String, dynamic> data) async => _saveChunkToRTDB(userId, _docFinance, data);
  Future<bool> saveHealth(String userId, Map<String, dynamic> data) async => _saveChunkToRTDB(userId, _docHealth, data);

  Future<bool> _saveChunkToRTDB(String userId, String chunk, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      await _rtdbRef(userId, chunk).set(jsonEncode(data));
      return true;
    } catch (e) {
      return false;
    }
  }

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
    } catch (e) {
      return false;
    }
  }

  Future<bool> saveReflections(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final logs = data['reflectionLogs'] as List<dynamic>? ??[];
      final Map<String, dynamic> updates = {};
      for (var log in logs) {
        updates[log['id']] = jsonEncode(log);
      }
      await _rtdb.ref('users/$userId/data/reflections').set(updates); 
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUserData(String userId) async {
    if (userId.isEmpty) return false;
    try {
      await _rtdb.ref('users/$userId').remove();

      final batch = _firestore.batch();
      batch.delete(_firestore.collection(_userCollection).doc(userId).collection(_userSubcollectionDocId).doc(_gameStateDocId));
      batch.delete(_firestore.collection(_userCollection).doc(userId).collection(_userSubcollectionDocId).doc('base_state'));
      await batch.commit();
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Historical Archives ---

  Future<bool> saveDailyData(String userId, String date, String type, Map<String, dynamic> data) async {
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
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, Map<String, dynamic>>> fetchRecentDailyData(String userId, int days) async {
    if (userId.isEmpty) return {};
    try {
      final Map<String, Map<String, dynamic>> result = {};

      // FIX: Changed to order by documentId and limit, avoiding the invalid argument error for inequality queries
      final snap = await _firestore
          .collection(_userCollection)
          .doc(userId)
          .collection('daily')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(days)
          .get();

      for (var doc in snap.docs) {
        result[doc.id] = doc.data();
      }
      return result;
    } catch (e) {
      return {};
    }
  }

  Future<bool> saveWeeklyReport(String userId, String date, Map<String, dynamic> data) async {
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
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchWeeklyReports(String userId) async {
    if (userId.isEmpty) return[];
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
    } catch (e) {
      return[];
    }
  }
}