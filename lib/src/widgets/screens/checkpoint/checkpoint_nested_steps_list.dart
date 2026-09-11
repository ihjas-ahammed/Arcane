import 'package:flutter/material.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/items/checkpoint_item.dart';
import 'package:missions/src/widgets/items/draggable_checkpoint_wrapper.dart';

class CheckpointNestedStepsList extends StatelessWidget {
  final List<SubSubTask> substeps;
  final Color agentColor;
  final bool isSelectionMode;
  final Set<String> selectedKeys;
  final Function(SubSubTask grand) onToggleSubstep;
  final Function(SubSubTask child) onOpenChild;
  final Function(SubSubTask child) onToggleCompleted;
  final Function(SubSubTask child) onDeleteChild;
  final Function(SubSubTask child) onDuplicateChild;
  final Function(SubSubTask child) onToggleType;
  final Function(String childId, bool isSelected) onSelectedChanged;
  final Function(String draggedId, String targetId, String position) onMoveChild;

  const CheckpointNestedStepsList({
    super.key,
    required this.substeps,
    required this.agentColor,
    required this.isSelectionMode,
    required this.selectedKeys,
    required this.onToggleSubstep,
    required this.onOpenChild,
    required this.onToggleCompleted,
    required this.onDeleteChild,
    required this.onDuplicateChild,
    required this.onToggleType,
    required this.onSelectedChanged,
    required this.onMoveChild,
  });

  @override
  Widget build(BuildContext context) {
    if (substeps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          "No nested instructions.",
          style: TextStyle(
            color: JweTheme.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: substeps.length,
      itemBuilder: (ctx, index) {
        final child = substeps[index];
        final item = CheckpointItem(
          key: ValueKey(child.id),
          title: child.name,
          isCompleted: child.completed,
          type: child.type,
          accentColor: agentColor,
          hasCheckableSubsteps: child.hasCheckableSubsteps,
          progress: child.calculateProgress(),
          substeps: child.substeps,
          onToggleSubstep: onToggleSubstep,
          onTap: () => onOpenChild(child),
          onToggle: () => onToggleCompleted(child),
          onDelete: () => onDeleteChild(child),
          onDuplicate: () => onDuplicateChild(child),
          onToggleType: () => onToggleType(child),
          isSelectionMode: isSelectionMode,
          isSelected: selectedKeys.contains(child.id),
          onSelectedChanged: (val) =>
              onSelectedChanged(child.id, val == true),
        );

        if (isSelectionMode) {
          return item;
        }

        return DraggableCheckpointWrapper(
          checkpointId: child.id,
          onMove: onMoveChild,
          child: item,
        );
      },
    );
  }
}
