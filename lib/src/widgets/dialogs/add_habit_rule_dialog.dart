import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/habit_models.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

class AddHabitRuleDialog extends StatefulWidget {
  const AddHabitRuleDialog({super.key});

  @override
  State<AddHabitRuleDialog> createState() => _AddHabitRuleDialogState();
}

class _AddHabitRuleDialogState extends State<AddHabitRuleDialog> {
  final _nameController = TextEditingController();
  final _delayController = TextEditingController(text: '10');
  final _limitController = TextEditingController(text: '30');
  bool _isGrayscale = true;

  @override
  void dispose() {
    _nameController.dispose();
    _delayController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: const BeveledRectangleBorder(side: BorderSide(color: JweTheme.accentRed, width: 2)),
      title: Text("CONFIGURE RESTRICTION", style: GoogleFonts.rajdhani(color: JweTheme.accentRed, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("APP/BEHAVIOR NAME", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: JweTheme.textWhite, fontSize: 14),
              decoration: const InputDecoration(
                filled: true,
                fillColor: JweTheme.bgBase,
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentRed)),
                hintText: "e.g. Instagram"
              ),
            ),
            const SizedBox(height: 16),
            
            const Text("FRICTION DELAY (SECONDS)", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _delayController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: JweTheme.textWhite, fontSize: 14, fontFamily: 'RobotoMono'),
              decoration: const InputDecoration(
                filled: true,
                fillColor: JweTheme.bgBase,
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentRed)),
              ),
            ),
            const SizedBox(height: 16),

            const Text("DAILY CAP (MINUTES)", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _limitController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: JweTheme.textWhite, fontSize: 14, fontFamily: 'RobotoMono'),
              decoration: const InputDecoration(
                filled: true,
                fillColor: JweTheme.bgBase,
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentRed)),
              ),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text("Grayscale Context", style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
              value: _isGrayscale,
              activeColor: JweTheme.accentRed,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _isGrayscale = val),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: JweTheme.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentRed, foregroundColor: Colors.white, shape: const BeveledRectangleBorder()),
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              final rule = HabitRule(
                id: const Uuid().v4(),
                appName: _nameController.text.trim(),
                frictionDelaySeconds: int.tryParse(_delayController.text) ?? 0,
                dailyLimitMinutes: int.tryParse(_limitController.text) ?? 0,
                isGrayscale: _isGrayscale,
              );
              Provider.of<AppProvider>(context, listen: false).addHabitRule(rule);
              Navigator.pop(context);
            }
          }, 
          child: const Text("ENFORCE")
        )
      ],
    );
  }
}