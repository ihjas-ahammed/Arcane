import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/spidey_theme.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/widgets/common/growing_text_field.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

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

/// Older reflections were written as separate situation / cause / feeling / action boxes. The
/// editor is now a single input, so those parts are folded into one text when such a log is opened.
String _singleText(String trigger, String reason, String emotion, String action) {
  final parts = <String>[
    if (trigger.trim().isNotEmpty) trigger.trim(),
    if (reason.trim().isNotEmpty) 'Cause: ${reason.trim()}',
    if (emotion.trim().isNotEmpty) 'Feeling: ${emotion.trim()}',
    if (action.trim().isNotEmpty) 'Action: ${action.trim()}',
  ];
  return parts.join('\n\n');
}

class _ReflectionEditorScreenState extends State<ReflectionEditorScreen> {
  late TextEditingController _textController;
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();

    // If editing an existing log, populate from log
    final log = widget.initialLog;
    if (log != null) {
      _textController = TextEditingController(text: _singleText(log.trigger, log.reason, log.emotion, log.action));
      _selectedDateTime = log.timestamp;
      return;
    }

    // New log: try to restore from draft
    final draft = _getDraft();
    _textController = TextEditingController(
      text: draft == null ? '' : _singleText(draft.trigger, draft.reason, draft.emotion, draft.action),
    );

    if (widget.dateStr.isNotEmpty) {
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

  ReflectionDraft? _getDraft() {
    try {
      return Provider.of<AppProvider>(context, listen: false).settings.reflectionDraft;
    } catch (_) {
      return null;
    }
  }

  bool get _hasContent => _textController.text.trim().isNotEmpty;

  void _saveDraft() {
    if (widget.initialLog != null) return; // never draft when editing
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (_hasContent) {
      provider.saveReflectionDraft(
        trigger: _textController.text.trim(),
        emotion: '',
        reason: '',
        action: '',
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
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
          colorScheme: ColorScheme.dark(
            primary: SpideyTheme.spideyCyan,
            onPrimary: JweTheme.onAccent,
            surface: SpideyTheme.bgPanel,
            onSurface: SpideyTheme.textWhite,
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
          colorScheme: ColorScheme.dark(
            primary: SpideyTheme.spideyCyan,
            onPrimary: JweTheme.onAccent,
            surface: SpideyTheme.bgPanel,
            onSurface: SpideyTheme.textWhite,
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
    final text = _textController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please write your reflection before saving.")),
      );
      return;
    }

    final appProvider = Provider.of<AppProvider>(context, listen: false);

    if (widget.initialLog != null) {
      appProvider.updateReflectionLog(
        widget.initialLog!.id,
        trigger: text,
        emotion: '',
        reason: '',
        action: '',
      );
      Navigator.pop(context);
      return;
    }

    // Fire-and-forget background AI analysis (the log itself is saved immediately either way).
    appProvider.startReflectionAnalysis(
      trigger: text,
      emotion: '',
      reason: '',
      action: '',
      timestamp: _selectedDateTime,
    );
    appProvider.clearReflectionDraft();

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(analyze ? "Reflection logged. Processing in background…" : "Log saved locally."),
      duration: const Duration(seconds: 2),
    ));
  }

  void _deleteLog() {
    if (widget.initialLog == null) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpideyTheme.bgPanel,
        title: Text("DELETE LOG?",
            style: GoogleFonts.rajdhani(color: SpideyTheme.spideyRed, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        content:   Text(
          "This action cannot be undone. Its wellbeing impact will be removed too.",
          style: TextStyle(color: SpideyTheme.textGrey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child:  Text("CANCEL", style: TextStyle(color: SpideyTheme.textGrey))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: SpideyTheme.spideyRed, foregroundColor: Colors.white),
              onPressed: () {
                appProvider.deleteReflectionLog(widget.initialLog!.id);
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text("DELETE"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _saveDraft();
        Navigator.of(context).pop();
      },
      child: Scaffold(
      body: Container(
        decoration:  BoxDecoration(gradient: SpideyTheme.backdropGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration:   BoxDecoration(
                  border: Border(bottom: BorderSide(color: SpideyTheme.border)),
                ),
                child: Row(
                  children: [
                    Container(width: 4, height: 24, color: SpideyTheme.spideyRed),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        _saveDraft();
                        Navigator.pop(context);
                      },
                      icon:  Icon(Icons.arrow_back, color: SpideyTheme.textWhite),
                    ),
                    Expanded(
                      child: Text("REFLECTION LOG",
                          style: GoogleFonts.rajdhani(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              color: SpideyTheme.textWhite))),
                    if (widget.initialLog != null)
                      IconButton(
                        icon: Icon(MdiIcons.deleteOutline, color: SpideyTheme.spideyRed),
                        onPressed: _deleteLog,
                        tooltip: "Delete Log",
                      ),
                  ],
                ),
              ),

              // Editor
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Timestamp
                    InkWell(
                      onTap: widget.initialLog == null ? _pickDateTime : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: SpideyTheme.bgPanel,
                          border: Border.all(color: SpideyTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("LOG TIMESTAMP",
                                    style: GoogleFonts.rajdhani(
                                        color: SpideyTheme.spideyCyan,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5)),
                                const SizedBox(height: 4),
                                Text(DateFormat('MMM dd, yyyy - HH:mm').format(_selectedDateTime),
                                    style:   TextStyle(
                                        color: SpideyTheme.textWhite,
                                        fontFamily: 'RobotoMono',
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (widget.initialLog == null)
                              Icon(MdiIcons.calendarClock, color: SpideyTheme.spideyCyan, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _buildSectionHeader("REFLECTION"),
                    GrowingTextField(
                      controller: _textController,
                      hint: "Write your reflection freely: what happened, why, how you feel, what you'll do...",
                      minLines: 6,
                    ),

                    const SizedBox(height: 32),

                    if (widget.initialLog == null) ...[
                      _SpideyActionButton(
                        label: "ANALYZE & SAVE",
                        primary: true,
                        onPressed: () => _saveReflection(analyze: true),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _SpideyActionButton(
                              label: "ABORT",
                              primary: false,
                              onPressed: () {
                                _saveDraft();
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextButton(
                              onPressed: () => _saveReflection(analyze: false),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                              child:   Text("QUICK SAVE (NO AI)",
                                  style: TextStyle(color: SpideyTheme.textGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _SpideyActionButton(
                              label: "CANCEL",
                              primary: false,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SpideyActionButton(
                              label: "UPDATE",
                              primary: true,
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
      ),
    ), // Scaffold
    ); // PopScope
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 2),
      child: Row(
        children: [
          Container(width: 3, height: 12, color: SpideyTheme.spideyRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: GoogleFonts.rajdhani(
                color: SpideyTheme.spideyCyan,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpideyActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  const _SpideyActionButton({required this.label, required this.onPressed, this.primary = true});

  @override
  Widget build(BuildContext context) {
    final bg = primary ? SpideyTheme.spideyRed : Colors.transparent;
    final border = primary ? SpideyTheme.spideyRed : SpideyTheme.spideyCyan;
    final fg = primary ? Colors.white : SpideyTheme.spideyCyan;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: BeveledRectangleBorder(
          side: BorderSide(color: border, width: 1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
      ),
      child: Text(label.toUpperCase(),
          style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.8, fontSize: 14)),
    );
  }
}
