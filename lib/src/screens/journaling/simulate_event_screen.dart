import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:missions/src/widgets/common/growing_text_field.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SimulateEventScreen extends StatefulWidget {
  const SimulateEventScreen({super.key});

  @override
  State<SimulateEventScreen> createState() => _SimulateEventScreenState();
}

class _SimulateEventScreenState extends State<SimulateEventScreen> {
  final _inputController = TextEditingController();
  String? _result;

  Future<void> _submit(AppProvider provider) async {
    if (_inputController.text.trim().isEmpty) return;

    try {
      final sim = await provider.journalingActions.simulateEvent(_inputController.text.trim());
      if (mounted) {
        setState(() => _result = sim);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("SITUATION SIMULATOR", style: TextStyle(color: AppTheme.fhAccentPurple)),
        iconTheme: const IconThemeData(color: AppTheme.fhAccentPurple),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SCENARIO PARAMETERS", style: TextStyle(color: AppTheme.fhAccentPurple, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
            const SizedBox(height: 8),
            GrowingTextField(controller: _inputController, hint: "Describe the future event you want to simulate...", minLines: 3),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ValorantButton(
                label: provider.loadingTaskName == "Simulating Event..." ? "PROCESSING..." : "RUN SIMULATION",
                color: AppTheme.fhAccentPurple,
                onPressed: provider.loadingTaskName != null ? null : () => _submit(provider),
              ),
            ),

            if (_result != null) ...[
              const SizedBox(height: 40),
              Row(
                children: [
                  Icon(MdiIcons.eyeSettingsOutline, color: AppTheme.fhAccentPurple),
                  const SizedBox(width: 8),
                  const Text("SIMULATION RESULTS", style: TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDark,
                  border: Border(left: BorderSide(color: AppTheme.fhAccentPurple, width: 3)),
                ),
                child: Text(_result!, style: const TextStyle(color: AppTheme.fhTextPrimary, height: 1.5, fontSize: 14)),
              )
            ]
          ],
        ),
      ),
    );
  }
}