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
    docs = await Directory.systemTemp.createTemp('arcane_load_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => docs.path,
    );
  });

  tearDown(() async {
    await StateDatabase.instance.close();
    await docs.delete(recursive: true);
  });

  const uid = 'loaduser';
  final good = {'settings': {'theme': 'dark'}, 'mainTasks': [{'id': 't1'}]};

  test('a corrupt JSON cache throws and is not replaced by the .bak copy', () async {
    File('${docs.path}/arcane_local_cache_$uid.json').writeAsStringSync('{"mainTasks": [');
    File('${docs.path}/arcane_local_cache_$uid.bak').writeAsStringSync(jsonEncode(good));

    await expectLater(
      LocalStorageService().loadState(uid),
      throwsA(isA<LocalStateException>().having((e) => e.details, 'details', isNotEmpty)),
    );
    expect(await StateDatabase.instance.readCollections(uid), isEmpty, reason: 'nothing may be written');
  });

  test('a .bak file alone is never loaded', () async {
    File('${docs.path}/arcane_local_cache_$uid.bak').writeAsStringSync(jsonEncode(good));
    expect(await LocalStorageService().loadState(uid), isNull);
  });

  test('importStateIntoDatabase replaces stored data and keeps the previous rows in backups/', () async {
    final service = LocalStorageService();
    await service.importStateIntoDatabase(uid, {'settings': {'theme': 'light'}, 'mainTasks': [{'id': 'old'}]});

    await service.importStateIntoDatabase(uid, good);

    final loaded = await LocalStorageService().loadState(uid);
    expect(const DeepCollectionEquality().equals(loaded, good), isTrue);

    final preserved = Directory('${docs.path}/backups').listSync().whereType<File>().where(
          (f) => f.path.contains('before_import_$uid'),
        );
    expect(preserved.length, 1);
    expect(jsonDecode(preserved.first.readAsStringSync())['mainTasks'], [{'id': 'old'}]);
  });
}
