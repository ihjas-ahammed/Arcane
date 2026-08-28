import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/tracked_skill_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/skills/skill_icon_helper.dart';

class AddEditSkillDialog extends StatefulWidget {
  final TrackedSkill? initialSkill;

  const AddEditSkillDialog({super.key, this.initialSkill});

  static Future<void> show(BuildContext context, {TrackedSkill? initialSkill}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => AddEditSkillDialog(initialSkill: initialSkill),
    );
  }

  @override
  State<AddEditSkillDialog> createState() => _AddEditSkillDialogState();
}

class _AddEditSkillDialogState extends State<AddEditSkillDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _subtitleController;
  late TextEditingController _descController;
  late TextEditingController _unitController;
  late TextEditingController _targetController;
  late TextEditingController _currentValController;
  late TextEditingController _customTierController;

  late String _category;
  late String _iconName;

  final List<String> _categories = [
    'MENTAL',
    'COGNITIVE',
    'PHYSICAL',
    'ENDURANCE',
    'REACTION',
    'DISCIPLINE',
    'GENERAL',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.initialSkill;
    _nameController = TextEditingController(text: s?.name ?? '');
    _subtitleController = TextEditingController(text: s?.subtitle ?? '');
    _descController = TextEditingController(text: s?.description ?? '');
    _unitController = TextEditingController(text: s?.unit ?? '');
    _targetController = TextEditingController(
        text: s != null ? (s.targetValue == s.targetValue.roundToDouble() ? s.targetValue.toInt().toString() : s.targetValue.toString()) : '100');
    _currentValController = TextEditingController(
        text: s != null ? (s.currentValue == s.currentValue.roundToDouble() ? s.currentValue.toInt().toString() : s.currentValue.toString()) : '0');
    _customTierController = TextEditingController(text: s?.customTier ?? '');

    _category = s?.category ?? 'MENTAL';
    _iconName = s?.iconName ?? 'chessKnight';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    _descController.dispose();
    _unitController.dispose();
    _targetController.dispose();
    _currentValController.dispose();
    _customTierController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final targetVal = double.tryParse(_targetController.text.trim()) ?? 100.0;
    final currentVal = double.tryParse(_currentValController.text.trim()) ?? 0.0;

    if (widget.initialSkill != null) {
      final updated = widget.initialSkill!.copyWith(
        name: _nameController.text.trim().toUpperCase(),
        subtitle: _subtitleController.text.trim().toUpperCase(),
        category: _category,
        description: _descController.text.trim(),
        unit: _unitController.text.trim(),
        targetValue: targetVal > 0 ? targetVal : 1.0,
        currentValue: currentVal,
        customTier: _customTierController.text.trim(),
        iconName: _iconName,
        updatedAt: DateTime.now(),
      );
      appProvider.updateTrackedSkill(updated);
    } else {
      final newSkill = TrackedSkill(
        name: _nameController.text.trim().toUpperCase(),
        subtitle: _subtitleController.text.trim().toUpperCase(),
        category: _category,
        description: _descController.text.trim(),
        unit: _unitController.text.trim(),
        targetValue: targetVal > 0 ? targetVal : 1.0,
        currentValue: currentVal,
        customTier: _customTierController.text.trim(),
        iconName: _iconName,
      );
      appProvider.addTrackedSkill(newSkill);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = JweTheme.accentAmber;
    final isEditing = widget.initialSkill != null;

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
                    Text(
                      isEditing ? 'EDIT SKILL PROTOCOL' : 'CREATE NEW SKILL',
                      style: GoogleFonts.rajdhani(
                        color: JweTheme.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
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
                        // Icon & Category Selector Row
                        Row(
                          children: [
                            // Icon Preview & Picker Button
                            GestureDetector(
                              onTap: () async {
                                final selected = await SkillIconPickerDialog.show(
                                  context,
                                  currentIconKey: _iconName,
                                  accentColor: accent,
                                );
                                if (selected != null) {
                                  setState(() => _iconName = selected);
                                }
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(SkillIconHelper.resolveIcon(_iconName), size: 30, color: accent),
                                    Positioned(
                                      bottom: 2,
                                      right: 2,
                                      child: Icon(Icons.edit, size: 12, color: JweTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Category Dropdown
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CATEGORY',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: JweTheme.bgBase,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: JweTheme.border),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _category,
                                        isExpanded: true,
                                        dropdownColor: JweTheme.panel,
                                        style: GoogleFonts.jetBrainsMono(color: accent, fontWeight: FontWeight.bold, fontSize: 12),
                                        items: _categories.map((c) {
                                          return DropdownMenuItem<String>(
                                            value: c,
                                            child: Text(c),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _category = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Skill Name
                        _buildField(
                          controller: _nameController,
                          label: 'SKILL NAME *',
                          hint: 'e.g. CHESS RATING, DIGIT SPAN, BREATH HOLD',
                          validator: (val) => val == null || val.trim().isEmpty ? 'Name required' : null,
                        ),
                        const SizedBox(height: 12),

                        // Subtitle
                        _buildField(
                          controller: _subtitleController,
                          label: 'SUBTITLE / DOMAIN (OPTIONAL)',
                          hint: 'e.g. ELO RATING (BLITZ), WORKING MEMORY, MAX REPS',
                        ),
                        const SizedBox(height: 12),

                        // Description
                        _buildField(
                          controller: _descController,
                          label: 'DESCRIPTION (OPTIONAL)',
                          hint: 'Measures your skill level using standard benchmark tests...',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),

                        // Unit & Target / Benchmark Row
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildField(
                                controller: _currentValController,
                                label: 'LATEST VALUE *',
                                hint: '1350',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Value required' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: _buildField(
                                controller: _targetController,
                                label: 'TARGET / MAX *',
                                hint: '3000',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Target required' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: _buildField(
                                controller: _unitController,
                                label: 'UNIT',
                                hint: '/ 3000, REPS',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Custom Tier / Status Label
                        _buildField(
                          controller: _customTierController,
                          label: 'CUSTOM TIER / RANK LABEL (OPTIONAL)',
                          hint: 'e.g. CLUB PLAYER, ABOVE AVERAGE, MASTER (Leave blank to auto-calculate)',
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
                        isEditing ? 'UPDATE SKILL' : 'CREATE SKILL',
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
