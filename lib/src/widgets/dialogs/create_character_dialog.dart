import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:uuid/uuid.dart';

class CreateCharacterDialog extends StatefulWidget {
  final AppProvider provider;
  final Function(NoraPersona)? onPersonaCreated;

  const CreateCharacterDialog({
    super.key,
    required this.provider,
    this.onPersonaCreated,
  });

  static Future<NoraPersona?> show(BuildContext context, AppProvider provider) {
    return showDialog<NoraPersona>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateCharacterDialog(
        provider: provider,
        onPersonaCreated: (p) => Navigator.of(ctx).pop(p),
      ),
    );
  }

  @override
  State<CreateCharacterDialog> createState() => _CreateCharacterDialogState();
}

class _CreateCharacterDialogState extends State<CreateCharacterDialog> {
  int _selectedModeIndex = 0; // 0: Movie/Character, 1: WhatsApp Chat, 2: Custom
  final TextEditingController _inputController = TextEditingController();
  bool _isGenerating = false;
  String? _errorMessage;

  // Generated Persona Draft (editable before final saving)
  NoraPersona? _generatedPersona;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _taglineController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _greetingController = TextEditingController();

  final List<String> _quickSuggestions = [
    "Tony Stark (Iron Man)",
    "Harvey Specter (Suits)",
    "TARS (Interstellar)",
    "Sherlock Holmes",
    "Master Yoda (Star Wars)",
    "Michael Scott (The Office)",
    "Walter White (Breaking Bad)",
    "Gandalf (Lord of the Rings)",
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _nameController.dispose();
    _taglineController.dispose();
    _promptController.dispose();
    _greetingController.dispose();
    super.dispose();
  }

  String get _sourceType {
    switch (_selectedModeIndex) {
      case 0:
        return 'movie_character';
      case 1:
        return 'whatsapp_chat';
      case 2:
      default:
        return 'custom';
    }
  }

  Future<void> _generateCharacter() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final persona = await widget.provider.generateCharacterFromInput(
        inputSource: input,
        sourceType: _sourceType,
      );

      setState(() {
        _generatedPersona = persona;
        _nameController.text = persona.name;
        _taglineController.text = persona.tagline;
        _promptController.text = persona.systemPrompt;
        _greetingController.text = persona.greetingMessage;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _errorMessage = "Failed to generate character: $e";
      });
    }
  }

  void _saveAndActivate() {
    if (_generatedPersona == null) return;

    final updated = _generatedPersona!.copyWith(
      name: _nameController.text.trim().isEmpty ? _generatedPersona!.name : _nameController.text.trim(),
      tagline: _taglineController.text.trim(),
      systemPrompt: _promptController.text.trim().isEmpty ? _generatedPersona!.systemPrompt : _promptController.text.trim(),
      greetingMessage: _greetingController.text.trim().isEmpty ? _generatedPersona!.greetingMessage : _greetingController.text.trim(),
    );

    widget.provider.saveCustomPersona(updated);
    if (widget.onPersonaCreated != null) {
      widget.onPersonaCreated!(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.fhBgDeepDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.fhAccentPurple.withOpacity(0.4), width: 1.5),
      ),
      child: Container(
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.creation, color: AppTheme.fhAccentPurple, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      "SUMMON AI PERSONA",
                      style: TextStyle(
                        color: AppTheme.fhAccentPurple,
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mode Tabs (if not yet reviewing generated draft)
            if (_generatedPersona == null) ...[
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    _buildModeTab(0, "🎬 Movie / Character", Icons.movie_outlined),
                    _buildModeTab(1, "💬 WhatsApp Chat", Icons.chat_bubble_outline),
                    _buildModeTab(2, "✍️ Custom Mode", Icons.auto_awesome_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Content Area
            Expanded(
              child: SingleChildScrollView(
                child: _generatedPersona == null
                    ? _buildInputForm()
                    : _buildPersonaDraftReview(),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],

            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    if (_generatedPersona != null) {
                      setState(() => _generatedPersona = null);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    _generatedPersona != null ? "BACK" : "CANCEL",
                    style: TextStyle(color: AppTheme.fhTextSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                if (_generatedPersona == null)
                  ValorantButton(
                    label: _isGenerating ? "FORGING WITH PRO AI..." : "FORGE CHARACTER",
                    icon: _isGenerating ? null : Icons.bolt,
                    color: AppTheme.fhAccentPurple,
                    onPressed: _isGenerating ? null : _generateCharacter,
                  )
                else
                  ValorantButton(
                    label: "ACTIVATE & SAVE PERSONA",
                    icon: Icons.check,
                    color: AppTheme.fhAccentPurple,
                    onPressed: _saveAndActivate,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(int index, String label, IconData icon) {
    final isSelected = _selectedModeIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedModeIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.fhAccentPurple.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: AppTheme.fhAccentPurple.withOpacity(0.6)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? AppTheme.fhAccentPurple : AppTheme.fhTextSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? AppTheme.fhTextPrimary : AppTheme.fhTextSecondary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputForm() {
    String hintText = "";
    String subtitle = "";

    if (_selectedModeIndex == 0) {
      hintText = "e.g. Tony Stark from Iron Man, Harvey Specter from Suits, Yoda, TARS from Interstellar...";
      subtitle = "Type any movie, TV, book, or historical character. Pro AI will analyze their speech patterns, worldview, and psychology to forge an authentic character sheet.";
    } else if (_selectedModeIndex == 1) {
      hintText = "Paste exported WhatsApp chat logs or conversation text here...";
      subtitle = "Paste a conversation excerpt. Pro AI will clone the texting style, slang, emoji frequency, humor, and personality into a dedicated persona.";
    } else {
      hintText = "e.g. A tough-love startup coach who is obsessed with speed, high leverage, and cutting through excuses...";
      subtitle = "Describe the personality, role, tone, and traits you want for your custom AI companion.";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subtitle,
          style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _inputController,
          maxLines: _selectedModeIndex == 1 ? 8 : 4,
          style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12),
            filled: true,
            fillColor: AppTheme.fhBgDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.fhBorderColor),
            ),
          ),
        ),
        if (_selectedModeIndex == 0) ...[
          const SizedBox(height: 14),
          Text(
            "QUICK INSPIRATIONS:",
            style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickSuggestions.map((s) {
              return ActionChip(
                backgroundColor: AppTheme.fhBgDark,
                side: BorderSide(color: AppTheme.fhAccentPurple.withOpacity(0.3)),
                label: Text(s, style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 11)),
                onPressed: () {
                  _inputController.text = s;
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPersonaDraftReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.fhAccentPurple.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.fhAccentPurple.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(MdiIcons.checkCircle, color: AppTheme.fhAccentPurple, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Character sheet forged! Review and customize the persona before activating.",
                  style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text("CHARACTER NAME", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: _nameController,
          style: TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(filled: true, fillColor: AppTheme.fhBgDark, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),

        Text("TAGLINE / CATCHPHRASE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: _taglineController,
          style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
          decoration: InputDecoration(filled: true, fillColor: AppTheme.fhBgDark, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),

        Text("INITIAL GREETING", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: _greetingController,
          maxLines: 2,
          style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
          decoration: InputDecoration(filled: true, fillColor: AppTheme.fhBgDark, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),

        Text("CHARACTER SYSTEM PROMPT & RULES", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: _promptController,
          maxLines: 6,
          style: GoogleFonts.jetBrainsMono(color: AppTheme.fhTextPrimary, fontSize: 11),
          decoration: InputDecoration(filled: true, fillColor: AppTheme.fhBgDark, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),

        if (_generatedPersona!.memorySpace.isNotEmpty) ...[
          Text("INITIAL MEMORY SPACE ENTRIES (${_generatedPersona!.memorySpace.length})", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ..._generatedPersona!.memorySpace.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(MdiIcons.brain, size: 14, color: AppTheme.fhAccentPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.key, style: TextStyle(color: AppTheme.fhAccentPurple, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(m.content, style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}
