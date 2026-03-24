import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/common/growing_text_field.dart';
import 'package:arcane/src/screens/journaling/therapy_report_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class QuickTherapyScreen extends StatefulWidget {
  const QuickTherapyScreen({super.key});

  @override
  State<QuickTherapyScreen> createState() => _QuickTherapyScreenState();
}

class _QuickTherapyScreenState extends State<QuickTherapyScreen> {
  final _reasonController = TextEditingController();
  final _feelingController = TextEditingController();
  final _actionController = TextEditingController();
  bool _requestComms = false;

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
        requestComms: _requestComms,
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
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        title: Text("EMERGENCY THERAPY", style: GoogleFonts.rajdhani(color: JweTheme.accentRed, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: JweTheme.bgBase,
        iconTheme: const IconThemeData(color: JweTheme.accentRed),
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: JweTheme.accentRed.withOpacity(0.1),
                      border: Border.all(color: JweTheme.accentRed, width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(MdiIcons.alertDecagram, color: JweTheme.accentRed, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "RAPID TRIAGE PROTOCOL INITIATED.",
                            style: GoogleFonts.rajdhani(color: JweTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text("SITUATION REPORT", style: TextStyle(color: JweTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
                  const SizedBox(height: 8),
                  GrowingTextField(controller: _reasonController, hint: "Why do you need triage right now?", minLines: 3),
                  
                  const SizedBox(height: 24),
                  
                  const Text("CURRENT STATE", style: TextStyle(color: JweTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
                  const SizedBox(height: 8),
                  GrowingTextField(controller: _feelingController, hint: "How are you feeling?", minLines: 2),

                  const SizedBox(height: 24),

                  const Text("PLANNED ACTION (OPTIONAL)", style: TextStyle(color: JweTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
                  const SizedBox(height: 8),
                  GrowingTextField(controller: _actionController, hint: "What were you planning to do?", minLines: 2),

                  const SizedBox(height: 24),
                  
                  SwitchListTile(
                    title: Text("REQUIRE COMMS ASSISTANCE", style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text("Request AI to scan known allies and provide a conversation strategy.", style: TextStyle(color: JweTheme.textMuted, fontSize: 12)),
                    value: _requestComms,
                    onChanged: (v) => setState(() => _requestComms = v),
                    activeColor: JweTheme.accentCyan,
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: provider.loadingTaskName == "Formulating Strategy..." 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(MdiIcons.shieldSearch, size: 18),
                      label: Text(provider.loadingTaskName == "Formulating Strategy..." ? "PROCESSING..." : "SUBMIT FOR ANALYSIS", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JweTheme.accentRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const BeveledRectangleBorder()
                      ),
                      onPressed: provider.loadingTaskName != null ? null : () => _submit(provider),
                    ),
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