import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class TacticalGratitudeBriefingSection extends StatelessWidget {
  final List<dynamic> gratefulToday;

  const TacticalGratitudeBriefingSection({
    super.key,
    required this.gratefulToday,
  });

  static IconData getIcon(String type) {
    switch (type) {
      case 'people':
        return MdiIcons.accountGroup;
      case 'nature':
        return MdiIcons.leaf;
      case 'health':
        return MdiIcons.heartPulse;
      case 'learning':
        return MdiIcons.bookOpenVariant;
      case 'work':
        return MdiIcons.briefcaseOutline;
      case 'home':
        return MdiIcons.homeOutline;
      case 'food':
        return MdiIcons.foodApple;
      case 'social':
        return MdiIcons.messageTextOutline;
      case 'growth':
        return MdiIcons.trendingUp;
      case 'mind':
        return MdiIcons.brain;
      case 'moment':
        return MdiIcons.clockOutline;
      default:
        return MdiIcons.heartOutline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (gratefulToday.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        HudSectionHead(
          label: 'GRATITUDE INTEL (${gratefulToday.length} NOTES)',
          accent: HudTone.teal,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(gratefulToday.length, (i) {
            final rawItem = gratefulToday[i];
            final item = rawItem is Map<String, dynamic>
                ? rawItem
                : (rawItem is Map ? Map<String, dynamic>.from(rawItem) : {'text': rawItem.toString()});
            final text = (item['text'] as String?)?.isNotEmpty == true
                ? item['text'] as String
                : (item['name'] ?? item['why'] ?? item['reason'] ?? '').toString();
            if (text.isEmpty) return const SizedBox.shrink();
            final iconType = item['icon_type']?.toString().toLowerCase() ?? 'general';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: JweTheme.accentTeal.withValues(alpha: 0.08),
                border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(getIcon(iconType), size: 13, color: JweTheme.accentTeal),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: GoogleFonts.inter(
                      color: JweTheme.textWhite,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ).animate().fadeIn(duration: 400.ms),
      ],
    );
  }
}
