import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// This file primarily exports instances. Initialization happens in main.dart.
// Specific service methods (like wrappers around auth or firestore calls)
// can be added here if desired, but GameProvider will mostly use these directly.

final FirebaseAuth firebaseAuthInstance = FirebaseAuth.instance;
final FirebaseFirestore firestoreInstance = FirebaseFirestore.instance;

// Example of a user helper, though GameProvider will handle most auth state
Stream<User?> get authStateChanges => firebaseAuthInstance.authStateChanges();

Future<User?> signInWithEmail(String email, String password) async {
  try {
    UserCredential userCredential = await firebaseAuthInstance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  } on FirebaseAuthException catch (e) { // Catch specific exception
    print('[FirebaseService] signInWithEmail error: Code: ${e.code}, Message: ${e.message}'); // DEBUG
    rethrow; // Rethrow to be caught by UI or provider
  } catch (e) { // Catch generic errors
    print('[FirebaseService] signInWithEmail generic error: $e'); // DEBUG
    rethrow;
  }
}

Future<User?> signUpWithEmail(String email, String password) async {
  try {
    UserCredential userCredential = await firebaseAuthInstance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  } on FirebaseAuthException catch (e) { // Catch specific exception
    print('[FirebaseService] signUpWithEmail error: Code: ${e.code}, Message: ${e.message}'); // DEBUG
    rethrow;
  } catch (e) { // Catch generic errors
    print('[FirebaseService] signUpWithEmail generic error: $e'); // DEBUG
    rethrow;
  }
}

Future<void> signOut() async {
  try {
    await firebaseAuthInstance.signOut();
  } on FirebaseAuthException catch (e) {
     print('[FirebaseService] signOut error: Code: ${e.code}, Message: ${e.message}'); // DEBUG
     rethrow;
  } catch (e) {
     print('[FirebaseService] signOut generic error: $e'); // DEBUG
     rethrow;
  }
}

Future<void> changePassword(String newPassword) async {
  User? user = firebaseAuthInstance.currentUser;
  if (user != null) {
    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) { // Catch specific exception
       print('[FirebaseService] changePassword error: Code: ${e.code}, Message: ${e.message}'); // DEBUG
       rethrow;
    } catch (e) { // Catch generic errors
       print('[FirebaseService] changePassword generic error: $e'); // DEBUG
       rethrow;
    }
  } else {
    throw FirebaseAuthException(message: "No user currently signed in.", code: "no-user");
  }
}