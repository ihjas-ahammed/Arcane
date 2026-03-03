import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/widgets/dialogs/xp_gain_dialog.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/common/growing_text_field.dart';
import 'package:intl/intl.dart';

class ReflectionEditorScreen extends StatefulWidget {
  final ReflectionLog? initialLog;
  final String dateStr;

  const ReflectionEditorScreen({
    super.key,
    this.initialLog,
    this.dateStr = '',
  });

  @override
  State<ReflectionEditorScreen> createState() => _ReflectionEditorScreenState();
}

class _ReflectionEditorScreenState extends State<ReflectionEditorScreen> {
  late TextEditingController _triggerController;
  late TextEditingController _emotionController;
  late TextEditingController _reasonController;
  late TextEditingController _actionController;
  late DateTime _selectedDateTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _triggerController = TextEditingController(text: widget.initialLog?.trigger ?? '');
    _emotionController = TextEditingController(text: widget.initialLog?.emotion ?? '');
    _reasonController = TextEditingController(text: widget.initialLog?.reason ?? '');
    _actionController = TextEditingController(text: widget.initialLog?.action ?? '');
    
    if (widget.initialLog != null) {
      _selectedDateTime = widget.initialLog!.timestamp;
    } else if (widget.dateStr.isNotEmpty) {
      final parsed = DateTime.tryParse(widget.dateStr) ?? DateTime.now();
      final now = DateTime.now();
      if (parsed.year == now.year && parsed.month == now.month && parsed.day == now.day) {
        _selectedDateTime = now;
      } else {
        _selectedDateTime = DateTime(parsed.year, parsed.month, parsed.day, 12, 0);
      }
    } else {
      _selectedDateTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _triggerController.dispose();
    _emotionController.dispose();
    _reasonController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.fhAccentTeal,
            onPrimary: Colors.black,
            surface: AppTheme.fhBgDark,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null) return;

    if (!mounted) return;
    
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.fhAccentTeal,
            onPrimary: Colors.black,
            surface: AppTheme.fhBgDark,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _saveReflection({bool analyze = true}) async {
    if (_triggerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Situation cannot be empty.")));
      return;
    }

    final appProvider = Provider.of<AppProvider>(context, listen: false);

    if (widget.initialLog != null) {
      // Editing existing log
      appProvider.updateReflectionLog(
        widget.initialLog!.id,
        trigger: _triggerController.text.trim(),
        emotion: _emotionController.text.trim(),
        reason: _reasonController.text.trim(),
        action: _actionController.text.trim(),
      );
      // Currently, date modification for existing logs isn't fully supported in update method,
      // but UI-wise we allow it. For true date change, we'd need to update timestamp in model.
      // To keep it simple, we focus on content updates.
      Navigator.pop(context);
      return;
    }

    // New Log
    if (!analyze) {
      appProvider.quickSaveReflection(
        trigger: _triggerController.text.trim(),
        emotion: _emotionController.text.trim(),
        reason: _reasonController.text.trim(),
        action: _actionController.text.trim(),
        timestamp: _selectedDateTime,
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
          action: _actionController.text.trim(),
          timestamp: _selectedDateTime,
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
                    child: Text("REFLECTION LOG", style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppTheme.fhTextPrimary))
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
                  // DateTime Picker
                  InkWell(
                    onTap: widget.initialLog == null ? _pickDateTime : null, // Prevent edit time for simplicity
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.fhBgDark,
                        border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("LOG TIMESTAMP", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy - HH:mm').format(_selectedDateTime),
                                style: const TextStyle(color: AppTheme.fhTextPrimary, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                          if (widget.initialLog == null)
                            Icon(MdiIcons.calendarClock, color: AppTheme.fhAccentTeal, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader("SITUATION (What happened?)"),
                  GrowingTextField(controller: _triggerController, hint: "Describe the event or situation...", minLines: 2),
                  
                  const SizedBox(height: 20),

                  _buildSectionHeader("CAUSE (Why did it happen?)"),
                  GrowingTextField(controller: _reasonController, hint: "Root cause, context, or triggers...", minLines: 2),

                  const SizedBox(height: 20),
                  
                  _buildSectionHeader("FEELING (How do you feel?)"),
                  GrowingTextField(controller: _emotionController, hint: "Your emotions, physical sensations...", minLines: 2),

                  const SizedBox(height: 20),

                  _buildSectionHeader("ACTION (What will you do?)"),
                  GrowingTextField(controller: _actionController, hint: "Next steps, coping mechanism, or lesson learned...", minLines: 2),

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
                          color: AppTheme.fhAccentTeal,
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
                    // Edit Existing Log Actions
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
                            color: AppTheme.fhAccentTeal,
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
        title.toUpperCase(),
        style: const TextStyle(color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 11),
      ),
    );
  }
}