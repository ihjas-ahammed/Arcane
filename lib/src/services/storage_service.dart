import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:missions/src/services/auth_service.dart';
import 'package:missions/src/services/cloud_snapshot_store.dart';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_dart/firebase_dart.dart' as fd;
import 'package:firedart/firedart.dart' as firedart;

const String _userCollection = 'users';

const String _docTasks = 'tasks';
const String _docSettings = 'settings';
const String _docFinance = 'finance';
const String _docHealth = 'health';
const String _docTrading = 'trading';
const String _docLauncher = 'launcher';

// ── Chunked cloud writes ─────────────────────────────────────────────────
// A whole collection used to be written as one multi-MB string, which blew the heap and the
// platform-channel buffer. Collections are now stored as many small parts under
// users/<uid>/chunks/<name>/<version>/pNNNNN, with a tiny pointer node at data/<name>. Syncing
// runs overnight, so we favour small parts, pauses and retries over speed.
const int _partChars = 24 * 1024;
const Duration _partPause = Duration(milliseconds: 60);
const int _partRetries = 8;

String _partKey(int i) => 'p${i.toString().padLeft(5, '0')}';

List<String> _splitJsonParts(String json) {
  final parts = <String>[];
  var start = 0;
  while (start < json.length) {
    var end = start + _partChars;
    if (end >= json.length) {
      end = json.length;
    } else if (json.codeUnitAt(end - 1) >= 0xD800 && json.codeUnitAt(end - 1) <= 0xDBFF) {
      end -= 1; // never cut a surrogate pair in half
    }
    parts.add(json.substring(start, end));
    start = end;
  }
  return parts.isEmpty ? [''] : parts;
}

Future<void> _withRetry(Future<void> Function() op) async {
  for (var attempt = 0;; attempt++) {
    try {
      await op();
      return;
    } catch (_) {
      if (attempt >= _partRetries - 1) rethrow;
      await Future.delayed(Duration(seconds: 2 << attempt));
    }
  }
}

/// Turns a pointer node back into the JSON string it stands for; anything else passes through.
Future<dynamic> _resolveChunked(dynamic value, Future<dynamic> Function(int ver, int i) readPart) async {
  if (value is! Map || value['_chunked'] != true) return value;
  final ver = (value['ver'] as num).toInt();
  final n = (value['n'] as num).toInt();
  final b = StringBuffer();
  for (var i = 0; i < n; i++) {
    final part = await readPart(ver, i);
    if (part is! String) throw StateError('Missing cloud part $i/$n (v$ver)');
    b.write(part);
  }
  return b.toString();
}

/// Cross-platform cloud storage facade. The factory constructor selects the
/// concrete impl: FlutterFire on Android/iOS/web/macOS/Windows, and a pair
/// of pure-Dart clients (firebase_dart for RTDB, firedart for Firestore) on
/// Linux. Consumers keep calling `StorageService()` and never see the split.
abstract class StorageService {
  factory StorageService() => (!kIsWeb && Platform.isLinux)
      ? _LinuxStorageService()
      : _FlutterFireStorageService();

  CloudSnapshotStore get snapshots;
  Future<void> saveOffsiteSnapshot(String userId, Uint8List bytes, String period);
  Future<Map<String, dynamic>> saveSnapshot(String userId, Map<String, dynamic> collections, {required int baseline, String? baselineVersion, required String deviceId, bool allowShrink = false});
  Future<List<Map<String, dynamic>>> getCloudVersions(String userId);
  Future<Map<String, dynamic>> getCloudVersion(String userId, String version);
  Future<Map<String, dynamic>?> getUserSnapshot(String userId);
  Future<Map<String, dynamic>?> getUserData(String userId);
  Future<int> getLastModified(String userId);
  Future<void> setLastModified(String userId, int timestamp);
  Stream<int> watchLastModified(String userId);
  Future<bool> saveTasks(String userId, Map<String, dynamic> data);
  Future<bool> saveSettings(String userId, Map<String, dynamic> data);
  Future<bool> saveFinance(String userId, Map<String, dynamic> data);
  Future<bool> saveHealth(String userId, Map<String, dynamic> data);
  Future<bool> saveTrading(String userId, Map<String, dynamic> data);
  Future<bool> saveLauncher(String userId, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> getTrading(String userId);
  Future<bool> saveCrashLogs(String userId, List<String> logs);
  Future<bool> saveHistory(String userId, Map<String, dynamic> data);
  Future<bool> saveReflections(String userId, Map<String, dynamic> data);
  Future<bool> deleteReflection(String userId, String reflectionId);
  Future<bool> deleteUserData(String userId);
  Future<bool> saveDailyData(
      String userId, String date, String type, Map<String, dynamic> data);
  Future<Map<String, Map<String, dynamic>>> fetchRecentDailyData(
      String userId, int days);
  Future<bool> saveWeeklyReport(
      String userId, String date, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> fetchWeeklyReports(String userId);
  Future<bool> saveMonthlyReport(
      String userId, String date, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> fetchMonthlyReports(String userId);
}

Future<List<String>> _cloudKeys(String path) async {
  final token = await AuthService.instance.getIdToken();
  if (token == null) throw StateError('Sign in to read the cloud index');
  final uri = Uri.https('task-dominion-default-rtdb.asia-southeast1.firebasedatabase.app', '/$path.json', {'shallow': 'true', 'auth': token});
  final response = await http.get(uri).timeout(const Duration(seconds: 30));
  if (response.statusCode != 200) throw StateError('Cloud index request failed (${response.statusCode})');
  final value = jsonDecode(response.body);
  return value is Map ? value.keys.map((k) => k.toString()).toList() : [];
}

// Shared helper — collapses the RTDB chunk JSON back into one flat state map.
Map<String, dynamic> _parseRtdbData(Map<dynamic, dynamic> raw) {
  Map<String, dynamic> fullData = {};
  if (raw[_docSettings] != null) {
    if (raw[_docSettings] is String) {
      fullData.addAll(jsonDecode(raw[_docSettings] as String));
    } else if (raw[_docSettings] is Map) {
      fullData.addAll(Map<String, dynamic>.from(raw[_docSettings] as Map));
    }
  }
  if (raw[_docTasks] != null) {
    if (raw[_docTasks] is String) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(raw[_docTasks] as String));
        decoded.remove('completedByDay');
        fullData.addAll(decoded);
      } catch (_) {
        rethrow;
      }
    } else if (raw[_docTasks] is Map) {
      final decoded = Map<String, dynamic>.from(raw[_docTasks] as Map);
      decoded.remove('completedByDay');
      fullData.addAll(decoded);
    }
  }
  if (raw[_docFinance] != null) {
    if (raw[_docFinance] is String) {
      fullData.addAll(jsonDecode(raw[_docFinance] as String));
    } else if (raw[_docFinance] is Map) {
      fullData.addAll(Map<String, dynamic>.from(raw[_docFinance] as Map));
    }
  }
  if (raw[_docHealth] != null) {
    if (raw[_docHealth] is String) {
      fullData.addAll(jsonDecode(raw[_docHealth] as String));
    } else if (raw[_docHealth] is Map) {
      fullData.addAll(Map<String, dynamic>.from(raw[_docHealth] as Map));
    }
  }

  if (raw['history'] != null) {
    if (raw['history'] is String) {
      fullData.addAll(jsonDecode(raw['history'] as String));
    } else if (raw['history'] is Map) {
      Map<String, dynamic> history = {};
      (raw['history'] as Map).forEach((date, jsonStr) {
        if (jsonStr is String) {
          try {
            history[date.toString()] = jsonDecode(jsonStr);
          } catch (_) {
            history[date.toString()] = jsonStr;
          }
        } else {
          history[date.toString()] = jsonStr;
        }
      });
      fullData['completedByDay'] = history;
    }
  }

  if (raw['reflections'] != null) {
    if (raw['reflections'] is String) {
      fullData.addAll(jsonDecode(raw['reflections'] as String));
    } else if (raw['reflections'] is Map) {
      List<dynamic> reflections = [];
      (raw['reflections'] as Map).forEach((id, jsonStr) {
        if (jsonStr is String) {
          try {
            reflections.add(jsonDecode(jsonStr));
          } catch (_) {
            reflections.add(jsonStr);
          }
        } else {
          reflections.add(jsonStr);
        }
      });
      // Sort reflections chronologically ascending by timestamp so order is deterministic
      reflections.sort((a, b) {
        final tA = a is Map ? (a['timestamp'] ?? '') : '';
        final tB = b is Map ? (b['timestamp'] ?? '') : '';
        return tA.toString().compareTo(tB.toString());
      });
      fullData['reflectionLogs'] = reflections;
    }
  }

  if (raw[_docTrading] != null) {
    if (raw[_docTrading] is String) {
      try {
        fullData['trading'] = jsonDecode(raw[_docTrading] as String);
      } catch (_) {
        fullData['trading'] = raw[_docTrading];
      }
    } else if (raw[_docTrading] is Map) {
      fullData['trading'] = Map<String, dynamic>.from(raw[_docTrading] as Map);
    }
  }

  if (raw[_docLauncher] != null) {
    if (raw[_docLauncher] is String) {
      try {
        fullData['launcher'] = jsonDecode(raw[_docLauncher] as String);
      } catch (_) {
        fullData['launcher'] = raw[_docLauncher];
      }
    } else if (raw[_docLauncher] is Map) {
      fullData['launcher'] = Map<String, dynamic>.from(raw[_docLauncher] as Map);
    }
  }

  // Catch-all for any additional raw nodes under data/
  raw.forEach((key, val) {
    final k = key.toString();
    if (k != _docSettings &&
        k != _docTasks &&
        k != _docFinance &&
        k != _docHealth &&
        k != _docTrading &&
        k != _docLauncher &&
        k != 'history' &&
        k != 'reflections') {
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is Map) {
            fullData[k] = Map<String, dynamic>.from(decoded);
          } else {
            fullData[k] = decoded;
          }
        } catch (_) {
          fullData[k] = val;
        }
      } else if (val is Map) {
        fullData[k] = val;
      } else {
        fullData[k] = val;
      }
    }
  });

  return fullData;
}

/// Weekly offsite backup in the Realtime Database (Firebase Storage is not used for this project).
/// The gzip bytes are base64-encoded and written as parts under `offsite_parts/{period}/{ver}`. The
/// pointer `offsite/{period}` is written last, so a half-finished backup never replaces a good one.
Future<void> _saveOffsiteBytes(
  String userId,
  String period,
  Uint8List bytes, {
  required Future<void> Function(String path, Object value) set,
  required Future<Object?> Function(String path) get,
}) async {
  final parts = _splitJsonParts(base64Encode(bytes)); // base64 is ASCII, so splitting is safe
  final ver = DateTime.now().millisecondsSinceEpoch;
  final base = 'users/$userId/offsite_parts/$period/$ver';
  for (var i = 0; i < parts.length; i++) {
    await _withRetry(() => set('$base/${_partKey(i)}', parts[i]));
    await Future.delayed(_partPause);
  }
  for (final i in {0, parts.length - 1}) {
    final back = await get('$base/${_partKey(i)}');
    if (back != parts[i]) throw StateError('Offsite backup part $i failed verification');
  }
  await _withRetry(() => set('users/$userId/offsite/$period', {
        'ver': ver,
        'n': parts.length,
        'bytes': bytes.length,
        'encoding': 'base64-gzip',
      }));
}

// ─────────────────────────────────────────────────────────────────────────
// FlutterFire-backed impl (Android, iOS, web, macOS, Windows).
// Identical behavior to the pre-refactor StorageService.
// ─────────────────────────────────────────────────────────────────────────
class _FlutterFireStorageService implements StorageService {
  @override
  Future<void> saveOffsiteSnapshot(String userId, Uint8List bytes, String period) => _saveOffsiteBytes(
        userId,
        period,
        bytes,
        set: (path, value) => _rtdb.ref(path).set(value).timeout(_rtdbTimeout),
        get: (path) async => (await _rtdb.ref(path).get().timeout(_rtdbTimeout)).value,
      );

  @override
  late final CloudSnapshotStore snapshots = CloudSnapshotStore(
    read: (path) async => (await _rtdb.ref(path).get().timeout(_rtdbTimeout)).value,
    write: (path, value) => _withRetry(() => _rtdb.ref(path).set(value).timeout(_rtdbTimeout)),
    listKeys: _cloudKeys,
    removeOldParts: (path, cutoff) async {
      await _rtdb.ref(path).runTransaction((current) {
        if (current is! Map || (current['_uploadedAt'] as num? ?? double.infinity) >= cutoff) return Transaction.abort();
        return Transaction.success(null);
      }, applyLocally: false);
    },
    commit: (path, expected, head) async { final result = await _rtdb.ref(path).runTransaction((current) {
        if ((current is Map ? current['version']?.toString() : null) != expected) return Transaction.abort();
        return Transaction.success(head);
      }, applyLocally: false);
      return result.committed; },
  );

  @override
  Future<Map<String, dynamic>> saveSnapshot(String userId, Map<String, dynamic> collections, {required int baseline, String? baselineVersion, required String deviceId, bool allowShrink = false}) => snapshots.save(userId, collections, baseline: baseline, baselineVersion: baselineVersion, deviceId: deviceId, allowShrink: allowShrink);

  @override
  Future<List<Map<String, dynamic>>> getCloudVersions(String userId) => snapshots.versions(userId);

  @override
  Future<Map<String, dynamic>> getCloudVersion(String userId, String version) async {
    final available = await getCloudVersions(userId);
    final snapshot = available.firstWhere((v) => v['version'] == version);
    return _parseRtdbData(await snapshots.resolveData(userId, snapshot['data'] as Map));
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  static const Duration _rtdbTimeout = Duration(seconds: 15);

  DatabaseReference _rtdbRef(String userId, String chunk) =>
      _rtdb.ref('users/$userId/data/$chunk');

  @override
  Future<Map<String, dynamic>?> getUserSnapshot(String userId) async {
    if (userId.isEmpty) throw ArgumentError('Missing user id');
    final snapshot = await snapshots.current(userId);
    if (snapshot == null) return null;
    return {...snapshot, 'state': _parseRtdbData(snapshot['data'] as Map)};
  }

  @override
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    if (userId.isEmpty) throw ArgumentError('Missing user id');
    final snapshot = await getUserSnapshot(userId);
    return snapshot?['state'] as Map<String, dynamic>?;
  }

  @override
  Future<int> getLastModified(String userId) async {
    if (userId.isEmpty) throw ArgumentError('Missing user id');
    final head = await snapshots.read('users/$userId/head');
    final legacy = (await snapshots.read('users/$userId/lastModified') as num?)?.toInt() ?? 0;
    final current = head is Map ? (head['lastModified'] as num?)?.toInt() ?? 0 : 0;
    return current > legacy ? current : legacy;
  }

  @override
  Future<void> setLastModified(String userId, int timestamp) async {
    if (userId.isEmpty) return;
    try {
      await _rtdb.ref('users/$userId/lastModified').set(timestamp).timeout(_rtdbTimeout);
    } catch (e, stack) {
      debugPrint('[StorageService.setLastModified] $e\n$stack');
    }
  }

  @override
  Stream<int> watchLastModified(String userId) {
    if (userId.isEmpty) return const Stream.empty();
    return _rtdb.ref('users/$userId/lastModified').onValue.map((event) {
      return (event.snapshot.value as num?)?.toInt() ?? 0;
    });
  }

  @override
  Future<bool> saveTasks(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docTasks, data);
  @override
  Future<bool> saveSettings(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docSettings, data);
  @override
  Future<bool> saveFinance(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docFinance, data);
  @override
  Future<bool> saveHealth(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docHealth, data);
  @override
  Future<bool> saveTrading(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docTrading, data);
  @override
  Future<bool> saveLauncher(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docLauncher, data);

  @override
  Future<Map<String, dynamic>?> getTrading(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final snap = await _rtdbRef(userId, _docTrading).get().timeout(_rtdbTimeout);
      if (snap.exists && snap.value != null) {
        final value = await _readChunk(userId, _docTrading, snap.value);
        if (value is String) {
          return jsonDecode(value) as Map<String, dynamic>?;
        } else if (value is Map) {
          return Map<String, dynamic>.from(value);
        }
      }
      return null;
    } catch (e, stack) {
      debugPrint('[StorageService.getTrading] $e\n$stack');
      return null;
    }
  }

  Future<bool> _saveChunkToRTDB(
      String userId, String chunk, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    final ver = DateTime.now().millisecondsSinceEpoch;
    final partsRef = _rtdb.ref('users/$userId/chunks/$chunk');
    try {
      final parts = _splitJsonParts(jsonEncode(data));

      for (var i = 0; i < parts.length; i++) {
        await _withRetry(() => partsRef.child('$ver/${_partKey(i)}').set(parts[i]).timeout(_rtdbTimeout));
        await Future.delayed(_partPause);
      }
      // Read the first and last parts back: the pointer only flips once the cloud really holds them.
      for (final i in {0, parts.length - 1}) {
        final back = (await _rtdb.ref('users/$userId/chunks/$chunk/$ver/${_partKey(i)}').get().timeout(_rtdbTimeout)).value;
        if (back != parts[i]) throw StateError('Cloud verification failed for $chunk part $i');
      }
      // Only now flip the pointer, so a half-finished upload never replaces good data.
      await _withRetry(() => _rtdbRef(userId, chunk)
          .set({'_chunked': true, 'ver': ver, 'n': parts.length}).timeout(_rtdbTimeout));

      return true;
    } catch (e, stack) {
      debugPrint('[StorageService._saveChunkToRTDB:$chunk] $e\n$stack');

      return false;
    }
  }

  Future<dynamic> _readChunk(String userId, String chunk, dynamic value) =>
      _resolveChunked(value, (ver, i) async {
        dynamic v;
        await _withRetry(() async {
          v = (await _rtdb.ref('users/$userId/chunks/$chunk/$ver/${_partKey(i)}').get().timeout(_rtdbTimeout)).value;
        });
        return v;
      });

  @override
  Future<bool> saveCrashLogs(String userId, List<String> logs) async {
    if (userId.isEmpty || logs.isEmpty) return true;
    try {
      await _rtdbRef(userId, 'crash_logs').set(jsonEncode(logs)).timeout(_rtdbTimeout);
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveCrashLogs] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> saveHistory(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final history = data['completedByDay'] as Map<String, dynamic>? ?? {};
      final Map<String, dynamic> updates = {};
      for (final entry in history.entries) {
        final cleanKey = entry.key.toString().replaceAll(RegExp(r'[.#$\[\]/]'), '_');
        updates[cleanKey] = jsonEncode(entry.value);
      }
      if (updates.isNotEmpty) {
        // Batch in groups of 20 to avoid Android Binder IPC buffer limits (>1MB) and prevent RTDB OOM
        final entries = updates.entries.toList();
        const batchSize = 5;
        for (int i = 0; i < entries.length; i += batchSize) {
          final end = (i + batchSize < entries.length) ? i + batchSize : entries.length;
          final batch = Map<String, dynamic>.fromEntries(entries.sublist(i, end));
          await _withRetry(() => _rtdb.ref('users/$userId/data/history').update(batch).timeout(_rtdbTimeout));
          await Future.delayed(_partPause);
        }
      }
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveHistory] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> saveReflections(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final logs = data['reflectionLogs'] as List<dynamic>? ?? [];
      final Map<String, dynamic> updates = {};
      for (var log in logs) {
        if (log is Map && log['id'] != null) {
          final cleanId = log['id'].toString().replaceAll(RegExp(r'[.#$\[\]/]'), '_');
          updates[cleanId] = jsonEncode(log);
        }
      }
      if (updates.isNotEmpty) {
        // Batch in groups of 30 to avoid Android Binder IPC buffer limits (>1MB) and prevent RTDB OOM
        final entries = updates.entries.toList();
        const batchSize = 8;
        for (int i = 0; i < entries.length; i += batchSize) {
          final end = (i + batchSize < entries.length) ? i + batchSize : entries.length;
          final batch = Map<String, dynamic>.fromEntries(entries.sublist(i, end));
          await _withRetry(() => _rtdb.ref('users/$userId/data/reflections').update(batch).timeout(_rtdbTimeout));
          await Future.delayed(_partPause);
        }
      }
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveReflections] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> deleteReflection(String userId, String reflectionId) async {
    if (userId.isEmpty || reflectionId.isEmpty) return false;
    try {
      final cleanId = reflectionId.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      await _rtdb.ref('users/$userId/data/reflections/$cleanId').remove().timeout(_rtdbTimeout);
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.deleteReflection] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> deleteUserData(String userId) async {
    if (userId.isEmpty) return false;
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final root = 'users/$userId';
      final reports = <String, dynamic>{};
      final removals = <Future<void> Function()>[];
      for (final kind in ['daily', 'weekly', 'monthly', 'data']) {
        final collection = _firestore.collection(_userCollection).doc(userId).collection(kind);
        final docs = await collection.get();
        reports[kind] = {for (final doc in docs.docs) doc.id: doc.data()};
        for (final doc in docs.docs) { removals.add(() => doc.reference.delete()); }
      }
      final archive = {
        'data': await snapshots.read('$root/data'),
        'head': await snapshots.read('$root/head'),
        'firestore': jsonEncode(reports, toEncodable: (value) {
          if (value is Timestamp) return {'_firestoreTimestamp': {'seconds': value.seconds, 'nanoseconds': value.nanoseconds}};
          if (value is DateTime) return {'_dateTime': value.toUtc().toIso8601String()};
          if (value is GeoPoint) return {'_geoPoint': {'latitude': value.latitude, 'longitude': value.longitude}};
          if (value is DocumentReference) return {'_documentReference': value.path};
          throw StateError('Unsupported Firestore recovery value: ${value.runtimeType}');
        }),
        'expiresAt': stamp + const Duration(days: 30).inMilliseconds,
      };
      await snapshots.write('$root/trash/$stamp', archive);
      final verified = await snapshots.read('$root/trash/$stamp');
      // Verify every recovery field before deleting either database's live data.
      if (!cloudRecoveryMatches(archive, verified)) throw StateError('Purge backup verification failed');
      for (final remove in removals) { await remove(); }
      await _rtdb.ref('users/$userId').update({'head': null, 'data': null, 'manifest': null, 'lastModified': null, 'purgedAt': stamp}).timeout(_rtdbTimeout);
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.softDeleteUserData] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> saveDailyData(String userId, String date, String type,
      Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      await _firestore
          .collection(_userCollection)
          .doc(userId)
          .collection('daily')
          .doc(date)
          .set({
        type: data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveDailyData] $e\n$stack');
      return false;
    }
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchRecentDailyData(
      String userId, int days) async {
    if (userId.isEmpty) return {};
    try {
      final Map<String, Map<String, dynamic>> result = {};
      final snap = await _firestore
          .collection(_userCollection)
          .doc(userId)
          .collection('daily')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(days)
          .get();

      final docs = snap.docs.toList()
        ..sort((a, b) => b.id.compareTo(a.id));

      for (var doc in docs.take(days)) {
        result[doc.id] = doc.data();
      }
      return result;
    } catch (e, stack) {
      debugPrint('[StorageService.fetchRecentDailyData] $e\n$stack');
      return {};
    }
  }

  @override
  Future<bool> saveWeeklyReport(
      String userId, String date, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      await _firestore
          .collection(_userCollection)
          .doc(userId)
          .collection('weekly')
          .doc(date)
          .set({
        'report': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveWeeklyReport] $e\n$stack');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchWeeklyReports(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snap = await _firestore
          .collection(_userCollection)
          .doc(userId)
          .collection('weekly')
          .orderBy('updatedAt', descending: true)
          .limit(60)
          .get();

      return snap.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e, stack) {
      debugPrint('[StorageService.fetchWeeklyReports] $e\n$stack');
      return [];
    }
  }

  @override
  Future<bool> saveMonthlyReport(
      String userId, String date, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      await _firestore
          .collection(_userCollection)
          .doc(userId)
          .collection('monthly')
          .doc(date)
          .set({
        'report': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveMonthlyReport] $e\n$stack');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMonthlyReports(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snap = await _firestore
          .collection(_userCollection)
          .doc(userId)
          .collection('monthly')
          .orderBy('updatedAt', descending: true)
          .limit(60)
          .get();

      return snap.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e, stack) {
      debugPrint('[StorageService.fetchMonthlyReports] $e\n$stack');
      return [];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Linux impl: firebase_dart for RTDB, firedart for Firestore.
// `firedart`'s Firestore lacks `FieldPath.documentId` ordering and batch
// writes, so a few queries fetch-then-sort in Dart or run as sequential
// deletes. Server-timestamp writes use a client-side timestamp instead.
// ─────────────────────────────────────────────────────────────────────────
class _LinuxStorageService implements StorageService {
  @override
  Future<void> saveOffsiteSnapshot(String userId, Uint8List bytes, String period) => _saveOffsiteBytes(
        userId,
        period,
        bytes,
        set: (path, value) => _rtdb.reference().child(path).set(value).timeout(_rtdbTimeout),
        get: (path) async => (await _rtdb.reference().child(path).once().timeout(_rtdbTimeout)).value,
      );

  @override
  late final CloudSnapshotStore snapshots = CloudSnapshotStore(
    read: (path) async => (await _rtdb.reference().child(path).once().timeout(_rtdbTimeout)).value,
    write: (path, value) => _withRetry(() => _rtdb.reference().child(path).set(value).timeout(_rtdbTimeout)),
    listKeys: _cloudKeys,
    removeOldParts: (path, cutoff) async {
      await _rtdb.reference().child(path).runTransaction((mutable) {
        final current = mutable.value;
        if (current is! Map || (current['_uploadedAt'] as num? ?? double.infinity) >= cutoff) return null;
        mutable.value = null;
        return mutable;
      }, timeout: const Duration(seconds: 30));
    },
    commit: (path, expected, head) async { final result = await _rtdb.reference().child(path).runTransaction((mutable) {
        final current = mutable.value;
        if ((current is Map ? current['version']?.toString() : null) != expected) return null;
        mutable.value = head;
        return mutable;
      }, timeout: const Duration(seconds: 30));
      if (result.error != null) throw result.error!;
      return result.committed; },
  );

  @override
  Future<Map<String, dynamic>> saveSnapshot(String userId, Map<String, dynamic> collections, {required int baseline, String? baselineVersion, required String deviceId, bool allowShrink = false}) => snapshots.save(userId, collections, baseline: baseline, baselineVersion: baselineVersion, deviceId: deviceId, allowShrink: allowShrink);

  @override
  Future<List<Map<String, dynamic>>> getCloudVersions(String userId) => snapshots.versions(userId);

  @override
  Future<Map<String, dynamic>> getCloudVersion(String userId, String version) async {
    final available = await getCloudVersions(userId);
    final snapshot = available.firstWhere((v) => v['version'] == version);
    return _parseRtdbData(await snapshots.resolveData(userId, snapshot['data'] as Map));
  }

  fd.FirebaseDatabase get _rtdb => fd.FirebaseDatabase(app: fd.Firebase.app());
  firedart.Firestore get _firestore => firedart.Firestore.instance;

  static const Duration _rtdbTimeout = Duration(seconds: 15);

  fd.DatabaseReference _rtdbRef(String userId, String chunk) =>
      _rtdb.reference().child('users/$userId/data/$chunk');

  @override
  Future<Map<String, dynamic>?> getUserSnapshot(String userId) async {
    if (userId.isEmpty) throw ArgumentError('Missing user id');
    final snapshot = await snapshots.current(userId);
    if (snapshot == null) return null;
    return {...snapshot, 'state': _parseRtdbData(snapshot['data'] as Map)};
  }

  @override
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    if (userId.isEmpty) throw ArgumentError('Missing user id');
    final snapshot = await getUserSnapshot(userId);
    return snapshot?['state'] as Map<String, dynamic>?;
  }

  @override
  Future<int> getLastModified(String userId) async {
    if (userId.isEmpty) throw ArgumentError('Missing user id');
    final head = await snapshots.read('users/$userId/head');
    final legacy = (await snapshots.read('users/$userId/lastModified') as num?)?.toInt() ?? 0;
    final current = head is Map ? (head['lastModified'] as num?)?.toInt() ?? 0 : 0;
    return current > legacy ? current : legacy;
  }

  @override
  Future<void> setLastModified(String userId, int timestamp) async {
    if (userId.isEmpty) return;
    try {
      await _rtdb.reference().child('users/$userId/lastModified').set(timestamp).timeout(_rtdbTimeout);
    } catch (e, stack) {
      debugPrint('[StorageService.setLastModified/linux] $e\n$stack');
    }
  }

  @override
  Stream<int> watchLastModified(String userId) {
    if (userId.isEmpty) return const Stream.empty();
    return _rtdb
        .reference()
        .child('users/$userId/lastModified')
        .onValue
        .map((event) => (event.snapshot.value as num?)?.toInt() ?? 0);
  }

  @override
  Future<bool> saveTasks(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docTasks, data);
  @override
  Future<bool> saveSettings(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docSettings, data);
  @override
  Future<bool> saveFinance(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docFinance, data);
  @override
  Future<bool> saveHealth(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docHealth, data);
  @override
  Future<bool> saveTrading(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docTrading, data);
  @override
  Future<bool> saveLauncher(String userId, Map<String, dynamic> data) =>
      _saveChunkToRTDB(userId, _docLauncher, data);

  @override
  Future<Map<String, dynamic>?> getTrading(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final snap = await _rtdbRef(userId, _docTrading).once().timeout(_rtdbTimeout);
      if (snap.value != null) {
        final value = await _readChunk(userId, _docTrading, snap.value);
        if (value is String) {
          return jsonDecode(value) as Map<String, dynamic>?;
        } else if (value is Map) {
          return Map<String, dynamic>.from(value);
        }
      }
      return null;
    } catch (e, stack) {
      debugPrint('[StorageService.getTrading/linux] $e\n$stack');
      return null;
    }
  }

  Future<bool> _saveChunkToRTDB(
      String userId, String chunk, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    final ver = DateTime.now().millisecondsSinceEpoch;
    final partsRef = _rtdb.reference().child('users/$userId/chunks/$chunk');
    try {
      final parts = _splitJsonParts(jsonEncode(data));

      for (var i = 0; i < parts.length; i++) {
        await _withRetry(() => partsRef.child('$ver/${_partKey(i)}').set(parts[i]).timeout(_rtdbTimeout));
        await Future.delayed(_partPause);
      }
      // Read the first and last parts back: the pointer only flips once the cloud really holds them.
      for (final i in {0, parts.length - 1}) {
        final back = (await partsRef.child('$ver/${_partKey(i)}').once().timeout(_rtdbTimeout)).value;
        if (back != parts[i]) throw StateError('Cloud verification failed for $chunk part $i');
      }
      // Only now flip the pointer, so a half-finished upload never replaces good data.
      await _withRetry(() => _rtdbRef(userId, chunk)
          .set({'_chunked': true, 'ver': ver, 'n': parts.length}).timeout(_rtdbTimeout));

      return true;
    } catch (e, stack) {
      debugPrint('[StorageService._saveChunkToRTDB:$chunk/linux] $e\n$stack');

      return false;
    }
  }

  Future<dynamic> _readChunk(String userId, String chunk, dynamic value) =>
      _resolveChunked(value, (ver, i) async {
        dynamic v;
        await _withRetry(() async {
          v = (await _rtdb.reference().child('users/$userId/chunks/$chunk/$ver/${_partKey(i)}').once().timeout(_rtdbTimeout)).value;
        });
        return v;
      });

  @override
  Future<bool> saveCrashLogs(String userId, List<String> logs) async {
    if (userId.isEmpty || logs.isEmpty) return true;
    try {
      await _rtdb
          .reference()
          .child('users/$userId/data/crash_logs')
          .set(jsonEncode(logs))
          .timeout(_rtdbTimeout);
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveCrashLogs/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> saveHistory(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final history = data['completedByDay'] as Map<String, dynamic>? ?? {};
      final Map<String, dynamic> updates = {};
      for (final entry in history.entries) {
        final cleanKey = entry.key.toString().replaceAll(RegExp(r'[.#$\[\]/]'), '_');
        updates[cleanKey] = jsonEncode(entry.value);
      }
      if (updates.isNotEmpty) {
        final entries = updates.entries.toList();
        const batchSize = 5;
        for (int i = 0; i < entries.length; i += batchSize) {
          final end = (i + batchSize < entries.length) ? i + batchSize : entries.length;
          final batch = Map<String, dynamic>.fromEntries(entries.sublist(i, end));
          await _rtdb
              .reference()
              .child('users/$userId/data/history')
              .update(batch)
              .timeout(_rtdbTimeout);
        }
      }
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveHistory/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> saveReflections(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final logs = data['reflectionLogs'] as List<dynamic>? ?? [];
      final Map<String, dynamic> updates = {};
      for (var log in logs) {
        if (log is Map && log['id'] != null) {
          final cleanId = log['id'].toString().replaceAll(RegExp(r'[.#$\[\]/]'), '_');
          updates[cleanId] = jsonEncode(log);
        }
      }
      if (updates.isNotEmpty) {
        final entries = updates.entries.toList();
        const batchSize = 8;
        for (int i = 0; i < entries.length; i += batchSize) {
          final end = (i + batchSize < entries.length) ? i + batchSize : entries.length;
          final batch = Map<String, dynamic>.fromEntries(entries.sublist(i, end));
          await _rtdb
              .reference()
              .child('users/$userId/data/reflections')
              .update(batch)
              .timeout(_rtdbTimeout);
        }
      }
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveReflections/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> deleteReflection(String userId, String reflectionId) async {
    if (userId.isEmpty || reflectionId.isEmpty) return false;
    try {
      final cleanId = reflectionId.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      await _rtdb
          .reference()
          .child('users/$userId/data/reflections/$cleanId')
          .remove()
          .timeout(_rtdbTimeout);
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.deleteReflection/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> deleteUserData(String userId) async {
    if (userId.isEmpty) return false;
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final root = 'users/$userId';
      final reports = <String, dynamic>{};
      final removals = <Future<void> Function()>[];
      for (final kind in ['daily', 'weekly', 'monthly', 'data']) {
        final collection = _firestore.collection('$_userCollection/$userId/$kind');
        final docs = await collection.get();
        final entries = docs.toList();
        reports[kind] = {for (final doc in entries) doc.id: doc.map};
        for (final doc in entries) { removals.add(() => collection.document(doc.id).delete()); }
      }
      final archive = {
        'data': await snapshots.read('$root/data'),
        'head': await snapshots.read('$root/head'),
        'firestore': jsonEncode(reports, toEncodable: (value) {
          if (value is Timestamp) return {'_firestoreTimestamp': {'seconds': value.seconds, 'nanoseconds': value.nanoseconds}};
          if (value is DateTime) return {'_dateTime': value.toUtc().toIso8601String()};
          if (value is GeoPoint) return {'_geoPoint': {'latitude': value.latitude, 'longitude': value.longitude}};
          if (value is DocumentReference) return {'_documentReference': value.path};
          throw StateError('Unsupported Firestore recovery value: ${value.runtimeType}');
        }),
        'expiresAt': stamp + const Duration(days: 30).inMilliseconds,
      };
      await snapshots.write('$root/trash/$stamp', archive);
      final verified = await snapshots.read('$root/trash/$stamp');
      // Verify every recovery field before deleting either database's live data.
      if (!cloudRecoveryMatches(archive, verified)) throw StateError('Purge backup verification failed');
      for (final remove in removals) { await remove(); }
      await _rtdb.reference().child('users/$userId').update({'head': null, 'data': null, 'manifest': null, 'lastModified': null, 'purgedAt': stamp}).timeout(_rtdbTimeout);
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.softDeleteUserData] $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> saveDailyData(String userId, String date, String type,
      Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final docRef = _firestore
          .collection('$_userCollection/$userId/daily')
          .document(date);

      await docRef.update({type: data, 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveDailyData/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchRecentDailyData(
      String userId, int days) async {
    if (userId.isEmpty) return {};
    try {
      // Firestore's __name__ field orders document ids before applying the limit.
      final docs = await _firestore
          .collection('$_userCollection/$userId/daily')
          .orderBy('__name__', descending: true)
          .limit(days)
          .get();

      final entries = docs.toList()
        ..sort((a, b) => b.id.compareTo(a.id)); // descending date

      final Map<String, Map<String, dynamic>> result = {};
      for (final doc in entries.take(days)) {
        result[doc.id] = Map<String, dynamic>.from(doc.map);
      }
      return result;
    } catch (e, stack) {
      debugPrint('[StorageService.fetchRecentDailyData/linux] $e\n$stack');
      return {};
    }
  }

  @override
  Future<bool> saveWeeklyReport(
      String userId, String date, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final docRef = _firestore
          .collection('$_userCollection/$userId/weekly')
          .document(date);

      await docRef.update({'report': data, 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveWeeklyReport/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchWeeklyReports(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final docs = await _firestore
          .collection('$_userCollection/$userId/weekly')
          .orderBy('__name__', descending: true)
          .limit(60)
          .get();

      final entries = docs.toList()
        ..sort((a, b) {
          final aTs = (a.map['updatedAt'] ?? '').toString();
          final bTs = (b.map['updatedAt'] ?? '').toString();
          return bTs.compareTo(aTs);
        });

      return entries
          .map((doc) => {
                'id': doc.id,
                ...Map<String, dynamic>.from(doc.map),
              })
          .toList();
    } catch (e, stack) {
      debugPrint('[StorageService.fetchWeeklyReports/linux] $e\n$stack');
      return [];
    }
  }

  @override
  Future<bool> saveMonthlyReport(
      String userId, String date, Map<String, dynamic> data) async {
    if (userId.isEmpty) return false;
    try {
      final docRef = _firestore
          .collection('$_userCollection/$userId/monthly')
          .document(date);

      await docRef.update({'report': data, 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      return true;
    } catch (e, stack) {
      debugPrint('[StorageService.saveMonthlyReport/linux] $e\n$stack');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMonthlyReports(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final docs = await _firestore
          .collection('$_userCollection/$userId/monthly')
          .orderBy('__name__', descending: true)
          .limit(60)
          .get();

      final entries = docs.toList()
        ..sort((a, b) {
          final aTs = (a.map['updatedAt'] ?? '').toString();
          final bTs = (b.map['updatedAt'] ?? '').toString();
          return bTs.compareTo(aTs);
        });

      return entries
          .map((doc) => {
                'id': doc.id,
                ...Map<String, dynamic>.from(doc.map),
              })
          .toList();
    } catch (e, stack) {
      debugPrint('[StorageService.fetchMonthlyReports/linux] $e\n$stack');
      return [];
    }
  }
}
