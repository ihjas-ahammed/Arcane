import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/tracked_skill_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class AddEditSkillLogDialog extends StatefulWidget {
  final String skillId;
  final String skillName;
  final String unit;
  final SkillTrainingLog? initialLog;

  const AddEditSkillLogDialog({
    super.key,
    required this.skillId,
    required this.skillName,
    required this.unit,
    this.initialLog,
  });

  static Future<void> show(
    BuildContext context, {
    required String skillId,
    required String skillName,
    required String unit,
    SkillTrainingLog? initialLog,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => AddEditSkillLogDialog(
        skillId: skillId,
        skillName: skillName,
        unit: unit,
        initialLog: initialLog,
      ),
    );
  }

  @override
  State<AddEditSkillLogDialog> createState() => _AddEditSkillLogDialogState();
}

class _AddEditSkillLogDialogState extends State<AddEditSkillLogDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _modeController;
  late TextEditingController _valueController;
  late TextEditingController _deltaController;
  late TextEditingController _durationMinutesController;
  late TextEditingController _notesController;

  late DateTime _selectedDateTime;
  late String _resultType;

  final List<String> _resultTypes = [
    'WIN',
    'LOSS',
    'DRAW',
    'PASS',
    'FAIL',
    'COMPLETED',
  ];

  @override
  void initState() {
    super.initState();
    final log = widget.initialLog;
    _modeController = TextEditingController(text: log?.mode ?? 'STANDARD');
    _valueController = TextEditingController(
        text: log != null ? (log.value == log.value.roundToDouble() ? log.value.toInt().toString() : log.value.toString()) : '');
    _deltaController = TextEditingController(
        text: log?.delta != null
            ? (log!.delta! > 0 ? '+${log.delta!.toInt()}' : log.delta!.toInt().toString())
            : '');
    _durationMinutesController = TextEditingController(
        text: log != null && log.durationSeconds > 0 ? (log.durationSeconds ~/ 60).toString() : '20');
    _notesController = TextEditingController(text: log?.notes ?? '');

    _selectedDateTime = log?.timestamp ?? DateTime.now();
    _resultType = log?.resultType ?? 'WIN';
  }

  @override
  void dispose() {
    _modeController.dispose();
    _valueController.dispose();
    _deltaController.dispose();
    _durationMinutesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: JweTheme.pickerScheme(accent: JweTheme.accentAmber),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: JweTheme.pickerScheme(accent: JweTheme.accentAmber),
        ),
        child: child!,
      ),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final val = double.tryParse(_valueController.text.trim()) ?? 0.0;
    
    // Parse delta
    final deltaText = _deltaController.text.replaceAll('+', '').trim();
    final delta = double.tryParse(deltaText);

    final durationMins = int.tryParse(_durationMinutesController.text.trim()) ?? 0;

    if (widget.initialLog != null) {
      final updated = widget.initialLog!.copyWith(
        timestamp: _selectedDateTime,
        mode: _modeController.text.trim().toUpperCase(),
        value: val,
        delta: delta,
        resultType: _resultType,
        durationSeconds: durationMins * 60,
        notes: _notesController.text.trim(),
      );
      appProvider.updateSkillTrainingLog(widget.skillId, updated);
    } else {
      final newLog = SkillTrainingLog(
        timestamp: _selectedDateTime,
        mode: _modeController.text.trim().toUpperCase(),
        value: val,
        delta: delta,
        resultType: _resultType,
        durationSeconds: durationMins * 60,
        notes: _notesController.text.trim(),
      );
      appProvider.addSkillTrainingLog(widget.skillId, newLog);
    }

    Navigator.pop(context);
  }

  void _delete() {
    if (widget.initialLog == null) return;
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    appProvider.deleteSkillTrainingLog(widget.skillId, widget.initialLog!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = JweTheme.accentAmber;
    final isEditing = widget.initialLog != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: JweTheme.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: JweTheme.lineSoft)),
                ),
                child: Row(
                  children: [
                    Container(width: 4, height: 16, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'EDIT TRAINING LOG' : 'LOG TRAINING SESSION',
                            style: GoogleFonts.rajdhani(
                              color: JweTheme.textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            widget.skillName.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Form Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timestamp Picker Row
                        InkWell(
                          onTap: _pickDateTime,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: JweTheme.bgBase,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: JweTheme.border),
                            ),
                            child: Row(
                              children: [
                                Icon(MdiIcons.calendarClock, size: 18, color: accent),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('dd MMM yyyy · HH:mm').format(_selectedDateTime).toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.edit, size: 14, color: JweTheme.textMuted),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Mode & Result Type Row
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildField(
                                controller: _modeController,
                                label: 'MODE / FORMAT *',
                                hint: 'e.g. BLITZ 5+0, UNBROKEN',
                                validator: (val) => val == null || val.trim().isEmpty ? 'Mode required' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'OUTCOME',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.textMuted,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: JweTheme.bgBase,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: JweTheme.border),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _resultType,
                                        isExpanded: true,
                                        dropdownColor: JweTheme.panel,
                                        style: GoogleFonts.jetBrainsMono(
                                          color: _resultType == 'WIN' || _resultType == 'PASS'
                                              ? JweTheme.accentCyan
                                              : (_resultType == 'LOSS' || _resultType == 'FAIL'
                                                  ? JweTheme.accentRed
                                                  : JweTheme.textWhite),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        items: _resultTypes.map((r) {
                                          return DropdownMenuItem<String>(
                                            value: r,
                                            child: Text(r),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _resultType = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Score / Value & Delta & Duration Row
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildField(
                                controller: _valueController,
                                label: 'RATING / SCORE *',
                                hint: '1350',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Score required' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: _buildField(
                                controller: _deltaController,
                                label: 'DELTA (+/-)',
                                hint: '+18, -6',
                                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: _buildField(
                                controller: _durationMinutesController,
                                label: 'TIME (MINS)',
                                hint: '20',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Session Notes
                        _buildField(
                          controller: _notesController,
                          label: 'SESSION NOTES / REFLECTION (OPTIONAL)',
                          hint: 'Techniques used, errors made, tactical breakthroughs...',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: JweTheme.lineSoft)),
                ),
                child: Row(
                  children: [
                    if (isEditing)
                      IconButton(
                        onPressed: _delete,
                        icon: Icon(MdiIcons.trashCanOutline, color: JweTheme.accentRed, size: 20),
                        tooltip: 'Delete Log',
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'CANCEL',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: JweTheme.onAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(
                        isEditing ? 'UPDATE LOG' : 'RECORD LOG',
                        style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.4,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: JweTheme.textMuted.withValues(alpha: 0.5), fontSize: 11),
            filled: true,
            fillColor: JweTheme.bgBase,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: JweTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: JweTheme.accentRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: JweTheme.accentRed, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
