import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/data_export_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/external_ai_people_helper.dart';
import 'package:provider/provider.dart';

/// External AI people scan. Copies the lifetime reflection context to an external AI, takes back its
/// JSON reply, and returns the parsed people to the People Intel screen, which resolves them.
class ExternalAiPeopleScreen extends StatefulWidget {
  const ExternalAiPeopleScreen({super.key});

  @override
  State<ExternalAiPeopleScreen> createState() => _ExternalAiPeopleScreenState();
}

class _ExternalAiPeopleScreenState extends State<ExternalAiPeopleScreen> {
  final TextEditingController _outputController = TextEditingController();
  String? _parseError;

  @override
  void dispose() {
    _outputController.dispose();
    super.dispose();
  }

  void _toast(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color ?? JweTheme.accentCyan,
        content: Text(
          message,
          style: GoogleFonts.jetBrainsMono(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyPrompt() {
    Clipboard.setData(ClipboardData(text: ExternalAiPeopleHelper.buildPrompt()));
    _toast('People scan prompt copied. Paste it into your external AI.');
  }

  void _copyData(AppProvider provider) {
    final data = ExternalAiPeopleHelper.buildExportData(provider);
    Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)));
    _toast('Reflection & people JSON copied.', color: JweTheme.accentWarn);
  }

  Future<void> _shareData(AppProvider provider) async {
    final data = ExternalAiPeopleHelper.buildExportData(provider);
    await DataExportService().shareJsonFile(
      data: data,
      baseFilename: 'arcane_people_scan',
      subject: 'Arcane People Intel Scan Dataset',
      text: 'Arcane People Intel Scan Dataset (all lifetime reflections)',
    );
  }

  Future<void> _paste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = clip?.text?.trim() ?? '';
    if (text.isEmpty) {
      _toast('Clipboard is empty.', color: JweTheme.accentRed);
      return;
    }
    setState(() {
      _outputController.text = text;
      _parseError = null;
    });
  }

  void _import() {
    final raw = _outputController.text.trim();
    if (raw.isEmpty) {
      setState(() => _parseError = 'Paste the JSON reply from your external AI first.');
      return;
    }
    try {
      final people = ExternalAiPeopleHelper.parseOutput(raw);
      Navigator.of(context).pop(people);
    } catch (e) {
      setState(() => _parseError = 'Could not read the reply: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final reflections = provider.reflectionLogs.length;
    final people = provider.chatbotMemory.people.length;

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        backgroundColor: JweTheme.panel,
        title: Text(
          'EXTERNAL PEOPLE SCAN',
          style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SCANS ALL LIFETIME REFLECTIONS ($reflections) WITH $people KNOWN PEOPLE, THE SAME WAY THE IN-APP SCAN DOES.',
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _actionButton('COPY PROMPT', MdiIcons.contentCopy, JweTheme.accentTeal, _copyPrompt)),
                const SizedBox(width: 6),
                Expanded(child: _actionButton('COPY DATA', MdiIcons.codeJson, JweTheme.accentWarn, () => _copyData(provider))),
                const SizedBox(width: 6),
                Expanded(child: _actionButton('SHARE', MdiIcons.shareVariant, JweTheme.accentCyan, () => _shareData(provider))),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'AI REPLY (JSON)',
              style: GoogleFonts.jetBrainsMono(color: JweTheme.accentTeal, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _outputController,
              minLines: 8,
              maxLines: 8,
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 11),
              decoration: InputDecoration(
                hintText: '{ "people": [ ... ] }',
                hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
                filled: true,
                fillColor: JweTheme.panel,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: JweTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: JweTheme.accentTeal)),
              ),
            ),
            if (_parseError != null) ...[
              const SizedBox(height: 6),
              Text(
                _parseError!,
                style: GoogleFonts.jetBrainsMono(color: JweTheme.accentRed, fontSize: 10),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _actionButton('PASTE', MdiIcons.contentPaste, JweTheme.accentCyan, _paste)),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JweTheme.accentTeal,
                      foregroundColor: JweTheme.onAccent,
                      shape: const BeveledRectangleBorder(),
                    ),
                    onPressed: _import,
                    child: Text(
                      'IMPORT & RESOLVE',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 13, color: color),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        shape: const BeveledRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      ),
    );
  }
}
