import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:missions/src/widgets/journaling/person_info_header.dart';
import 'package:missions/src/widgets/journaling/person_core_stats.dart';
import 'package:missions/src/widgets/journaling/person_dossier_section.dart';
import 'package:intl/intl.dart';

class PersonDetailScreen extends StatelessWidget {
  final String personId;

  const PersonDetailScreen({super.key, required this.personId});

  Future<void> _generateProfile(BuildContext context, AppProvider provider) async {
    try {
      await provider.journalingActions.generatePersonDetails(personId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final personIndex = provider.chatbotMemory.people.indexWhere((p) => p.id == personId);
    
    if (personIndex == -1) {
      return Scaffold(
        backgroundColor: PersonInfoTheme.bgDark,
        appBar: AppBar(title: const Text("NOT FOUND"), backgroundColor: Colors.transparent),
      );
    }

    final person = provider.chatbotMemory.people[personIndex];
    
    // Parse the JSON details if available
    Map<String, dynamic>? parsedDetails;
    String? legacyText;

    if (person.details != null && person.details!.isNotEmpty) {
      try {
        parsedDetails = jsonDecode(person.details!);
      } catch (e) {
        legacyText = person.details; // Fallback for old plain text profiles
      }
    }

    return Scaffold(
      // The background gradient matching HTML body
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            colors: [Color(0xFF132030), Color(0xFF000000)],
            radius: 1.0,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600), // Max width from CSS
              child: Column(
                children: [
                  // App Bar override
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: PersonInfoTheme.textWhite),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                  
                  // Main UI Container
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: PersonInfoTheme.bgPanel,
                        border: Border.all(color: const Color(0xFF1f2f40)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            blurRadius: 30,
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          if (parsedDetails != null) ...[
                            // Structured View
                            PersonInfoHeader(
                              level: parsedDetails['level'] ?? 1,
                              xp: parsedDetails['xp'] ?? 0,
                              role: parsedDetails['role'] ?? person.relation,
                              titleName: "${person.name} / ${parsedDetails['title'] ?? 'Entity'}",
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
                                child: Column(
                                  children: [
                                    PersonCoreStats(
                                      relation: person.relation,
                                      status: parsedDetails['status'] ?? "Unknown",
                                      updatedStr: person.lastUpdated != null ? DateFormat('MMM dd, yyyy').format(person.lastUpdated!) : "N/A",
                                      role: parsedDetails['role'] ?? "Unknown",
                                    ),
                                    PersonDossierSection(
                                      profile: parsedDetails['psychological_profile'] ?? "No profile generated.",
                                      interactionHistory: parsedDetails['interaction_history'] ?? [],
                                      communicationTips: parsedDetails['communication_tips'] ?? [],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else if (legacyText != null) ...[
                            // Legacy View
                            PersonInfoHeader(
                              level: 1, xp: 0, role: person.relation, titleName: person.name,
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(30),
                                child: Text(
                                  legacyText,
                                  style: const TextStyle(color: PersonInfoTheme.textWhite, fontSize: 15, height: 1.6),
                                ),
                              ),
                            ),
                          ] else ...[
                            // Empty State / Initial Generation
                            PersonInfoHeader(
                              level: 0, xp: 0, role: person.relation, titleName: person.name,
                            ),
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(30.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        "Profile not yet analyzed. Click below to generate dossier.", 
                                        style: TextStyle(color: PersonInfoTheme.textGrey), 
                                        textAlign: TextAlign.center
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ValorantButton(
                                          label: provider.loadingTaskName == "Analyzing Profile..." ? "ANALYZING..." : "ANALYZE PROFILE",
                                          isPrimary: false,
                                          color: PersonInfoTheme.spideyCyan,
                                          onPressed: provider.loadingTaskName != null ? null : () => _generateProfile(context, provider),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),

                  // Regenerate button at bottom if already populated
                  if (parsedDetails != null || legacyText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0, left: 16, right: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: provider.loadingTaskName != null ? null : () => _generateProfile(context, provider),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PersonInfoTheme.textGrey,
                            side: const BorderSide(color: Color(0xFF1f2f40)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                          ),
                          child: Text(
                            provider.loadingTaskName == "Analyzing Profile..." ? "RECALCULATING..." : "REFRESH DOSSIER",
                            style: const TextStyle(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}