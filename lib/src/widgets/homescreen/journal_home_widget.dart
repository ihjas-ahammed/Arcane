import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';

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

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          border: Border.all(color: AppTheme.fhAccentTeal, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      color: AppTheme.fhAccentTeal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "// REFLECTION LOG",
                      style: TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
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
                Text(
                  "REFLECTION PROTOCOL",
                  style: TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
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
