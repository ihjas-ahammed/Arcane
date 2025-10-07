import 'package:cloud_firestore/cloud_firestore.dart';

const String _userCollection = 'users';
const String _userSubcollectionDocId = 'data';
const String _gameStateDocId = 'gameState';

class StorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDocRef(String userId) {
    return _firestore
        .collection(_userCollection)
        .doc(userId)
        .collection(_userSubcollectionDocId)
        .doc(_gameStateDocId);
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    if (userId.isEmpty) {
      // print("StorageService Error: userId is required for getUserData.");
      return null;
    }
    try {
      final docSnap = await _userDocRef(userId).get();
      if (docSnap.exists) {
        return docSnap.data();
      } else {
        // print("No game data found for user $userId, will initialize.");
        return null; // Indicates no data, GameProvider will initialize
      }
    } catch (e) {
      // print("Error getting user data from Firestore: $e");
      return null;
    }
  }

  Future<bool> setUserData(String userId, Map<String, dynamic> data) async {
     if (userId.isEmpty) {
      // print("StorageService Error: userId is required for setUserData.");
      return false;
    }
    try {
      await _userDocRef(userId).set(data);
      return true;
    } catch (e) {
      // print("Error setting user data in Firestore: $e");
      return false;
    }
  }

  Future<bool> updateUserData(String userId, Map<String, dynamic> partialData) async {
     if (userId.isEmpty) {
      // print("StorageService Error: userId is required for updateUserData.");
      return false;
    }
    try {
      await _userDocRef(userId).update(partialData);
      return true;
    } catch (e) {
      // print("Error updating user data in Firestore: $e");
      // If the document doesn't exist, update will fail.
      // Consider checking doc existence or using set with merge:true if needed.
      return false;
    }
  }

  Future<bool> deleteUserData(String userId) async {
     if (userId.isEmpty) {
      // print("StorageService Error: userId is required for deleteUserData.");
      return false;
    }
    try {
      await _userDocRef(userId).delete();
      // print("Game data deleted for user $userId.");
      return true;
    } catch (e) {
      // print("Error deleting user data from Firestore: $e");
      return false;
    }
  }
}