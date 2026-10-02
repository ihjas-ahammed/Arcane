import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/journaling/monthly_review_screen.dart';
import 'package:missions/src/screens/journaling/weekly_review_screen.dart';
import 'package:missions/src/services/data_export_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/external_ai_briefing_helper.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';
import 'package:provider/provider.dart';

/// Dedicated screen for zero-latency briefing synthesis via External AI engines (ChatGPT, Claude, etc.).
/// Operates as an independent screen that updates the realtime AppProvider upon ingestion.
class ExternalAiBriefingScreen extends StatefulWidget {
  final BriefingType initialType;
  final DateTime? initialDate;

  const ExternalAiBriefingScreen({
    super.key,
    this.initialType = BriefingType.daily,
    this.initialDate,
  });

  @override
  State<ExternalAiBriefingScreen> createState() => _ExternalAiBriefingScreenState();
}

class _ExternalAiBriefingScreenState extends State<ExternalAiBriefingScreen> {
  late BriefingType _selectedType;
  late DateTime _selectedDate;
  final TextEditingController _outputController = TextEditingController();
  bool _isProcessing = false;
  String? _parseError;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _outputController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: JweTheme.accentAmber,
              surface: JweTheme.bgBase,
              onSurface: JweTheme.textWhite,
            ),
            dialogTheme: DialogThemeData(backgroundColor: JweTheme.bgBase),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _parseError = null;
      });
    }
  }

  void _copyPrompt(AppProvider provider) {
    final prompt = ExternalAiBriefingHelper.buildPrompt(
      type: _selectedType,
      targetDate: _selectedDate,
      provider: provider,
    );
    Clipboard.setData(ClipboardData(text: prompt));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: JweTheme.accentCyan,
        content: Text(
          'Briefing Prompt copied to clipboard! Paste into external AI.',
          style: GoogleFonts.jetBrainsMono(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _copyDataJson(AppProvider provider) {
    final data = ExternalAiBriefingHelper.buildExportData(
      provider: provider,
      targetDate: _selectedDate,
      type: _selectedType,
    );
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: JweTheme.accentAmber,
        content: Text(
          'Telemetry & History JSON copied to clipboard!',
          style: GoogleFonts.jetBrainsMono(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _shareDataJson(AppProvider provider) async {
    final data = ExternalAiBriefingHelper.buildExportData(
      provider: provider,
      targetDate: _selectedDate,
      type: _selectedType,
    );
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    await DataExportService().shareJsonFile(
      data: data,
      baseFilename: 'arcane_briefing_${_selectedType.name}_$dateStr',
      subject: 'Arcane ${_selectedType.label} Data ($dateStr)',
      text: 'Arcane ${_selectedType.label} Telemetry & Context Dataset ($dateStr)',
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _outputController.text = data.text!;
        _parseError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pasted ${data.text!.length} characters from clipboard.',
            style: GoogleFonts.jetBrainsMono(fontSize: 11),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: JweTheme.accentRed,
          content: Text(
            'Clipboard is empty.',
            style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
          ),
        ),
      );
    }
  }

  Future<void> _pasteAndSaveBriefing(AppProvider provider) async {
    // If output controller is empty, grab directly from clipboard
    if (_outputController.text.trim().isEmpty) {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      if (clip?.text != null && clip!.text!.trim().isNotEmpty) {
        _outputController.text = clip.text!;
      } else {
        setState(() {
          _parseError = 'No AI output provided. Please paste the JSON response from your external AI.';
        });
        return;
      }
    }

    setState(() {
      _isProcessing = true;
      _parseError = null;
    });

    try {
      final parsed = ExternalAiBriefingHelper.parseAiOutput(_outputController.text);

      await ExternalAiBriefingHelper.saveBriefing(
        provider: provider,
        type: _selectedType,
        targetDate: _selectedDate,
        data: parsed,
      );

      if (!mounted) return;

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final hasTomorrowStartup = _selectedType == BriefingType.daily &&
          (parsed.containsKey('tomorrow_startup_report') ||
              (parsed['daily_briefing'] is Map && parsed.containsKey('tomorrow_startup_report')));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: JweTheme.accentTeal,
          content: Text(
            hasTomorrowStartup
                ? '${_selectedType.label} ($dateStr) + Tomorrow Startup Brief successfully saved!'
                : '${_selectedType.label} ($dateStr) successfully saved to live databanks!',
            style: GoogleFonts.jetBrainsMono(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );

      // Navigate to the post-briefing screen
      switch (_selectedType) {
        case BriefingType.daily:
          final dailyData = parsed.containsKey('daily_briefing') && parsed['daily_briefing'] is Map
              ? Map<String, dynamic>.from(parsed['daily_briefing'] as Map)
              : parsed;
          Navigator.of(context).pop(dailyData);
          break;
        case BriefingType.startup:
          // Pop back to Daily Summary View which will now immediately display the saved tactical briefing card
          Navigator.of(context).pop(parsed);
          break;

        case BriefingType.weekly:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => WeeklyReviewScreen(
                reportData: parsed,
                provider: provider,
                targetDate: _selectedDate,
                onArchive: () async {
                  await provider.saveWeeklyReport(dateStr, parsed);
                },
              ),
            ),
          );
          break;

        case BriefingType.monthly:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MonthlyReviewScreen(
                reportData: parsed,
                provider: provider,
                targetDate: _selectedDate,
                onArchive: () async {
                  await provider.saveMonthlyReport(dateStr, parsed);
                },
              ),
            ),
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _parseError = 'Failed to parse AI output: $e\nEnsure the model returned valid JSON.';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = JweTheme.isLight;
    final provider = Provider.of<AppProvider>(context);
    final themeColor = provider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;

    final dataSnapshot = ExternalAiBriefingHelper.buildExportData(
      provider: provider,
      targetDate: _selectedDate,
      type: _selectedType,
    );
    final historical = dataSnapshot['historical_briefs'] as Map<String, dynamic>? ?? {};
    final telemetry = dataSnapshot['activity_telemetry'] as Map<String, dynamic>? ?? {};

    final weeklyCount = (historical['weekly_briefs_last_30_days'] as List?)?.length ?? 0;
    final monthlyCount = (historical['monthly_briefs_last_year'] as List?)?.length ?? 0;
    final dailyCount = (historical['daily_briefs_last_7_days'] as List?)?.length ?? 0;

    final reflectionsCount = telemetry['reflections_count'] ?? 0;
    final goalsCount = telemetry['goals_count'] ?? 0;
    final txCount = (telemetry['finance']?['transactions'] as List?)?.length ?? 0;
    final trackedMinutes = telemetry['time_tracking']?['total_minutes'] ?? 0;

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        backgroundColor: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF0D0E14),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: JweTheme.textWhite),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXTERNAL AI BRIEFING PROTOCOL',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: themeColor,
              ),
            ),
            Text(
              '// ZERO-LATENCY SYNTHESIS VIA EXTERNAL ENGINE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: JweTheme.textMuted,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24.0 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Scope / Briefing Type Tabs ───────────────────
              Row(
                children: [
                  _typeChip(BriefingType.daily, 'DAILY', themeColor, isLight),
                  const SizedBox(width: 8),
                  _typeChip(BriefingType.weekly, 'WEEKLY (7-DAY)', themeColor, isLight),
                  const SizedBox(width: 8),
                  _typeChip(BriefingType.monthly, 'MONTHLY (30-DAY)', themeColor, isLight),
                ],
              ),
              const SizedBox(height: 14),

              // ── Date Selector & Target Banner ────────────────
              HudPanel(
                clip: HudClip.br,
                accent: themeColor,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(MdiIcons.calendarClock, size: 18, color: themeColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TARGET INSPECTION DATE',
                            style: GoogleFonts.orbitron(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: JweTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate).toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: JweTheme.textWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: themeColor.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(4),
                          color: themeColor.withValues(alpha: 0.08),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.edit_calendar, size: 14, color: themeColor),
                            const SizedBox(width: 4),
                            Text(
                              'CHANGE',
                              style: GoogleFonts.orbitron(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Telemetry & Historical Context Summary Card ──
              HudPanel(
                clip: HudClip.both,
                accent: JweTheme.accentCyan,
                allBrackets: true,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(MdiIcons.databaseSync, size: 14, color: JweTheme.accentCyan),
                        const SizedBox(width: 6),
                        Text(
                          'DATASET TELEMETRY MANIFEST',
                          style: GoogleFonts.orbitron(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: JweTheme.accentCyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dataBullet(
                      icon: MdiIcons.history,
                      title: 'Historical Briefs Included:',
                      value: '$weeklyCount weekly (30d) • $monthlyCount monthly (1y) • $dailyCount daily (7d)',
                      accent: JweTheme.accentAmber,
                    ),
                    const SizedBox(height: 6),
                    _dataBullet(
                      icon: MdiIcons.chartLine,
                      title: 'Activity Telemetry (${_selectedType == BriefingType.monthly ? "30 Days" : "7 Days"}):',
                      value: '$reflectionsCount reflections • $goalsCount goals • $txCount txs • ${(trackedMinutes / 60).toStringAsFixed(1)}h tracked',
                      accent: JweTheme.accentTeal,
                    ),
                    if (_selectedType == BriefingType.daily) ...[
                      const SizedBox(height: 6),
                      _dataBullet(
                        icon: MdiIcons.weatherSunny,
                        title: 'Advance Synthesis:',
                        value: 'Synthesizes tomorrow morning\'s System Start-Up Sequence in advance',
                        accent: JweTheme.accentCyan,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Action Buttons: Copy Prompt & Share/Copy Data ──
              Text(
                'STEP 1: EXPORT TO EXTERNAL AI',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: JweTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      label: 'COPY PROMPT',
                      icon: Icons.copy,
                      color: JweTheme.accentCyan,
                      onTap: () => _copyPrompt(provider),
                      isLight: isLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      label: 'COPY DATA (JSON)',
                      icon: MdiIcons.codeJson,
                      color: JweTheme.accentAmber,
                      onTap: () => _copyDataJson(provider),
                      isLight: isLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _actionButton(
                label: 'SHARE DATASET (JSON)',
                icon: Icons.share,
                color: JweTheme.accentTeal,
                onTap: () => _shareDataJson(provider),
                isLight: isLight,
              ),
              const SizedBox(height: 20),

              // ── Step 2: Ingestion & Output Area ───────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STEP 2: INGEST AI OUTPUT',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: JweTheme.textMuted,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(Icons.paste, size: 14, color: themeColor),
                    label: Text(
                      'PASTE',
                      style: GoogleFonts.orbitron(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                    onPressed: _pasteFromClipboard,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                  border: Border.all(
                    color: _parseError != null
                        ? JweTheme.accentRed
                        : JweTheme.border,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _outputController,
                  maxLines: null,
                  expands: true,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: isLight ? Colors.black87 : Colors.white70,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Paste external AI output JSON here...\n(Markdown codeblocks are automatically stripped)',
                    hintStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: JweTheme.textMuted,
                    ),
                  ),
                ),
              ),

              if (_parseError != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: JweTheme.accentRed.withValues(alpha: 0.1),
                    border: Border.all(color: JweTheme.accentRed.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _parseError!,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: JweTheme.accentRed,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // ── Primary Save Button ──────────────────────────
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: JweTheme.onAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isProcessing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(JweTheme.onAccent),
                          ),
                        )
                      : const Icon(MdiIcons.contentSaveCheck, size: 20),
                  label: Text(
                    _isProcessing ? 'VALIDATING & SAVING...' : 'PASTE & SAVE BRIEFING',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  onPressed: _isProcessing ? null : () => _pasteAndSaveBriefing(provider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(BriefingType type, String label, Color accent, bool isLight) {
    final selected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
            _parseError = null;
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isLight ? 0.22 : 0.28)
                : (isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E)),
            border: Border.all(
              color: selected
                  ? accent
                  : (isLight ? Colors.black.withValues(alpha: 0.15) : Colors.white24),
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: selected
                  ? (isLight ? Colors.black87 : Colors.white)
                  : (isLight ? const Color(0xFF475569) : Colors.white60),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isLight,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isLight ? 0.12 : 0.10),
          border: Border.all(color: color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.orbitron(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataBullet({
    required IconData icon,
    required String title,
    required String value,
    required Color accent,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: accent),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: JweTheme.textWhite,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  color: JweTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
