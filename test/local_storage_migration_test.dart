import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/services/local_storage_service.dart';
import 'package:missions/src/services/state_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('arcane_migration_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => docs.path,
    );
  });

  tearDown(() async {
    await StateDatabase.instance.close();
    await docs.delete(recursive: true);
  });

  Map<String, dynamic> sampleState(int tasks) => {
        'settings': {'theme': 'dark', 'lastModified': 1},
        'mainTasks': [for (var i = 0; i < tasks; i++) {'id': 't$i', 'title': 'Task $i ' * 20}],
        'completedByDay': {'2026-10-07': 3},
      };

  test('imports legacy JSON, reloads from SQLite, saves incrementally, and clears', () async {
    const uid = 'testuser1';
    final legacy = sampleState(20000); // large enough to span several 256K parts
    final legacyFile = File('${docs.path}/arcane_local_cache_$uid.json');
    await legacyFile.writeAsString(jsonEncode(legacy));

    final service = LocalStorageService();

    final first = await service.loadState(uid);
    expect(first, isNotNull);
    expect(const DeepCollectionEquality().equals(first, legacy), isTrue);

    final rows = await StateDatabase.instance.readCollections(uid);
    expect(rows.keys.toSet(), legacy.keys.toSet());
    expect(legacyFile.existsSync(), isTrue, reason: 'legacy JSON must be kept after import');

    final relaunched = await LocalStorageService().loadState(uid);
    expect(const DeepCollectionEquality().equals(relaunched, legacy), isTrue);

    final changed = sampleState(20000)..['settings'] = {'theme': 'light', 'lastModified': 2};
    await service.saveState(uid, changed);
    final afterSave = await StateDatabase.instance.readCollections(uid);
    expect(jsonDecode(afterSave['settings']!), {'theme': 'light', 'lastModified': 2});
    expect(afterSave['mainTasks'], rows['mainTasks']);

    final backups = await service.getDailyBackupFiles(uid);
    expect(backups.length, 1);
    expect(jsonDecode(await backups.first.readAsString())['settings'], {'theme': 'light', 'lastModified': 2});

    await service.clearState(uid);
    expect(await StateDatabase.instance.readCollections(uid), isEmpty);
    expect(legacyFile.existsSync(), isFalse);
  });

  test('a user with no data loads null', () async {
    expect(await LocalStorageService().loadState('nobody'), isNull);
  });
}
