import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/system_metric_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class StartDayReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback? onRegenerate;
  final bool isRegenerating;

  const StartDayReportCard({
    super.key, 
    required this.report, 
    this.onRegenerate,
    this.isRegenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    // Legacy support or fallback if fields missing
    final forecast = report['forecast'] as String? ?? report['briefing'] as String? ?? "Systems nominal. Ready for input.";
    
    final metricsRaw = report['metrics'] as List<dynamic>?;
    List<Map<String, dynamic>> metrics = [];
    if (metricsRaw != null) {
      metrics = metricsRaw.map((e) => e as Map<String, dynamic>).toList();
    }

    final directivesRaw = (report['directives'] as List<dynamic>?) ?? (report['projected_ops'] as List<dynamic>?);
    final directives = directivesRaw?.map((e) => e.toString()).toList() ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.fhAccentTeal.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.fhAccentTeal.withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.fhAccentTeal.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppTheme.fhAccentTeal.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Icon(MdiIcons.chartBellCurveCumulative, color: AppTheme.fhAccentTeal, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "OPERATIONAL FORECAST",
                    style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.fhTextPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                if (onRegenerate != null)
                  IconButton(
                    icon: isRegenerating 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fhAccentTeal))
                      : Icon(MdiIcons.refresh, size: 20, color: AppTheme.fhTextSecondary),
                    onPressed: isRegenerating ? null : onRegenerate,
                    tooltip: "Re-calculate",
                  )
              ],
            ),
          ),

          // FORECAST BODY
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgDeepDark,
                    border: Border(left: BorderSide(color: AppTheme.fhAccentTeal, width: 3)),
                  ),
                  child: Text(
                    forecast,
                    style: const TextStyle(
                      color: AppTheme.fhTextPrimary,
                      height: 1.5,
                      fontSize: 14,
                      fontStyle: FontStyle.italic
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms),

                const SizedBox(height: 24),

                // METRICS
                if (metrics.isNotEmpty) ...[
                  const Text(
                    "SYSTEM STATUS",
                    style: TextStyle(
                      color: AppTheme.fhTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...metrics.map((m) {
                    // Try parse color
                    Color? c;
                    if (m['color_hex'] != null) {
                      try {
                        String hex = m['color_hex'].toString().replaceAll('#', '');
                        c = Color(int.parse("0xFF$hex"));
                      } catch (_) {}
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: SystemMetricWidget(
                        label: m['label'] ?? 'Metric',
                        value: (m['value'] as num? ?? 50).toInt(),
                        color: c,
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                // DIRECTIVES
                if (directives.isNotEmpty) ...[
                  const Text(
                    "TACTICAL DIRECTIVES",
                    style: TextStyle(
                      color: AppTheme.fhAccentPurple,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...directives.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Icon(MdiIcons.chevronRight, size: 14, color: AppTheme.fhAccentPurple),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d,
                            style: const TextStyle(
                              color: AppTheme.fhTextPrimary,
                              fontSize: 13,
                              height: 1.3
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }
}