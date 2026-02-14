import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/widgets/dialogs/xp_gain_dialog.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/common/growing_text_field.dart';

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

  Future<void> _saveReflection({bool analyze = true}) async {
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

    if (widget.initialLog != null) {
      // Editing existing log
      appProvider.updateReflectionLog(
        widget.initialLog!.id,
        trigger: _triggerController.text.trim(),
        emotion: _emotionController.text.trim(),
        reason: _reasonController.text.trim(),
      );
      Navigator.pop(context);
      return;
    }

    // New Log
    if (!analyze) {
      appProvider.quickSaveReflection(
        trigger: _triggerController.text.trim(),
        emotion: _emotionController.text.trim(),
        reason: _reasonController.text.trim(),
        timestamp: timestamp,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Log saved (No analysis).")));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
        final result = await appProvider.processReflection(
          trigger: _triggerController.text.trim(),
          emotion: _emotionController.text.trim(),
          reason: _reasonController.text.trim(),
          timestamp: timestamp,
        );

        final xpGained = result['xpGained'] as Map<String, int>;

        if (mounted) {
          Navigator.pop(context); 
          
          // Show XP Dialog
          await showDialog(
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

  void _deleteLog() {
    if (widget.initialLog == null) return;
    
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgMedium,
        title: const Text("DELETE LOG?", style: TextStyle(color: AppTheme.fhAccentRed, fontWeight: FontWeight.bold)),
        content: const Text("This action cannot be undone. XP gained from this reflection will be removed."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed),
            onPressed: () {
              appProvider.deleteReflectionLog(widget.initialLog!.id);
              Navigator.pop(ctx); 
              Navigator.pop(context); 
            },
            child: const Text("DELETE")
          )
        ],
      )
    );
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
                  const Expanded(
                    child: Text("DEBRIEF", style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppTheme.fhTextPrimary))
                  ),
                  if (widget.initialLog != null)
                    IconButton(
                      icon: Icon(MdiIcons.deleteOutline, color: AppTheme.fhAccentRed),
                      onPressed: _deleteLog,
                      tooltip: "Delete Log",
                    )
                ],
              ),
            ),

            // Editor Area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildSectionHeader("SITUATION"),
                  GrowingTextField(controller: _triggerController, hint: "What triggered this event?", minLines: 2),
                  
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader("FEELING"),
                  GrowingTextField(controller: _emotionController, hint: "Emotion felt...", minLines: 1),

                  const SizedBox(height: 24),

                  _buildSectionHeader("CAUSE"),
                  GrowingTextField(controller: _reasonController, hint: "Why did this happen? Root cause...", minLines: 3),

                  const SizedBox(height: 40),

                  // Actions
                  if (widget.initialLog == null) ...[
                    // New Log Actions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ValorantButton(
                          label: _isLoading ? "ANALYZING..." : "ANALYZE & SAVE",
                          isPrimary: true,
                          onPressed: _isLoading ? null : () => _saveReflection(analyze: true),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ValorantButton(
                                label: "ABORT",
                                isPrimary: false,
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextButton(
                                onPressed: _isLoading ? null : () => _saveReflection(analyze: false),
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                                child: const Text("QUICK SAVE (NO AI)", style: TextStyle(color: AppTheme.fhTextSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ],
                        )
                      ],
                    )
                  ] else ...[
                    // Edit Existing Log Actions (Simpler)
                    Row(
                      children: [
                        Expanded(
                          child: ValorantButton(
                            label: "CANCEL",
                            isPrimary: false,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ValorantButton(
                            label: "UPDATE",
                            isPrimary: true,
                            onPressed: () => _saveReflection(analyze: false),
                          ),
                        ),
                      ],
                    )
                  ]
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
}