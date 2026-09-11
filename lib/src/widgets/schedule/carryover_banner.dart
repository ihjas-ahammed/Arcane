import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart' as helper;

class CarryoverBanner extends StatelessWidget {
  final AppProvider provider;

  const CarryoverBanner({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final today = helper.getTodayDateString();
    if (provider.taskActions.wasCarryoverHandled(today)) {
      return const SizedBox.shrink();
    }
    final yesterday =
        DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
    if (!provider.taskActions.hasUnfinishedPlan(yesterday)) {
      return const SizedBox.shrink();
    }

    final unfinishedCount = provider.taskActions
        .getDayPlan(yesterday)
        .where((id) {
      final parts = id.split('|');
      if (parts.length < 2) return false;
      final task = provider.mainTasks.firstWhereOrNull((t) => t.id == parts[0] && !t.isDeleted);
      final sub = task?.subTasks.firstWhereOrNull((s) => s.id == parts[1] && !s.isDeleted);
      if (task == null || sub == null) return false;
      if (parts.length == 3) {
        final cp = sub.subSubTasks.firstWhereOrNull((c) => c.id == parts[2]);
        return cp != null && !cp.completed;
      }
      return !sub.completed;
    }).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: JweTheme.accentTeal.withValues(alpha: 0.08),
        border: Border(
          left: BorderSide(color: JweTheme.accentTeal, width: 3),
          bottom: BorderSide(color: JweTheme.border),
        ),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.arrowRightBoldOutline,
              size: 16, color: JweTheme.accentTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$unfinishedCount unfinished from yesterday',
              style: TextStyle(
                  color: JweTheme.textWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => provider.taskActions.dismissCarryover(today),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text('DISMISS',
                style: TextStyle(
                    color: JweTheme.textMuted,
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () =>
                provider.taskActions.carryOverUnfinished(yesterday, today),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text('CARRY OVER',
                style: TextStyle(
                    color: JweTheme.accentTeal,
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
