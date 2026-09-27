import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

/// Shows tomorrow's most likely friction point plus a concrete if-then plan,
/// derived from today's tactical briefing. Hides cleanly when the AI response
/// (or an older saved briefing) has no contingency data.
class TacticalContingencyBriefingSection extends StatelessWidget {
  final Map<String, dynamic>? contingency;

  const TacticalContingencyBriefingSection({
    super.key,
    required this.contingency,
  });

  @override
  Widget build(BuildContext context) {
    final risk = contingency?['risk']?.toString().trim() ?? '';
    final ifThen = contingency?['if_then']?.toString().trim() ?? '';
    if (risk.isEmpty && ifThen.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        HudSectionHead(
          label: 'CONTINGENCY FOR TOMORROW',
          accent: HudTone.red,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: JweTheme.bgDeep.withValues(alpha: 0.65),
            border: Border(left: BorderSide(color: JweTheme.accentRed, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (risk.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: JweTheme.accentRed.withValues(alpha: 0.10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(MdiIcons.alertOutline, size: 13, color: JweTheme.accentRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          risk,
                          style: GoogleFonts.inter(
                            color: JweTheme.textWhite,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (ifThen.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(MdiIcons.arrowRightBottom, size: 14, color: JweTheme.accentAmber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ifThen,
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontSize: 12.5,
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
        ).animate().fadeIn(duration: 400.ms),
      ],
    );
  }
}
