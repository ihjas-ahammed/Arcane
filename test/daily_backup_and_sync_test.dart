import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/services/local_storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  MockPathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempDir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory testDocsDir;
  late LocalStorageService storageService;
  const userId = 'test_user_sync_123';

  setUp(() async {
    testDocsDir = await Directory.systemTemp.createTemp('arcane_daily_backup_test_');
    PathProviderPlatform.instance = MockPathProviderPlatform(testDocsDir);
    storageService = LocalStorageService();
  });

  tearDown(() async {
    if (await testDocsDir.exists()) {
      await testDocsDir.delete(recursive: true);
    }
  });

  group('LocalStorageService Daily Backup & Recovery Tests', () {
    test('saves state atomically without auto daily backup, and supports explicit backup', () async {
      final sampleState = {
        'tasks': [{'id': 't1', 'title': 'Test Mission'}],
        'lastModified': 123456789,
      };

      await storageService.saveState(userId, sampleState);

      // Verify primary cache exists
      final primaryFile = File('${testDocsDir.path}/arcane_local_cache_$userId.json');
      expect(await primaryFile.exists(), isTrue);

      // Verify auto daily backup is disabled (no backups dir created automatically)
      final autoBackups = await storageService.getDailyBackupFiles(userId);
      expect(autoBackups.isEmpty, isTrue);

      // Explicit manual backup creates snapshot
      await storageService.performDailyBackup(userId, sampleState);
      final backups = await storageService.getDailyBackupFiles(userId);
      expect(backups.isNotEmpty, isTrue);
      expect(backups.first.path.contains('daily_backup_$userId'), isTrue);

      final decoded = jsonDecode(await backups.first.readAsString());
      expect(decoded['lastModified'], equals(123456789));
    });

    test('prunes old backups to maintain strictly at most 7 days of recovery data', () async {
      final backupDir = Directory('${testDocsDir.path}/backups');
      await backupDir.create(recursive: true);

      // Create 10 fake past daily backup files
      for (int i = 1; i <= 10; i++) {
        final dayStr = i < 10 ? '0$i' : '$i';
        final pastFile = File('${backupDir.path}/daily_backup_${userId}_2026-09-$dayStr.json');
        await pastFile.writeAsString(jsonEncode({'day': i}));
      }

      var filesBefore = await storageService.getDailyBackupFiles(userId);
      expect(filesBefore.length, equals(10));

      // Trigger daily backup creation / pruning
      final todayState = {'day': 'today', 'value': 999};
      await storageService.performDailyBackup(userId, todayState);

      final filesAfter = await storageService.getDailyBackupFiles(userId);
      // Must keep up to 7 most recent recovery files
      expect(filesAfter.length, equals(7));

      // Newest should be today's file or the highest chronological date
      final newestName = filesAfter.first.uri.pathSegments.last;
      expect(newestName.startsWith('daily_backup_$userId'), isTrue);

      // The oldest 3 files from 2026-09-01, 2026-09-02, 2026-09-03 must have been pruned
      expect(await File('${backupDir.path}/daily_backup_${userId}_2026-09-01.json').exists(), isFalse);
      expect(await File('${backupDir.path}/daily_backup_${userId}_2026-09-02.json').exists(), isFalse);
      expect(await File('${backupDir.path}/daily_backup_${userId}_2026-09-03.json').exists(), isFalse);
    });

    test('recovers state from latest daily backup when primary and .bak are missing', () async {
      final backupDir = Directory('${testDocsDir.path}/backups');
      await backupDir.create(recursive: true);

      final backupData = {
        'tasks': [{'id': 'recovered_task', 'title': 'Rescued Mission'}],
        'recovered': true,
      };
      final backupFile = File('${backupDir.path}/daily_backup_${userId}_2026-10-01.json');
      await backupFile.writeAsString(jsonEncode(backupData));

      // Primary and .bak files do NOT exist
      final primaryFile = File('${testDocsDir.path}/arcane_local_cache_$userId.json');
      final bakFile = File('${testDocsDir.path}/arcane_local_cache_$userId.bak');
      expect(await primaryFile.exists(), isFalse);
      expect(await bakFile.exists(), isFalse);

      // loadState should fallback to daily backup and restore primary
      final loaded = await storageService.loadState(userId);
      expect(loaded, isNotNull);
      expect(loaded!['recovered'], isTrue);
      expect(await primaryFile.exists(), isTrue);
    });

    test('updates daily backup with richer state but protects against shrunken partial overwrite', () async {
      // 1. Initial full state
      final fullState = {
        'tasks': List.generate(20, (i) => {'id': 't$i', 'title': 'Task $i'}),
        'reflections': List.generate(15, (i) => {'id': 'r$i', 'content': 'Deep reflection entry $i'}),
      };
      await storageService.performDailyBackup(userId, fullState);

      final backups = await storageService.getDailyBackupFiles(userId);
      expect(backups.length, equals(1));
      final initialLength = await backups.first.length();
      expect(initialLength, greaterThan(500));

      // 2. Richer state: adds 10 more tasks -> backup must update
      final richerState = {
        'tasks': List.generate(30, (i) => {'id': 't$i', 'title': 'Task $i'}),
        'reflections': List.generate(20, (i) => {'id': 'r$i', 'content': 'Deep reflection entry $i'}),
      };
      await storageService.performDailyBackup(userId, richerState);
      final updatedLength = await backups.first.length();
      expect(updatedLength, greaterThan(initialLength));

      // 3. Shrunken / empty state (< 70% size): should NOT overwrite the healthy backup
      final tinyState = {
        'tasks': [{'id': 't0'}],
      };
      await storageService.performDailyBackup(userId, tinyState);
      final preservedLength = await backups.first.length();
      expect(preservedLength, equals(updatedLength)); // Protected!
    });
  });
}
