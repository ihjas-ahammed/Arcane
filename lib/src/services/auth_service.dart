import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as ff;
import 'package:firebase_dart/firebase_dart.dart' as fd;

import 'package:missions/src/services/app_user.dart';

/// Platform-agnostic auth API. On Linux this delegates to `firebase_dart`'s
/// pure-Dart FirebaseAuth; everywhere else to the official `firebase_auth`
/// plugin.
abstract class AuthService {
  static AuthService? _instance;
  static AuthService get instance {
    _instance ??= (!kIsWeb && Platform.isLinux)
        ? _LinuxAuthService()
        : _FlutterFireAuthService();
    return _instance!;
  }

  AppUser? get currentUser;
  Stream<AppUser?> get authStateChanges;

  Future<AppUser?> signInWithEmail(String email, String password);
  Future<AppUser?> signUpWithEmail(String email, String password);
  Future<void> signOut();
  Future<void> changePassword(String newPassword);
  Future<void> updateDisplayName(String name);
  Future<void> reload();
}

// ─────────────────────────────────────────────────────────────────────────
// FlutterFire-backed impl (Android, iOS, web, macOS, Windows).
// ─────────────────────────────────────────────────────────────────────────

AppUser? _ffToAppUser(ff.User? u) => u == null
    ? null
    : AppUser(uid: u.uid, email: u.email, displayName: u.displayName);

class _FlutterFireAuthService implements AuthService {
  final ff.FirebaseAuth _auth = ff.FirebaseAuth.instance;

  @override
  AppUser? get currentUser => _ffToAppUser(_auth.currentUser);

  @override
  Stream<AppUser?> get authStateChanges =>
      _auth.authStateChanges().map(_ffToAppUser);

  @override
  Future<AppUser?> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return _ffToAppUser(cred.user);
    } on ff.FirebaseAuthException catch (e) {
      throw AuthFailure(code: e.code, message: e.message);
    }
  }

  @override
  Future<AppUser?> signUpWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return _ffToAppUser(cred.user);
    } on ff.FirebaseAuthException catch (e) {
      throw AuthFailure(code: e.code, message: e.message);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
          code: 'no-user', message: 'No user currently signed in.');
    }
    try {
      await user.updatePassword(newPassword);
    } on ff.FirebaseAuthException catch (e) {
      throw AuthFailure(code: e.code, message: e.message);
    }
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.updateDisplayName(name);
      await user.reload();
    } on ff.FirebaseAuthException catch (e) {
      throw AuthFailure(code: e.code, message: e.message);
    }
  }

  @override
  Future<void> reload() async {
    await _auth.currentUser?.reload();
  }
}

// ─────────────────────────────────────────────────────────────────────────
// firebase_dart-backed impl (Linux).
// ─────────────────────────────────────────────────────────────────────────

AppUser? _fdToAppUser(fd.User? u) => u == null
    ? null
    : AppUser(uid: u.uid, email: u.email, displayName: u.displayName);

class _LinuxAuthService implements AuthService {
  fd.FirebaseAuth get _auth => fd.FirebaseAuth.instance;

  @override
  AppUser? get currentUser => _fdToAppUser(_auth.currentUser);

  @override
  Stream<AppUser?> get authStateChanges =>
      _auth.authStateChanges().map(_fdToAppUser);

  @override
  Future<AppUser?> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return _fdToAppUser(cred.user);
    } on fd.FirebaseAuthException catch (e) {
      throw AuthFailure(code: e.code, message: e.message);
    }
  }

  @override
  Future<AppUser?> signUpWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return _fdToAppUser(cred.user);
    } on fd.FirebaseAuthException catch (e) {
      throw AuthFailure(code: e.code, message: e.message);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
          code: 'no-user', message: 'No user currently signed in.');
    }
    try {
      await user.updatePassword(newPassword);
    } on fd.FirebaseAuthException catch (e) {
      throw AuthFailure(code: e.code, message: e.message);
    }
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.updateProfile(displayName: name);
      await user.reload();
    } on fd.FirebaseAuthException catch (e) {
      throw AuthFailure(code: e.code, message: e.message);
    }
  }

  @override
  Future<void> reload() async {
    await _auth.currentUser?.reload();
  }
}
