
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Mock FirebaseAppPlatform
class MockFirebaseAppPlatform extends Mock implements FirebaseAppPlatform {
  @override
  String get name => 'mock'; // Or any other default you prefer
  @override
  FirebaseOptions get options => const FirebaseOptions(
        apiKey: 'mock_api_key',
        appId: 'mock_app_id',
        messagingSenderId: 'mock_sender_id',
        projectId: 'mock_project_id',
      );
}

// Mock FirebaseCorePlatform
class MockFirebaseCorePlatform extends Mock implements FirebasePlatform {
  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseAppPlatform();
  }

  @override
  List<FirebaseAppPlatform> get apps => [MockFirebaseAppPlatform()];

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseAppPlatform();
  }
}


void setupFirebaseAuthMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock FirebaseCorePlatform
  final mockCorePlatform = MockFirebaseCorePlatform();
  FirebasePlatform.instance = mockCorePlatform;
  
  // Mock FirebaseAppPlatform (used by Firebase.initializeApp)
  // This part might be tricky as Firebase.initializeApp directly calls native code.
  // For simple unit/widget tests not deeply testing Firebase,
  // ensuring Firebase.initializeApp doesn't throw is often enough.
  // The above mockCorePlatform should handle the Firebase.app() calls.

  // If you are testing Firebase Auth, Firestore, etc., you'd also mock their respective platform interfaces
  // using packages like firebase_auth_mocks, cloud_firestore_mocks, or custom mocks.
}
