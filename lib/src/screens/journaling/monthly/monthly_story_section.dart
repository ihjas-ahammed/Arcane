import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class MonthlyCreativeStoryWidget extends StatelessWidget {
  final Map<String, dynamic>? creativeStory;

  const MonthlyCreativeStoryWidget({
    super.key,
    required this.creativeStory,
  });

  @override
  Widget build(BuildContext context) {
    final storyMap = creativeStory;
    if (storyMap == null || (storyMap['story']?.toString() ?? '').isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudSectionHead(label: 'INSPIRATIONAL JOURNEY STORY', code: 'STR', accent: HudTone.amber),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: HudPanel(
            background: JweTheme.bgBase.withValues(alpha: 0.5),
            allBrackets: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.bookOpenVariant, size: 16, color: JweTheme.accentAmber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (storyMap['title']?.toString() ?? 'MONTHLY PARALLEL STORY').toUpperCase(),
                        style: GoogleFonts.saira(
                          color: JweTheme.accentAmber,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  storyMap['story']?.toString() ?? '',
                  style: TextStyle(
                    color: JweTheme.textWhite,
                    fontSize: 13,
                    height: 1.55,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if ((storyMap['takeaway']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: JweTheme.accentAmber.withValues(alpha: 0.08),
                      border: Border(left: BorderSide(color: JweTheme.accentAmber, width: 3)),
                    ),
                    child: Text(
                      'KEY LESSON: ${storyMap['takeaway']}',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.05, end: 0),
        ),
      ],
    );
  }
}

class MonthlyQuotedReflectionsWidget extends StatelessWidget {
  final List<dynamic> quoteReflections;

  const MonthlyQuotedReflectionsWidget({
    super.key,
    required this.quoteReflections,
  });

  @override
  Widget build(BuildContext context) {
    if (quoteReflections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudSectionHead(label: 'QUOTED HIGHLIGHTS & AI APPRECIATION', code: 'QUT', accent: HudTone.cyan),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: quoteReflections.map((item) {
              final map = item as Map<String, dynamic>;
              final userQuote = map['user_quote'] as String? ?? '';
              final aiComment = map['ai_comment'] as String? ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: JweTheme.bgBase.withValues(alpha: 0.5),
                  border: Border(left: BorderSide(color: JweTheme.accentCyan, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: JweTheme.accentCyan.withValues(alpha: 0.08),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(MdiIcons.formatQuoteOpen, size: 14, color: JweTheme.accentCyan),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '"$userQuote"',
                              style: GoogleFonts.inter(
                                color: JweTheme.textWhite,
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(MdiIcons.brain, size: 13, color: JweTheme.accentAmber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              aiComment,
                              style: GoogleFonts.inter(
                                color: JweTheme.textMid,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ).animate().fadeIn(delay: 240.ms),
        ),
      ],
    );
  }
}

class MonthlyStoryWidget extends StatelessWidget {
  final String narrative;

  const MonthlyStoryWidget({
    super.key,
    required this.narrative,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudSectionHead(label: 'THE STORY OF THE MONTH', code: 'LOG', accent: HudTone.cyan),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: HudPanel(
            background: JweTheme.bgBase.withValues(alpha: 0.5),
            allBrackets: false,
            padding: const EdgeInsets.all(16),
            child: Text(
              narrative,
              style: TextStyle(
                color: JweTheme.textWhite,
                fontSize: 13,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0),
        ),
      ],
    );
  }
}
