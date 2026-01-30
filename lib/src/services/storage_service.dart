import 'package:cloud_firestore/cloud_firestore.dart';

const String _userCollection = 'users'; // Users collection
const String _userSubcollectionDocId =
    'data'; // Subcollection name under user doc
const String _gameStateDocId = 'gameState'; // The legacy monolithic document ID

// Sub-collection document IDs (actually documents inside the 'data' collection now, for better organization,
// OR we can make 'data' the collection and these the documents.
// The prompt asked for "data/gameState" -> "data/tasks", "data/history", etc.
// Let's interpret the structure:
// users/{uid}/data/gameState (OLD)
// users/{uid}/data/tasks (NEW)
// users/{uid}/data/history (NEW)
// users/{uid}/data/reflections (NEW)
// users/{uid}/data/settings (NEW - includes small stuff like user profile, misc)
// users/{uid}/data/wallet (NEW)
const String _docTasks = 'tasks';
const String _docHistory = 'history';
const String _docReflections = 'reflections';
const String _docSettings = 'settings';
const String _docWallet = 'wallet';

class StorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // users/{userId}/data/{docId}
  DocumentReference<Map<String, dynamic>> _dataDocRef(
      String userId, String docId) {
    return _firestore
        .collection(_userCollection)
        .doc(userId)
        .collection(_userSubcollectionDocId) // 'data' collection
        .doc(docId);
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    if (userId.isEmpty) return null;

    try {
      // 1. Try to fetch the new split documents first.
      final tasksSnap = await _dataDocRef(userId, _docTasks).get();
      final historySnap = await _dataDocRef(userId, _docHistory).get();
      final reflectionsSnap = await _dataDocRef(userId, _docReflections).get();
      final settingsSnap = await _dataDocRef(userId, _docSettings).get();
      final walletSnap = await _dataDocRef(userId, _docWallet).get(); // Wallet

      bool hasNewData =
          tasksSnap.exists || historySnap.exists || settingsSnap.exists || walletSnap.exists;

      if (hasNewData) {
        // Construct the monolithic-like map from the pieces so the app logic remains mostly same
        // or we return them as is. Ideally, we reconstruct the map for AppProvider compatibility.
        Map<String, dynamic> fullData = {};
        if (settingsSnap.exists) fullData.addAll(settingsSnap.data()!);
        if (tasksSnap.exists) fullData.addAll(tasksSnap.data()!);
        if (historySnap.exists) fullData.addAll(historySnap.data()!);
        if (reflectionsSnap.exists) fullData.addAll(reflectionsSnap.data()!);
        if (walletSnap.exists) fullData.addAll(walletSnap.data()!); // Wallet
        return fullData;
      }

      // 2. Fallback to old monolithic 'gameState' document
      final oldDocSnap = await _dataDocRef(userId, _gameStateDocId).get();
      if (oldDocSnap.exists) {
        return oldDocSnap.data();
      }

      return null; // No data found
    } catch (e) {
      // print("Error getting user data: $e");
      return null;
    }
  }

  // Methods to save individual chunks
  Future<bool> saveTasks(String userId, Map<String, dynamic> data) async {
    return _saveChunk(userId, _docTasks, data);
  }

  Future<bool> saveHistory(String userId, Map<String, dynamic> data) async {
    return _saveChunk(userId, _docHistory, data);
  }

  Future<bool> saveReflections(String userId, Map<String, dynamic> data) async {
    return _saveChunk(userId, _docReflections, data);
  }

  Future<bool> saveSettings(String userId, Map<String, dynamic> data) async {
    return _saveChunk(userId, _docSettings, data);
  }

  Future<bool> saveWallet(String userId, Map<String, dynamic> data) async {
    return _saveChunk(userId, _docWallet, data);
  }

  Future<bool> _saveChunk(
      String userId, String docId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      await _dataDocRef(userId, docId).set(data);
      return true;
    } catch (e) {
      // print("Error saving $docId: $e");
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
      batch.delete(_dataDocRef(userId, _docWallet));
      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Helper for AppProvider to update what it thinks needed
  // This is generic, but practically we will use the specific save methods above.
  Future<bool> setUserData(String userId, Map<String, dynamic> fullData) async {
    // This method is now "save everything".
    // It should distribute the keys to the correct documents.
    if (userId.isEmpty) return false;

    // Split data
    final tasksData = <String, dynamic>{};
    if (fullData.containsKey('mainTasks'))
      tasksData['mainTasks'] = fullData['mainTasks'];

    final historyData = <String, dynamic>{};
    if (fullData.containsKey('completedByDay'))
      historyData['completedByDay'] = fullData['completedByDay'];

    final reflectionsData = <String, dynamic>{};
    if (fullData.containsKey('reflectionLogs'))
      reflectionsData['reflectionLogs'] = fullData['reflectionLogs'];

    final walletData = <String, dynamic>{};
    if (fullData.containsKey('walletTransactions'))
      walletData['walletTransactions'] = fullData['walletTransactions'];

    final settingsData = Map<String, dynamic>.from(fullData);
    settingsData.remove('mainTasks');
    settingsData.remove('completedByDay');
    settingsData.remove('reflectionLogs');
    settingsData.remove('walletTransactions');

    // Execute batch set
    try {
      final batch = _firestore.batch();
      batch.set(_dataDocRef(userId, _docTasks), tasksData);
      batch.set(_dataDocRef(userId, _docHistory), historyData);
      batch.set(_dataDocRef(userId, _docReflections), reflectionsData);
      batch.set(_dataDocRef(userId, _docWallet), walletData);
      batch.set(_dataDocRef(userId, _docSettings), settingsData);
      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }
}
