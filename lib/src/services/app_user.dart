/// Platform-agnostic user model used everywhere outside the auth service.
/// Decouples consumers from `firebase_auth`'s `User`, so the Linux build can
/// produce the same shape from `firebase_dart` without leaking SDK types.
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;

  const AppUser({required this.uid, this.email, this.displayName});

  AppUser copyWith({String? displayName, String? email}) => AppUser(
        uid: uid,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUser &&
          uid == other.uid &&
          email == other.email &&
          displayName == other.displayName);

  @override
  int get hashCode => Object.hash(uid, email, displayName);
}

/// Exception raised by the auth service so UI screens can react without
/// importing `FirebaseAuthException` directly.
class AuthFailure implements Exception {
  final String code;
  final String? message;
  const AuthFailure({required this.code, this.message});

  @override
  String toString() => 'AuthFailure($code): ${message ?? "(no message)"}';
}
