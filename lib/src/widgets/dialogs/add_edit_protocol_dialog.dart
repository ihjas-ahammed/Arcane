import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/widgets/dialogs/color_selector_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

class AddEditProtocolDialog extends StatefulWidget {
  final MainTask? task;

  const AddEditProtocolDialog({super.key, this.task});

  @override
  State<AddEditProtocolDialog> createState() => _AddEditProtocolDialogState();
}

class _AddEditProtocolDialogState extends State<AddEditProtocolDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late String _selectedTheme;
  late String _selectedColorHex;

  final List<Map<String, dynamic>> _availableThemes = [
    {'name': 'tech', 'icon': MdiIcons.memory, 'color': AppTheme.fhAccentTealFixed},
    {'name': 'knowledge', 'icon': MdiIcons.bookOpenPageVariantOutline, 'color': AppTheme.fhAccentPurple},
    {'name': 'learning', 'icon': MdiIcons.schoolOutline, 'color': AppTheme.fhAccentOrange},
    {'name': 'discipline', 'icon': MdiIcons.karate, 'color': AppTheme.fhAccentRed},
    {'name': 'order', 'icon': MdiIcons.playlistCheck, 'color': AppTheme.fhAccentGreen},
    {'name': 'health', 'icon': MdiIcons.heartPulse, 'color': const Color(0xFF58D68D)},
    {'name': 'finance', 'icon': MdiIcons.cashMultiple, 'color': const Color(0xFFF1C40F)},
    {'name': 'creative', 'icon': MdiIcons.paletteOutline, 'color': const Color(0xFFEC7063)},
    {'name': 'exploration', 'icon': MdiIcons.mapSearchOutline, 'color': const Color(0xFF5DADE2)},
    {'name': 'social', 'icon': MdiIcons.accountGroupOutline, 'color': const Color(0xFFE59866)},
    {'name': 'nature', 'icon': MdiIcons.treeOutline, 'color': const Color(0xFF2ECC71)},
    {'name': 'general', 'icon': MdiIcons.targetAccount, 'color': AppTheme.fhTextSecondary},
  ];

  Color _getColorForTheme(String themeName) {
    return _availableThemes.firstWhere((t) => t['name'] == themeName,
        orElse: () => {'color': AppTheme.fhAccentTealFixed})['color'] as Color;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _descController = TextEditingController(text: widget.task?.description ?? '');
    _selectedTheme = widget.task?.theme ?? 'tech';
    _selectedColorHex = widget.task?.colorHex ?? _getColorForTheme(_selectedTheme).value.toRadixString(16).toUpperCase().substring(2);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = Color(int.parse("0xFF$_selectedColorHex"));
    final isEditing = widget.task != null;

    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: Border.all(color: JweTheme.accentCyan, width: 2),
      title: Text(isEditing ? 'EDIT PROTOCOL' : 'NEW PROTOCOL', style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _nameController, 
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: const InputDecoration(labelText: 'CODENAME', filled: true, fillColor: JweTheme.bgBase, border: OutlineInputBorder())
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController, 
              maxLines: 2,
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: const InputDecoration(labelText: 'BRIEFING', filled: true, fillColor: JweTheme.bgBase, border: OutlineInputBorder())
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'CLASS', filled: true, fillColor: JweTheme.bgBase, border: OutlineInputBorder()),
              dropdownColor: JweTheme.panel,
              value: _selectedTheme,
              items: _availableThemes.map((themeMap) => DropdownMenuItem(
                value: themeMap['name'] as String,
                child: Text((themeMap['name'] as String).toUpperCase(), style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold))
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedTheme = val;
                    // Auto-update color if it hasn't been manually set, or we can just always sync it.
                    _selectedColorHex = _getColorForTheme(val).value.toRadixString(16).toUpperCase().substring(2);
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            const Text("CLASS COLOR", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => ColorSelectorDialog(
                    selectedColor: currentColor,
                    onColorSelected: (color) {
                      setState(() {
                        _selectedColorHex = color.value.toRadixString(16).toUpperCase().substring(2);
                      });
                    },
                  ),
                );
              },
              child: Container(
                height: 40,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: currentColor,
                  border: Border.all(color: JweTheme.border),
                ),
                child: const Center(child: Text("TAP TO CHANGE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10))),
              ),
            )
          ],
        ),
      ),
      actions: [
        TextButton(child: const Text('ABORT', style: TextStyle(color: JweTheme.textMuted)), onPressed: () => Navigator.pop(context)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentCyan, foregroundColor: Colors.black, shape: const BeveledRectangleBorder()),
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              final provider = Provider.of<AppProvider>(context, listen: false);
              if (isEditing) {
                provider.editMainTask(
                  widget.task!.id,
                  name: _nameController.text,
                  description: _descController.text,
                  theme: _selectedTheme,
                  colorHex: _selectedColorHex,
                );
              } else {
                provider.addMainTask(
                  name: _nameController.text,
                  description: _descController.text,
                  theme: _selectedTheme,
                  colorHex: _selectedColorHex,
                );
              }
              Navigator.pop(context);
            }
          },
          child: Text(isEditing ? 'UPDATE' : 'INITIALIZE', style: const TextStyle(fontWeight: FontWeight.bold)),
        )
      ],
    );
  }
}