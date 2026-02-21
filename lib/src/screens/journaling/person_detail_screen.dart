import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
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
        backgroundColor: AppTheme.fhBgDeepDark,
        appBar: AppBar(title: const Text("NOT FOUND")),
      );
    }

    final person = provider.chatbotMemory.people[personIndex];

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: Text(person.name.toUpperCase()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("RELATION: ${person.relation.toUpperCase()}", style: const TextStyle(color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ValorantButton(
                label: provider.loadingTaskName == "Analyzing Profile..." ? "ANALYZING..." : "ANALYZE PROFILE",
                isPrimary: false,
                color: AppTheme.fhAccentTeal,
                onPressed: provider.loadingTaskName != null ? null : () => _generateProfile(context, provider),
              ),
            ),
            
            const SizedBox(height: 32),

            if (person.details != null) ...[
              const Text("PSYCHOLOGICAL PROFILE & COMMS", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDark.withOpacity(0.5),
                  border: Border(left: BorderSide(color: AppTheme.fhAccentTeal, width: 2)),
                ),
                child: Text(
                  person.details!,
                  style: const TextStyle(color: AppTheme.fhTextPrimary, height: 1.5, fontSize: 14),
                ),
              ),
              if (person.lastUpdated != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("Last updated: ${DateFormat('MMM dd, yyyy HH:mm').format(person.lastUpdated!)}", style: const TextStyle(color: AppTheme.fhTextDisabled, fontSize: 10)),
                )
            ] else 
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text("Profile not yet analyzed. Click above to generate.", style: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                ),
              )
          ],
        ),
      ),
    );
  }
}