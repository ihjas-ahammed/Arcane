import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/screens/nora_ai_screen.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class TherapyReportScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;

  const TherapyReportScreen({super.key, required this.reportData});

  void _continueWithNora(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final actionPlan = reportData['action_plan'] as String? ?? "";
    
    final customContext = """
    EMERGENCY TRIAGE CONTEXT:
    The user just completed a rapid triage sequence.
    System provided this action plan: $actionPlan
    
    Continue as NORA, acting as their therapist/tactician to help them process or execute this plan. 
    Acknowledge they just did the triage.
    """;
    
    provider.createNoraSession(
      title: "TRIAGE FOLLOW-UP",
      tone: "Therapist",
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      endDate: DateTime.now(),
      customContext: customContext,
    );
    
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NoraAiScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final actionPlan = reportData['action_plan'] as String? ?? "No action plan provided.";
    final suggestedPerson = reportData['suggested_person'] as String?;
    final mapRaw = reportData['conversation_map'] as List<dynamic>? ?? [];
    final convoMap = mapRaw.map((e) => e.toString()).toList();

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        title: Text("TRIAGE REPORT", style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: JweTheme.bgBase,
        automaticallyImplyLeading: false, 
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.medicalBag, color: JweTheme.accentCyan, size: 28),
                      const SizedBox(width: 12),
                      Text("ACTION PLAN", style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: JweTheme.panel,
                      border: Border(left: BorderSide(color: JweTheme.accentCyan, width: 4)),
                    ),
                    child: Text(actionPlan, style: const TextStyle(color: JweTheme.textWhite, height: 1.5, fontSize: 14)),
                  ),

                  const SizedBox(height: 32),

                  if (suggestedPerson != null && suggestedPerson.toLowerCase() != 'null') ...[
                    const Text("SUGGESTED COMMS TARGET", style: TextStyle(color: JweTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: JweTheme.accentCyan),
                        color: JweTheme.accentCyan.withOpacity(0.1),
                      ),
                      child: Row(
                        children: [
                          Icon(MdiIcons.accountVoice, color: JweTheme.accentCyan),
                          const SizedBox(width: 12),
                          Text(suggestedPerson.toUpperCase(), style: GoogleFonts.chakraPetch(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),

                    if (convoMap.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text("CONVERSATION MAP", style: TextStyle(color: JweTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(height: 12),
                      ...convoMap.asMap().entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("0${e.key + 1}", style: const TextStyle(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono')),
                              const SizedBox(width: 12),
                              Expanded(child: Text(e.value, style: const TextStyle(color: JweTheme.textWhite, height: 1.4))),
                            ],
                          ),
                        );
                      }),
                    ]
                  ],

                  const SizedBox(height: 40),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: JweTheme.textMuted,
                            side: const BorderSide(color: JweTheme.border),
                            shape: const BeveledRectangleBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 16)
                          ),
                          child: const Text("ACKNOWLEDGE"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _continueWithNora(context),
                          icon: Icon(MdiIcons.brain, size: 18),
                          label: Text("NORA LINK", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8A2BE2), // Purple
                            foregroundColor: Colors.white,
                            shape: const BeveledRectangleBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 16)
                          ),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}