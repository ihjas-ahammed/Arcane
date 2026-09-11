import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/health_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/health/add_activity_dialog.dart';
import 'package:missions/src/widgets/health/add_sleep_dialog.dart';
import 'package:missions/src/widgets/health/circadian_advisor_card.dart';
import 'package:missions/src/widgets/health/energy_panel.dart';
import 'package:missions/src/widgets/health/health_combined_chart.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class HealthLogsTab extends StatelessWidget {
  final AppProvider provider;
  final DailyHealthLog log;
  final String dateStr;
  final DateTime selectedDate;
  final Color accent;
  final double bottomPadding;

  const HealthLogsTab({
    super.key,
    required this.provider,
    required this.log,
    required this.dateStr,
    required this.selectedDate,
    required this.accent,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final totalSleepMinutes = log.sleepLogs.fold(0, (sum, item) => sum + item.durationMinutes);
    final nightSleepMinutes = log.sleepLogs.where((s) => !s.isNap).fold(0, (sum, item) => sum + item.durationMinutes);
    final napMinutes = log.sleepLogs.where((s) => s.isNap).fold(0, (sum, item) => sum + item.durationMinutes);
    final workoutMinutes = log.activityLogs.fold(0, (sum, item) => sum + item.workoutMinutes);
    final distanceKm = log.activityLogs.fold(0.0, (sum, item) => sum + item.walkDistanceKm);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 7-Day Trend Chart
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentCyan,
            brackets: true,
            allBrackets: false,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HEALTH TREND ANALYSIS (7-DAY)',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentCyan,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: HealthCombinedChart(provider: provider),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Hydration Panel
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentCyan,
            brackets: true,
            allBrackets: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'HYDRATION TELEMETRY',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentCyan,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, color: JweTheme.textMuted),
                      onPressed: () => provider.updateWater(dateStr, (log.waterGlasses - 1).clamp(0, 99)),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "${log.waterGlasses}",
                      style: GoogleFonts.rajdhani(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: JweTheme.textWhite,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: Icon(Icons.add, color: JweTheme.accentCyan),
                      onPressed: () => provider.updateWater(dateStr, log.waterGlasses + 1),
                    ),
                  ],
                ),
                Center(
                  child: Text(
                    "GLASSES COMPLETED (${log.waterGlasses * 250} ml / 2000 ml target)",
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      color: JweTheme.textMuted,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sleep Metrics Panel
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentCyan,
            brackets: true,
            allBrackets: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SLEEP MONITORING',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      "${(totalSleepMinutes / 60).floor()}H ${totalSleepMinutes % 60}M",
                      style: GoogleFonts.chakraPetch(
                        color: JweTheme.accentCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (napMinutes > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BREAKDOWN',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        "Night: ${(nightSleepMinutes / 60).floor()}h ${nightSleepMinutes % 60}m • Nap: ${napMinutes}m",
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMid,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (log.sleepLogs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "NO SLEEP SESSIONS LOGGED TODAY.",
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...log.sleepLogs.map((s) {
                    final isNap = s.isNap;
                    final rowAccent = isNap ? JweTheme.accentAmber : JweTheme.accentCyan;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: JweTheme.bgCanvas.withValues(alpha: 0.3),
                        child: Row(
                          children: [
                            Icon(
                              isNap ? MdiIcons.batteryChargingOutline : MdiIcons.bedOutline,
                              size: 14,
                              color: rowAccent,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: rowAccent.withValues(alpha: 0.15),
                                border: Border.all(color: rowAccent.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                isNap ? 'NAP' : 'NIGHT',
                                style: GoogleFonts.jetBrainsMono(
                                  color: rowAccent,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                "${DateFormat('HH:mm').format(s.startTime)} — ${DateFormat('HH:mm').format(s.endTime)} (${(s.durationMinutes / 60).floor()}h ${s.durationMinutes % 60}m)",
                                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 10.5),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: JweTheme.accentRed, size: 14),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => provider.deleteSleepLog(dateStr, s.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('RECORD SLEEP'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: JweTheme.accentCyan,
                          side: BorderSide(color: JweTheme.accentCyan.withValues(alpha: 0.5)),
                          shape: const BeveledRectangleBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AddSleepDialog(dateStr: dateStr, isNapDefault: false),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(MdiIcons.batteryChargingOutline, size: 14, color: JweTheme.accentAmber),
                        label: const Text('LOG NAP'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: JweTheme.accentAmber,
                          side: BorderSide(color: JweTheme.accentAmber.withValues(alpha: 0.5)),
                          shape: const BeveledRectangleBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AddSleepDialog(dateStr: dateStr, isNapDefault: true),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Circadian Sleep & Nap Advisor
          CircadianAdvisorCard(provider: provider, refDate: selectedDate, dateStr: dateStr),
          const SizedBox(height: 16),

          // Activity logs
          HudPanel(
            clip: HudClip.br,
            accent: JweTheme.accentTeal,
            brackets: true,
            allBrackets: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PHYSICAL TELEMETRY',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentTeal,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      "${workoutMinutes}M / ${distanceKm.toStringAsFixed(1)}KM",
                      style: GoogleFonts.chakraPetch(
                        color: JweTheme.accentTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (log.activityLogs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "NO PHYSICAL ACTIVITY SESSIONS LOGGED TODAY.",
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...log.activityLogs.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: JweTheme.bgCanvas.withValues(alpha: 0.3),
                          child: Row(
                            children: [
                              Icon(MdiIcons.walk, size: 14, color: JweTheme.accentTeal),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${a.walkDistanceKm} km walk / ${a.workoutMinutes} mins active",
                                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 10.5),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: JweTheme.accentRed, size: 14),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => provider.deleteActivityLog(dateStr, a.id),
                              ),
                            ],
                          ),
                        ),
                      )),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('RECORD ACTIVITY'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.accentTeal,
                    side: BorderSide(color: JweTheme.accentTeal.withValues(alpha: 0.5)),
                    shape: const BeveledRectangleBorder(),
                  ),
                  onPressed: () => showActivityDialog(context, provider, dateStr),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Energy Wave Panel
          EnergyPanel(dateStr: dateStr),
        ],
      ),
    );
  }
}
