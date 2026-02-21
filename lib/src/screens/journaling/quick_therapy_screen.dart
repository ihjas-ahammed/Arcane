import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/common/growing_text_field.dart';
import 'package:arcane/src/screens/journaling/therapy_report_screen.dart';

class QuickTherapyScreen extends StatefulWidget {
  const QuickTherapyScreen({super.key});

  @override
  State<QuickTherapyScreen> createState() => _QuickTherapyScreenState();
}

class _QuickTherapyScreenState extends State<QuickTherapyScreen> {
  final _reasonController = TextEditingController();
  final _feelingController = TextEditingController();
  final _actionController = TextEditingController();

  Future<void> _submit(AppProvider provider) async {
    if (_reasonController.text.isEmpty || _feelingController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill the critical fields.")));
      return;
    }

    try {
      final result = await provider.journalingActions.runQuickTherapy(
        _reasonController.text,
        _feelingController.text,
        _actionController.text,
      );

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TherapyReportScreen(reportData: result)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Therapy failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("EMERGENCY THERAPY", style: TextStyle(color: AppTheme.fhAccentRed)),
        iconTheme: const IconThemeData(color: AppTheme.fhAccentRed),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SITUATION REPORT", style: TextStyle(color: AppTheme.fhAccentRed, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
            const SizedBox(height: 8),
            GrowingTextField(controller: _reasonController, hint: "Why do you need triage right now?", minLines: 3),
            
            const SizedBox(height: 24),
            
            const Text("CURRENT STATE", style: TextStyle(color: AppTheme.fhAccentRed, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
            const SizedBox(height: 8),
            GrowingTextField(controller: _feelingController, hint: "How are you feeling?", minLines: 2),

            const SizedBox(height: 24),

            const Text("PLANNED ACTION (OPTIONAL)", style: TextStyle(color: AppTheme.fhAccentRed, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
            const SizedBox(height: 8),
            GrowingTextField(controller: _actionController, hint: "What were you planning to do?", minLines: 2),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ValorantButton(
                label: provider.loadingTaskName == "Formulating Strategy..." ? "PROCESSING..." : "SUBMIT FOR ANALYSIS",
                color: AppTheme.fhAccentRed,
                onPressed: provider.loadingTaskName != null ? null : () => _submit(provider),
              ),
            )
          ],
        ),
      ),
    );
  }
}