import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

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
      final snap = await _rtdb.ref('users/$userId/data').get();
      
      if (snap.exists && snap.value != null) {
        return _parseRtdbData(snap.value as Map<dynamic, dynamic>);
      } else {
        return await getFirestoreBackup(userId);
      }
    } catch (e) {
      return await getFirestoreBackup(userId);
    }
  }

  // Live Sync Stream
  Stream<Map<String, dynamic>> watchUserData(String userId) {
    if (userId.isEmpty) return const Stream.empty();
    
    return _rtdb.ref('users/$userId/data').onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        return _parseRtdbData(event.snapshot.value as Map<dynamic, dynamic>);
      }
      return {};
    });
  }

  Map<String, dynamic> _parseRtdbData(Map<dynamic, dynamic> raw) {
    Map<String, dynamic> fullData = {};
    if (raw[_docSettings] is String) fullData.addAll(jsonDecode(raw[_docSettings] as String));
    if (raw[_docTasks] is String) fullData.addAll(jsonDecode(raw[_docTasks] as String));
    if (raw[_docFinance] is String) fullData.addAll(jsonDecode(raw[_docFinance] as String));
    if (raw[_docHealth] is String) fullData.addAll(jsonDecode(raw[_docHealth] as String));
    
    // Safely parse chunked maps or legacy strings to fix Type Cast errors
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

  // Optimized Chunked Saving for large arrays (History/Reflections)
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
      final logs = data['reflectionLogs'] as List<dynamic>? ?? [];
      final Map<String, dynamic> updates = {};
      for (var log in logs) {
        updates[log['id']] = jsonEncode(log);
      }
      // Use Set to overwrite node, dropping locally deleted elements from DB implicitly
      await _rtdb.ref('users/$userId/data/reflections').set(updates); 
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Firestore Database (Backup & Archival) ---

  DocumentReference<Map<String, dynamic>> _firestoreDocRef(String userId, String docId) {
    return _firestore
        .collection(_userCollection)
        .doc(userId)
        .collection(_userSubcollectionDocId)
        .doc(docId);
  }

  Future<Map<String, dynamic>?> getFirestoreBackup(String userId) async {
    if (userId.isEmpty) return null;

    try {
      // Load base state
      final baseSnap = await _firestoreDocRef(userId, 'base_state').get();
      Map<String, dynamic> fullData = {};
      
      if (baseSnap.exists) {
        fullData.addAll(baseSnap.data()!);
      } else {
        // Legacy fallback handling for older snapshots
        final oldDocSnap = await _firestoreDocRef(userId, _gameStateDocId).get();
        if (oldDocSnap.exists) return oldDocSnap.data();
        
        final tasksSnap = await _firestoreDocRef(userId, 'tasks').get();
        if (tasksSnap.exists) {
           final historySnap = await _firestoreDocRef(userId, 'history').get();
           final reflectionsSnap = await _firestoreDocRef(userId, 'reflections').get();
           final settingsSnap = await _firestoreDocRef(userId, 'settings').get();
           final financeSnap = await _firestoreDocRef(userId, 'finance').get();
           final healthSnap = await _firestoreDocRef(userId, 'health').get();

           if (settingsSnap.exists) fullData.addAll(settingsSnap.data()!);
           if (tasksSnap.exists) fullData.addAll(tasksSnap.data()!);
           if (historySnap.exists) fullData.addAll(historySnap.data()!);
           if (reflectionsSnap.exists) fullData.addAll(reflectionsSnap.data()!);
           if (financeSnap.exists) fullData.addAll(financeSnap.data()!);
           if (healthSnap.exists) fullData.addAll(healthSnap.data()!);
           return fullData;
        }
        return null;
      }

      // Reconstruct Chunked Tasks
      final tasksCol = await _firestore.collection(_userCollection).doc(userId).collection('tasks_backup').get();
      if (tasksCol.docs.isNotEmpty) {
        fullData['mainTasks'] = tasksCol.docs.map((doc) => doc.data()).toList();
      }

      // Reconstruct Chunked History
      final historyCol = await _firestore.collection(_userCollection).doc(userId).collection('history_backup').get();
      if (historyCol.docs.isNotEmpty) {
        fullData['completedByDay'] = {};
        for (var doc in historyCol.docs) {
          fullData['completedByDay'][doc.id] = doc.data();
        }
      }

      // Reconstruct Chunked Reflections
      final refCol = await _firestore.collection(_userCollection).doc(userId).collection('reflections_backup').get();
      if (refCol.docs.isNotEmpty) {
        fullData['reflectionLogs'] = refCol.docs.map((doc) => doc.data()).toList();
      }

      return fullData;
    } catch (e) {
      return null;
    }
  }

  // Bypassing 1MB Document Limits by aggressively chunking to subcollections
  Future<bool> backupToFirestore(String userId, Map<String, dynamic> fullData) async {
    if (userId.isEmpty) return false;

    // Clone mapping to avoid mutating active memory state
    final Map<String, dynamic> baseData = Map.from(fullData);
    final historyData = baseData.remove('completedByDay') as Map<String, dynamic>? ?? {};
    final reflectionsData = baseData.remove('reflectionLogs') as List<dynamic>? ?? [];
    final tasksDataList = baseData.remove('mainTasks') as List<dynamic>? ?? [];

    try {
      final batches = [_firestore.batch()];
      int ops = 0;
      int batchIndex = 0;

      void addSet(DocumentReference ref, Map<String, dynamic> data) {
        batches[batchIndex].set(ref, data);
        ops++;
        if (ops >= 490) { // Keep under 500 max writes per batch limit
          batches.add(_firestore.batch());
          batchIndex++;
          ops = 0;
        }
      }

      addSet(_firestoreDocRef(userId, 'base_state'), baseData);

      final tasksCol = _firestore.collection(_userCollection).doc(userId).collection('tasks_backup');
      for(var task in tasksDataList) {
        addSet(tasksCol.doc(task['id']), task as Map<String, dynamic>);
      }

      final historyCol = _firestore.collection(_userCollection).doc(userId).collection('history_backup');
      historyData.forEach((date, data) {
        addSet(historyCol.doc(date), data as Map<String, dynamic>);
      });

      final refCol = _firestore.collection(_userCollection).doc(userId).collection('reflections_backup');
      for(var log in reflectionsData) {
        addSet(refCol.doc(log['id']), log as Map<String, dynamic>);
      }

      for (var b in batches) {
        await b.commit();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUserData(String userId) async {
    if (userId.isEmpty) return false;
    try {
      await _rtdb.ref('users/$userId/data').remove();

      final batch = _firestore.batch();
      batch.delete(_firestoreDocRef(userId, _gameStateDocId));
      batch.delete(_firestoreDocRef(userId, 'base_state'));
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
      final now = DateTime.now();
      final Map<String, Map<String, dynamic>> result = {};
      final cutoffDate = now.subtract(Duration(days: days));
      final cutoffDateStr = DateFormat('yyyy-MM-dd').format(cutoffDate);

      final snap = await _firestore
          .collection(_userCollection)
          .doc(userId)
          .collection('daily')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: cutoffDateStr)
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