import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:missions/src/widgets/common/growing_text_field.dart';

class SubtaskConfigDialog extends StatefulWidget {
  final String initialName;
  final String initialDescription;
  final bool isRecurring;
  final bool isActive;
  final String initialProgressMode;

  const SubtaskConfigDialog({
    super.key,
    required this.initialName,
    this.initialDescription = '',
    this.isRecurring = false,
    this.isActive = true,
    this.initialProgressMode = 'auto',
  });

  @override
  State<SubtaskConfigDialog> createState() => _SubtaskConfigDialogState();
}

class _SubtaskConfigDialogState extends State<SubtaskConfigDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late bool _isRecurring;
  late bool _isActive;
  late String _progressMode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descController = TextEditingController(text: widget.initialDescription);
    _isRecurring = widget.isRecurring;
    _isActive = widget.isActive;
    _progressMode = widget.initialProgressMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("CONFIGURE OBJECTIVE"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("NAME", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GrowingTextField(controller: _nameController, hint: "Objective title...", minLines: 1),

            const SizedBox(height: 16),

            const Text("BRIEFING", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GrowingTextField(controller: _descController, hint: "Description and notes...", minLines: 3),

            const SizedBox(height: 24),

            Text(
              'PROGRESS MODE',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            _ProgressModeSelector(
              value: _progressMode,
              onChanged: (v) => setState(() => _progressMode = v),
            ),
            const SizedBox(height: 4),
            Text(
              _progressModeHint(_progressMode),
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted.withValues(alpha: 0.6),
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),

            const SizedBox(height: 20),

            SwitchListTile(
              title: const Text("ACTIVE STATUS", style: TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text("Suspend this objective temporarily", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
              value: _isActive,
              activeThumbColor: AppTheme.fhAccentTeal,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _isActive = val),
            ),

            SwitchListTile(
              title: const Text("RECURRING PROTOCOL", style: TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text("Resets daily at 00:00", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
              value: _isRecurring,
              activeThumbColor: AppTheme.fhAccentTeal,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _isRecurring = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL"),
        ),
        ValorantButton(
          label: "UPDATE",
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'description': _descController.text.trim(),
                'isRecurring': _isRecurring,
                'isActive': _isActive,
                'progressMode': _progressMode,
              });
            }
          },
        ),
      ],
    );
  }

  String _progressModeHint(String mode) {
    switch (mode) {
      case 'time':
        return 'Bar = today\'s time ÷ 7-day avg';
      case 'subtask':
        return 'Bar = completed steps ÷ total steps';
      case 'manual':
        return 'Bar = custom percentage input';
      case 'auto':
      default:
        return 'Steps if available, otherwise time-based';
    }
  }
}

class _ProgressModeSelector extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;

  const _ProgressModeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const modes = [
      ('auto', 'AUTO'),
      ('time', 'TIME'),
      ('subtask', 'STEPS'),
      ('manual', 'MANUAL'),
    ];
    return Row(
      children: modes.map((entry) {
        final (mode, label) = entry;
        final selected = value == mode;
        final color = selected ? JweTheme.accentCyan : JweTheme.textMuted;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(mode),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: selected ? JweTheme.accentCyan.withValues(alpha: 0.12) : Colors.transparent,
                border: Border.all(
                  color: selected ? JweTheme.accentCyan : JweTheme.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
