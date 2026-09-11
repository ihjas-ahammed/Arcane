import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class TacticalQuotesBriefingSection extends StatelessWidget {
  final List<dynamic> quoteReflections;

  const TacticalQuotesBriefingSection({
    super.key,
    required this.quoteReflections,
  });

  @override
  Widget build(BuildContext context) {
    if (quoteReflections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        HudSectionHead(
          label: 'QUOTED HIGHLIGHTS & AI APPRECIATION',
          accent: HudTone.cyan,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 10),
        ...quoteReflections.map((item) {
          final map = item as Map<String, dynamic>;
          final userQuote = map['user_quote'] as String? ?? '';
          final aiComment = map['ai_comment'] as String? ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: JweTheme.bgDeep.withValues(alpha: 0.6),
              border: Border(
                left: BorderSide(color: JweTheme.accentCyan, width: 3),
              ),
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
                      Icon(MdiIcons.formatQuoteOpen,
                          size: 14, color: JweTheme.accentCyan),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"$userQuote"',
                          style: GoogleFonts.inter(
                            color: JweTheme.textWhite,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
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
                      Icon(MdiIcons.brain,
                          size: 13, color: JweTheme.accentAmber),
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
          ).animate().fadeIn(duration: 400.ms);
        }),
      ],
    );
  }
}
