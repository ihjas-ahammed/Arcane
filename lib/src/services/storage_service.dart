import 'package:cloud_firestore/cloud_firestore.dart';

const String _userCollection = 'users'; 
const String _userSubcollectionDocId = 'data';
const String _gameStateDocId = 'gameState';

const String _docTasks = 'tasks';
const String _docHistory = 'history';
const String _docReflections = 'reflections';
const String _docSettings = 'settings';
const String _docFinance = 'finance';

class StorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _dataDocRef(
      String userId, String docId) {
    return _firestore
        .collection(_userCollection)
        .doc(userId)
        .collection(_userSubcollectionDocId)
        .doc(docId);
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final tasksSnap = await _dataDocRef(userId, _docTasks).get();
      final historySnap = await _dataDocRef(userId, _docHistory).get();
      final reflectionsSnap = await _dataDocRef(userId, _docReflections).get();
      final settingsSnap = await _dataDocRef(userId, _docSettings).get();
      final financeSnap = await _dataDocRef(userId, _docFinance).get();

      bool hasNewData =
          tasksSnap.exists || historySnap.exists || settingsSnap.exists || financeSnap.exists;

      if (hasNewData) {
        Map<String, dynamic> fullData = {};
        if (settingsSnap.exists) fullData.addAll(settingsSnap.data()!);
        if (tasksSnap.exists) fullData.addAll(tasksSnap.data()!);
        if (historySnap.exists) fullData.addAll(historySnap.data()!);
        if (reflectionsSnap.exists) fullData.addAll(reflectionsSnap.data()!);
        if (financeSnap.exists) fullData.addAll(financeSnap.data()!);
        return fullData;
      }

      final oldDocSnap = await _dataDocRef(userId, _gameStateDocId).get();
      if (oldDocSnap.exists) {
        return oldDocSnap.data();
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveTasks(String userId, Map<String, dynamic> data) async => _saveChunk(userId, _docTasks, data);
  Future<bool> saveHistory(String userId, Map<String, dynamic> data) async => _saveChunk(userId, _docHistory, data);
  Future<bool> saveReflections(String userId, Map<String, dynamic> data) async => _saveChunk(userId, _docReflections, data);
  Future<bool> saveSettings(String userId, Map<String, dynamic> data) async => _saveChunk(userId, _docSettings, data);
  Future<bool> saveFinance(String userId, Map<String, dynamic> data) async => _saveChunk(userId, _docFinance, data);

  Future<bool> _saveChunk(
      String userId, String docId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      await _dataDocRef(userId, docId).set(data, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }

  // NEW: Save Daily Reports & Briefings to /daily/{date}
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

  // NEW: Save Weekly Reports to /weekly/{date}
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

  Future<bool> deleteLegacyData(String userId) async {
    if (userId.isEmpty) return false;
    try {
      await _dataDocRef(userId, _gameStateDocId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUserData(String userId) async {
    if (userId.isEmpty) return false;
    try {
      final batch = _firestore.batch();
      batch.delete(_dataDocRef(userId, _gameStateDocId));
      batch.delete(_dataDocRef(userId, _docTasks));
      batch.delete(_dataDocRef(userId, _docHistory));
      batch.delete(_dataDocRef(userId, _docReflections));
      batch.delete(_dataDocRef(userId, _docSettings));
      batch.delete(_dataDocRef(userId, _docFinance));
      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setUserData(String userId, Map<String, dynamic> fullData) async {
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

    final settingsData = Map<String, dynamic>.from(fullData);
    settingsData.remove('mainTasks');
    settingsData.remove('completedByDay');
    settingsData.remove('reflectionLogs');
    settingsData.remove('transactions');
    settingsData.remove('categories');
    settingsData.remove('savingsGoals');

    try {
      final batch = _firestore.batch();
      batch.set(_dataDocRef(userId, _docTasks), tasksData);
      batch.set(_dataDocRef(userId, _docHistory), historyData);
      batch.set(_dataDocRef(userId, _docReflections), reflectionsData);
      batch.set(_dataDocRef(userId, _docSettings), settingsData);
      batch.set(_dataDocRef(userId, _docFinance), financeData);
      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }
}