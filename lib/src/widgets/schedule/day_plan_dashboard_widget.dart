import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/ui/rhombus_checkbox.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DayPlanDashboardWidget extends StatelessWidget {
  const DayPlanDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final plan = provider.taskActions.getDayPlan(helper.getTodayDateString());

    if (plan.isEmpty) return const SizedBox.shrink();

    // Map IDs to actual active widgets for the horizontal list
    List<Widget> queueItems = [];

    for (String compId in plan) {
      final parts = compId.split('|');
      if (parts.length < 2) continue;

      final mainId = parts[0];
      final subId = parts[1];
      final task = provider.mainTasks.firstWhereOrNull((t) => t.id == mainId);
      final sub = task?.subTasks.firstWhereOrNull((s) => s.id == subId);

      if (task == null || sub == null) continue;

      final isCheckpoint = parts.length == 3;
      bool isCompleted = false;
      String title = sub.name;
      String typeLabel = "MISSION";

      if (isCheckpoint) {
        final cpId = parts[2];
        final cp = sub.subSubTasks.firstWhereOrNull((c) => c.id == cpId);
        if (cp == null) continue;
        
        isCompleted = cp.completed;
        title = cp.name;
        typeLabel = "CHECKPOINT";

        queueItems.add(_buildCard(
          context, provider,
          title: title,
          parentName: sub.name,
          color: task.taskColor,
          typeLabel: typeLabel,
          isCompleted: isCompleted,
          onToggle: () {
            if (isCompleted) {
              provider.taskActions.uncompleteSubSubtask(mainId, subId, cpId);
            } else {
              provider.taskActions.completeSubSubtask(mainId, subId, cpId);
            }
          }
        ));

      } else {
        isCompleted = sub.completed;
        queueItems.add(_buildCard(
          context, provider,
          title: title,
          parentName: task.name,
          color: task.taskColor,
          typeLabel: typeLabel,
          isCompleted: isCompleted,
          onToggle: () {
            if (isCompleted) {
              provider.taskActions.uncompleteSubtask(mainId, subId);
            } else {
              provider.taskActions.completeSubtask(mainId, subId);
            }
          }
        ));
      }
    }

    if (queueItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(MdiIcons.formatListChecks, size: 16, color: AppTheme.fhTextSecondary),
              const SizedBox(width: 8),
              const Text("TODAY'S QUEUE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100, // Compact horizontal card height
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: queueItems.length,
            separatorBuilder: (c, i) => const SizedBox(width: 12),
            itemBuilder: (c, i) => queueItems[i],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, AppProvider provider, {
    required String title,
    required String parentName,
    required Color color,
    required String typeLabel,
    required bool isCompleted,
    required VoidCallback onToggle,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCompleted ? AppTheme.fhBorderColor : color.withOpacity(0.5)),
        boxShadow: isCompleted ? null : [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)]
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: RhombusCheckbox(
              checked: isCompleted,
              onChanged: (_) => onToggle(),
              size: CheckboxSize.small,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  typeLabel,
                  style: TextStyle(color: isCompleted ? AppTheme.fhTextDisabled : color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 2),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.chakraPetch(
                    color: isCompleted ? AppTheme.fhTextSecondary : AppTheme.fhTextPrimary, 
                    fontSize: 14, 
                    fontWeight: FontWeight.bold,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  parentName,
                  style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}