import 'dart:convert';
import 'package:missions/src/services/web_state_store.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:missions/src/services/app_storage_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/models/skill_models.dart';

enum DiffType { add, remove, modify }

class FieldDiff {
  final String field;
  final dynamic oldValue;
  final dynamic newValue;
  final DiffType type;

  const FieldDiff({
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'field': field,
        'oldValue': oldValue,
        'newValue': newValue,
        'type': type.name,
      };

  factory FieldDiff.fromJson(Map<String, dynamic> json) => FieldDiff(
        field: json['field'] as String? ?? '',
        oldValue: json['oldValue'],
        newValue: json['newValue'],
        type: DiffType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => DiffType.modify,
        ),
      );

  String toGitDiffString() {
    switch (type) {
      case DiffType.add:
        return '+ $field: ${_formatVal(newValue)}';
      case DiffType.remove:
        return '- $field: ${_formatVal(oldValue)}';
      case DiffType.modify:
        return '~ $field: ${_formatVal(oldValue)} ➔ ${_formatVal(newValue)}';
    }
  }

  static String _formatVal(dynamic val) {
    if (val == null) return 'null';
    if (val is String) return '"$val"';
    if (val is num || val is bool) return '$val';
    return jsonEncode(val);
  }
}

class DbActionEntry {
  final String id;
  final DateTime timestamp;
  final String actionType; // CREATE, UPDATE, DELETE, COMPLETE
  final String collection; // task, subtask, transaction, reflection, goal, project
  final String entityId;
  final String title;
  final String summary;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final List<FieldDiff> diffs;

  const DbActionEntry({
    required this.id,
    required this.timestamp,
    required this.actionType,
    required this.collection,
    required this.entityId,
    required this.title,
    required this.summary,
    this.before,
    this.after,
    required this.diffs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'actionType': actionType,
        'collection': collection,
        'entityId': entityId,
        'title': title,
        'summary': summary,
        'before': before,
        'after': after,
        'diffs': diffs.map((d) => d.toJson()).toList(),
      };

  factory DbActionEntry.fromJson(Map<String, dynamic> json) => DbActionEntry(
        id: json['id'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        actionType: json['actionType'] as String? ?? 'UPDATE',
        collection: json['collection'] as String? ?? 'misc',
        entityId: json['entityId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        before: json['before'] != null ? Map<String, dynamic>.from(json['before'] as Map) : null,
        after: json['after'] != null ? Map<String, dynamic>.from(json['after'] as Map) : null,
        diffs: (json['diffs'] as List? ?? [])
            .whereType<Map>()
            .map((e) => FieldDiff.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class AppActionLedgerService {
  static final AppActionLedgerService instance = AppActionLedgerService._();
  AppActionLedgerService._();

  List<DbActionEntry> _entries = [];
  bool _loaded = false;
  String? _currentUserId;
  Future<void> _writeQueue = Future.value();
  String? loadError;

  List<DbActionEntry> get entries => List.unmodifiable(_entries);

  Future<void> init(String userId) async {
    await _writeQueue;
    _currentUserId = userId;
    _entries = [];
    _loaded = false;
    loadError = null;
    await _loadFromDisk();
  }

  Future<void> detachAccount() async {
    await _writeQueue;
    _currentUserId = null;
    _entries = [];
    _loaded = false;
    loadError = null;
  }

  Future<File> _getFile(String userId) async {
    final docsDir = await AppStoragePaths.directory();
    final ledgerDir = Directory('${docsDir.path}/ledger');
    if (!await ledgerDir.exists()) {
      await ledgerDir.create(recursive: true);
    }
    return File('${ledgerDir.path}/db_action_ledger_$userId.json');
  }

  Future<void> _loadFromDisk() async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      final recovered = <String, DbActionEntry>{};
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final raw = await WebStateStore.read('ledger_$uid') ?? prefs.getString('db_action_ledger_$uid');
        if (raw != null) {
          for (final e in jsonDecode(raw) as List) {
            final entry = DbActionEntry.fromJson(Map<String, dynamic>.from(e));
            recovered[entry.id] = entry;
          }
        }
      } else {
        final legacy = await _getFile(uid);
        if (await legacy.exists()) {
          try {
            for (final e in jsonDecode(await legacy.readAsString()) as List) {
              final entry = DbActionEntry.fromJson(Map<String, dynamic>.from(e));
              recovered[entry.id] = entry;
            }
          } catch (_) {
            await legacy.rename('${legacy.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}');
          }
        }
        final journals = (await legacy.parent.list().toList()).whereType<File>().where((f) => f.uri.pathSegments.last.startsWith('db_action_ledger_${uid}_') && f.path.endsWith('.jsonl')).toList()..sort((a,b) => a.path.compareTo(b.path));
        for (final file in journals) {
          var corrupt = false;
          final validLines = <String>[];
          for (final line in await file.readAsLines()) {
            if (line.trim().isEmpty) continue;
            try {
              final record = Map<String, dynamic>.from(jsonDecode(line));
              validLines.add(line);
              if (record['_clear'] == true) { recovered.clear(); continue; }
              final entry = DbActionEntry.fromJson(record);
              recovered[entry.id] = entry;
            } catch (_) { corrupt = true; }
          }
          if (corrupt) {
            final tmp = File('${file.path}.recovered.tmp');
            await tmp.writeAsString('${validLines.join('\n')}\n', flush: true);
            await file.rename('${file.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}');
            await tmp.rename(file.path);
          }
        }
      }
      if (_currentUserId != uid) return;
      _entries = recovered.values.toList()..sort((a,b) => b.timestamp.compareTo(a.timestamp));
      _pruneOldEntries();
      _loaded = true;
    } catch (e) {
      loadError = '$e';
      debugPrint('[ActionLedger] Load failed; original files preserved: $e');
      rethrow;
    }
  }

  void _pruneOldEntries() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    _entries.removeWhere((e) => e.timestamp.isBefore(cutoff));
  }

  Future<void> _appendRecord(Map<String, dynamic> record) {
    final uid = _currentUserId;
    if (uid == null) return Future.value();
    final webSnapshot = kIsWeb ? jsonEncode(_entries.map((e) => e.toJson()).toList()) : null;
    final line = '${jsonEncode(record)}\n';
    final run = _writeQueue.then((_) async {
      if (kIsWeb) {
        await WebStateStore.write('ledger_$uid', webSnapshot!);
        return;
      }
      final legacy = await _getFile(uid);
      final day = DateTime.now().toIso8601String().substring(0,10);
      final file = File('${legacy.parent.path}/db_action_ledger_${uid}_$day.jsonl');
      await file.writeAsString(line, mode: FileMode.append, flush: true);
      final cutoff = DateTime.now().subtract(const Duration(days: 2)).toIso8601String().substring(0,10);
      for (final old in (await legacy.parent.list().toList()).whereType<File>()) {
        final name = old.uri.pathSegments.last;
        final prefix = 'db_action_ledger_${uid}_';
        if (name.startsWith(prefix) && name.endsWith('.jsonl') && name.substring(prefix.length, name.length-6).compareTo(cutoff) < 0) await old.delete();
      }
    });
    _writeQueue = run.catchError((_) {});
    return run;
  }

  /// Records a live DB mutation in the 24-hour action ledger with before/after diffs.
  Future<void> recordAction({
    required String actionType,
    required String collection,
    required String entityId,
    required String title,
    required String summary,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    if (!_loaded && _currentUserId != null) {
      await _loadFromDisk();
    }

    final diffs = _computeDiff(before, after);
    final entry = DbActionEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_entries.length}',
      timestamp: DateTime.now(),
      actionType: actionType,
      collection: collection,
      entityId: entityId,
      title: title,
      summary: summary,
      before: before,
      after: after,
      diffs: diffs,
    );

    _entries.insert(0, entry);
    // Prune entries older than 24h
    _pruneOldEntries();
    await _appendRecord(entry.toJson());
  }

  static List<FieldDiff> _computeDiff(Map<String, dynamic>? before, Map<String, dynamic>? after) {
    final diffs = <FieldDiff>[];
    final allKeys = <String>{...?before?.keys, ...?after?.keys};
    for (final k in allKeys) {
      final v1 = before?[k];
      final v2 = after?[k];
      if (v1 == null && v2 != null) {
        diffs.add(FieldDiff(field: k, oldValue: null, newValue: v2, type: DiffType.add));
      } else if (v1 != null && v2 == null) {
        diffs.add(FieldDiff(field: k, oldValue: v1, newValue: null, type: DiffType.remove));
      } else if (v1 != null && v2 != null) {
        final s1 = jsonEncode(v1);
        final s2 = jsonEncode(v2);
        if (s1 != s2) {
          diffs.add(FieldDiff(field: k, oldValue: v1, newValue: v2, type: DiffType.modify));
        }
      }
    }
    return diffs;
  }

  /// Reverts a ledger entry back to its [before] state.
  Future<bool> revertEntry(DbActionEntry entry, AppProvider provider) async {
    try {
      final before = entry.before;

      switch (entry.collection) {
        case 'task':
          if (entry.actionType == 'CREATE') {
            provider.taskActions.deleteMainTask(entry.entityId);
          } else if (before != null) {
            final restored = MainTask.fromJson(before);
            final tasks = List<MainTask>.from(provider.mainTasks);
            final existing = tasks.indexWhere((t) => t.id == entry.entityId);
            if (existing >= 0) {
              tasks[existing] = restored;
            } else {
              tasks.add(restored);
            }
            provider.setProviderState(mainTasks: tasks);
          }
          break;

        case 'subtask':
          final parts = entry.entityId.split(':');
          final parentId = parts[0];
          final subId = parts.length > 1 ? parts[1] : entry.entityId;

          if (entry.actionType == 'CREATE') {
            provider.taskActions.deleteSubtask(parentId, subId);
          } else if (before != null) {
            final restoredSt = SubTask.fromJson(before);
            final tasks = provider.mainTasks.map((t) {
              if (t.id != parentId) return t;
              final subtasks = List<SubTask>.from(t.subTasks);
              final sIdx = subtasks.indexWhere((s) => s.id == subId);
              if (sIdx >= 0) {
                subtasks[sIdx] = restoredSt;
              } else {
                subtasks.add(restoredSt);
              }
              return t.copyWith(subTasks: subtasks);
            }).toList();
            provider.setProviderState(mainTasks: tasks);
          }
          break;

        case 'transaction':
          if (entry.actionType == 'CREATE') {
            provider.financeActions.deleteTransaction(entry.entityId);
          } else if (before != null) {
            final restoredTx = FinanceTransaction.fromJson(before);
            final txs = List<FinanceTransaction>.from(provider.transactions);
            final existing = txs.indexWhere((t) => t.id == entry.entityId);
            if (existing >= 0) {
              txs[existing] = restoredTx;
            } else {
              txs.add(restoredTx);
            }
            provider.setProviderState(transactions: txs);
          }
          break;

        case 'reflection':
          if (entry.actionType == 'CREATE') {
            provider.deleteReflectionLog(entry.entityId);
          } else if (before != null) {
            final restoredRef = ReflectionLog.fromJson(before);
            final logs = List<ReflectionLog>.from(provider.reflectionLogs);
            final idx = logs.indexWhere((l) => l.id == entry.entityId);
            if (idx >= 0) {
              logs[idx] = restoredRef;
            } else {
              logs.add(restoredRef);
            }
            provider.setReflectionLogs(logs);
          }
          break;

        default:
          return false;
      }

      await provider.forceLocalBackup();

      // Record a new entry acknowledging the revert
      await recordAction(
        actionType: 'REVERT',
        collection: entry.collection,
        entityId: entry.entityId,
        title: entry.title,
        summary: 'Reverted action: ${entry.summary}',
        before: entry.after,
        after: entry.before,
      );

      return true;
    } catch (e) {
      debugPrint('[ActionLedger] Error reverting entry: $e');
      return false;
    }
  }

  /// Clears the ledger
  Future<void> clear() async {
    _entries.clear();
    await _appendRecord({'_clear': true, 'timestamp': DateTime.now().toIso8601String()});
  }
}
