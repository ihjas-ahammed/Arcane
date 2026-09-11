import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/utils/task_calculations.dart';

class RunningTaskCheckableList extends StatelessWidget {
  final List<ResolvedDayPlanItem> topFiveTasks;
  final String capacity;
  final Color neonCyan;
  final Color textMuted;

  const RunningTaskCheckableList({
    super.key,
    required this.topFiveTasks,
    required this.capacity,
    required this.neonCyan,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 400,
        height: 200,
        child: ClipPath(
          clipper: const Chamfer4CornerClipper(chamfer: 10.0),
          child: CustomPaint(
            foregroundPainter: TacticalCardBorderPainter(
              themeColor: neonCyan,
              chamfer: 10.0,
              bracketSize: 12.0,
            ),
            child: Container(
              color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: neonCyan.withValues(alpha: 0.25))),
                    ),
                    child: Row(
                      children: [
                        const HudDot(tone: HudTone.cyan),
                        const SizedBox(width: 8),
                        Text(
                          'DAY PLAN // TACTICAL DISPATCH',
                          style: GoogleFonts.rajdhani(
                            color: neonCyan,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const Spacer(),
                        if (capacity.isNotEmpty)
                          Text(
                            'CAP $capacity',
                            style: GoogleFonts.rajdhani(
                              color: textMuted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // List of top 5 tasks
                  Expanded(
                    child: topFiveTasks.isEmpty
                        ? Center(
                            child: Text(
                              'NO ACTIVE PLAN',
                              style: GoogleFonts.teko(
                                color: textMuted,
                                fontSize: 18,
                                letterSpacing: 1.2,
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Column(
                              children: List.generate(5, (index) {
                                if (index >= topFiveTasks.length) {
                                  return const SizedBox(height: 26);
                                }
                                final item = topFiveTasks[index];
                                return Container(
                                  height: 26,
                                  margin: const EdgeInsets.only(bottom: 2),
                                  child: Row(
                                    children: [
                                      // Task Indicator / Color bar
                                      Container(
                                        width: 3,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: item.color,
                                          borderRadius: BorderRadius.circular(1),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Task details (Name & Subtitle)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              item.name.toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.rajdhani(
                                                color: JweTheme.textWhite,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              item.parentName.toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.rajdhani(
                                                color: textMuted,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Checkbox representation
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: neonCyan,
                                            width: 1.2,
                                          ),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 11,
                                          color: Colors.transparent,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
