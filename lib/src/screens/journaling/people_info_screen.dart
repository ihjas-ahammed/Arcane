import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/screens/journaling/person_detail_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class PeopleInfoScreen extends StatelessWidget {
  const PeopleInfoScreen({super.key});

  Future<void> _extractPeople(BuildContext context, AppProvider provider) async {
    try {
      await provider.journalingActions.extractAndSavePeople();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Extraction Complete.")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final people = provider.chatbotMemory.people;

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("PEOPLE INTEL"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ValorantButton(
                label: provider.loadingTaskName == "Extracting Entities..." ? "SCANNING..." : "EXTRACT/REFRESH ENTITIES",
                icon: MdiIcons.accountSearchOutline,
                isPrimary: true,
                color: AppTheme.fhAccentTeal,
                onPressed: provider.loadingTaskName != null ? null : () => _extractPeople(context, provider),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "Note: This scans all reflection logs to find mentioned individuals.",
              style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: people.isEmpty
              ? const Center(child: Text("NO INTEL AVAILABLE.", style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: AppTheme.fontDisplay, fontSize: 20)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final p = people[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.fhBgDark,
                        border: Border(left: BorderSide(color: AppTheme.fhAccentTeal, width: 3)),
                      ),
                      child: ListTile(
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary)),
                        subtitle: Text(p.relation, style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
                        trailing: p.details != null 
                            ? Icon(Icons.assignment_turned_in, color: AppTheme.fhAccentTeal, size: 20)
                            : Icon(Icons.assignment_outlined, color: AppTheme.fhTextDisabled, size: 20),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: p.id)));
                        },
                      ),
                    );
                  },
                ),
          )
        ],
      ),
    );
  }
}