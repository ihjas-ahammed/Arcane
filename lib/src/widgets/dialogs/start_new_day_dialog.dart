import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/dialogs/create_time_log_start_dialog.dart';
import 'package:provider/provider.dart';

class StartNewDayDialog extends StatefulWidget {
  final String date;

  const StartNewDayDialog({
    super.key,
    required this.date,
  });

  static Future<void> show(BuildContext context, {required String date}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => StartNewDayDialog(date: date),
    );
  }

  @override
  State<StartNewDayDialog> createState() => _StartNewDayDialogState();
}

class _StartNewDayDialogState extends State<StartNewDayDialog> {
  late TextEditingController _noteController;
  late TextEditingController _directiveInputController;
  final List<String> _directives = [];
  bool _isGeneratingAi = false;
  String? _motivationalQuote;
  String? _quoteAuthor;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _directiveInputController = TextEditingController();

    final provider = context.read<AppProvider>();
    final report = provider.getStartDayReport(widget.date);

    if (report != null) {
      final forecast = report['forecast']?.toString() ?? report['briefing']?.toString() ?? '';
      _noteController.text = forecast;

      if (report['directives'] is List) {
        for (final d in report['directives'] as List) {
          final s = d.toString().trim();
          if (s.isNotEmpty) _directives.add(s);
        }
      }

      if (report['motivational_quote'] is Map) {
        final q = report['motivational_quote'] as Map;
        _motivationalQuote = q['quote']?.toString();
        _quoteAuthor = q['author']?.toString();
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _directiveInputController.dispose();
    super.dispose();
  }

  Future<void> _generateWithAi() async {
    setState(() => _isGeneratingAi = true);
    final provider = context.read<AppProvider>();
    try {
      await provider.reportActions.generateStartDayReport();
      if (!mounted) return;
      final updatedReport = provider.getStartDayReport(widget.date);
      if (updatedReport != null) {
        final forecast = updatedReport['forecast']?.toString() ?? '';
        _noteController.text = forecast;
        _directives.clear();
        if (updatedReport['directives'] is List) {
          for (final d in updatedReport['directives'] as List) {
            final s = d.toString().trim();
            if (s.isNotEmpty) _directives.add(s);
          }
        }
        if (updatedReport['motivational_quote'] is Map) {
          final q = updatedReport['motivational_quote'] as Map;
          _motivationalQuote = q['quote']?.toString();
          _quoteAuthor = q['author']?.toString();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: JweTheme.accentRed,
            content: Text("AI Generation failed: $e"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  void _addDirective() {
    final text = _directiveInputController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _directives.add(text);
        _directiveInputController.clear();
      });
    }
  }

  void _removeDirective(int index) {
    setState(() {
      _directives.removeAt(index);
    });
  }

  void _commenceDay() {
    final provider = context.read<AppProvider>();
    provider.startNewDayForDate(
      widget.date,
      startupNote: _noteController.text.trim(),
      directives: _directives,
    );

    Navigator.of(context).pop();

    final timeStr = DateFormat('HH:mm').format(DateTime.now());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: JweTheme.accentCyan,
        content: Text(
          "Day initialized at $timeStr. Task progress tracking active from this moment forward.",
          style: GoogleFonts.rajdhani(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse(widget.date) ?? DateTime.now();
    final dateDisplay = DateFormat('EEEE, dd MMM yyyy').format(d).toUpperCase();

    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: JweTheme.accentCyan.withValues(alpha: 0.4), width: 1.2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: JweTheme.accentCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.5)),
            ),
            child: Icon(MdiIcons.power, color: JweTheme.accentCyan, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "START A NEW DAY",
                  style: GoogleFonts.rajdhani(
                    color: JweTheme.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.4,
                  ),
                ),
                Text(
                  dateDisplay,
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentCyan,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),

              // Operational notice banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JweTheme.bgDeep.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: JweTheme.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(MdiIcons.informationOutline, size: 16, color: JweTheme.accentAmber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Starting this day locks in your task baseline right now. Every checkbox checked and timer logged from this moment forward will count cleanly toward today's task progress.",
                        style: TextStyle(
                          color: JweTheme.textMid,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Startup Note Section
              Row(
                children: [
                  Container(width: 3, height: 12, color: JweTheme.accentCyan),
                  const SizedBox(width: 8),
                  Text(
                    "STARTUP NOTE & TACTICAL FOCUS",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  if (_isGeneratingAi)
                    Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(JweTheme.accentAmber),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "SYNTHESIZING...",
                          style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 9.5),
                        ),
                      ],
                    )
                  else
                    InkWell(
                      onTap: _generateWithAi,
                      borderRadius: BorderRadius.circular(3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            Icon(MdiIcons.brain, size: 12, color: JweTheme.accentAmber),
                            const SizedBox(width: 4),
                            Text(
                              "+ AI GENERATE",
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
              const SizedBox(height: 8),

              TextField(
                controller: _noteController,
                maxLines: 4,
                style: GoogleFonts.inter(
                  color: JweTheme.textWhite,
                  fontSize: 12.5,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: "Enter your startup directives, mindset, or daily focus notes...",
                  hintStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: JweTheme.bgDeep.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: JweTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: JweTheme.accentCyan),
                  ),
                ),
              ),

              // Motivational quote if present
              if (_motivationalQuote != null && _motivationalQuote!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: JweTheme.bgDeep.withValues(alpha: 0.4),
                    border: Border(left: BorderSide(color: JweTheme.accentAmber, width: 2.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "\"$_motivationalQuote\"",
                        style: GoogleFonts.lora(
                          color: JweTheme.textWhite,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                        ),
                      ),
                      if (_quoteAuthor != null && _quoteAuthor!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "— $_quoteAuthor",
                            style: GoogleFonts.rajdhani(
                              color: JweTheme.accentAmber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Morning Directives Section
              Row(
                children: [
                  Container(width: 3, height: 12, color: JweTheme.accentAmber),
                  const SizedBox(width: 8),
                  Text(
                    "MORNING DIRECTIVES (${_directives.length})",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_directives.isNotEmpty)
                Column(
                  children: List.generate(_directives.length, (idx) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: JweTheme.bgDeep.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: JweTheme.border.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(MdiIcons.chevronRight, size: 14, color: JweTheme.accentAmber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _directives[idx],
                              style: TextStyle(
                                color: JweTheme.textWhite,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _removeDirective(idx),
                            child: Icon(MdiIcons.close, size: 14, color: JweTheme.textMuted),
                          ),
                        ],
                      ),
                    );
                  }),
                ),

              // Add directive field
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _directiveInputController,
                      style: TextStyle(color: JweTheme.textWhite, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "Add specific directive...",
                        hintStyle: TextStyle(color: JweTheme.textMuted, fontSize: 11.5),
                        isDense: true,
                        filled: true,
                        fillColor: JweTheme.bgDeep.withValues(alpha: 0.3),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(3),
                          borderSide: BorderSide(color: JweTheme.border),
                        ),
                      ),
                      onSubmitted: (_) => _addDirective(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _addDirective,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: JweTheme.accentAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.5)),
                      ),
                      child: Icon(MdiIcons.plus, size: 16, color: JweTheme.accentAmber),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Optional Backfill Link
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: JweTheme.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    CreateTimeLogStartDialog.show(context);
                  },
                  icon: const Icon(MdiIcons.history, size: 13),
                  label: Text(
                    "Checked tasks earlier today? Backfill completed tasks instead",
                    style: TextStyle(fontSize: 11, decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            "CANCEL",
            style: GoogleFonts.rajdhani(
              color: JweTheme.textMuted,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: JweTheme.accentCyan,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          onPressed: _commenceDay,
          icon: const Icon(MdiIcons.playCircleOutline, size: 18),
          label: Text(
            "COMMENCE DAY & START TRACKING",
            style: GoogleFonts.rajdhani(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
