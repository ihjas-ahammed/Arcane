import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/widgets/dialogs/xp_gain_dialog.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';

class ReflectionEditorScreen extends StatefulWidget {
  final ReflectionLog? initialLog;
  final String dateStr;

  const ReflectionEditorScreen({
    super.key,
    this.initialLog,
    required this.dateStr,
  });

  @override
  State<ReflectionEditorScreen> createState() => _ReflectionEditorScreenState();
}

class _ReflectionEditorScreenState extends State<ReflectionEditorScreen> {
  late TextEditingController _triggerController;
  late TextEditingController _emotionController;
  late TextEditingController _reasonController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _triggerController = TextEditingController(text: widget.initialLog?.trigger ?? '');
    _emotionController = TextEditingController(text: widget.initialLog?.emotion ?? '');
    _reasonController = TextEditingController(text: widget.initialLog?.reason ?? '');
  }

  @override
  void dispose() {
    _triggerController.dispose();
    _emotionController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _saveReflection() async {
    if (_triggerController.text.trim().isEmpty) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final targetDate = DateTime.parse(widget.dateStr);
    final now = DateTime.now();
    DateTime timestamp;

    if (targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day) {
      timestamp = now;
    } else {
      timestamp = DateTime(targetDate.year, targetDate.month, targetDate.day, 12, 0);
    }

    setState(() => _isLoading = true);
    
    // ... (Existing save logic) ...
    try {
        final xpGained = await appProvider.processReflection(
          trigger: _triggerController.text.trim(),
          emotion: _emotionController.text.trim(),
          reason: _reasonController.text.trim(),
          timestamp: timestamp,
        );

        if (mounted) {
          Navigator.pop(context); 
          showDialog(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.8),
            builder: (ctx) => XpGainDialog(xpGained: xpGained),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: AppTheme.fhTextPrimary),
                  ),
                  const SizedBox(width: 8),
                  const Text("DEBRIEF", style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppTheme.fhTextPrimary)),
                ],
              ),
            ),

            // Editor Area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildSectionHeader("SITUATION"),
                  _buildValorantInput(_triggerController, "What triggered this event?", 2),
                  
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader("FEELING"),
                  _buildValorantInput(_emotionController, "Emotion felt...", 1),

                  const SizedBox(height: 24),

                  _buildSectionHeader("CAUSE"),
                  _buildValorantInput(_reasonController, "Why did this happen? Root cause...", 5),

                  const SizedBox(height: 40),

                  Row(
                    children: [
                      Expanded(
                        child: ValorantButton(
                          label: "ABORT",
                          isPrimary: false,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ValorantButton(
                          label: _isLoading ? "PROCESSING..." : "CONFIRM",
                          isPrimary: true,
                          onPressed: _isLoading ? null : _saveReflection,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        title,
        style: const TextStyle(color: AppTheme.fhAccentRed, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
      ),
    );
  }

  Widget _buildValorantInput(TextEditingController controller, String hint, int lines) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark.withValues(alpha: 0.5),
        border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.5)),
        // No rounded corners
      ),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        maxLines: lines,
        style: const TextStyle(color: AppTheme.fhTextPrimary, height: 1.5),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.fhTextDisabled),
          contentPadding: EdgeInsets.zero,
          filled: false,
        ),
      ),
    );
  }
}