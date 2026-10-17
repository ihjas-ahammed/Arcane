import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/data_export_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/external_ai_person_report_helper.dart';
import 'package:provider/provider.dart';

/// Generates intelligence reports for one or more people in an external AI.
/// Pops with the number of people whose report was saved (or null if nothing was saved).
class ExternalAiPersonReportScreen extends StatefulWidget {
  final List<String> personIds;

  const ExternalAiPersonReportScreen({super.key, required this.personIds});

  @override
  State<ExternalAiPersonReportScreen> createState() => _ExternalAiPersonReportScreenState();
}

class _ExternalAiPersonReportScreenState extends State<ExternalAiPersonReportScreen> {
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
    Clipboard.setData(ClipboardData(text: ExternalAiPersonReportHelper.buildPrompt()));
    _toast('Report prompt copied. Paste it into your external AI.');
  }

  void _copyData(AppProvider provider) {
    final data = ExternalAiPersonReportHelper.buildExportData(provider, widget.personIds);
    Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)));
    _toast('Reports dataset copied.', color: JweTheme.accentWarn);
  }

  Future<void> _shareData(AppProvider provider) async {
    final data = ExternalAiPersonReportHelper.buildExportData(provider, widget.personIds);
    await DataExportService().shareJsonFile(
      data: data,
      baseFilename: 'arcane_person_reports',
      subject: 'Arcane Person Intel Reports Dataset',
      text: 'Arcane Person Intel Reports Dataset (${widget.personIds.length} people)',
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

  void _import(AppProvider provider) {
    final raw = _outputController.text.trim();
    if (raw.isEmpty) {
      setState(() => _parseError = 'Paste the JSON reply from your external AI first.');
      return;
    }
    try {
      final reports = ExternalAiPersonReportHelper.parseOutput(raw, widget.personIds.toSet());
      final saved = provider.journalingActions.applyExternalPersonReports(reports);
      Navigator.of(context).pop(saved);
    } catch (e) {
      setState(() => _parseError = 'Could not read the reply: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final names = [
      for (final p in provider.chatbotMemory.people)
        if (widget.personIds.contains(p.id)) p.name,
    ];

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        backgroundColor: JweTheme.panel,
        title: Text(
          'EXTERNAL INTEL REPORT',
          style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'REPORTS FOR ${names.length} ${names.length == 1 ? 'PERSON' : 'PEOPLE'}: ${names.join(', ').toUpperCase()}',
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
                hintText: '{ "reports": [ ... ] }',
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
                    onPressed: () => _import(provider),
                    child: Text(
                      'IMPORT & SAVE',
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
