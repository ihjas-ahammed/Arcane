import 'package:flutter/material.dart';

import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/widgets/dialogs/xp_gain_dialog.dart';

/// Shows the last reflection's AI feedback using the same INSIGHT ACQUIRED
/// HUD treatment as the post-reflection dialog.
class LastInsightDialog extends StatelessWidget {
  final ReflectionLog log;

  const LastInsightDialog({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return XpGainDialog(
      xpGained: log.xpGained,
      insightText: log.aiFeedback,
    );
  }
}
