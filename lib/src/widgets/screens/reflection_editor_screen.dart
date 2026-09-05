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

class FoodLogEntry {
  final TextEditingController nameController;
  final TextEditingController amountController;

  FoodLogEntry({String name = '', String amount = ''})
      : nameController = TextEditingController(text: name),
        amountController = TextEditingController(text: amount);

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }

  bool get isNotEmpty =>
      nameController.text.trim().isNotEmpty || amountController.text.trim().isNotEmpty;
}

class _ReflectionEditorScreenState extends State<ReflectionEditorScreen> {
  late TextEditingController _triggerController;
  late TextEditingController _emotionController;
  late TextEditingController _reasonController;
  late TextEditingController _actionController;
  late TextEditingController _wholeWritingController;
  final List<FoodLogEntry> _foodEntries = [];
  late DateTime _selectedDateTime;
  bool _isWholeWriting = false;

  @override
  void initState() {
    super.initState();

    _wholeWritingController = TextEditingController();
    _foodEntries.add(FoodLogEntry());

    // If editing an existing log, populate from log
    if (widget.initialLog != null) {
      _triggerController = TextEditingController(text: widget.initialLog!.trigger);
      _emotionController = TextEditingController(text: widget.initialLog!.emotion);
      _reasonController = TextEditingController(text: widget.initialLog!.reason);
      _actionController = TextEditingController(text: widget.initialLog!.action);
      _selectedDateTime = widget.initialLog!.timestamp;

      // If emotion, reason, and action are empty, open in Whole Writing mode
      if (widget.initialLog!.emotion.isEmpty && widget.initialLog!.reason.isEmpty && widget.initialLog!.action.isEmpty) {
        _isWholeWriting = true;
        _wholeWritingController.text = widget.initialLog!.trigger;
      }
      return;
    }

    // New log: try to restore from draft
    final draft = _getDraft();
    _triggerController = TextEditingController(text: draft?.trigger ?? '');
    _emotionController = TextEditingController(text: draft?.emotion ?? '');
    _reasonController = TextEditingController(text: draft?.reason ?? '');
    _actionController = TextEditingController(text: draft?.action ?? '');

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

  bool get _hasContent =>
      _wholeWritingController.text.trim().isNotEmpty ||
      _foodEntries.any((e) => e.isNotEmpty) ||
      _triggerController.text.trim().isNotEmpty ||
      _emotionController.text.trim().isNotEmpty ||
      _reasonController.text.trim().isNotEmpty ||
      _actionController.text.trim().isNotEmpty;

  void _saveDraft() {
    if (widget.initialLog != null) return; // never draft when editing
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (_hasContent) {
      provider.saveReflectionDraft(
        trigger: _isWholeWriting ? _wholeWritingController.text.trim() : _triggerController.text.trim(),
        emotion: _emotionController.text.trim(),
        reason: _reasonController.text.trim(),
        action: _actionController.text.trim(),
      );
    }
  }

  @override
  void dispose() {
    _triggerController.dispose();
    _emotionController.dispose();
    _reasonController.dispose();
    _actionController.dispose();
    _wholeWritingController.dispose();
    for (final entry in _foodEntries) {
      entry.dispose();
    }
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
    final triggerText = _isWholeWriting
        ? _wholeWritingController.text.trim()
        : _triggerController.text.trim();

    final validFoodEntries = _foodEntries
        .where((e) => e.nameController.text.trim().isNotEmpty)
        .map((e) => {
              'name': e.nameController.text.trim(),
              'amount': e.amountController.text.trim(),
            })
        .toList();

    if (triggerText.isEmpty && validFoodEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please write your reflection or food items before saving.")),
      );
      return;
    }

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDateTime);

    // If food details were entered, automatically analyze & log nutrition to bio
    if (validFoodEntries.isNotEmpty) {
      appProvider.logNutritionFromStructuredItems(dateStr, validFoodEntries);
    }

    // If only food details were entered (no reflection text), pop with notification
    if (triggerText.isEmpty) {
      appProvider.clearReflectionDraft();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Nutrition items logged to Bio & Health Dashboard!"),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    if (widget.initialLog != null) {
      appProvider.updateReflectionLog(
        widget.initialLog!.id,
        trigger: triggerText,
        emotion: _isWholeWriting ? '' : _emotionController.text.trim(),
        reason: _isWholeWriting ? '' : _reasonController.text.trim(),
        action: _isWholeWriting ? '' : _actionController.text.trim(),
      );
      Navigator.pop(context);
      return;
    }

    if (!analyze) {
      appProvider.startReflectionAnalysis(
        trigger: triggerText,
        emotion: _isWholeWriting ? '' : _emotionController.text.trim(),
        reason: _isWholeWriting ? '' : _reasonController.text.trim(),
        action: _isWholeWriting ? '' : _actionController.text.trim(),
        timestamp: _selectedDateTime,
      );
      appProvider.clearReflectionDraft();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Log saved locally.")));
      return;
    }

    // Fire-and-forget background AI analysis
    appProvider.startReflectionAnalysis(
      trigger: triggerText,
      emotion: _isWholeWriting ? '' : _emotionController.text.trim(),
      reason: _isWholeWriting ? '' : _reasonController.text.trim(),
      action: _isWholeWriting ? '' : _actionController.text.trim(),
      timestamp: _selectedDateTime,
    );

    appProvider.clearReflectionDraft();

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Reflection & Nutrition logged. Processing in background…"),
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
        content:   Text(
          "This action cannot be undone. XP gained from this reflection will be removed.",
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

                    // Mode Switcher (Guided Form vs Whole Writing)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isWholeWriting = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: !_isWholeWriting ? SpideyTheme.spideyCyan.withValues(alpha: 0.2) : SpideyTheme.bgPanel,
                                border: Border.all(color: !_isWholeWriting ? SpideyTheme.spideyCyan : SpideyTheme.border),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                "GUIDED FORM",
                                style: GoogleFonts.rajdhani(
                                  color: !_isWholeWriting ? SpideyTheme.spideyCyan : SpideyTheme.textGrey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isWholeWriting = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _isWholeWriting ? SpideyTheme.spideyCyan.withValues(alpha: 0.2) : SpideyTheme.bgPanel,
                                border: Border.all(color: _isWholeWriting ? SpideyTheme.spideyCyan : SpideyTheme.border),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                "WHOLE WRITING",
                                style: GoogleFonts.rajdhani(
                                  color: _isWholeWriting ? SpideyTheme.spideyCyan : SpideyTheme.textGrey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Form Fields based on Mode
                    if (_isWholeWriting) ...[
                      _buildSectionHeader("FULL REFLECTION (Freeform Whole Writing)"),
                      GrowingTextField(
                        controller: _wholeWritingController,
                        hint: "Write your reflection freely here without answering separate questions...",
                        minLines: 5,
                      ),
                    ] else ...[
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
                    ],

                    const SizedBox(height: 24),
                    Divider(color: SpideyTheme.border, height: 1),
                    const SizedBox(height: 20),

                    // Food / Nutrition Log Box in Both Modes (Structured List View)
                    Row(
                      children: [
                        Icon(MdiIcons.silverwareForkKnife, size: 14, color: JweTheme.accentAmber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildSectionHeader("NUTRITION / WHAT DID YOU EAT TODAY? (OPTIONAL)"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._foodEntries.asMap().entries.map((entry) => _buildFoodItemRow(entry.key, entry.value)),
                    const SizedBox(height: 6),
                    _buildAddFoodItemButton(),

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

  Widget _buildFoodItemRow(int index, FoodLogEntry entry) {
    final isLight = JweTheme.isLight;
    final borderCol = isLight ? Colors.black12 : JweTheme.border.withValues(alpha: 0.35);
    final bgCol = isLight ? const Color(0xFFF1EFE8) : const Color(0xFF10131B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: JweTheme.accentAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${index + 1}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: JweTheme.accentAmber,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: entry.nameController,
              style: GoogleFonts.inter(
                color: isLight ? const Color(0xFF1E293B) : Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                hintText: "Item name (e.g. Eggs)",
                hintStyle: GoogleFonts.inter(
                  color: isLight ? Colors.black38 : Colors.white38,
                  fontSize: 11.5,
                ),
                filled: true,
                fillColor: isLight ? Colors.white : const Color(0xFF161A26),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: borderCol),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: borderCol),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: JweTheme.accentAmber),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: entry.amountController,
              style: GoogleFonts.inter(
                color: isLight ? const Color(0xFF1E293B) : Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                hintText: "Amount (e.g. 2 pcs)",
                hintStyle: GoogleFonts.inter(
                  color: isLight ? Colors.black38 : Colors.white38,
                  fontSize: 11,
                ),
                filled: true,
                fillColor: isLight ? Colors.white : const Color(0xFF161A26),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: borderCol),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: borderCol),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: JweTheme.accentAmber),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: JweTheme.accentRed.withValues(alpha: 0.8)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Remove item',
            onPressed: () {
              setState(() {
                if (_foodEntries.length > 1) {
                  final removed = _foodEntries.removeAt(index);
                  removed.dispose();
                } else {
                  _foodEntries[0].nameController.clear();
                  _foodEntries[0].amountController.clear();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddFoodItemButton() {
    final isLight = JweTheme.isLight;
    return InkWell(
      onTap: () {
        setState(() {
          _foodEntries.add(FoodLogEntry());
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(6),
          color: JweTheme.accentAmber.withValues(alpha: isLight ? 0.08 : 0.12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 15, color: JweTheme.accentAmber),
            const SizedBox(width: 6),
            Text(
              "+ ADD FOOD ITEM",
              style: GoogleFonts.orbitron(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: JweTheme.accentAmber,
              ),
            ),
          ],
        ),
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
