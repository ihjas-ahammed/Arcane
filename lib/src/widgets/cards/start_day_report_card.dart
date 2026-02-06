import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/system_metric_widget.dart';
import 'package:arcane/src/widgets/ui/tactical_directives_list.dart';
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
      decoration: BoxDecoration(
        color: AppTheme.fhBgDeepDark,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomRight: Radius.circular(16)
        ),
        border: Border.all(color: AppTheme.fhAccentTeal.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.fhAccentTeal.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 0,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.fhBgDark,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppTheme.fhAccentTeal.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Icon(MdiIcons.chartBellCurveCumulative, color: AppTheme.fhAccentTeal, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "OPERATIONAL FORECAST",
                    style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.fhTextPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                if (onRegenerate != null)
                  IconButton(
                    icon: isRegenerating 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fhAccentTeal))
                      : Icon(MdiIcons.refresh, size: 18, color: AppTheme.fhTextSecondary),
                    onPressed: isRegenerating ? null : onRegenerate,
                    tooltip: "Re-calculate",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
              ],
            ),
          ),

          // FORECAST BODY
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Forecast Text
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgDark.withValues(alpha: 0.5),
                    border: Border(left: BorderSide(color: AppTheme.fhAccentTeal, width: 2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SYSTEM PREDICTION", style: TextStyle(color: AppTheme.fhAccentTeal, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      const SizedBox(height: 8),
                      Text(
                        forecast,
                        style: const TextStyle(
                          color: AppTheme.fhTextPrimary,
                          height: 1.4,
                          fontSize: 13,
                          fontFamily: "RobotoMono"
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 600.ms),

                const SizedBox(height: 20),

                // METRICS & DIRECTIVES GRID (Responsive logic via Column for mobile)
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
                  const SizedBox(height: 20),
                ],

                // DIRECTIVES
                if (directives.isNotEmpty)
                  TacticalDirectivesList(directives: directives),
              ],
            ),
          ),
          
          // Decorative footer line
          Container(
            height: 2,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.fhAccentTeal.withValues(alpha: 0.5), Colors.transparent]
              )
            ),
          )
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }
}