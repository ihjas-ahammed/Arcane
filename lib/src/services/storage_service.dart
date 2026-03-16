import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

const String _userCollection = 'users'; 
const String _userSubcollectionDocId = 'data';
const String _gameStateDocId = 'gameState';

const String _docTasks = 'tasks';
const String _docHistory = 'history';
const String _docReflections = 'reflections';
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
        // Migration Fallback: If no RTDB data, pull from Firestore and return it.
        return await getFirestoreBackup(userId);
      }
    } catch (e) {
      // In case of extreme failure, fallback to Firestore
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
    if (raw[_docSettings] != null) fullData.addAll(jsonDecode(raw[_docSettings] as String));
    if (raw[_docTasks] != null) fullData.addAll(jsonDecode(raw[_docTasks] as String));
    if (raw[_docHistory] != null) fullData.addAll(jsonDecode(raw[_docHistory] as String));
    if (raw[_docReflections] != null) fullData.addAll(jsonDecode(raw[_docReflections] as String));
    if (raw[_docFinance] != null) fullData.addAll(jsonDecode(raw[_docFinance] as String));
    if (raw[_docHealth] != null) fullData.addAll(jsonDecode(raw[_docHealth] as String));
    return fullData;
  }

  Future<bool> saveTasks(String userId, Map<String, dynamic> data) async => _saveChunkToRTDB(userId, _docTasks, data);
  Future<bool> saveHistory(String userId, Map<String, dynamic> data) async => _saveChunkToRTDB(userId, _docHistory, data);
  Future<bool> saveReflections(String userId, Map<String, dynamic> data) async => _saveChunkToRTDB(userId, _docReflections, data);
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
      final tasksSnap = await _firestoreDocRef(userId, _docTasks).get();
      final historySnap = await _firestoreDocRef(userId, _docHistory).get();
      final reflectionsSnap = await _firestoreDocRef(userId, _docReflections).get();
      final settingsSnap = await _firestoreDocRef(userId, _docSettings).get();
      final financeSnap = await _firestoreDocRef(userId, _docFinance).get();
      final healthSnap = await _firestoreDocRef(userId, _docHealth).get();

      bool hasNewData = tasksSnap.exists || historySnap.exists || settingsSnap.exists || financeSnap.exists || healthSnap.exists;

      if (hasNewData) {
        Map<String, dynamic> fullData = {};
        if (settingsSnap.exists) fullData.addAll(settingsSnap.data()!);
        if (tasksSnap.exists) fullData.addAll(tasksSnap.data()!);
        if (historySnap.exists) fullData.addAll(historySnap.data()!);
        if (reflectionsSnap.exists) fullData.addAll(reflectionsSnap.data()!);
        if (financeSnap.exists) fullData.addAll(financeSnap.data()!);
        if (healthSnap.exists) fullData.addAll(healthSnap.data()!);
        return fullData;
      }

      final oldDocSnap = await _firestoreDocRef(userId, _gameStateDocId).get();
      if (oldDocSnap.exists) {
        return oldDocSnap.data();
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> backupToFirestore(String userId, Map<String, dynamic> fullData) async {
    if (userId.isEmpty) return false;

    final tasksData = <String, dynamic>{};
    if (fullData.containsKey('mainTasks')) tasksData['mainTasks'] = fullData['mainTasks'];

    final historyData = <String, dynamic>{};
    if (fullData.containsKey('completedByDay')) historyData['completedByDay'] = fullData['completedByDay'];

    final reflectionsData = <String, dynamic>{};
    if (fullData.containsKey('reflectionLogs')) reflectionsData['reflectionLogs'] = fullData['reflectionLogs'];

    final financeData = <String, dynamic>{};
    if (fullData.containsKey('transactions')) financeData['transactions'] = fullData['transactions'];
    if (fullData.containsKey('categories')) financeData['categories'] = fullData['categories'];
    if (fullData.containsKey('savingsGoals')) financeData['savingsGoals'] = fullData['savingsGoals'];

    final healthData = <String, dynamic>{};
    if (fullData.containsKey('foodItems')) healthData['foodItems'] = fullData['foodItems'];
    if (fullData.containsKey('healthLogs')) healthData['healthLogs'] = fullData['healthLogs'];

    final settingsData = Map<String, dynamic>.from(fullData);
    settingsData.remove('mainTasks');
    settingsData.remove('completedByDay');
    settingsData.remove('reflectionLogs');
    settingsData.remove('transactions');
    settingsData.remove('categories');
    settingsData.remove('savingsGoals');
    settingsData.remove('foodItems');
    settingsData.remove('healthLogs');

    try {
      final batch = _firestore.batch();
      batch.set(_firestoreDocRef(userId, _docTasks), tasksData);
      batch.set(_firestoreDocRef(userId, _docHistory), historyData);
      batch.set(_firestoreDocRef(userId, _docReflections), reflectionsData);
      batch.set(_firestoreDocRef(userId, _docSettings), settingsData);
      batch.set(_firestoreDocRef(userId, _docFinance), financeData);
      batch.set(_firestoreDocRef(userId, _docHealth), healthData);
      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUserData(String userId) async {
    if (userId.isEmpty) return false;
    try {
      // Clear RTDB
      await _rtdb.ref('users/$userId/data').remove();

      // Clear Firestore
      final batch = _firestore.batch();
      batch.delete(_firestoreDocRef(userId, _gameStateDocId));
      batch.delete(_firestoreDocRef(userId, _docTasks));
      batch.delete(_firestoreDocRef(userId, _docHistory));
      batch.delete(_firestoreDocRef(userId, _docReflections));
      batch.delete(_firestoreDocRef(userId, _docSettings));
      batch.delete(_firestoreDocRef(userId, _docFinance));
      batch.delete(_firestoreDocRef(userId, _docHealth));
      await batch.commit();
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Historical Archives (Remain in Firestore) ---

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