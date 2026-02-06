import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ValueUpdateConfirmDialog extends StatelessWidget {
  final Map<String, dynamic> updateData;

  const ValueUpdateConfirmDialog({super.key, required this.updateData});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Find value and question for context display
    String valueTitle = "Protocol";
    String questionText = "Question";
    try {
      final value = provider.lifeValues.firstWhere((v) => v.id == updateData['valueId']);
      valueTitle = value.title;
      final q = value.questions.firstWhere((q) => q.id == updateData['questionId']);
      questionText = q.question;
    } catch (_) {}

    final suggestedAnswer = updateData['suggestedAnswer'] ?? '...';
    // Simple check if it's an append operation by looking for newline or specific marker we added
    final bool isAppend = suggestedAnswer.contains('\n\n[UPDATE]:');

    return AlertDialog(
      backgroundColor: AppTheme.fhBgDeepDark,
      title: Row(
        children: [
          Icon(MdiIcons.databaseSyncOutline, color: AppTheme.fhAccentTeal),
          const SizedBox(width: 8),
          const Text("VALUES UPDATE", style: TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Based on your logs, the system suggests updating the following protocol data:", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.fhBgDark, border: Border.all(color: AppTheme.fhBorderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("PROTOCOL: $valueTitle", style: const TextStyle(color: AppTheme.fhAccentPurple, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Q: $questionText", style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 12),
                  Text(
                    isAppend ? "APPENDING NEW DATA:" : "SUGGESTED ANSWER:", 
                    style: TextStyle(
                      color: isAppend ? AppTheme.fhAccentGreen : AppTheme.fhAccentTeal, 
                      fontSize: 10, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestedAnswer, 
                    style: const TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold, height: 1.4)
                  ),
                ],
              ),
            ),
            
            if (updateData['reason'] != null) ...[
              const SizedBox(height: 12),
              Text("REASON: ${updateData['reason']}", style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11)),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("IGNORE"),
        ),
        ValorantButton(
          label: isAppend ? "APPEND DATA" : "UPDATE PROTOCOL",
          onPressed: () => Navigator.pop(context, true),
          isPrimary: true,
        )
      ],
    );
  }
}