import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class StartupWellbeingMetrics extends StatelessWidget {
  final List<dynamic> metrics;

  const StartupWellbeingMetrics({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    // Sort by magnitude of delta to highlight biggest changes
    final sorted = List<dynamic>.from(metrics)
      ..sort((a, b) => ((b['delta'] as num).abs()).compareTo((a['delta'] as num).abs()));
      
    // Take top 6 for compactness
    final topMetrics = sorted.take(6).toList();

    int maxAbsDelta = 1;
    for (var m in topMetrics) {
      final d = (m['delta'] as num).abs().toInt();
      if (d > maxAbsDelta) maxAbsDelta = d;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "MOMENTUM SHIFT (YESTERDAY VS TODAY)",
          style: TextStyle(
            color: JweTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: JweTheme.bgBase,
            border: Border.all(color: JweTheme.border),
          ),
          child: Column(
            children: topMetrics.map((m) {
              final delta = (m['delta'] as num).toInt();
              if (delta == 0) return const SizedBox.shrink();

              final fraction = (delta.abs() / maxAbsDelta).clamp(0.0, 1.0);
              final isPositive = delta > 0;
              final color = isPositive ? JweTheme.accentCyan : JweTheme.accentAmber;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        m['name'].toString().toUpperCase(),
                        style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontSize: 11, fontWeight: FontWeight.bold),
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
                                      height: 4,
                                      width: (width / 2) * fraction,
                                      color: color,
                                    ),
                                  )
                                else
                                  Positioned(
                                    right: width / 2,
                                    child: Container(
                                      height: 4,
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
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 35,
                      child: Text(
                        "${isPositive ? '+' : ''}$delta",
                        textAlign: TextAlign.right,
                        style: GoogleFonts.robotoMono(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}