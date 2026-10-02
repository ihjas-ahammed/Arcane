import 'package:flutter/foundation.dart';
import 'package:missions/src/services/app_user.dart';
import 'package:missions/src/services/auth_service.dart';

/// Debug-only Firebase account so `flutter run` builds skip the login screen.
/// Never runs in profile/release builds. It is a separate account from the real
/// one, so it starts with empty data.
class DebugUser {
  static const email = 'arcane-debug@example.com';
  static const _password = 'ArcaneDebug#2026';

  /// Signs in (creating the account on first use) when nobody is signed in.
  static Future<void> ensureSignedIn() async {
    if (!kDebugMode) return;
    final auth = AuthService.instance;
    if (auth.currentUser != null) return;
    try {
      await auth.signInWithEmail(email, _password);
      debugPrint('[DebugUser] Signed in as $email');
    } on AuthFailure catch (e) {
      debugPrint('[DebugUser] Sign-in failed (${e.code}), creating debug account');
      try {
        await auth.signUpWithEmail(email, _password);
        debugPrint('[DebugUser] Created and signed in as $email');
      } on AuthFailure catch (e2) {
        debugPrint('[DebugUser] Could not create debug account: $e2');
      }
    } catch (e) {
      debugPrint('[DebugUser] Auto sign-in error: $e');
    }
  }
}
