import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/models/health_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class HealthStatsTab extends StatelessWidget {
  final AppProvider provider;
  final DailyHealthLog currentLog;
  final Color accent;
  final double bottomPadding;

  const HealthStatsTab({
    super.key,
    required this.provider,
    required this.currentLog,
    required this.accent,
    required this.bottomPadding,
  });

  Widget _buildDirectiveItem(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Generate averages over last 30 days (DropNA).
    final now = DateTime.now();
    double totalWater = 0;
    int waterDays = 0;

    double totalSleepHours = 0;
    int sleepDays = 0;

    double totalWalkKm = 0;
    int walkDays = 0;

    int totalWorkoutMins = 0;
    int workoutDays = 0;

    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final log = provider.healthLogs[dateStr];
      if (log == null) continue;

      // 1. Water
      if (log.waterGlasses > 0) {
        totalWater += log.waterGlasses;
        waterDays++;
      }

      // 2. Sleep
      final sleepMins = log.sleepLogs.fold(0, (sum, item) => sum + item.durationMinutes);
      if (sleepMins > 0) {
        totalSleepHours += sleepMins / 60.0;
        sleepDays++;
      }

      // 3. Walk / Locomotion
      final walkKm = log.activityLogs.fold(0.0, (sum, item) => sum + item.walkDistanceKm);
      if (walkKm > 0) {
        totalWalkKm += walkKm;
        walkDays++;
      }

      // 4. Workout
      final workoutMins = log.activityLogs.fold(0, (sum, item) => sum + item.workoutMinutes);
      if (workoutMins > 0) {
        totalWorkoutMins += workoutMins;
        workoutDays++;
      }
    }

    double avgOver(num total, int count) => count == 0 ? 0 : total / count;
    final avgWater = avgOver(totalWater, waterDays);
    final avgSleep = avgOver(totalSleepHours, sleepDays);
    final avgWalkKm = avgOver(totalWalkKm, walkDays);
    final avgWorkoutMins = avgOver(totalWorkoutMins, workoutDays);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Row(
            children: [
              Container(width: 4, height: 12, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'HEALTH TELEMETRY & LONGEVITY STATS (30-DAY AVG)',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentCyan,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sleep & hydration averages
          Row(
            children: [
              Expanded(
                child: HudPanel(
                  clip: HudClip.br,
                  accent: JweTheme.accentCyan,
                  brackets: true,
                  allBrackets: false,
                  child: HudStat(
                    label: "SLEEP AVERAGE",
                    value: avgSleep.toStringAsFixed(1),
                    unit: "HRS",
                    sub: sleepDays > 0 ? "Walker limit: 8.0h • ${sleepDays}d" : "Walker limit: 8.0h",
                    tone: HudTone.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HudPanel(
                  clip: HudClip.br,
                  accent: JweTheme.accentCyan,
                  brackets: true,
                  allBrackets: false,
                  child: HudStat(
                    label: "WATER AVERAGE",
                    value: avgWater.toStringAsFixed(1),
                    unit: "GLS",
                    sub: waterDays > 0 ? "Attia target: 8.0 • ${waterDays}d" : "Attia target: 8.0",
                    tone: HudTone.cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Exercise Averages
          Row(
            children: [
              Expanded(
                child: HudPanel(
                  clip: HudClip.br,
                  accent: JweTheme.accentTeal,
                  brackets: true,
                  allBrackets: false,
                  child: HudStat(
                    label: "DAILY ACTIVE DURATION",
                    value: "${avgWorkoutMins.round()}",
                    unit: "MINS",
                    sub: workoutDays > 0 ? "Goal: 30 min • ${workoutDays}d" : "Goal: 30 min",
                    tone: HudTone.teal,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HudPanel(
                  clip: HudClip.br,
                  accent: JweTheme.accentTeal,
                  brackets: true,
                  allBrackets: false,
                  child: HudStat(
                    label: "DAILY LOCOMOTION",
                    value: avgWalkKm.toStringAsFixed(1),
                    unit: "KM",
                    sub: walkDays > 0 ? "Goal: 5.0 km • ${walkDays}d" : "Goal: 5.0 km",
                    tone: HudTone.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Science-Based Longevity Recommendations (Peter Attia, Matthew Walker, James Clear)
          HudPanel(
            clip: HudClip.both,
            accent: JweTheme.accentAmber,
            allBrackets: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.bookOpenVariant, color: JweTheme.accentAmber, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'LONGEVITY CLINICAL DIRECTIVES',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentAmber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDirectiveItem(
                  "CARDIORESPIRATORY PERFORMANCE (Peter Attia, 'Outlive')",
                  "Zone 2 training represents the foundation of mitochondrial health. Strive for 150 minutes per week at a pace where you can carry a conversation but prefer not to. VO2 Max is the single strongest predictor of lifespan.",
                ),
                const SizedBox(height: 10),
                _buildDirectiveItem(
                  "REST PROTOCOL & SLEEP ARCHITECTURE (Matthew Walker, 'Why We Sleep')",
                  "Aim for 7.5 to 8 hours of sleep per night. Sleep is an active state essential for glymphatic clearance (brain waste removal) and memory consolidation. Maintain a strict wake-up time.",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
