import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/global_toast.dart';

/// Copies the goals of one period (daily, weekly or monthly) to the clipboard as JSON,
/// then shows a toast. [date] picks the period the same way the goals drawer does.
Future<void> copyGoalsForPeriod(AppProvider provider, GoalScope scope, DateTime date) async {
  final goals = provider.getGoalsForDate(date, scope);
  final payload = {
    'scope': scope.name,
    'date': DateFormat('yyyy-MM-dd').format(date),
    'periodKey': GoalModel.getPeriodKey(scope, date),
    'count': goals.length,
    'goals': goals.map((g) => g.toJson()).toList(),
  };
  await Clipboard.setData(
    ClipboardData(text: const JsonEncoder.withIndent('  ').convert(payload)),
  );
  // The bottom margin keeps the toast above the Android clipboard preview, which sits at the bottom left.
  showGlobalToast(
    goals.isEmpty
        ? 'No ${scope.name} goals to copy. Empty JSON copied.'
        : 'Copied ${goals.length} ${scope.name} goal${goals.length == 1 ? '' : 's'} as JSON',
    bottomMargin: 150,
  );
}
