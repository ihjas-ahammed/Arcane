import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:missions/src/services/app_storage_paths.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Stores each top-level state collection as JSON text, split into parts so no single row
/// exceeds the Android cursor window limit (about 2 MB).
class StateDatabase {
  StateDatabase._();
  static final StateDatabase instance = StateDatabase._();

  static const _partChars = 256 * 1024;
  static const _table = 'state_parts';

  Future<Database>? _opening;
  int generation = 0;

  Future<Database> get _database => _opening ??= _open();

  /// Closes the open database so the next call reopens it. Used by tests that remove the
  /// database directory between cases.
  Future<void> close() async {
    generation++;
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }

  Future<Database> _open() async {
    // Android and iOS use the platform sqflite plugin; only desktop needs the FFI factory.
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await AppStoragePaths.directory();
    return openDatabase(
      '${dir.path}/arcane_state.db',
      version: 2,
      onConfigure: (db) async {
        // journal_mode returns a row; Android sqflite rejects row-returning statements in execute().
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA synchronous=FULL');
      },
      onOpen: (db) async {
        final check = await db.rawQuery('PRAGMA quick_check');
        if (check.first.values.first != 'ok') {
          throw StateError('SQLite integrity check failed: $check');
        }
      },
      onUpgrade: (db, old, next) async {
        await db.execute('CREATE TABLE IF NOT EXISTS state_meta (user_id TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY (user_id, key))');
      },
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE state_meta (user_id TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY (user_id, key))');
        await db.execute(
        'CREATE TABLE $_table ('
        'user_id TEXT NOT NULL, '
        'collection TEXT NOT NULL, '
        'part INTEGER NOT NULL, '
        'data TEXT NOT NULL, '
        'PRIMARY KEY (user_id, collection, part))',
        );
      },
    );
  }

  Future<Map<String, String>> readCollections(String userId) async {
    final db = await _database;
    return db.transaction((txn) => _readCollections(txn, userId));
  }

  Future<Map<String, String>> _readCollections(DatabaseExecutor db, String userId) async {
    final rows = await db.query(
      _table,
      columns: ['collection', 'data'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'collection, part',
    );
    final buffers = <String, StringBuffer>{};
    Map<String, Object?>? previousPart;
    for (final row in rows) {
      if (previousPart != null && previousPart['collection'] == row['collection'] && (previousPart['data'] as String).endsWith('\uFFFD') && (row['data'] as String).startsWith('\uFFFD')) {
        throw StateError('Legacy Unicode boundary damage in ${row['collection']}; restore this collection from a backup.');
      }
      previousPart = row;
      buffers.putIfAbsent(row['collection'] as String, StringBuffer.new).write(row['data'] as String);
    }
    final result = {for (final e in buffers.entries) e.key: e.value.toString()};
    final hashes = await db.query('state_meta', where: 'user_id = ?', whereArgs: [userId]);
    for (final row in hashes) {
      final key = row['key'] as String;
      if (!key.startsWith('hash:')) continue;
      final json = result[key.substring(5)];
      if (json == null || sha256.convert(utf8.encode(json)).toString() != row['value']) {
        throw StateError('Checksum mismatch for ${key.substring(5)}');
      }
    }
    return result;
  }

  /// A null value removes that collection. All changes commit in one transaction.
  Future<void> writeCollections(String userId, Map<String, String?> changes) async {
    if (changes.isEmpty) return;
    final db = await _database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      changes.forEach((collection, json) {
        batch.delete(
          _table,
          where: 'user_id = ? AND collection = ?',
          whereArgs: [userId, collection],
        );
        batch.delete('state_meta', where: 'user_id = ? AND key = ?', whereArgs: [userId, 'hash:$collection']);
        if (json != null) _insertParts(batch, userId, collection, json);
      });
      await batch.commit(noResult: true);
    });
  }

  /// Replaces everything stored for [userId] with [collections], in one transaction.
  Future<void> replaceUser(String userId, Map<String, String> collections) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(_table, where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('state_meta', where: 'user_id = ? AND key LIKE ?', whereArgs: [userId, 'hash:%']);
      final batch = txn.batch();
      collections.forEach((collection, json) => _insertParts(batch, userId, collection, json));
      await batch.commit(noResult: true);
      final verified = await _readCollections(txn, userId);
      if (!mapEquals(verified, collections)) throw StateError('Import read-back differs; rolling back');
    });
  }

  void _insertParts(Batch batch, String userId, String collection, String json) {
    batch.insert('state_meta', {'user_id': userId, 'key': 'hash:$collection', 'value': sha256.convert(utf8.encode(json)).toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
    var part = 0;
    var start = 0;
    while (start < json.length) {
      var end = start + _partChars > json.length ? json.length : start + _partChars;
      if (end < json.length && json.codeUnitAt(end - 1) >= 0xD800 && json.codeUnitAt(end - 1) <= 0xDBFF) end--;
      batch.insert(_table, {
        'user_id': userId,
        'collection': collection,
        'part': part++,
        'data': json.substring(start, end),
      });
      start = end;
    }
  }

  Future<void> setMeta(String userId, String key, String value) async {
    final db = await _database;
    await db.insert('state_meta', {'user_id': userId, 'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getMeta(String userId, String key) async {
    final db = await _database;
    final rows = await db.query('state_meta', where: 'user_id = ? AND key = ?', whereArgs: [userId, key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> deleteUser(String userId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(_table, where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('state_meta', where: 'user_id = ?', whereArgs: [userId]);
    });
  }
}
