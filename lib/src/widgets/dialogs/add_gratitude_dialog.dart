import 'package:flutter/material.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

class AddGratitudeDialog extends StatefulWidget {
  final GratitudeItem? initialItem;
  const AddGratitudeDialog({super.key, this.initialItem});

  @override
  State<AddGratitudeDialog> createState() => _AddGratitudeDialogState();
}

class _AddGratitudeDialogState extends State<AddGratitudeDialog> {
  late TextEditingController _nameController;
  late TextEditingController _whyController;
  late TextEditingController _howController;
  late TextEditingController _whatController;
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialItem?.name ?? '');
    _whyController = TextEditingController(text: widget.initialItem?.why ?? '');
    _howController = TextEditingController(text: widget.initialItem?.how ?? '');
    _whatController = TextEditingController(text: widget.initialItem?.what ?? '');
    
    _selectedType = widget.initialItem?.type ?? 'resource';
    
    // Validate type against allowed list just in case
    if (!['resource', 'skill', 'person', 'object'].contains(_selectedType)) {
      _selectedType = 'resource';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whyController.dispose();
    _howController.dispose();
    _whatController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) return;

    final item = GratitudeItem(
      id: widget.initialItem?.id ?? const Uuid().v4(), // Use existing ID or generate new
      type: _selectedType,
      name: _nameController.text.trim(),
      why: _whyController.text.trim(),
      how: _howController.text.trim(),
      what: _whatController.text.trim(),
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PersonInfoTheme.bgPanel,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: PersonInfoTheme.spideyCyan, width: 2),
        borderRadius: BorderRadius.circular(0), // Sharp edges
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initialItem != null ? "EDIT ASSET" : "NEW ASSET ENTRY",
                style: GoogleFonts.rajdhani(
                  color: PersonInfoTheme.spideyCyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              _buildLabel("ASSET TYPE"),
              DropdownButtonFormField<String>(
                value: _selectedType,
                dropdownColor: PersonInfoTheme.bgDark,
                decoration: _inputDecoration(),
                style: GoogleFonts.rajdhani(color: PersonInfoTheme.textWhite, fontSize: 16),
                items: const [
                  DropdownMenuItem(value: 'resource', child: Text("RESOURCE / ITEM")),
                  DropdownMenuItem(value: 'skill', child: Text("SKILL / ABILITY")),
                  DropdownMenuItem(value: 'person', child: Text("PERSON / ALLY")),
                  DropdownMenuItem(value: 'object', child: Text("OBJECT / GEAR")),
                ],
                onChanged: (val) => setState(() => _selectedType = val!),
              ),

              const SizedBox(height: 16),
              _buildLabel("NAME / TITLE"),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: PersonInfoTheme.textWhite),
                decoration: _inputDecoration(hint: "e.g. Flutter, My Mentor, Good Coffee"),
              ),

              const SizedBox(height: 16),
              _buildLabel("STRATEGIC VALUE (WHY)"),
              TextField(
                controller: _whyController,
                maxLines: 2,
                style: const TextStyle(color: PersonInfoTheme.textWhite, fontSize: 13),
                decoration: _inputDecoration(hint: "Why is this important?"),
              ),

              const SizedBox(height: 16),
              _buildLabel("USAGE METHOD (HOW)"),
              TextField(
                controller: _howController,
                maxLines: 2,
                style: const TextStyle(color: PersonInfoTheme.textWhite, fontSize: 13),
                decoration: _inputDecoration(hint: "How do you utilize or interact with this?"),
              ),

              const SizedBox(height: 16),
              _buildLabel("EXPECTED YIELD (WHAT)"),
              TextField(
                controller: _whatController,
                maxLines: 2,
                style: const TextStyle(color: PersonInfoTheme.textWhite, fontSize: 13),
                decoration: _inputDecoration(hint: "What is the direct benefit or outcome?"),
              ),

              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PersonInfoTheme.textGrey,
                        side: const BorderSide(color: Color(0xFF1f2f40)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text("CANCEL", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PersonInfoTheme.spideyCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                      ),
                      onPressed: _submit,
                      child: Text(widget.initialItem != null ? "UPDATE" : "LOG ASSET", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: GoogleFonts.rajdhani(color: PersonInfoTheme.spideyRed, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: PersonInfoTheme.textGrey.withOpacity(0.5)),
      filled: true,
      fillColor: PersonInfoTheme.bgDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: const OutlineInputBorder(borderSide: BorderSide.none),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: PersonInfoTheme.spideyCyan, width: 1)),
    );
  }
}