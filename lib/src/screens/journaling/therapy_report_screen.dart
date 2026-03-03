import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TherapyReportScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;

  const TherapyReportScreen({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final actionPlan = reportData['action_plan'] as String? ?? "No action plan provided.";
    final suggestedPerson = reportData['suggested_person'] as String?;
    final mapRaw = reportData['conversation_map'] as List<dynamic>? ?? [];
    final convoMap = mapRaw.map((e) => e.toString()).toList();

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("TRIAGE REPORT", style: TextStyle(color: AppTheme.fhAccentTeal)),
        automaticallyImplyLeading: false, // Force them to hit "ACKNOWLEDGE"
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.medicalBag, color: AppTheme.fhAccentTeal, size: 28),
                const SizedBox(width: 12),
                const Text("ACTION PLAN", style: TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                border: Border(left: BorderSide(color: AppTheme.fhAccentTeal, width: 4)),
              ),
              child: Text(actionPlan, style: const TextStyle(color: AppTheme.fhTextPrimary, height: 1.5, fontSize: 14)),
            ),

            const SizedBox(height: 32),

            if (suggestedPerson != null && suggestedPerson.toLowerCase() != 'null') ...[
              const Text("SUGGESTED COMMS TARGET", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.fhAccentTeal),
                  color: AppTheme.fhAccentTeal.withOpacity(0.1),
                ),
                child: Row(
                  children: [
                    Icon(MdiIcons.accountVoice, color: AppTheme.fhAccentTeal),
                    const SizedBox(width: 12),
                    Text(suggestedPerson.toUpperCase(), style: const TextStyle(color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: AppTheme.fontDisplay)),
                  ],
                ),
              ),

              if (convoMap.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text("CONVERSATION MAP", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                ...convoMap.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("0${e.key + 1}", style: const TextStyle(color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono')),
                        const SizedBox(width: 12),
                        Expanded(child: Text(e.value, style: const TextStyle(color: AppTheme.fhTextPrimary, height: 1.4))),
                      ],
                    ),
                  );
                }),
              ]
            ],

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ValorantButton(
                label: "ACKNOWLEDGE & CLOSE",
                color: AppTheme.fhAccentTeal,
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      ),
    );
  }
}