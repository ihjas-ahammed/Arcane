import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Header section above dispatch timetable with run counts and filter controls
class BusTimetableHeader extends StatelessWidget {
  final int runsCount;
  final String filterMode;
  final bool isEditMode;
  final VoidCallback onToggleFilterMode;
  final VoidCallback onToggleEditMode;
  final VoidCallback onAddTime;

  const BusTimetableHeader({
    super.key,
    required this.runsCount,
    required this.filterMode,
    required this.isEditMode,
    required this.onToggleFilterMode,
    required this.onToggleEditMode,
    required this.onAddTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(MdiIcons.clockOutline, size: 14, color: JweTheme.accentAmber),
            const SizedBox(width: 6),
            Text(
              "DISPATCH TIMETABLE",
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: JweTheme.textWhite,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: JweTheme.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "$runsCount RUNS",
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.0,
                  fontWeight: FontWeight.bold,
                  color: JweTheme.accentAmber,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Upcoming vs All Filter Chip
            GestureDetector(
              onTap: onToggleFilterMode,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: filterMode == "UPCOMING"
                      ? JweTheme.accentCyan.withValues(alpha: 0.15)
                      : Colors.transparent,
                  border: Border.all(
                    color: filterMode == "UPCOMING"
                        ? JweTheme.accentCyan
                        : JweTheme.border,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  filterMode == "UPCOMING" ? 'UPCOMING' : 'ALL',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                    color: filterMode == "UPCOMING"
                        ? JweTheme.accentCyan
                        : JweTheme.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (isEditMode)
              IconButton(
                icon: Icon(MdiIcons.plusBoxOutline, color: JweTheme.accentAmber, size: 20),
                onPressed: onAddTime,
              ),
            IconButton(
              icon: Icon(
                isEditMode ? MdiIcons.check : MdiIcons.pencilOutline,
                color: isEditMode ? JweTheme.accentCyan : JweTheme.textMuted,
                size: 19,
              ),
              onPressed: onToggleEditMode,
            ),
          ],
        ),
      ],
    );
  }
}
