import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

/// RTDB omits empty containers and null children, and may return indexed maps
/// as lists. Compare the entire archive after normalizing that wire format.
bool cloudRecoveryMatches(dynamic expected, dynamic restored) {
  dynamic normalize(dynamic value) {
    if (value is List)
      return normalize(<String, dynamic>{
        for (var i = 0; i < value.length; i++) '$i': value[i]
      });
    if (value is! Map) return value;
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final child = normalize(entry.value);
      if (child != null) result[entry.key.toString()] = child;
    }
    return result.isEmpty ? null : result;
  }

  return const DeepCollectionEquality()
      .equals(normalize(expected), normalize(restored));
}

class CloudConflictException implements Exception {
  const CloudConflictException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Upload immutable, checksum-verified parts first. A transaction on the small
/// head record commits every collection pointer and its timestamp together.
/// An interrupted upload never changes what readers see.
class CloudSnapshotStore {
  CloudSnapshotStore(
      {required this.read,
      required this.write,
      required this.commit,
      this.listKeys,
      this.removeOldParts});
  final Future<dynamic> Function(String path) read;
  final Future<void> Function(String path, dynamic value) write;
  final Future<bool> Function(
      String path, String? expectedVersion, Map<String, dynamic> head) commit;
  final Future<List<String>> Function(String path)? listKeys;
  final Future<void> Function(String path, int cutoff)? removeOldParts;
  static const retainedVersions = 22;

  /// Capture a head once, then resolve its immutable pointers. A restore must
  /// attach to this exact version, rather than a timestamp fetched afterward.
  Future<Map<String, dynamic>?> current(String userId) async {
    final root = 'users/$userId';
    final head = await read('$root/head');
    if (head != null && head is! Map)
      throw StateError('Invalid cloud snapshot head');
    final legacyTimestamp =
        (await read('$root/lastModified') as num?)?.toInt() ?? 0;
    final headTimestamp =
        head is Map ? (head['lastModified'] as num?)?.toInt() ?? 0 : 0;
    final useLegacy = head == null || legacyTimestamp > headTimestamp;
    final raw = useLegacy ? await read('$root/data') : head['data'];
    if (raw == null && head == null) return null;
    if (raw is! Map) throw StateError('Invalid cloud snapshot data');
    final data = await resolveData(userId, raw);
    if (useLegacy &&
        ((await read('$root/lastModified') as num?)?.toInt() ?? 0) !=
            legacyTimestamp) {
      throw const CloudConflictException(
          'Cloud changed during restore. Retry to read a consistent snapshot.');
    }
    return {
      'version': head is Map ? head['version'] : null,
      'lastModified': useLegacy ? legacyTimestamp : headTimestamp,
      'data': data
    };
  }

  Future<List<String>> _keys(String path) async {
    if (listKeys != null) return listKeys!(path);
    final value = await read(path);
    return value is Map ? value.keys.map((k) => k.toString()).toList() : [];
  }

  Future<void> prune(String userId) async {
    final root = 'users/$userId';
    final head = await read('$root/head');
    if (head is! Map) return;
    final keepVersions = <String>{
      ...List<String>.from(head['versions'] as List? ?? [])
    };
    final referenced = <String, Set<String>>{};
    void collect(Map data) {
      void visit(String name, dynamic node) {
        if (node is! Map) return;
        if (node['_chunked'] == true) {
          referenced
              .putIfAbsent(name, () => <String>{})
              .add(node['ver'].toString());
        } else {
          for (final value in node.values) {
            visit(name, value);
          }
        }
      }

      for (final e in data.entries) {
        visit(e.key.toString(), e.value);
      }
    }

    collect(head['data'] as Map? ?? {});
    for (final id in keepVersions.toList()) {
      final version = await read('$root/versions/$id');
      if (version is Map) collect(version['data'] as Map? ?? {});
    }
    // Trash manifests keep their referenced chunks alive throughout the recovery window.
    for (final id in await _keys('$root/trash')) {
      final archive = await read('$root/trash/$id');
      if (archive is! Map) continue;
      final expires = (archive['expiresAt'] as num?)?.toInt();
      if (expires != null && expires < (head['lastModified'] as num).toInt()) {
        await write('$root/trash/$id', null);
        continue;
      }
      collect(archive['data'] as Map? ?? {});
      final oldHead = archive['head'];
      if (oldHead is Map) {
        collect(oldHead['data'] as Map? ?? {});
        for (final versionId in oldHead['versions'] as List? ?? []) {
          keepVersions.add(versionId.toString());
          final version = await read('$root/versions/$versionId');
          if (version is Map) collect(version['data'] as Map? ?? {});
        }
      }
    }
    final cutoff = (head['lastModified'] as num).toInt() -
        const Duration(days: 1).inMilliseconds;
    if ((await read('$root/head') as Map?)?['version'] != head['version'])
      return;
    for (final name in await _keys('$root/chunks')) {
      for (final version in await _keys('$root/chunks/$name')) {
        if (referenced[name]?.contains(version) == true) continue;
        // Backend transaction rechecks the stage timestamp. Uploads refresh it
        // before writing any part, so GC cannot race a prepared snapshot.
        if (removeOldParts != null)
          await removeOldParts!('$root/chunks/$name/$version', cutoff);
      }
    }
    for (final id in await _keys('$root/versions')) {
      if (keepVersions.contains(id)) continue;
      final version = await read('$root/versions/$id');
      if (version is Map &&
          (version['lastModified'] as num? ?? cutoff) < cutoff)
        await write('$root/versions/$id', null);
    }
  }

  static Map<String, int> counts(Map<String, dynamic> state) {
    final tasks = state['tasks'] as Map? ?? state;
    final history = state['history'] as Map? ?? state;
    final finance = state['finance'] as Map? ?? state;
    final reflections = state['reflections'] as Map? ?? state;
    final list = tasks['mainTasks'] as List? ?? [];
    return {
      'tasks': list.where((t) => t is Map && t['isDeleted'] != true).length,
      'subtasks': list.whereType<Map>().fold(
          0,
          (n, t) =>
              n +
              (t['subTasks'] as List? ?? [])
                  .where((s) => s is Map && s['isDeleted'] != true)
                  .length),
      'transactions': (finance['transactions'] as List? ?? []).length,
      'reflections': (reflections['reflectionLogs'] as List? ?? []).length,
      'historyDays': (history['completedByDay'] as Map? ?? {}).length,
    };
  }

  static bool shrinks(Map previous, Map incoming) => previous.entries.any((e) {
        final old = (e.value as num?)?.toInt() ?? 0;
        final next = (incoming[e.key] as num?)?.toInt() ?? 0;
        return old > 0 && (next == 0 || next < old * .7);
      });

  Future<dynamic> resolve(
      String userId, String collection, dynamic value) async {
    if (value is! Map || value['_chunked'] != true) return value;
    final buffer = StringBuffer();
    for (var i = 0; i < (value['n'] as num).toInt(); i++) {
      final part = await read(
          'users/$userId/chunks/$collection/${value['ver']}/p${i.toString().padLeft(5, '0')}');
      if (part is! String)
        throw StateError('Missing cloud part $collection/$i');
      buffer.write(part);
    }
    final json = buffer.toString();
    final bytes = utf8.encode(json);
    if (value['sha256'] != null &&
        (sha256.convert(bytes).toString() != value['sha256'] ||
            bytes.length != value['bytes'])) {
      throw StateError('Cloud checksum mismatch: $collection');
    }
    return json;
  }

  Future<Map<String, dynamic>> resolveData(String userId, Map raw) async {
    final resolved = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is Map && value['_entities'] == true) {
        final entries = <String, dynamic>{};
        for (final item in (value['items'] as Map? ?? {}).values) {
          final node = item as Map;
          entries[node['key'] as String] =
              await resolve(userId, key, node['value']);
        }
        resolved[key] = entries;
      } else {
        resolved[key] = await resolve(userId, key, value);
      }
    }
    return resolved;
  }

  Future<Map<String, dynamic>> _upload(
      String userId, String name, dynamic value, dynamic previous) async {
    final json = jsonEncode(value);
    final bytes = utf8.encode(json);
    final hash = sha256.convert(bytes).toString();
    if (previous is Map && previous['sha256'] == hash)
      return Map<String, dynamic>.from(previous);
    // Content-addressed storage makes retries idempotent and avoids trusting the device clock.
    final parts = <String>[];
    for (var start = 0; start < json.length;) {
      var end = (start + 24 * 1024).clamp(0, json.length);
      if (end < json.length &&
          json.codeUnitAt(end - 1) >= 0xd800 &&
          json.codeUnitAt(end - 1) <= 0xdbff) end--;
      parts.add(json.substring(start, end));
      start = end;
    }
    await write(
        'users/$userId/chunks/$name/$hash/_uploadedAt', {'.sv': 'timestamp'});
    for (var i = 0; i < parts.length; i++) {
      final path =
          'users/$userId/chunks/$name/$hash/p${i.toString().padLeft(5, '0')}';
      await write(path, parts[i]);
      if (await read(path) != parts[i])
        throw StateError('Cloud verification failed: $name/$i');
    }
    return {
      '_chunked': true,
      'ver': hash,
      'n': parts.length,
      'sha256': hash,
      'bytes': bytes.length
    };
  }

  Future<Map<String, dynamic>> save(
    String userId,
    Map<String, dynamic> collections, {
    required int baseline,
    String? baselineVersion,
    required String deviceId,
    bool allowShrink = false,
  }) async {
    final root = 'users/$userId';
    final rawHead = await read('$root/head');
    final head = rawHead is Map
        ? Map<String, dynamic>.from(rawHead)
        : <String, dynamic>{};
    final legacyTs = (await read('$root/lastModified') as num?)?.toInt() ?? 0;
    final remoteTs = (head['lastModified'] as num?)?.toInt() ?? legacyTs;
    if (baselineVersion != null && head['version'] != baselineVersion) {
      throw const CloudConflictException(
          'Another device committed a different cloud version. Restore or merge it before uploading.');
    }
    if (remoteTs > baseline || legacyTs > baseline) {
      throw const CloudConflictException(
          'Another device has newer cloud data. Restore or merge it before uploading.');
    }
    final manifest = counts(collections);
    var previousManifest = head['manifest'] ?? await read('$root/manifest');
    if (previousManifest == null) {
      final legacy = await read('$root/data');
      if (legacy is Map && legacy.isNotEmpty) {
        final restored = await resolveData(userId, legacy);
        final state = <String, dynamic>{};
        for (final name in ['tasks', 'finance']) {
          final value = restored[name];
          if (value is String)
            state.addAll(Map<String, dynamic>.from(jsonDecode(value)));
          if (value is Map) state.addAll(Map<String, dynamic>.from(value));
        }
        final h = restored['history'];
        final r = restored['reflections'];
        state['completedByDay'] =
            h is String ? (jsonDecode(h) as Map)['completedByDay'] : h;
        state['reflectionLogs'] = r is String
            ? (jsonDecode(r) as Map)['reflectionLogs']
            : r is Map
                ? r.values.toList()
                : [];
        previousManifest = counts(state);
      }
    }
    if (!allowShrink &&
        previousManifest is Map &&
        shrinks(previousManifest, manifest)) {
      throw const CloudConflictException(
          'The upload would remove more than 30% of saved data. Review the deletion and confirm it in Cloud Sync.');
    }
    final oldData =
        head['data'] as Map? ?? await read('$root/data') as Map? ?? {};
    final data = <String, dynamic>{};
    for (final e in collections.entries) {
      if ((e.key == 'history' || e.key == 'reflections') && e.value is Map) {
        final payload = e.value as Map;
        final entries = e.key == 'history'
            ? Map<String, dynamic>.from(payload['completedByDay'] as Map? ?? {})
            : {
                for (final log in payload['reflectionLogs'] as List? ?? [])
                  (log as Map)['id'].toString(): log
              };
        final old = oldData[e.key];
        final oldItems = old is Map && old['_entities'] == true
            ? old['items'] as Map? ?? {}
            : {};
        final items = <String, dynamic>{};
        for (final item in entries.entries) {
          final key =
              base64Url.encode(utf8.encode(item.key)).replaceAll('=', '');
          items[key] = {
            'key': item.key,
            'value': await _upload(
                userId, e.key, item.value, (oldItems[key] as Map?)?['value'])
          };
        }
        data[e.key] = {'_entities': true, 'items': items};
      } else if (e.key == 'launcher' &&
          (e.value as Map).isEmpty &&
          oldData[e.key] != null) {
        // An uninitialized launcher has no state to publish.
        data[e.key] = oldData[e.key];
      } else {
        data[e.key] = await _upload(userId, e.key, e.value, oldData[e.key]);
      }
    }
    final version = const Uuid().v4();
    final previousVersion = head['version']?.toString();
    final versions = List<String>.from(head['versions'] as List? ?? []);
    if (head.isEmpty && oldData.isNotEmpty) {
      final legacyVersion = 'legacy-${const Uuid().v4()}';
      await write('$root/versions/$legacyVersion', {
        'version': legacyVersion,
        'data': oldData,
        'lastModified': legacyTs,
        'manifest': previousManifest ?? {}
      });
      versions.insert(0, legacyVersion);
    }
    final next = <String, dynamic>{
      'version': version,
      'data': data,
      'manifest': manifest,
      'lastModified': {'.sv': 'timestamp'},
      'lastPushedBy': deviceId,
      'versions': [version, ...versions].take(retainedVersions).toList(),
    };
    await write('$root/versions/$version', next);
    if (!await commit('$root/head', previousVersion, next)) {
      throw const CloudConflictException(
          'Cloud data changed during the upload. Merge the newer backup before retrying.');
    }
    final saved = Map<String, dynamic>.from(await read('$root/head') as Map);
    // Preserve a timestamped immutable manifest for the restore list.
    if (saved['version'] != version)
      throw const CloudConflictException(
          'Another device committed a newer snapshot. Merge it before uploading again.');
    // The already-uploaded manifest remains readable if this metadata refresh fails.
    try {
      await write('$root/versions/$version', saved);
    } catch (_) {}
    // The head is authoritative. Legacy mirrors are kept for older clients.
    // They are never used to declare a new snapshot committed.
    return saved;
  }

  Future<List<Map<String, dynamic>>> versions(String userId) async {
    final head = await read('users/$userId/head');
    if (head is! Map) return [];
    final result = <Map<String, dynamic>>[];
    for (final id in head['versions'] as List? ?? []) {
      final version = await read('users/$userId/versions/$id');
      if (version is Map) result.add(Map<String, dynamic>.from(version));
    }
    return result;
  }
}
