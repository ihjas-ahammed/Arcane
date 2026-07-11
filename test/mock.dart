
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

// Fakes must EXTEND the platform classes (not `implements` via Mock):
// PlatformInterface.verify rejects `implements`-based mocks.
class FakeFirebaseAppPlatform extends FirebaseAppPlatform {
  FakeFirebaseAppPlatform()
      : super(
          defaultFirebaseAppName,
          const FirebaseOptions(
            apiKey: 'mock_api_key',
            appId: 'mock_app_id',
            messagingSenderId: 'mock_sender_id',
            projectId: 'mock_project_id',
          ),
        );
}

class FakeFirebasePlatform extends FirebasePlatform {
  final FakeFirebaseAppPlatform _app = FakeFirebaseAppPlatform();

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return _app;
  }

  @override
  List<FirebaseAppPlatform> get apps => [_app];

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) => _app;
}

void setupFirebaseAuthMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = FakeFirebasePlatform();
}
