import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/ui/startup_wellbeing_metrics.dart';
import 'package:arcane/src/screens/nora_ai_screen.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final directives = (report['directives'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final metrics = report['metrics'] as List<dynamic>?;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        border: Border.all(color: JweTheme.accentCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: JweTheme.accentCyan.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: JweTheme.accentCyan.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                 Icon(MdiIcons.power, color: JweTheme.accentCyan, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "SYSTEM STARTUP OVERVIEW",
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: JweTheme.accentCyan,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                if (onRegenerate != null)
                  InkWell(
                    onTap: isRegenerating ? null : onRegenerate,
                    child: isRegenerating 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: JweTheme.accentCyan))
                      :  Icon(MdiIcons.refresh, size: 16, color: JweTheme.textMuted),
                  )
              ],
            ),
          ),

          // BODY
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Forecast Text
                const Text("AI FORECAST", style: TextStyle(color: JweTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const SizedBox(height: 6),
                Text(
                  forecast,
                  style: const TextStyle(
                    color: JweTheme.textWhite,
                    height: 1.4,
                    fontSize: 12,
                    fontFamily: "RobotoMono"
                  ),
                ),

                if (directives.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text("DIRECTIVES", style: TextStyle(color: JweTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 6),
                  ...directives.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("> ", style: TextStyle(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                        Expanded(child: Text(d, style: const TextStyle(color: JweTheme.textWhite, fontSize: 12, height: 1.3))),
                      ],
                    ),
                  )),
                ],

                const SizedBox(height: 16),

                // METRICS
                if (metrics != null)
                  StartupWellbeingMetrics(metrics: metrics),

                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon:  Icon(MdiIcons.brain, size: 14),
                    label: Text("INITIATE NORA LINK", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: JweTheme.accentCyan,
                      side: const BorderSide(color: JweTheme.accentCyan),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const BeveledRectangleBorder(),
                    ),
                    onPressed: () => _startWithNora(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }
}