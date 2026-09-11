import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'today_available_row.dart';
import 'today_planner_models.dart';

List<Widget> buildSelectableTaskTree({
  required AppProvider provider,
  required String query,
  required bool isSelectionMode,
  required Set<String> selectedIds,
  required void Function(String compoundId, bool selected) onToggleSelection,
  required Map<String, int> plannedCounts,
  required void Function(String compoundId) onAdd,
}) {
  final List<Widget> widgets = [];
  final activeTasks = provider.mainTasks.where((t) => t.isActive && !t.isDeleted).toList();
  final q = query.trim().toLowerCase();

  for (final task in activeTasks) {
    final bool taskMatches = q.isEmpty || task.name.toLowerCase().contains(q);

    final activeSubs = task.subTasks.where((s) {
      if (s.isDeleted) return false;
      if (s.completed && !s.isRecurring) return false;
      return true;
    }).toList();

    if (activeSubs.isEmpty) continue;

    final List<Widget> subGroups = [];
    int taskCount = 0;

    for (final sub in activeSubs) {
      final subId = '${task.id}|${sub.id}';
      final bool subMatches = taskMatches || q.isEmpty || sub.name.toLowerCase().contains(q);
      final bool subOrCpMatch = subMatches || subTaskHasMatchingCheckpoints(sub, q);
      if (!subOrCpMatch) continue;

      final List<Widget> cpWidgets = buildCheckpointTreeWidgets(
        provider: provider,
        subId: subId,
        taskColor: task.taskColor,
        substeps: sub.subSubTasks,
        query: q,
        parentMatched: subMatches,
        isSelectionMode: isSelectionMode,
        selectedIds: selectedIds,
        onToggleSelection: onToggleSelection,
        plannedCounts: plannedCounts,
        onAdd: onAdd,
        level: 2,
      );

      int subCount = 0;
      if (isSelectionMode) {
        if (selectedIds.contains(subId)) {
          subCount += 1;
        }
        subCount += countSelectedCheckpoints(sub.subSubTasks, subId, selectedIds);
      } else {
        subCount += plannedCounts[subId] ?? 0;
        subCount += sumPlannedCheckpoints(sub.subSubTasks, subId, plannedCounts);
      }

      taskCount += subCount;

      subGroups.add(CollapsibleGroup(
        key: ValueKey('sub_${sub.id}_${q.isEmpty ? 0 : 1}'),
        title: sub.name,
        color: task.taskColor,
        level: 1,
        queuedCount: subCount,
        initiallyExpanded: q.isNotEmpty,
        children: [
          AvailableRow(
            title: isSelectionMode ? 'Select whole subtask' : 'Add whole subtask',
            color: task.taskColor,
            isCheckpoint: false,
            plannedCount: isSelectionMode ? 0 : (plannedCounts[subId] ?? 0),
            isSelectionMode: isSelectionMode,
            isSelected: isSelectionMode ? selectedIds.contains(subId) : false,
            onSelectedChanged: isSelectionMode
                ? (val) => onToggleSelection(subId, val == true)
                : null,
            onAdd: isSelectionMode ? () {} : () => onAdd(subId),
          ),
          ...cpWidgets,
        ],
      ));
    }

    if (subGroups.isNotEmpty) {
      widgets.add(CollapsibleGroup(
        key: ValueKey('task_${task.id}_${q.isEmpty ? 0 : 1}'),
        title: task.name,
        color: task.taskColor,
        level: 0,
        queuedCount: taskCount,
        initiallyExpanded: q.isNotEmpty,
        children: subGroups,
      ));
    }
  }

  return widgets;
}

List<Widget> buildCheckpointTreeWidgets({
  required AppProvider provider,
  required String subId,
  required Color taskColor,
  required List<SubSubTask> substeps,
  required String query,
  required bool parentMatched,
  required bool isSelectionMode,
  required Set<String> selectedIds,
  required void Function(String compoundId, bool selected) onToggleSelection,
  required Map<String, int> plannedCounts,
  required void Function(String compoundId) onAdd,
  required int level,
}) {
  final List<Widget> widgets = [];
  final q = query.trim().toLowerCase();

  for (final cp in substeps) {
    final parts = subId.split('|');
    final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
    final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
    final isRecurring = sub?.isRecurring ?? false;

    if (cp.completed && !isRecurring) continue;

    final bool cpMatched = parentMatched || q.isEmpty || cp.name.toLowerCase().contains(q);
    final bool cpOrDescendantMatch = cpMatched || checkpointOrDescendantsMatch(cp, q);
    if (!cpOrDescendantMatch) continue;

    final cpId = '$subId|${cp.id}';

    if (cp.substeps.isEmpty) {
      widgets.add(AvailableRow(
        title: cp.name,
        color: taskColor,
        isCheckpoint: true,
        plannedCount: isSelectionMode ? 0 : (plannedCounts[cpId] ?? 0),
        isSelectionMode: isSelectionMode,
        isSelected: isSelectionMode ? selectedIds.contains(cpId) : false,
        onSelectedChanged: isSelectionMode
            ? (val) => onToggleSelection(cpId, val == true)
            : null,
        onAdd: isSelectionMode ? () {} : () => onAdd(cpId),
      ));
    } else {
      final List<Widget> children = buildCheckpointTreeWidgets(
        provider: provider,
        subId: subId,
        taskColor: taskColor,
        substeps: cp.substeps,
        query: query,
        parentMatched: cpMatched,
        isSelectionMode: isSelectionMode,
        selectedIds: selectedIds,
        onToggleSelection: onToggleSelection,
        plannedCounts: plannedCounts,
        onAdd: onAdd,
        level: level + 1,
      );

      int count = 0;
      if (isSelectionMode) {
        if (selectedIds.contains(cpId)) {
          count += 1;
        }
        count += countSelectedCheckpoints(cp.substeps, subId, selectedIds);
      } else {
        count += plannedCounts[cpId] ?? 0;
        count += sumPlannedCheckpoints(cp.substeps, subId, plannedCounts);
      }

      widgets.add(CollapsibleGroup(
        key: ValueKey('cp_${cp.id}_${q.isEmpty ? 0 : 1}'),
        title: cp.name,
        color: taskColor,
        level: level,
        queuedCount: count,
        initiallyExpanded: q.isNotEmpty,
        children: [
          AvailableRow(
            title: isSelectionMode ? 'Select "${cp.name}" itself' : 'Add "${cp.name}" itself',
            color: taskColor,
            isCheckpoint: true,
            plannedCount: isSelectionMode ? 0 : (plannedCounts[cpId] ?? 0),
            isSelectionMode: isSelectionMode,
            isSelected: isSelectionMode ? selectedIds.contains(cpId) : false,
            onSelectedChanged: isSelectionMode
                ? (val) => onToggleSelection(cpId, val == true)
                : null,
            onAdd: isSelectionMode ? () {} : () => onAdd(cpId),
          ),
          ...children,
        ],
      ));
    }
  }
  return widgets;
}

bool subTaskHasMatchingCheckpoints(SubTask sub, String q) {
  if (q.isEmpty) return true;
  for (final cp in sub.subSubTasks) {
    if (checkpointOrDescendantsMatch(cp, q)) return true;
  }
  return false;
}

bool checkpointOrDescendantsMatch(SubSubTask cp, String q) {
  if (q.isEmpty) return true;
  if (cp.name.toLowerCase().contains(q)) return true;
  for (final sub in cp.substeps) {
    if (checkpointOrDescendantsMatch(sub, q)) return true;
  }
  return false;
}

int countSelectedCheckpoints(List<SubSubTask> list, String subId, Set<String> selectedIds) {
  int count = 0;
  for (final cp in list) {
    final cpId = '$subId|${cp.id}';
    if (selectedIds.contains(cpId)) {
      count += 1;
    }
    count += countSelectedCheckpoints(cp.substeps, subId, selectedIds);
  }
  return count;
}

int sumPlannedCheckpoints(List<SubSubTask> list, String subId, Map<String, int> plannedCounts) {
  int sum = 0;
  for (final cp in list) {
    final cpId = '$subId|${cp.id}';
    sum += plannedCounts[cpId] ?? 0;
    sum += sumPlannedCheckpoints(cp.substeps, subId, plannedCounts);
  }
  return sum;
}

ResolvedRoutineItem resolveRoutineItemDetails(AppProvider provider, String compoundId) {
  final parts = compoundId.split('|');
  if (parts.length < 2) {
    return ResolvedRoutineItem(title: 'Unknown Item', parentPath: '');
  }
  final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0]);
  final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1]);
  if (task == null || sub == null) {
    return ResolvedRoutineItem(title: 'Deleted Item', parentPath: '');
  }

  if (parts.length == 3) {
    final cp = sub.findCheckpoint(parts[2]);
    if (cp == null) {
      return ResolvedRoutineItem(title: 'Deleted Checkpoint', parentPath: '${task.name} > ${sub.name}');
    }
    return ResolvedRoutineItem(
      title: cp.name,
      parentPath: '${task.name} > ${findParentPath(sub, cp)}',
    );
  }

  return ResolvedRoutineItem(
    title: sub.name,
    parentPath: task.name,
  );
}
