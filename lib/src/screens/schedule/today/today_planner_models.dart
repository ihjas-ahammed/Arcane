import 'package:flutter/material.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:uuid/uuid.dart';

/// One slot in the day plan. The same compound id may appear more than once
/// (planning several sessions of the same work), so each slot carries its own
/// stable [key] for list identity and animations.
class PlanCheckpoint {
  final String id;
  String name;
  bool completed;
  int durationMinutes;

  PlanCheckpoint({
    required this.id,
    required this.name,
    this.completed = false,
    this.durationMinutes = 15,
  });

  PlanCheckpoint clone({String? newId}) => PlanCheckpoint(
        id: newId ?? const Uuid().v4(),
        name: name,
        completed: completed,
        durationMinutes: durationMinutes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'completed': completed,
        'durationMinutes': durationMinutes,
      };

  factory PlanCheckpoint.fromJson(Map<String, dynamic> json) => PlanCheckpoint(
        id: json['id'] as String? ?? const Uuid().v4(),
        name: json['name'] as String? ?? '',
        completed: json['completed'] as bool? ?? false,
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 15,
      );
}

/// One slot in the day plan. The same compound id may appear more than once
/// (planning several sessions of the same work), so each slot carries its own
/// stable [key] for list identity and animations.
class PlanEntry {
  static int _seq = 0;
  final String key;
  final String id;
  final bool addedAtRuntime;
  List<PlanCheckpoint> checkpoints;

  PlanEntry(
    this.id, {
    this.addedAtRuntime = false,
    String? key,
    List<PlanCheckpoint>? checkpoints,
  })  : key = key ?? 'plan-entry-${_seq++}',
        checkpoints = checkpoints ?? [];

  PlanEntry clone() {
    return PlanEntry(
      id,
      addedAtRuntime: true,
      checkpoints: checkpoints.map((c) => c.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'id': id,
        'addedAtRuntime': addedAtRuntime,
        'checkpoints': checkpoints.map((c) => c.toJson()).toList(),
      };

  factory PlanEntry.fromJson(Map<String, dynamic> json) => PlanEntry(
        json['id'] as String? ?? '',
        addedAtRuntime: json['addedAtRuntime'] as bool? ?? false,
        key: json['key'] as String?,
        checkpoints: (json['checkpoints'] as List?)
                ?.whereType<Map>()
                .map((m) => PlanCheckpoint.fromJson(Map<String, dynamic>.from(m)))
                .toList() ??
            [],
      );
}

/// A row in the multi-planner holding 1, 2, or 3 plans for multitasking.
class PlanRowData {
  static int _rowSeq = 0;
  final String key;
  final List<PlanEntry> entries;

  PlanRowData(this.entries, {String? key})
      : key = key ?? 'plan-row-${_rowSeq++}';

  int get count => entries.length.clamp(1, 3);
}

enum LeaveKind { removed, completed }

class RoutineItemSelectable {
  final String compoundId;
  final String title;
  final String parentPath;
  final Color color;

  RoutineItemSelectable({
    required this.compoundId,
    required this.title,
    required this.parentPath,
    required this.color,
  });
}

class ResolvedRoutineItem {
  final String title;
  final String parentPath;

  ResolvedRoutineItem({required this.title, required this.parentPath});
}

List<SubSubTask> getAllCheckpointsForPlanning(SubTask sub) {
  final List<SubSubTask> result = [];
  void recurse(List<SubSubTask> currentList) {
    for (final cp in currentList) {
      if (sub.isRecurring || !cp.completed) {
        result.add(cp);
        recurse(cp.substeps);
      }
    }
  }

  recurse(sub.subSubTasks);
  return result;
}

String findParentPath(SubTask sub, SubSubTask target) {
  String? search(List<SubSubTask> list, String currentPath) {
    for (final item in list) {
      if (item.id == target.id) return currentPath;
      final subPath = currentPath.isEmpty ? item.name : '$currentPath > ${item.name}';
      final found = search(item.substeps, subPath);
      if (found != null) return found;
    }
    return null;
  }

  final path = search(sub.subSubTasks, '');
  if (path == null || path.isEmpty) {
    return sub.name;
  }
  return '${sub.name} > $path';
}
