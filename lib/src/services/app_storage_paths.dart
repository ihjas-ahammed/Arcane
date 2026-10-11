import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:crypto/crypto.dart';

/// Desktop state belongs in the app support directory. Migrate a consistent
/// SQLite snapshot and verify copied recovery files; keep every legacy source.
class AppStoragePaths {
  static final Map<String, Future<void>> _migrations = {};
  static Future<Directory> directory() async {
    final legacy = await getApplicationDocumentsDirectory();
    if (!Platform.isLinux && !Platform.isWindows) return legacy;
    final target = await getApplicationSupportDirectory();
    await target.create(recursive: true);
    if (target.path != legacy.path) {
      await (_migrations[target.path] ??= _migrate(legacy, target));
    }
    return target;
  }

  static Future<void> _migrate(Directory old, Directory target) async {
    final marker = File('${target.path}/.legacy-migration-complete');
    if (await marker.exists()) return;
    final source = File('${old.path}/arcane_state.db');
    final destination = File('${target.path}/arcane_state.db');
    if (await source.exists() && !await destination.exists()) {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(source.path);
      final temporary = File(
          '${destination.path}.migration-${DateTime.now().microsecondsSinceEpoch}');
      try {
        final checked = await db.rawQuery('PRAGMA quick_check');
        if (checked.first.values.first != 'ok')
          throw StateError('Legacy database failed its integrity check');
        await db
            .execute("VACUUM INTO '${temporary.path.replaceAll("'", "''")}'");
      } finally {
        await db.close();
      }
      final copy = await databaseFactoryFfi.openDatabase(temporary.path);
      try {
        final checked = await copy.rawQuery('PRAGMA quick_check');
        if (checked.first.values.first != 'ok')
          throw StateError('Migrated database failed its integrity check');
      } finally {
        await copy.close();
      }
      await temporary.rename(destination.path);
    }
    if (await old.exists()) {
      await for (final entity in old.list()) {
        if (entity is File &&
            entity.uri.pathSegments.last.startsWith('arcane_local_cache_')) {
          await _copyVerified(
              entity, File('${target.path}/${entity.uri.pathSegments.last}'));
        }
      }
    }
    for (final name in ['backups', 'ledger']) {
      final directory = Directory('${old.path}/$name');
      if (!await directory.exists()) continue;
      await for (final entity
          in directory.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final relative = entity.path.substring(directory.path.length + 1);
        await _copyVerified(entity, File('${target.path}/$name/$relative'));
      }
    }
    await marker.writeAsString(
        'Legacy files were copied and verified; originals preserved.\n',
        flush: true);
  }

  static Future<void> _copyVerified(File source, File target) async {
    if (await target.exists()) return;
    await target.parent.create(recursive: true);
    final tmp = File('${target.path}.migration');
    await source.copy(tmp.path);
    final sourceHash = await sha256.bind(source.openRead()).first;
    final copyHash = await sha256.bind(tmp.openRead()).first;
    if (sourceHash != copyHash)
      throw StateError('Migration checksum mismatch: ${source.path}');
    await tmp.rename(target.path);
  }
}
