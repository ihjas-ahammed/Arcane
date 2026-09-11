import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class StartDayInspirationSection extends StatelessWidget {
  final String yesterdayQuote;
  final String aiTodayAdvice;
  final Map<String, dynamic>? motivationalQuote;

  const StartDayInspirationSection({
    super.key,
    required this.yesterdayQuote,
    required this.aiTodayAdvice,
    this.motivationalQuote,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Yesterday Quote vs AI Response for Today
        if (yesterdayQuote.isNotEmpty || aiTodayAdvice.isNotEmpty) ...[
          Row(
            children: [
              Container(width: 3, height: 10, color: JweTheme.accentAmber),
              const SizedBox(width: 8),
              Text(
                "YESTERDAY'S HIGHLIGHT & TODAY'S AI INSPIRATION",
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentAmber,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: JweTheme.bgDeep.withValues(alpha: 0.65),
              border: Border(left: BorderSide(color: JweTheme.accentAmber, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (yesterdayQuote.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    color: JweTheme.accentAmber.withValues(alpha: 0.08),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(MdiIcons.formatQuoteOpen, size: 14, color: JweTheme.accentAmber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '"$yesterdayQuote"',
                            style: GoogleFonts.inter(
                              color: JweTheme.textWhite,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (aiTodayAdvice.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(MdiIcons.lightningBolt, size: 14, color: JweTheme.accentCyan),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            aiTodayAdvice,
                            style: GoogleFonts.inter(
                              color: JweTheme.accentCyan,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Motivational Quote from Famous Scientist/Philosopher/Writer
        if (motivationalQuote != null && (motivationalQuote!['quote']?.toString() ?? '').isNotEmpty) ...[
          Row(
            children: [
              Container(width: 3, height: 10, color: JweTheme.accentTeal),
              const SizedBox(width: 8),
              Text(
                'MOMENTUM QUOTE OF THE DAY',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentTeal,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JweTheme.accentTeal.withValues(alpha: 0.05),
              border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${motivationalQuote!['quote']}"',
                  style: GoogleFonts.inter(
                    color: JweTheme.textWhite,
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '— ${motivationalQuote!['author'] ?? 'Unknown'}',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentTeal,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}
