import 'package:missions/src/services/app_user.dart';
import 'package:missions/src/services/auth_service.dart';

export 'package:missions/src/services/app_user.dart' show AppUser, AuthFailure;

// Top-level facade that preserves the prior `fb_service.X` call surface used
// across the app. All real logic lives in [AuthService], which picks the
// FlutterFire or firebase_dart backend at runtime based on `Platform.isLinux`.

Stream<AppUser?> get authStateChanges => AuthService.instance.authStateChanges;
AppUser? get currentUser => AuthService.instance.currentUser;

Future<AppUser?> signInWithEmail(String email, String password) =>
    AuthService.instance.signInWithEmail(email, password);

Future<AppUser?> signUpWithEmail(String email, String password) =>
    AuthService.instance.signUpWithEmail(email, password);

Future<void> signOut() => AuthService.instance.signOut();

Future<void> changePassword(String newPassword) =>
    AuthService.instance.changePassword(newPassword);

Future<void> updateDisplayName(String name) =>
    AuthService.instance.updateDisplayName(name);

Future<void> reload() => AuthService.instance.reload();
