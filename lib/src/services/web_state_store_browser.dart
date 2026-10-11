import 'package:idb_shim/idb_browser.dart';

class WebStateStore {
  static Future<Database>? _opening;
  static Future<Database> get _database => _opening ??= idbFactoryNative
          .open('arcane_state', version: 1, onUpgradeNeeded: (event) {
        event.database.createObjectStore('state');
      });
  static Future<String?> read(String key) async {
    final db = await _database;
    final txn = db.transaction('state', idbModeReadOnly);
    final value = await txn.objectStore('state').getObject(key);
    await txn.completed;
    return value as String?;
  }

  static Future<void> write(String key, String value) async {
    final db = await _database;
    final txn = db.transaction('state', idbModeReadWrite);
    await txn.objectStore('state').put(value, key);
    await txn.completed;
  }

  static Future<void> remove(String key) async {
    final db = await _database;
    final txn = db.transaction('state', idbModeReadWrite);
    await txn.objectStore('state').delete(key);
    await txn.completed;
  }
}
