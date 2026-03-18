import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/theme/wellbeing_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

class StartupWellbeingMetrics extends StatelessWidget {
  const StartupWellbeingMetrics({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final now = DateTime.now();
    final last7 = now.subtract(const Duration(days: 7));
    final prev7 = now.subtract(const Duration(days: 14));
    
    Map<String, int> currentXp = {};
    Map<String, int> prevXp = {};
    
    for (var log in provider.reflectionLogs) {
      if (log.timestamp.isAfter(last7)) {
        log.xpGained.forEach((k, v) => currentXp[k] = (currentXp[k] ?? 0) + v);
      } else if (log.timestamp.isAfter(prev7) && log.timestamp.isBefore(last7)) {
        log.xpGained.forEach((k, v) => prevXp[k] = (prevXp[k] ?? 0) + v);
      }
    }

    final skills = provider.getBaseWellbeingSkills();
    List<Map<String, dynamic>> deltas = [];
    int maxAbsDelta = 1;

    for (var skill in skills) {
      final current = currentXp[skill.name] ?? 0;
      final previous = prevXp[skill.name] ?? 0;
      final delta = current - previous;
      if (delta.abs() > maxAbsDelta) maxAbsDelta = delta.abs();
      deltas.add({'name': skill.name, 'delta': delta, 'color': WellbeingTheme.getColor(skill.name)});
    }

    deltas.sort((a, b) => (b['delta'] as int).compareTo(a['delta'] as int));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "WELL-BEING TRAJECTORY (7-DAY)",
          style: TextStyle(
            color: JweTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5
          ),
        ),
        const SizedBox(height: 12),
        ...deltas.map((d) {
          final delta = d['delta'] as int;
          if (delta == 0) return const SizedBox.shrink(); 

          final fraction = (delta.abs() / maxAbsDelta).clamp(0.0, 1.0);
          final isPositive = delta > 0;
          final color = d['color'] as Color;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    d['name'].toString().toUpperCase(),
                    style: GoogleFonts.rajdhani(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return SizedBox(
                        height: 6,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(width: 1, height: 8, color: JweTheme.border), // Center line
                            if (isPositive)
                              Positioned(
                                left: width / 2,
                                child: Container(
                                  height: 6,
                                  width: (width / 2) * fraction,
                                  color: color,
                                ),
                              )
                            else
                              Positioned(
                                right: width / 2,
                                child: Container(
                                  height: 6,
                                  width: (width / 2) * fraction,
                                  color: color,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}