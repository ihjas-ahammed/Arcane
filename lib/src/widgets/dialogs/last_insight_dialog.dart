import 'package:flutter/material.dart';

import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/widgets/dialogs/insight_dialog.dart';

/// Shows the last reflection's AI feedback using the same INSIGHT ACQUIRED
/// HUD treatment as the post-reflection dialog.
class LastInsightDialog extends StatelessWidget {
  final ReflectionLog log;

  const LastInsightDialog({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return InsightDialog(
      areas: log.xpGained.entries.where((e) => e.value > 0).map((e) => e.key),
      insightText: log.aiFeedback,
    );
  }
}
