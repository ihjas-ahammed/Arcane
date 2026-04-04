import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:arcane/src/widgets/screens/submission_detail_screen.dart';
import 'package:arcane/src/widgets/screens/checkpoint_detail_screen.dart';
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

    List<Widget> queueItems = [];
    bool isFirstItem = true;

    for (String compId in plan) {
      final parts = compId.split('|');
      if (parts.length < 2) continue;

      final mainId = parts[0];
      final subId = parts[1];
      
      // Filter out soft-deleted tasks
      final task = provider.mainTasks.firstWhereOrNull((t) => t.id == mainId && !t.isDeleted);
      final sub = task?.subTasks.firstWhereOrNull((s) => s.id == subId && !s.isDeleted);

      if (task == null || sub == null) continue;

      final isCheckpoint = parts.length == 3;
      bool isCompleted = false;
      String title = sub.name;
      String? cpId;

      if (isCheckpoint) {
        cpId = parts[2];
        final cp = sub.subSubTasks.firstWhereOrNull((c) => c.id == cpId);
        if (cp == null) continue;
        
        isCompleted = cp.completed;
        title = cp.name;
      } else {
        isCompleted = sub.completed;
      }
      
      if (isCompleted) continue;
      if (isFirstItem) {
         isFirstItem = false;
         continue; 
      }

      queueItems.add(_buildCard(
        context, provider,
        title: title,
        parentName: isCheckpoint ? sub.name : task.name,
        color: isCheckpoint ? PersonInfoTheme.spideyCyan : PersonInfoTheme.spideyRed,
        onTap: () {
          if (isCheckpoint && cpId != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CheckpointDetailScreen(
              mainTaskId: mainId,
              parentSubTaskId: subId,
              checkpointId: cpId!,
            )));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => SubmissionDetailScreen(
              parentTask: task,
              subTask: sub,
            )));
          }
        },
      ));
    }

    if (queueItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(MdiIcons.formatListChecks, size: 14, color: AppTheme.fhTextSecondary),
              const SizedBox(width: 8),
              const Text("ON DECK", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 65, 
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: queueItems.length,
            separatorBuilder: (c, i) => const SizedBox(width: 10),
            itemBuilder: (c, i) => queueItems[i],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, AppProvider provider, {
    required String title,
    required String parentName,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: PersonInfoTheme.bgPanel,
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title.toUpperCase(),
              style: GoogleFonts.chakraPetch(
                color: AppTheme.fhTextPrimary, 
                fontSize: 12, 
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              parentName,
              style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}