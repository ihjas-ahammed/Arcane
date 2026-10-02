import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/data_export_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/external_ai_schedule_helper.dart';

/// Dedicated screen for zero-latency schedule prediction & day planning
/// via External AI engines (ChatGPT, Claude, Gemini, Perplexity, etc.).
///
/// Compiles rich user telemetry, historical sessions, and today's uncompleted plan
/// into copyable prompts/datasets, and parses external AI responses into non-editable
/// overlay timeline entries that the operator overdraws through during the day.
class ExternalAiScheduleScreen extends StatefulWidget {
  final DateTime? initialDate;

  const ExternalAiScheduleScreen({
    super.key,
    this.initialDate,
  });

  @override
  State<ExternalAiScheduleScreen> createState() => _ExternalAiScheduleScreenState();
}

class _ExternalAiScheduleScreenState extends State<ExternalAiScheduleScreen> {
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  final TextEditingController _outputController = TextEditingController();
  List<TimelineEntry>? _parsedEntries;
  String? _parseError;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    _startTime = isToday ? TimeOfDay.now() : const TimeOfDay(hour: 8, minute: 0);
  }

  @override
  void dispose() {
    _outputController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'SELECT SCHEDULE START TIME',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: JweTheme.pickerScheme(
              accent: JweTheme.accentAmber,
              surface: JweTheme.panel,
            ),
            dialogTheme: DialogThemeData(backgroundColor: JweTheme.bgDeep),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
        _parsedEntries = null;
        _parseError = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: JweTheme.pickerScheme(
              accent: JweTheme.accentCyan,
              surface: JweTheme.panel,
            ),
            dialogTheme: DialogThemeData(backgroundColor: JweTheme.bgDeep),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      final now = DateTime.now();
      final isToday = picked.year == now.year &&
          picked.month == now.month &&
          picked.day == now.day;
      setState(() {
        _selectedDate = picked;
        if (!isToday) {
          _startTime = const TimeOfDay(hour: 8, minute: 0);
        }
        _parsedEntries = null;
        _parseError = null;
      });
    }
  }

  void _copyPrompt(AppProvider provider) {
    final prompt = ExternalAiScheduleHelper.buildPrompt(
      provider: provider,
      targetDate: _selectedDate,
      startTime: _startTime,
    );
    Clipboard.setData(ClipboardData(text: prompt));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: JweTheme.accentCyan,
        content: Text(
          '✓ Schedule Prompt & Schema copied! Paste into external AI.',
          style: GoogleFonts.jetBrainsMono(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _copyDataJson(AppProvider provider) {
    final data = ExternalAiScheduleHelper.buildExportData(
      provider: provider,
      targetDate: _selectedDate,
      startTime: _startTime,
    );
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    Clipboard.setData(ClipboardData(text: jsonStr));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: JweTheme.accentAmber,
        content: Text(
          '✓ Schedule Context JSON copied to clipboard!',
          style: GoogleFonts.jetBrainsMono(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _shareDataJson(AppProvider provider) async {
    final data = ExternalAiScheduleHelper.buildExportData(
      provider: provider,
      targetDate: _selectedDate,
      startTime: _startTime,
    );
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    await DataExportService().shareJsonFile(
      data: data,
      baseFilename: 'arcane_schedule_context_$dateStr',
      subject: 'Arcane Schedule Prediction Context - $dateStr',
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _outputController.text = data.text!;
        _parseError = null;
      });
      _handleParseOutput();
    }
  }

  void _handleParseOutput() {
    final text = _outputController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parseError = 'Please paste the external AI response first.';
        _parsedEntries = null;
      });
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    setState(() {
      _isProcessing = true;
      _parseError = null;
    });

    try {
      final entries = ExternalAiScheduleHelper.parsePredictions(
        text,
        targetDate: _selectedDate,
        provider: provider,
        startTime: _startTime,
      );

      if (entries.isEmpty) {
        setState(() {
          _parseError = 'Parsed array was empty. Ensure the AI produced session blocks.';
          _parsedEntries = null;
        });
      } else {
        setState(() {
          _parsedEntries = entries;
          _parseError = null;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      setState(() {
        _parseError = 'Failed to parse AI output: $e';
        _parsedEntries = null;
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmAndApplyOverlay(AppProvider provider) async {
    if (_parsedEntries == null || _parsedEntries!.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await provider.scheduleActions.setPredictedEntriesForDate(_selectedDate, _parsedEntries!);
      HapticFeedback.heavyImpact();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: JweTheme.accentCyan,
          content: Text(
            '✓ ${_parsedEntries!.length} predicted session blocks imported as overlay!',
            style: GoogleFonts.jetBrainsMono(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _parseError = 'Error saving overlay: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _clearOverlay(AppProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(
          'CLEAR PREDICTED OVERLAY?',
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.textWhite,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        content: Text(
          'Remove all predicted overlay blocks for ${DateFormat('yyyy-MM-dd').format(_selectedDate)}?',
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.textMuted,
            fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CLEAR OVERLAY', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.scheduleActions.clearPredictedEntriesForDate(_selectedDate);
      setState(() {
        _parsedEntries = null;
        _outputController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: JweTheme.accentRed,
            content: Text(
              'Predicted overlay cleared for ${DateFormat('yyyy-MM-dd').format(_selectedDate)}.',
              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final activeOverlay = provider.scheduleActions.getPredictedEntriesForDate(_selectedDate);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;

    return Scaffold(
      backgroundColor: JweTheme.bgCanvas,
      appBar: AppBar(
        backgroundColor: JweTheme.panel,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: JweTheme.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXTERNAL AI // SCHEDULE PREDICTOR',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentCyan,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              'PREDICT DAY & PLAN OVERLAY',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted,
                fontSize: 9.5,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              backgroundColor: JweTheme.panel2,
              side: BorderSide(
                color: JweTheme.accentAmber.withValues(alpha: 0.5),
                width: 1,
              ),
              avatar: Icon(
                MdiIcons.clockOutline,
                size: 14,
                color: JweTheme.accentAmber,
              ),
              label: Text(
                _startTime.format(context),
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentAmber,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _pickStartTime,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              backgroundColor: isToday
                  ? JweTheme.accentCyan.withValues(alpha: JweTheme.isLight ? 0.15 : 0.2)
                  : JweTheme.panel2,
              side: BorderSide(
                color: isToday ? JweTheme.accentCyan : JweTheme.border,
                width: 1,
              ),
              avatar: Icon(
                MdiIcons.calendarBlank,
                size: 14,
                color: isToday ? JweTheme.accentCyan : JweTheme.textWhite,
              ),
              label: Text(
                isToday ? 'TODAY' : dateStr,
                style: GoogleFonts.jetBrainsMono(
                  color: isToday ? JweTheme.accentCyan : JweTheme.textWhite,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _pickDate,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Active overlay banner if present
            if (activeOverlay.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: JweTheme.accentCyan.withValues(alpha: JweTheme.isLight ? 0.08 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: JweTheme.accentCyan.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: JweTheme.accentCyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ACTIVE OVERLAY: ${activeOverlay.length} predicted session block(s) currently active for $dateStr.',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.isLight ? JweTheme.accentCyan : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _clearOverlay(provider),
                      child: Text(
                        'CLEAR',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentRed,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 1. Context Telemetry Card
            _buildTelemetryCard(provider),
            const SizedBox(height: 16),

            // 2. Export Actions Card
            _buildExportActionsCard(provider),
            const SizedBox(height: 16),

            // 3. AI Ingestion & Paste Card
            _buildIngestionCard(provider),

            // 4. Parsed Preview Card
            if (_parsedEntries != null && _parsedEntries!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPreviewCard(provider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryCard(AppProvider provider) {
    final uncompletedCount = provider.taskActions.getDayPlan(DateFormat('yyyy-MM-dd').format(_selectedDate)).length;
    final activeTasksCount = provider.mainTasks.where((t) => !t.isDeleted && t.isActive).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: JweTheme.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.radar, size: 14, color: JweTheme.accentAmber),
              const SizedBox(width: 6),
              Text(
                'LIVE CONTEXT TELEMETRY',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentAmber,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _pickStartTime,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: JweTheme.accentAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MdiIcons.clockEditOutline, size: 11, color: JweTheme.accentAmber),
                      const SizedBox(width: 4),
                      Text(
                        'START: ${_startTime.format(context)}',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentAmber,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'PLAN ITEMS',
                  value: '$uncompletedCount',
                  color: JweTheme.accentCyan,
                  icon: Icons.checklist_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'ACTIVE PROTOCOLS',
                  value: '$activeTasksCount',
                  color: JweTheme.accentAmber,
                  icon: MdiIcons.console,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'OVERLAY STATUS',
                  value: 'BLUEPRINT',
                  color: JweTheme.accentTeal,
                  icon: Icons.layers_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: JweTheme.panel2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: JweTheme.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportActionsCard(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: JweTheme.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.shareVariant, size: 14, color: JweTheme.accentCyan),
              const SizedBox(width: 6),
              Text(
                'EXPORT CONTEXT & PROMPT',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentCyan,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Copy the prompt into ChatGPT, Claude, Gemini, or export the full JSON context for external AI synthesis.',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textMuted,
              fontSize: 9.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: JweTheme.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text(
                    'COPY PROMPT & SCHEMA',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: () => _copyPrompt(provider),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.accentAmber,
                    side: BorderSide(color: JweTheme.accentAmber, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 14),
                  label: Text(
                    'SHARE JSON',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  onPressed: () => _shareDataJson(provider),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Copy JSON Dataset',
                style: IconButton.styleFrom(
                  backgroundColor: JweTheme.panel2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(color: JweTheme.border, width: 1),
                  ),
                ),
                icon: Icon(MdiIcons.codeJson, size: 16, color: JweTheme.textWhite),
                onPressed: () => _copyDataJson(provider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngestionCard(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _parseError != null ? JweTheme.accentRed : JweTheme.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.clipboardArrowLeft, size: 14, color: JweTheme.accentTeal),
              const SizedBox(width: 6),
              Text(
                'PASTE AI SCHEDULE RESPONSE',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentTeal,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: Icon(Icons.paste_rounded, size: 12, color: JweTheme.accentCyan),
                label: Text(
                  'PASTE',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentCyan,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _pasteFromClipboard,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _outputController,
            maxLines: 7,
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textWhite,
              fontSize: 11,
            ),
            decoration: InputDecoration(
              hintText: 'Paste the JSON array output from external AI here...\n[\n  {\n    "taskName": "Deep Work",\n    "subTaskName": "Refactor Module",\n    "startTime": "20:00",\n    "endTime": "21:00"\n  }\n]',
              hintStyle: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted.withValues(alpha: 0.6),
                fontSize: 10,
              ),
              filled: true,
              fillColor: JweTheme.bgDeep,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: JweTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: JweTheme.accentCyan, width: 1.5),
              ),
            ),
          ),
          if (_parseError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: JweTheme.accentRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: JweTheme.accentRed.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 14, color: JweTheme.accentRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _parseError!,
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentRed,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Icon(MdiIcons.crystalBall, size: 16),
              label: Text(
                _isProcessing ? 'PARSING PREDICTIONS...' : 'PARSE & PREVIEW OVERLAY',
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
              onPressed: _isProcessing ? null : _handleParseOutput,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(AppProvider provider) {
    final entries = _parsedEntries!;
    int totalMinutes = 0;
    for (final e in entries) {
      totalMinutes += e.durationSeconds ~/ 60;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: JweTheme.accentCyan, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: JweTheme.accentCyan),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'PREDICTED OVERLAY PREVIEW (${entries.length} SESSIONS · ${totalMinutes}m)',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentCyan,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'These blocks will be rendered as a non-editable background blueprint overlay on the schedule timeline. As you work and log sessions, real sessions will overdraw directly through it.',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textMuted,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (ctx, i) {
              final e = entries[i];
              final startStr = DateFormat('HH:mm').format(e.startTime);
              final endStr = DateFormat('HH:mm').format(e.endTime);
              final mins = e.durationSeconds ~/ 60;
              final calColor = JweTheme.isLight ? JweTheme.calibrate(e.color) : e.color;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: calColor.withValues(alpha: JweTheme.isLight ? 0.08 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border(
                    left: BorderSide(color: calColor, width: 3.5),
                    top: BorderSide(color: calColor.withValues(alpha: 0.3), width: 0.8),
                    right: BorderSide(color: calColor.withValues(alpha: 0.3), width: 0.8),
                    bottom: BorderSide(color: calColor.withValues(alpha: 0.3), width: 0.8),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '[PREDICTED] ',
                                style: GoogleFonts.jetBrainsMono(
                                  color: calColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.title,
                                  style: TextStyle(
                                    color: JweTheme.isLight ? calColor : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (e.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              e.subtitle!,
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.textMuted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: JweTheme.panel2,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: JweTheme.border, width: 0.8),
                      ),
                      child: Text(
                        '$startStr - $endStr (${mins}m)',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.isLight ? JweTheme.textWhite : calColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentTeal,
                foregroundColor: JweTheme.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(
                'CONFIRM & IMPORT TO SCHEDULE OVERLAY',
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
              onPressed: _isProcessing ? null : () => _confirmAndApplyOverlay(provider),
            ),
          ),
        ],
      ),
    );
  }
}
