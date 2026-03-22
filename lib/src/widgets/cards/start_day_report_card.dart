import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/startup_wellbeing_metrics.dart';
import 'package:arcane/src/screens/nora_ai_screen.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';
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

  void _startWithNora(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final forecast = report['forecast'] as String? ?? "System Started.";
    final directives = (report['directives'] as List?)?.join(', ') ?? "";
    
    final customContext = """
    STARTUP CONTEXT:
    Forecast: $forecast
    Directives: $directives
    
    The user has just initiated the system. Act as a supportive tactical commander or friend to prepare them for the day.
    """;
    
    provider.createNoraSession(
      title: "STARTUP LINK",
      tone: "Tactician",
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      endDate: DateTime.now(),
      customContext: customContext,
    );
    
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NoraAiScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final forecast = report['forecast'] as String? ?? report['briefing'] as String? ?? "Systems nominal. Ready for input.";

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

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: Icon(MdiIcons.brain, size: 16),
                    label: const Text("START WITH NORA", style: TextStyle(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.fhAccentPurple,
                      side: BorderSide(color: AppTheme.fhAccentPurple.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                    ),
                    onPressed: () => _startWithNora(context),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms),

                const SizedBox(height: 20),

                // COMPACT JWE DIVERGING BAR CHART
                const StartupWellbeingMetrics(),
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