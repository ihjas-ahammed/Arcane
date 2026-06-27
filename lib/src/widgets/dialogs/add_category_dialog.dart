import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/utils/finance_helpers.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class AddCategoryDialog extends StatefulWidget {
  final bool isIncome;
  final FinanceCategory? category; // If not null, we are editing!

  const AddCategoryDialog({
    super.key,
    required this.isIncome,
    this.category,
  });

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  late final TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColorHex;

  final List<String> _colors = [
    '00E5FF', // Cyan
    'FF4655', // Red
    'F1C40F', // Amber
    '8A2BE2', // Purple
    '00F59B', // Emerald
    'FF007F', // Pink
    '007BFF', // Blue
    'FF5722', // Orange
  ];

  final List<String> _icons = [
    'briefcase',
    'food',
    'car',
    'flash',
    'gamepad',
    'target',
    'cart',
    'cash',
    'gift',
    'school',
    'heart',
    'bank',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedIcon = widget.category?.iconName ?? 'circle';
    _selectedColorHex = widget.category?.colorHex ?? '00E5FF';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final isEdit = widget.category != null;
    final accentColor = JweTheme.accentAmber;

    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: Border.all(color: accentColor, width: 2),
      title: Text(
        isEdit ? "EDIT CATEGORY" : "NEW CATEGORY",
        style: GoogleFonts.saira(
          color: accentColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.6,
          fontSize: 14,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "CATEGORY NAME",
                labelStyle: TextStyle(color: JweTheme.textMuted),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 20),
            Text(
              "SELECT COLOR",
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              width: double.maxFinite,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _colors.length,
                itemBuilder: (context, idx) {
                  final hex = _colors[idx];
                  final col = Color(int.parse("0xFF$hex"));
                  final isSel = _selectedColorHex == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorHex = hex),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? col : col.withValues(alpha: 0.3),
                          width: isSel ? 3 : 1.5,
                        ),
                      ),
                      child: isSel
                          ? Center(child: Icon(Icons.check, size: 14, color: col))
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "SELECT ICON",
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 85,
              width: double.maxFinite,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _icons.length,
                itemBuilder: (context, idx) {
                  final name = _icons[idx];
                  final icon = FinanceHelpers.getIconData(name);
                  final isSel = _selectedIcon == name;
                  final themeColor = Color(int.parse("0xFF$_selectedColorHex"));
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = name),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSel ? themeColor.withValues(alpha: 0.15) : JweTheme.bgBase,
                        border: Border.all(
                          color: isSel ? themeColor : JweTheme.lineSoft,
                          width: isSel ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          color: isSel ? themeColor : JweTheme.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: JweTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.black,
            shape: const BeveledRectangleBorder(),
          ),
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isNotEmpty) {
              if (isEdit) {
                provider.financeActions.updateCategory(
                  widget.category!.id,
                  name: name,
                  colorHex: _selectedColorHex,
                  iconName: _selectedIcon,
                );
              } else {
                provider.financeActions.addCategory(
                  name,
                  _selectedColorHex,
                  _selectedIcon,
                  widget.isIncome,
                );
              }
              Navigator.pop(context);
            }
          },
          child: Text(isEdit ? "SAVE" : "ADD", style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}