import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Stores each top-level state collection as JSON text, split into parts so no single row
/// exceeds the Android cursor window limit (about 2 MB).
class StateDatabase {
  StateDatabase._();
  static final StateDatabase instance = StateDatabase._();

  static const _partChars = 256 * 1024;
  static const _table = 'state_parts';

  Future<Database>? _opening;

  Future<Database> get _database => _opening ??= _open();

  Future<Database> _open() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationDocumentsDirectory();
    return openDatabase(
      '${dir.path}/arcane_state.db',
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE $_table ('
        'user_id TEXT NOT NULL, '
        'collection TEXT NOT NULL, '
        'part INTEGER NOT NULL, '
        'data TEXT NOT NULL, '
        'PRIMARY KEY (user_id, collection, part))',
      ),
    );
  }

  Future<Map<String, String>> readCollections(String userId) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      columns: ['collection', 'data'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'collection, part',
    );
    final buffers = <String, StringBuffer>{};
    for (final row in rows) {
      buffers.putIfAbsent(row['collection'] as String, StringBuffer.new).write(row['data'] as String);
    }
    return {for (final e in buffers.entries) e.key: e.value.toString()};
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
        if (json == null) return;
        var part = 0;
        for (var start = 0; start < json.length; start += _partChars) {
          final end = start + _partChars > json.length ? json.length : start + _partChars;
          batch.insert(_table, {
            'user_id': userId,
            'collection': collection,
            'part': part++,
            'data': json.substring(start, end),
          });
        }
      });
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteUser(String userId) async {
    final db = await _database;
    await db.delete(_table, where: 'user_id = ?', whereArgs: [userId]);
  }
}
