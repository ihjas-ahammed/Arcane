import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class JournalHomeWidget extends StatelessWidget {
  final int count;
  final bool wake;
  final bool morn;
  final bool aft;
  final bool eve;
  final bool night;

  const JournalHomeWidget({
    super.key,
    required this.count,
    required this.wake,
    required this.morn,
    required this.aft,
    required this.eve,
    required this.night,
  });

  @override
  Widget build(BuildContext context) {
    final todayCount = [wake, morn, aft, eve, night].where((e) => e).length;

    final bgPanel = JweTheme.isLight ? JweTheme.panel : const Color(0xFF0D1426);
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 400,
        height: 200,
        child: ClipPath(
          clipper: const Chamfer4CornerClipper(chamfer: 10),
          child: CustomPaint(
            foregroundPainter: TacticalCardBorderPainter(
              themeColor: AppTheme.fhAccentTeal,
              chamfer: 10,
              bracketSize: 12,
              leftBarWidth: 3.0,
            ),
            child: Container(
              color: bgPanel,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        color: AppTheme.fhAccentTeal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "// REFLECTION LOG",
                          style: TextStyle(
                            color: AppTheme.fhAccentTeal,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "$count ${count == 1 ? 'ENTRY' : 'ENTRIES'}",
                  style: TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "REFLECTION PROTOCOL",
                    style: TextStyle(
                      color: AppTheme.fhTextSecondary,
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "$todayCount/5 COMPLETE",
                  style: TextStyle(
                    color: AppTheme.fhAccentTeal,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Progress segments
            Row(
              children: [
                Expanded(child: _buildSegment("WAKE", wake)),
                const SizedBox(width: 6),
                Expanded(child: _buildSegment("MORN", morn)),
                const SizedBox(width: 6),
                Expanded(child: _buildSegment("AFT", aft)),
                const SizedBox(width: 6),
                Expanded(child: _buildSegment("EVE", eve)),
                const SizedBox(width: 6),
                Expanded(child: _buildSegment("NIGHT", night)),
              ],
            ),
            const Spacer(),
            // Buttons Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhAccentTeal, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "+ NEW LOG",
                      style: TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 100,
                  height: 32,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.fhAccentGold, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "ARCHIVE",
                    style: TextStyle(
                      color: AppTheme.fhAccentGold,
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
),
);
  }

  Widget _buildSegment(String label, bool isComplete) {
    return Column(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: isComplete ? AppTheme.fhAccentTeal : AppTheme.fhBgMedium,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isComplete ? AppTheme.fhAccentTeal : AppTheme.fhTextSecondary,
            fontSize: 9,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
