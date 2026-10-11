import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/local_storage_service.dart';
import 'package:missions/src/services/state_database.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/models/sop_model.dart';
import 'package:missions/src/services/storage_service.dart';
import 'package:missions/src/services/app_user.dart';
import 'package:missions/src/services/state_validator.dart';
import 'mock.dart';

class RecoveryStorage extends Fake implements StorageService {
  int remoteTimestamp = 0;
  @override
  Future<int> getLastModified(String userId) async => remoteTimestamp;
}

class RecoveryProvider extends AppProvider {
  RecoveryProvider(this.backend) : super.forTest();
  final RecoveryStorage backend;
  @override
  StorageService get storageService => backend;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseAuthMocks();
  late Directory docs;
  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    docs = await Directory.systemTemp.createTemp('arcane_integrity_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => docs.path);
  });
  tearDown(() async {
    await StateDatabase.instance.close();
    await docs.delete(recursive: true);
  });
  test(
      'emoji spanning the 256K boundary survives write/read and verified import',
      () async {
    final text = '"${'a' * 262142}😀 tail"';
    await StateDatabase.instance.replaceUser('emoji', {'text': text});
    expect(
        (await StateDatabase.instance.readCollections('emoji'))['text'], text);
    await LocalStorageService()
        .importStateIntoDatabase('emoji', {'text': jsonDecode(text)});
    expect((await LocalStorageService().loadState('emoji'))!['text'],
        jsonDecode(text));
  });
  test('failed backup creation preserves all existing rows', () async {
    await StateDatabase.instance
        .replaceUser('backup-failure', {'settings': '{"theme":"dark"}'});
    await File('${docs.path}/backups')
        .writeAsString('A file blocking directory creation');
    await expectLater(
        LocalStorageService().importStateIntoDatabase('backup-failure', {
          'settings': {'theme': 'light'}
        }),
        throwsA(isA<LocalStateException>()));
    expect(
        (await StateDatabase.instance
            .readCollections('backup-failure'))['settings'],
        '{"theme":"dark"}');
  });
  test('insertion failure rolls back the delete and replacement', () async {
    await StateDatabase.instance
        .replaceUser('rollback', {'settings': '{"theme":"dark"}'});
    final db =
        await databaseFactoryFfi.openDatabase('${docs.path}/arcane_state.db');
    await db.execute(
        "CREATE TRIGGER reject_import BEFORE INSERT ON state_parts WHEN NEW.data = '\"fail\"' BEGIN SELECT RAISE(ABORT, 'simulated disk full'); END");
    await expectLater(
        LocalStorageService()
            .importStateIntoDatabase('rollback', {'settings': 'fail'}),
        throwsA(isA<LocalStateException>()));
    expect(
        (await StateDatabase.instance.readCollections('rollback'))['settings'],
        '{"theme":"dark"}');
  });
  test(
      'one malformed child preserves readable siblings, raw records, and history through a round trip',
      () async {
    final provider = AppProvider.forTest();
    provider.beginDataLoad();
    final state = {
      'mainTasks': [
        {
          'id': 'main',
          'name': 'Tasks',
          'description': '',
          'theme': '',
          'subTasks': [
            {
              'id': 'ok',
              'name': 'Readable',
              'currentTimeSpent': 12.0,
              'createdAt': 'bad date'
            },
            {
              'id': 'broken',
              'name': 'Raw record',
              'currentTimeSpent': 'not a number'
            },
          ]
        }
      ],
      'completedByDay': {
        '2026-01-01': {'note': 'keep this history'}
      },
    };
    provider.loadStateFromMap(state);
    provider.endDataLoad();
    expect(provider.mainTasks.single.subTasks.single.id, 'ok');
    expect(provider.mainTasks.single.subTasks.single.currentTimeSpent, 12);
    expect(provider.failedCollections, contains('mainTasks'));
    expect(provider.quarantine, isNotEmpty);
    await LocalStorageService()
        .saveState('corrupt-child', provider.getFullAppState());
    final restored = await LocalStorageService().loadState('corrupt-child');
    expect(restored!['mainTasks'], state['mainTasks']);
    expect(restored['completedByDay'], state['completedByDay']);
    expect(restored['_quarantine'], isNotEmpty);
    provider.dispose();
  });
  test('an incremental history change rewrites only its day row', () async {
    final service = LocalStorageService();
    final initial = {
      'completedByDay': {
        '2026-10-10': {'note': 'old'},
        '2026-10-11': {'note': 'today'}
      }
    };
    await service.importStateIntoDatabase('partitioned', initial);
    final before = await StateDatabase.instance.readCollections('partitioned');
    await service.saveState(
        'partitioned',
        {
          'completedByDay': {
            '2026-10-10': {'note': 'old'},
            '2026-10-11': {'note': 'changed'}
          }
        },
        partial: true);
    final after = await StateDatabase.instance.readCollections('partitioned');
    expect(before.keys.where((k) => before[k] != after[k]).length, 1);
    expect(
        (await service.loadState('partitioned'))!['completedByDay']
            ['2026-10-11']['note'],
        'changed');
  });
  test('lenient task parsing accepts JSON integer doubles and missing names',
      () {
    final task = SubTask.fromJson(
        {'id': 's', 'currentTimeSpent': 12.0, 'createdAt': 'invalid'});
    expect(task.currentTimeSpent, 12);
    expect(task.name, '');
  });
  test('empty local DB must attach even when a prior baseline survives',
      () async {
    SharedPreferences.setMockInitialValues({'cloud_baseline_empty': 1234});
    final provider =
        RecoveryProvider(RecoveryStorage()..remoteTimestamp = 1234);
    provider.setCurrentUser(const AppUser(uid: 'empty'));
    await provider.retryLocalLoad();
    expect(provider.cloudAttachRequired, isTrue);
    expect(provider.localLoadError, isNotNull);
    expect(await StateDatabase.instance.readCollections('empty'), isEmpty);
    provider.dispose();
  });
  test('retry after repairing raw data clears the recovery guards', () async {
    final service = LocalStorageService();
    await service.importStateIntoDatabase('repair', {
      'mainTasks': [
        {'id': 'broken', 'subTasks': 'invalid'}
      ]
    });
    final provider = RecoveryProvider(RecoveryStorage());
    provider.setCurrentUser(const AppUser(uid: 'repair'));
    await provider.retryLocalLoad();
    expect(provider.failedCollections, contains('mainTasks'));
    await service.importStateIntoDatabase('repair', {
      'mainTasks': [
        {'id': 'fixed', 'name': 'Repaired'}
      ]
    });
    await provider.retryLocalLoad();
    expect(provider.localLoadError, isNull);
    expect(provider.failedCollections, isEmpty);
    expect(provider.quarantine, isEmpty);
    expect(provider.mainTasks.single.id, 'fixed');
    provider.dispose();
  });
  test('malformed trading and launcher records remain protected on load',
      () async {
    final raw = {
      'mainTasks': [],
      'trading': {'cashBalance': 'broken'},
      'launcher': {
        'widgets': [
          {'id': 'broken'}
        ]
      }
    };
    await LocalStorageService().importStateIntoDatabase('raw', raw);
    final provider = RecoveryProvider(RecoveryStorage());
    provider.setCurrentUser(const AppUser(uid: 'raw'));
    await provider.retryLocalLoad();
    expect(provider.failedCollections, containsAll(['trading', 'launcher']));
    expect(provider.getFullAppState()['trading'], raw['trading']);
    expect(provider.getFullAppState()['launcher'], raw['launcher']);
    await provider.forceLocalBackup();
    final stored = await LocalStorageService().loadState('raw');
    expect(stored!['trading'], raw['trading']);
    expect(stored['launcher'], raw['launcher']);
    provider.dispose();
  });
  test('replacement removes local-only records and creates recovery files',
      () async {
    final provider = RecoveryProvider(RecoveryStorage());
    provider.setCurrentUser(const AppUser(uid: 'replace'));
    await provider.replaceStateSafely({
      'mainTasks': [
        {'id': 'local-only', 'name': 'Original'}
      ],
      'reflectionLogs': []
    });
    await provider.replaceStateSafely({
      'mainTasks': [
        {'id': 'restored', 'name': 'Restored'}
      ],
      'reflectionLogs': []
    });
    expect(provider.mainTasks.map((task) => task.id), ['restored']);
    final stored = await LocalStorageService().loadState('replace');
    expect((stored!['mainTasks'] as List).single['id'], 'restored');
    final backups = (await Directory('${docs.path}/backups').list().toList())
        .whereType<File>();
    expect(backups.any((file) => file.path.contains('before_replace_replace_')),
        isTrue);
    expect(backups.any((file) => file.path.contains('before_import_replace_')),
        isTrue);
    provider.dispose();
  });
  test('normalization rejects malformed records instead of dropping them', () {
    for (final state in [
      {
        'mainTasks': [
          {'id': 'ok'},
          'unreadable'
        ]
      },
      {
        'reflectionLogs': {'bad': 'unreadable'}
      },
      {
        'completedByDay': {'2026-10-11': 'unreadable'}
      },
      {
        'users': {'account-a': {}, 'account-b': {}}
      },
    ]) {
      expect(() => AppProvider.normalizeImportedData(state),
          throwsFormatException);
    }
    expect(
        () => validateAppState({
              'trading': {
                'orders': ['unreadable']
              }
            }),
        throwsA(isA<TypeError>()));
  });
  test('account reload clears the previous account skills and SOPs', () async {
    final provider = RecoveryProvider(RecoveryStorage());
    provider.setCurrentUser(const AppUser(uid: 'previous'));
    provider.setSkills(
        [Skill(id: 'private', name: 'Private skill', description: 'Private')]);
    provider.setSops([
      SopModel.fromJson({'id': 'private', 'title': 'Private SOP', 'steps': []})
    ]);
    await provider.forceLocalBackup();
    provider.setCurrentUser(const AppUser(uid: 'next'));
    await provider.retryLocalLoad();
    expect(provider.sops, isEmpty);
    expect(provider.skills.any((skill) => skill.id == 'private'), isFalse);
    provider.dispose();
  });
  test('a restart retains the fact that saved local edits need cloud backup',
      () async {
    final first = RecoveryProvider(RecoveryStorage());
    first.setCurrentUser(const AppUser(uid: 'dirty'));
    first.markDirty('tasks');
    await first.forceLocalBackup();
    first.dispose();
    final restarted = RecoveryProvider(RecoveryStorage());
    restarted.setCurrentUser(const AppUser(uid: 'dirty'));
    await restarted.retryLocalLoad();
    expect(restarted.hasUnsavedChanges, isTrue);
    restarted.dispose();
  });
  test(
      'pending energy replies wait for account load, preserve dates, and acknowledge only after saving',
      () async {
    final timestamp = DateTime(2026, 10, 9, 23, 40);
    final raw = jsonEncode({
      'id': 'energy',
      'reply': 'tired',
      'level': 3,
      'userId': 'energy',
      'timestamp': timestamp.toIso8601String()
    });
    final foreign = jsonEncode({
      'id': 'foreign',
      'reply': 'good',
      'userId': 'other-account',
      'timestamp': timestamp.toIso8601String()
    });
    SharedPreferences.setMockInitialValues({
      'pending_energy_log_energy': raw,
      'pending_energy_log_foreign': foreign
    });
    final provider = RecoveryProvider(RecoveryStorage());
    provider.setCurrentUser(const AppUser(uid: 'energy'));
    provider.beginDataLoad();
    await provider.drainPendingEnergyLogs();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pending_energy_log_energy'), raw);
    provider.endDataLoad();
    await provider.retryLocalLoad();
    await provider.drainPendingEnergyLogs();
    expect(provider.getDailyHealthLog('2026-10-09').energyLogs.single.timestamp,
        timestamp);
    expect(prefs.getString('pending_energy_log_energy'), isNull);
    expect(prefs.getString('pending_energy_log_foreign'), foreign);
    await prefs.setString('pending_energy_log_energy', raw);
    await provider.drainPendingEnergyLogs();
    expect(provider.getDailyHealthLog('2026-10-09').energyLogs, hasLength(1),
        reason: 'Replayed native replies must be idempotent');
    final stored = await LocalStorageService().loadState('energy');
    expect(stored!['healthLogs']['2026-10-09']['energyLogs'], hasLength(1));
    provider.dispose();
  });
  test('merge retains health entries from both devices and preserves conflicts',
      () {
    final provider = RecoveryProvider(RecoveryStorage());
    provider.loadStateFromMap({
      'healthLogs': {
        '2026-10-10': {
          'dateStr': '2026-10-10',
          'waterGlasses': 4,
          'energyLogs': [
            {'id': 'local', 'level': 4}
          ]
        },
        '2026-10-11': {'dateStr': '2026-10-11', 'waterGlasses': 3},
      }
    });
    provider.mergeAppStateFromMap({
      'healthLogs': {
        '2026-10-10': {
          'dateStr': '2026-10-10',
          'waterGlasses': 2,
          'energyLogs': [
            {'id': 'remote', 'level': 6}
          ]
        },
      }
    });
    expect(provider.healthLogs.keys, containsAll(['2026-10-10', '2026-10-11']));
    expect(provider.healthLogs['2026-10-10']!.energyLogs.map((log) => log.id),
        containsAll(['local', 'remote']));
    expect(provider.healthLogs['2026-10-10']!.waterGlasses, 4);
    expect(
        provider.mergeConflicts
            .any((conflict) => conflict['collection'] == 'healthLogs'),
        isTrue);
    provider.dispose();
  });
  test(
      'loading restored categories replaces default names and accepts explicit empty collections',
      () {
    final provider = RecoveryProvider(RecoveryStorage());
    provider.initializeDefaultFinanceCategories();
    provider.loadStateFromMap({
      'categories': [
        {'id': 'cat_food', 'name': 'My groceries'}
      ]
    });
    expect(provider.categories.single.name, 'My groceries');
    provider.loadStateFromMap({'categories': [], 'trackedSkills': []});
    expect(provider.categories, isEmpty);
    expect(provider.trackedSkills, isEmpty);
    provider.dispose();
  });
}
