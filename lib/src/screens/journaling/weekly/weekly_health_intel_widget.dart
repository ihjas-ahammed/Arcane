import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'weekly_common_widgets.dart';

class HealthMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  const HealthMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border.all(color: color.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.chakraPetch(
                  color: JweTheme.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sub,
                style: GoogleFonts.jetBrainsMono(
                  color: color,
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HealthIntelView extends StatelessWidget {
  final Map<String, dynamic> healthIntel;

  const HealthIntelView({super.key, required this.healthIntel});

  @override
  Widget build(BuildContext context) {
    final sleepInsight = healthIntel['sleep_insight']?.toString() ?? '';
    final activityInsight = healthIntel['activity_insight']?.toString() ?? '';
    final recoveryScore = healthIntel['recovery_score']?.toString() ?? '';
    final vitalityQuote = healthIntel['vitality_quote']?.toString() ?? '';
    final tip = healthIntel['actionable_tip']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.accentTeal.withOpacity(0.06),
        border: Border(left: BorderSide(color: JweTheme.accentTeal, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recoveryScore.isNotEmpty) ...[
            Row(
              children: [
                Icon(MdiIcons.shieldCheckOutline, size: 14, color: JweTheme.accentTeal),
                const SizedBox(width: 6),
                Text(
                  'RECOVERY INDEX: $recoveryScore'.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentTeal,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (sleepInsight.isNotEmpty) ...[
            HealthInsightRow(icon: MdiIcons.bedClock, label: 'SLEEP & RECOVERY', text: sleepInsight),
            const SizedBox(height: 6),
          ],
          if (activityInsight.isNotEmpty) ...[
            HealthInsightRow(icon: MdiIcons.runFast, label: 'MOVEMENT & VITALITY', text: activityInsight),
            const SizedBox(height: 6),
          ],
          if (tip.isNotEmpty) ...[
            HealthInsightRow(icon: MdiIcons.lightbulbOnOutline, label: 'ACTIONABLE TIP', text: tip, isAccent: true),
            const SizedBox(height: 6),
          ],
          if (vitalityQuote.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '"$vitalityQuote"',
                style: TextStyle(
                  color: JweTheme.textMid,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HealthInsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final bool isAccent;

  const HealthInsightRow({
    super.key,
    required this.icon,
    required this.label,
    required this.text,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isAccent ? JweTheme.accentAmber : JweTheme.accentTeal;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: GoogleFonts.jetBrainsMono(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: text,
                  style: TextStyle(
                    color: JweTheme.textWhite,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class WeeklyHealthTelemetrySummary extends StatelessWidget {
  final AppProvider provider;
  final DateTime effDate;

  const WeeklyHealthTelemetrySummary({
    super.key,
    required this.provider,
    required this.effDate,
  });

  @override
  Widget build(BuildContext context) {
    double totalWater = 0;
    double totalSleepMins = 0;
    double totalWalkKm = 0;
    double totalWorkoutMins = 0;
    int loggedDays = 0;
    for (int i = 0; i < 7; i++) {
      final dStr = DateFormat('yyyy-MM-dd').format(effDate.subtract(Duration(days: i)));
      final log = provider.getDailyHealthLog(dStr);
      final sleep = log.sleepLogs.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      final walk = log.activityLogs.fold<double>(0, (sum, a) => sum + a.walkDistanceKm);
      final workout = log.activityLogs.fold<int>(0, (sum, a) => sum + a.workoutMinutes);
      if (log.waterGlasses > 0 || sleep > 0 || walk > 0 || workout > 0) loggedDays++;
      totalWater += log.waterGlasses;
      totalSleepMins += sleep;
      totalWalkKm += walk;
      totalWorkoutMins += workout;
    }
    final avgWater = totalWater / 7;
    final avgSleep = totalSleepMins / 7 / 60;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.4),
        border: Border.all(color: JweTheme.lineSoft),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabel(
                title: '7-DAY HEALTH TELEMETRY',
                icon: MdiIcons.chartBellCurveCumulative,
                color: JweTheme.accentTeal,
              ),
              Text(
                '$loggedDays/7 DAYS LOGGED',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: HealthMetricTile(
                  label: 'SLEEP AVG',
                  value: '${avgSleep.toStringAsFixed(1)} H',
                  sub: avgSleep >= 7 ? 'OPTIMAL' : 'RECHARGE',
                  icon: MdiIcons.bedClock,
                  color: JweTheme.accentCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HealthMetricTile(
                  label: 'WATER AVG',
                  value: '${avgWater.toStringAsFixed(1)} GL',
                  sub: avgWater >= 8 ? 'HYDRATED' : 'HYDRATE',
                  icon: MdiIcons.cupWater,
                  color: JweTheme.accentTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: HealthMetricTile(
                  label: 'WALKS TOTAL',
                  value: '${totalWalkKm.toStringAsFixed(1)} KM',
                  sub: 'DISTANCE',
                  icon: MdiIcons.walk,
                  color: JweTheme.accentAmber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HealthMetricTile(
                  label: 'WORKOUTS',
                  value: '${(totalWorkoutMins / 60).toStringAsFixed(1)} H',
                  sub: 'TOTAL ACTIVE',
                  icon: MdiIcons.dumbbell,
                  color: JweTheme.accentRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
