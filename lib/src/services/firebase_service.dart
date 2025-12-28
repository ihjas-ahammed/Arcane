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
    UserCredential userCredential =
        await firebaseAuthInstance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  } on FirebaseAuthException catch (_) {
    // Catch specific exception

    rethrow; // Rethrow to be caught by UI or provider
  } catch (_) {
    // Catch generic errors

    rethrow;
  }
}

Future<User?> signUpWithEmail(String email, String password) async {
  try {
    UserCredential userCredential =
        await firebaseAuthInstance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  } on FirebaseAuthException catch (_) {
    // Catch specific exception

    rethrow;
  } catch (_) {
    // Catch generic errors

    rethrow;
  }
}

Future<void> signOut() async {
  try {
    await firebaseAuthInstance.signOut();
  } on FirebaseAuthException catch (_) {
    rethrow;
  } catch (_) {
    rethrow;
  }
}

Future<void> changePassword(String newPassword) async {
  User? user = firebaseAuthInstance.currentUser;
  if (user != null) {
    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (_) {
      // Catch specific exception

      rethrow;
    } catch (_) {
      // Catch generic errors

      rethrow;
    }
  } else {
    throw FirebaseAuthException(
        message: "No user currently signed in.", code: "no-user");
  }
}
