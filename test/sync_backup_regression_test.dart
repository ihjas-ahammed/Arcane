import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/providers/mixins/sync_mixin.dart';
import 'package:missions/src/services/storage_service.dart';
import 'package:missions/src/services/app_user.dart';
import 'package:missions/src/services/state_database.dart';

class RecordingStorage extends Fake implements StorageService {
  int remoteTimestamp = 0;
  int pushes = 0;
  @override
  Future<int> getLastModified(String userId) async => remoteTimestamp;
  @override
  Future<Map<String, dynamic>> saveSnapshot(
      String userId, Map<String, dynamic> collections,
      {required int baseline,
      String? baselineVersion,
      required String deviceId,
      bool allowShrink = false}) async {
    pushes++;
    return {'lastModified': ++remoteTimestamp};
  }

  @override
  Future<void> saveOffsiteSnapshot(
      String userId, Uint8List bytes, String period) async {}
}

class SyncHarness extends ChangeNotifier with SyncMixin {
  SyncHarness(this.backend);
  final RecordingStorage backend;
  @override
  StorageService get storageService => backend;
  @override
  final currentUser = const AppUser(uid: 'sync-test');
  @override
  final settings = AppSettings(autoSaveEnabled: false);
  @override
  Map<String, dynamic> getFullAppState() =>
      {'settings': settings.toJson(), 'mainTasks': [], 'completedByDay': {}};
  @override
  Map<String, dynamic> getTaskStateMap() =>
      {'mainTasks': [], 'completedByDay': {}};
  @override
  Map<String, dynamic> getUserStateMap({bool includeReflections = true}) =>
      {'settings': settings.toJson()};
  @override
  void loadStateFromMap(Map<String, dynamic> data) {}
  @override
  dynamic mergeAppStateFromMap(Map<String, dynamic> data) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    docs = await Directory.systemTemp.createTemp('arcane_sync_regression_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => docs.path);
  });
  tearDown(() async {
    await StateDatabase.instance.close();
    await docs.delete(recursive: true);
  });
  test('manual sync works when automatic cloud backup is disabled', () async {
    final backend = RecordingStorage();
    final harness = SyncHarness(backend);
    expect(await harness.syncEndOfDay(showNotification: false, maxAttempts: 1),
        isFalse);
    expect(
        await harness.syncEndOfDay(
            showNotification: false, maxAttempts: 1, manual: true),
        isTrue);
    expect(backend.pushes, 1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    harness.dispose();
  });
  test('a fresh device with existing cloud data cannot upload defaults',
      () async {
    final backend = RecordingStorage()..remoteTimestamp = 1234;
    final harness = SyncHarness(backend);
    expect(
        await harness.syncEndOfDay(
            showNotification: false, maxAttempts: 1, manual: true),
        isFalse);
    expect(backend.pushes, 0);
    expect(harness.cloudSyncError, contains('existing cloud data'));
    harness.dispose();
  });
  test('UI-only notifications do not schedule data serialization', () {
    final harness = SyncHarness(RecordingStorage());
    harness.notifyListeners();
    expect(harness.hasPendingLocalSave, isFalse);
    harness.markDirty('history');
    expect(harness.hasPendingLocalSave, isTrue);
    harness.dispose();
  });
}
