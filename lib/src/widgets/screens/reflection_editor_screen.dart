import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/spidey_theme.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/models/health_models.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/widgets/common/growing_text_field.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/app_state_models.dart';

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
  double _energyLevel = 5;

  @override
  void initState() {
    super.initState();

    // If editing an existing log, always populate from the log
    if (widget.initialLog != null) {
      _triggerController = TextEditingController(text: widget.initialLog!.trigger);
      _emotionController = TextEditingController(text: widget.initialLog!.emotion);
      _reasonController = TextEditingController(text: widget.initialLog!.reason);
      _actionController = TextEditingController(text: widget.initialLog!.action);
      _selectedDateTime = widget.initialLog!.timestamp;
      return;
    }

    // New log: try to restore from draft
    final draft = _getDraft();
    _triggerController = TextEditingController(text: draft?.trigger ?? '');
    _emotionController = TextEditingController(text: draft?.emotion ?? '');
    _reasonController = TextEditingController(text: draft?.reason ?? '');
    _actionController = TextEditingController(text: draft?.action ?? '');
    if (draft != null) _energyLevel = draft.energyLevel;

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
    // Must be called after initState (use addPostFrameCallback if needed)
    // Safe here because initState fires after the element tree is built for
    // stateful widgets pushed via Navigator.
    try {
      return Provider.of<AppProvider>(context, listen: false).settings.reflectionDraft;
    } catch (_) {
      return null;
    }
  }

  bool get _hasContent =>
      _triggerController.text.trim().isNotEmpty ||
      _emotionController.text.trim().isNotEmpty ||
      _reasonController.text.trim().isNotEmpty ||
      _actionController.text.trim().isNotEmpty;

  void _saveDraft() {
    if (widget.initialLog != null) return; // never draft when editing
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (_hasContent) {
      provider.saveReflectionDraft(
        trigger: _triggerController.text.trim(),
        emotion: _emotionController.text.trim(),
        reason: _reasonController.text.trim(),
        action: _actionController.text.trim(),
        energyLevel: _energyLevel,
      );
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
            primary: SpideyTheme.spideyCyan,
            onPrimary: Colors.black,
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
          colorScheme: const ColorScheme.dark(
            primary: SpideyTheme.spideyCyan,
            onPrimary: Colors.black,
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

  void _logEnergy(AppProvider provider) {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDateTime);
    provider.addEnergyLog(
      dateKey,
      EnergyLog(
        id: const Uuid().v4(),
        level: _energyLevel.round(),
        timestamp: _selectedDateTime,
      ),
    );
  }

  Future<void> _saveReflection({bool analyze = true}) async {
    if (_triggerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Situation cannot be empty.")));
      return;
    }

    final appProvider = Provider.of<AppProvider>(context, listen: false);

    if (widget.initialLog != null) {
      appProvider.updateReflectionLog(
        widget.initialLog!.id,
        trigger: _triggerController.text.trim(),
        emotion: _emotionController.text.trim(),
        reason: _reasonController.text.trim(),
        action: _actionController.text.trim(),
      );
      Navigator.pop(context);
      return;
    }

    _logEnergy(appProvider);

    if (!analyze) {
      appProvider.startReflectionAnalysis(
        trigger: _triggerController.text.trim(),
        emotion: _emotionController.text.trim(),
        reason: _reasonController.text.trim(),
        action: _actionController.text.trim(),
        timestamp: _selectedDateTime,
      );
      appProvider.clearReflectionDraft();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Log saved locally.")));
      return;
    }

    // Fire-and-forget: kick off AI in the background; the root-level
    // InsightWatcher will show the dialog when analysis completes.
    appProvider.startReflectionAnalysis(
      trigger: _triggerController.text.trim(),
      emotion: _emotionController.text.trim(),
      reason: _reasonController.text.trim(),
      action: _actionController.text.trim(),
      timestamp: _selectedDateTime,
    );

    appProvider.clearReflectionDraft();

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Reflection logged. Analyzing in background…"),
      duration: Duration(seconds: 2),
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
        content: const Text(
          "This action cannot be undone. XP gained from this reflection will be removed.",
          style: TextStyle(color: SpideyTheme.textGrey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: SpideyTheme.textGrey))),
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

  Color _energyColor(double v) {
    if (v <= 3) return SpideyTheme.spideyRed;
    if (v <= 6) return SpideyTheme.spideyGold;
    return SpideyTheme.spideyCyan;
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
        decoration: const BoxDecoration(gradient: SpideyTheme.backdropGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
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
                      icon: const Icon(Icons.arrow_back, color: SpideyTheme.textWhite),
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
                                    style: const TextStyle(
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
                    const SizedBox(height: 20),

                    if (widget.initialLog == null) ...[
                      _buildEnergySlider(),
                      const SizedBox(height: 20),
                    ],

                    _buildSectionHeader("SITUATION (What happened?)"),
                    GrowingTextField(controller: _triggerController, hint: "Describe the event or situation...", minLines: 2),

                    const SizedBox(height: 18),
                    _buildSectionHeader("CAUSE (Why did it happen?)"),
                    GrowingTextField(controller: _reasonController, hint: "Root cause, context, or triggers...", minLines: 2),

                    const SizedBox(height: 18),
                    _buildSectionHeader("FEELING (How do you feel?)"),
                    GrowingTextField(controller: _emotionController, hint: "Your emotions, physical sensations...", minLines: 2),

                    const SizedBox(height: 18),
                    _buildSectionHeader("ACTION (What will you do?)"),
                    GrowingTextField(controller: _actionController, hint: "Next steps, coping mechanism, or lesson learned...", minLines: 2),

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
                              child: const Text("QUICK SAVE (NO AI)",
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
          Text(title.toUpperCase(),
              style: GoogleFonts.rajdhani(
                  color: SpideyTheme.spideyCyan,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEnergySlider() {
    final color = _energyColor(_energyLevel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: SpideyTheme.bgPanel,
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(MdiIcons.lightningBolt, color: color, size: 18),
                  const SizedBox(width: 8),
                  Text("ENERGY LEVEL",
                      style: GoogleFonts.rajdhani(
                          color: color, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
                ],
              ),
              Text("${_energyLevel.round()} / 10",
                  style: GoogleFonts.rajdhani(
                      color: color, fontWeight: FontWeight.bold, fontSize: 22)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.15),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _energyLevel,
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) => setState(() => _energyLevel = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("DRAINED", style: TextStyle(color: SpideyTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
              Text("CHARGED", style: TextStyle(color: SpideyTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
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
