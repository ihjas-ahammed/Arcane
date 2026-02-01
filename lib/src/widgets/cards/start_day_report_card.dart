import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/system_metric_widget.dart';
import 'package:arcane/src/widgets/valorant/valorant_expansion_card.dart';
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
    // Parsing data
    final forecast = report['forecast'] as String? ?? report['briefing'] as String? ?? "Systems nominal.";
    
    final metricsRaw = report['metrics'] as List<dynamic>?;
    List<Map<String, dynamic>> metrics = [];
    if (metricsRaw != null) {
      metrics = metricsRaw.map((e) => e as Map<String, dynamic>).toList();
    }

    final directivesRaw = (report['directives'] as List<dynamic>?) ?? (report['projected_ops'] as List<dynamic>?);
    final directives = directivesRaw?.map((e) => e.toString()).toList() ?? [];

    return ValorantExpansionCard(
      title: "OPERATIONAL FORECAST",
      icon: MdiIcons.chartBellCurveCumulative,
      accentColor: AppTheme.fhAccentTeal,
      trailing: onRegenerate != null
          ? SizedBox(
              height: 24,
              width: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: isRegenerating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.fhAccentTeal))
                    : Icon(MdiIcons.refresh,
                        size: 16, color: AppTheme.fhTextSecondary),
                onPressed: isRegenerating ? null : onRegenerate,
                tooltip: "Re-calculate",
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Forecast Text (Compact)
          Text(
            forecast,
            style: const TextStyle(
                color: AppTheme.fhTextPrimary,
                height: 1.4,
                fontSize: 13,
                fontStyle: FontStyle.italic),
          ).animate().fadeIn(),

          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 12),
            // Compact Metrics Grid
            LayoutBuilder(
              builder: (context, constraints) {
                // Use a Grid or Row depending on count to save vertical space
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: metrics.map((m) {
                    Color? c;
                    if (m['color_hex'] != null) {
                      try {
                        String hex =
                            m['color_hex'].toString().replaceAll('#', '');
                        c = Color(int.parse("0xFF$hex"));
                      } catch (_) {}
                    }
                    // Mini metric widget
                    return SizedBox(
                      width: (constraints.maxWidth / 2) - 8, // 2 columns
                      child: SystemMetricWidget(
                        label: m['label'] ?? 'Metric',
                        value: (m['value'] as num? ?? 50).toInt(),
                        color: c,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],

          if (directives.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 12),
            const Text(
              "DIRECTIVES",
              style: TextStyle(
                  color: AppTheme.fhAccentPurple,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            ...directives.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Icon(MdiIcons.chevronRight,
                            size: 12, color: AppTheme.fhAccentPurple),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          d,
                          style: const TextStyle(
                              color: AppTheme.fhTextSecondary,
                              fontSize: 12,
                              height: 1.3),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}