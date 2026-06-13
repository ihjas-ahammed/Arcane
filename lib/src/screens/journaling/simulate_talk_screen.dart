import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:missions/src/widgets/valorant/valorant_dropdown.dart';
import 'package:missions/src/widgets/common/growing_text_field.dart';
import 'package:missions/src/screens/nora_ai_screen.dart';

class SimulateTalkScreen extends StatefulWidget {
  const SimulateTalkScreen({super.key});

  @override
  State<SimulateTalkScreen> createState() => _SimulateTalkScreenState();
}

class _SimulateTalkScreenState extends State<SimulateTalkScreen> {
  String? _selectedPersonId;
  final _chatHistoryController = TextEditingController();

  void _submit(AppProvider provider) {
    if (_selectedPersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a person to simulate.")));
      return;
    }

    final person = provider.chatbotMemory.people.firstWhere((p) => p.id == _selectedPersonId);
    
    provider.journalingActions.simulateTalk(person, _chatHistoryController.text.trim());
    
    // Navigate to Nora
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NoraAiScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final people = provider.chatbotMemory.people;

    if (people.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.fhBgDeepDark,
        appBar: AppBar(title: const Text("COMMS SIMULATOR")),
        body: const Center(child: Text("No People Intel found. Extract from logs first.", style: TextStyle(color: AppTheme.fhTextDisabled))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: Text("COMMS SIMULATOR", style: TextStyle(color: AppTheme.fhAccentOrange)),
        iconTheme: IconThemeData(color: AppTheme.fhAccentOrange),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValorantDropdown<String>(
              label: "SELECT TARGET PERSONA",
              value: _selectedPersonId,
              items: people.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
              onChanged: (val) => setState(() => _selectedPersonId = val),
            ),
            
            const SizedBox(height: 24),
            
            const Text("CONTEXTUAL CHAT HISTORY (OPTIONAL)", style: TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
            const SizedBox(height: 8),
            GrowingTextField(controller: _chatHistoryController, hint: "Paste recent texts/WhatsApp logs here so the AI learns their exact speaking style...", minLines: 6),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ValorantButton(
                label: "INITIALIZE COMMS LINK",
                color: AppTheme.fhAccentOrange,
                onPressed: () => _submit(provider),
              ),
            )
          ],
        ),
      ),
    );
  }
}