import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class GratitudeIntelCard extends StatelessWidget {
  final String text;
  final String iconType;
  final int index;

  const GratitudeIntelCard({
    super.key,
    required this.text,
    required this.iconType,
    required this.index,
  });

  static IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'people':   return MdiIcons.accountGroup;
      case 'nature':   return MdiIcons.leaf;
      case 'health':   return MdiIcons.heartPulse;
      case 'learning': return MdiIcons.bookOpenVariant;
      case 'work':     return MdiIcons.briefcaseOutline;
      case 'home':     return MdiIcons.homeOutline;
      case 'food':     return MdiIcons.foodApple;
      case 'social':   return MdiIcons.messageTextOutline;
      case 'growth':   return MdiIcons.trendingUp;
      case 'mind':     return MdiIcons.brain;
      case 'moment':   return MdiIcons.clockOutline;
      default:         return MdiIcons.starFourPoints;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(iconType);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: JweTheme.accentTeal.withValues(alpha: 0.04),
        border: Border(
          left: BorderSide(color: JweTheme.accentTeal.withValues(alpha: 0.6), width: 2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: JweTheme.accentTeal.withValues(alpha: 0.10),
              border: Border.all(
                  color: JweTheme.accentTeal.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, size: 13, color: JweTheme.accentTeal),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                Text(
                  text,
                  style: GoogleFonts.inter(
                    color: JweTheme.textWhite,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
