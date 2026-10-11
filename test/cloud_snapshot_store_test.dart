import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/services/cloud_snapshot_store.dart';

class FakeCloud {
  final Map<String, dynamic> root = {};
  final List<String> writes = [];
  String? failWritesContaining;
  bool conflictOnCommit = false;
  int timestamp = 1000;
  dynamic readNow(String path) {
    dynamic value = root;
    for (final key in path.split('/')) {
      if (value is! Map) return null;
      value = value[key];
    }
    return value == null ? null : jsonDecode(jsonEncode(value));
  }

  dynamic serverValues(dynamic value) {
    if (value is Map && value['.sv'] == 'timestamp') return ++timestamp;
    if (value is Map) return value.map((k, v) => MapEntry(k, serverValues(v)));
    if (value is List) return value.map(serverValues).toList();
    return value;
  }

  Future<void> write(String path, dynamic value) async {
    if (failWritesContaining != null && path.contains(failWritesContaining!))
      throw StateError('Simulated failed upload');
    writes.add(path);
    dynamic node = root;
    final keys = path.split('/');
    for (final key in keys.take(keys.length - 1)) {
      node = node.putIfAbsent(key, () => <String, dynamic>{});
    }
    if (value == null) {
      node.remove(keys.last);
    } else {
      node[keys.last] = serverValues(value);
    }
  }

  late final store = CloudSnapshotStore(
    read: (path) async => readNow(path),
    write: write,
    commit: (path, expected, value) async {
      if (conflictOnCommit ||
          (readNow(path)?['version'] as String?) != expected) return false;
      await write(path, value);
      return true;
    },
  );
}

Map<String, dynamic> snapshot(int tasks, {int historyValue = 1}) => {
      'tasks': {
        'mainTasks': [
          for (var i = 0; i < tasks; i++) {'id': 't$i', 'subTasks': []}
        ]
      },
      'finance': {'transactions': []},
      'history': {
        'completedByDay': {
          '2026-10-10': {'value': 0},
          '2026-10-11': {'value': historyValue}
        }
      },
      'reflections': {
        'reflectionLogs': [
          {'id': 'r1', 'note': 'hello'}
        ]
      },
    };
void main() {
  test('exact baseline versions detect commits even when timestamps collide',
      () async {
    final cloud = FakeCloud();
    final first = await cloud.store
        .save('u', snapshot(10), baseline: 0, deviceId: 'phone');
    await cloud.store.save('u', snapshot(11),
        baseline: first['lastModified'],
        baselineVersion: first['version'],
        deviceId: 'desktop');
    await cloud.write('users/u/head/lastModified', first['lastModified']);
    await expectLater(
        cloud.store.save('u', snapshot(12),
            baseline: first['lastModified'],
            baselineVersion: first['version'],
            deviceId: 'phone'),
        throwsA(isA<CloudConflictException>()));
  });
  test(
      'restores capture the immutable version they read and prefer newer legacy data',
      () async {
    final cloud = FakeCloud();
    final first = await cloud.store
        .save('u', snapshot(10), baseline: 0, deviceId: 'phone');
    final captured = await cloud.store.current('u');
    expect(captured!['version'], first['version']);
    expect((jsonDecode(captured['data']['tasks'])['mainTasks'] as List).length,
        10);
    await cloud.write('users/u/data', {
      'tasks': {
        'mainTasks': [
          {'id': 'legacy-new'}
        ]
      }
    });
    await cloud.write('users/u/lastModified', first['lastModified'] + 1000);
    final newer = await cloud.store.current('u');
    expect(newer!['lastModified'], first['lastModified'] + 1000);
    expect(newer['data']['tasks']['mainTasks'].single['id'], 'legacy-new');
  });
  test(
      'purge verification compares all recovery data despite RTDB empty-value normalization',
      () {
    final archive = {
      'data': {'tasks': 'original'},
      'firestore': '{"daily":{}}',
      'head': null,
      'expiresAt': 5000,
      'empty': []
    };
    expect(
        cloudRecoveryMatches(archive, {
          'data': {'tasks': 'original'},
          'firestore': '{"daily":{}}',
          'expiresAt': 5000
        }),
        isTrue);
    expect(
        cloudRecoveryMatches(
            archive, {'firestore': '{"daily":{}}', 'expiresAt': 5000}),
        isFalse);
    expect(
        cloudRecoveryMatches(archive, {
          'data': {'tasks': 'damaged'},
          'firestore': '{"daily":{}}',
          'expiresAt': 5000
        }),
        isFalse);
    expect(
        cloudRecoveryMatches({
          'logs': ['a', 'b']
        }, {
          'logs': {'0': 'a', '1': 'b'}
        }),
        isTrue);
  });
  test('a failed upload leaves all live pointers and timestamp unchanged',
      () async {
    final cloud = FakeCloud();
    final first = await cloud.store
        .save('u', snapshot(10), baseline: 0, deviceId: 'phone');
    cloud.failWritesContaining = '/chunks/tasks/';
    await expectLater(
        cloud.store.save('u', snapshot(11),
            baseline: first['lastModified'], deviceId: 'phone'),
        throwsStateError);
    expect(cloud.readNow('users/u/head'), first);
  });
  test('newer cloud baseline and concurrent commits refuse to overwrite',
      () async {
    final cloud = FakeCloud();
    final first = await cloud.store
        .save('u', snapshot(10), baseline: 0, deviceId: 'phone');
    await expectLater(
        cloud.store.save('u', snapshot(11), baseline: 0, deviceId: 'desktop'),
        throwsA(isA<CloudConflictException>()));
    cloud.conflictOnCommit = true;
    await expectLater(
        cloud.store.save('u', snapshot(11),
            baseline: first['lastModified'], deviceId: 'desktop'),
        throwsA(isA<CloudConflictException>()));
    expect(cloud.readNow('users/u/head'), first);
  });
  test('shrink guard requires explicit deletion confirmation', () async {
    final cloud = FakeCloud();
    final first = await cloud.store
        .save('u', snapshot(10), baseline: 0, deviceId: 'phone');
    await expectLater(
        cloud.store.save('u', snapshot(6),
            baseline: first['lastModified'], deviceId: 'phone'),
        throwsA(isA<CloudConflictException>()));
    final second = await cloud.store.save('u', snapshot(6),
        baseline: first['lastModified'], deviceId: 'phone', allowShrink: true);
    expect(second['manifest']['tasks'], 6);
  });
  test('retained snapshots can be restored and all chunk content is verified',
      () async {
    final cloud = FakeCloud();
    final first = await cloud.store
        .save('u', snapshot(10), baseline: 0, deviceId: 'phone');
    var latest = first;
    for (var i = 0; i < 25; i++) {
      latest = await cloud.store.save('u', snapshot(11 + i),
          baseline: latest['lastModified'], deviceId: 'phone');
    }
    final versions = await cloud.store.versions('u');
    expect(versions.length, CloudSnapshotStore.retainedVersions);
    final previous = await cloud.store.resolveData('u', versions[1]['data']);
    expect((jsonDecode(previous['tasks'])['mainTasks'] as List).length, 34);
    final pointer = versions[1]['data']['tasks'];
    await cloud.write(
        'users/u/chunks/tasks/${pointer['ver']}/p00000', 'corrupt');
    await expectLater(
        cloud.store.resolveData('u', versions[1]['data']), throwsStateError);
  });
  test(
      'unchanged days and reflections are not re-uploaded, and deletions stay deleted',
      () async {
    final cloud = FakeCloud();
    final first = await cloud.store
        .save('u', snapshot(10), baseline: 0, deviceId: 'phone');
    cloud.writes.clear();
    final changed = snapshot(10, historyValue: 2);
    changed['reflections'] = {'reflectionLogs': []};
    final next = await cloud.store.save('u', changed,
        baseline: first['lastModified'], deviceId: 'phone', allowShrink: true);
    expect(
        cloud.writes
            .where((p) => p.contains('/chunks/') && !p.endsWith('/_uploadedAt'))
            .length,
        1);
    final restored = await cloud.store.resolveData('u', next['data']);
    expect(restored['reflections'], isEmpty);
    expect(jsonDecode(restored['history']['2026-10-11'])['value'], 2);
  });
  test('missing cloud parts are errors, never empty backups', () async {
    final cloud = FakeCloud();
    final first = await cloud.store
        .save('u', snapshot(10), baseline: 0, deviceId: 'phone');
    final pointer = first['data']['tasks'];
    await cloud.write('users/u/chunks/tasks/${pointer['ver']}/p00000', null);
    await expectLater(
        cloud.store.resolveData('u', first['data']), throwsStateError);
  });
}
