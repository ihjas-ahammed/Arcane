import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class StartDayHealthSection extends StatelessWidget {
  final AppProvider provider;
  final String yesterdayStr;

  const StartDayHealthSection({
    super.key,
    required this.provider,
    required this.yesterdayStr,
  });

  Widget _buildHealthRow(
    IconData icon,
    String label,
    String value,
    Color color, {
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 10),
              SizedBox(
                width: 85,
                child: Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    color: JweTheme.textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(color: JweTheme.lineSoft, height: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final yesterdayHealthLog = provider.getDailyHealthLog(yesterdayStr);

    final sleepLogs = yesterdayHealthLog.sleepLogs;
    final totalSleepMins = sleepLogs.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final waterGlasses = yesterdayHealthLog.waterGlasses;
    final walkDist = yesterdayHealthLog.activityLogs.fold<double>(0.0, (sum, a) => sum + a.walkDistanceKm);
    final workoutMins = yesterdayHealthLog.activityLogs.fold<int>(0, (sum, a) => sum + a.workoutMinutes);

    final hasAnyHealth = totalSleepMins > 0 || waterGlasses > 0 || walkDist > 0 || workoutMins > 0;

    if (!hasAnyHealth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 10, color: JweTheme.accentTeal),
            const SizedBox(width: 8),
            Icon(MdiIcons.heartPulse, size: 11, color: JweTheme.accentTeal),
            const SizedBox(width: 5),
            Text(
              'YESTERDAY\'S HEALTH DIAGNOSTICS',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentTeal,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JweTheme.bgBase,
              border: Border.all(color: JweTheme.border),
            ),
            child: Text(
              'No health metrics logged yesterday.',
              style: GoogleFonts.inter(
                color: JweTheme.textMuted,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      );
    }

    final sleepStr = totalSleepMins > 0
        ? '${totalSleepMins ~/ 60}h ${totalSleepMins % 60}m'
        : 'No sleep logged';

    final waterStr = waterGlasses > 0
        ? '$waterGlasses glasses'
        : 'No water logged';

    final activityStr = (walkDist > 0 || workoutMins > 0)
        ? '${walkDist > 0 ? "${walkDist.toStringAsFixed(1)} km walked" : ""}${walkDist > 0 && workoutMins > 0 ? " • " : ""}${workoutMins > 0 ? "${workoutMins}m workout" : ""}'
        : 'No activity logged';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 10, color: JweTheme.accentTeal),
          const SizedBox(width: 8),
          Icon(MdiIcons.heartPulse, size: 11, color: JweTheme.accentTeal),
          const SizedBox(width: 5),
          Text(
            'YESTERDAY\'S HEALTH DIAGNOSTICS',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.accentTeal,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: JweTheme.bgBase,
            border: Border.all(color: JweTheme.border),
          ),
          child: Column(
            children: [
              _buildHealthRow(MdiIcons.sleep, 'SLEEP', sleepStr, JweTheme.accentCyan, showDivider: true),
              _buildHealthRow(MdiIcons.water, 'HYDRATION', waterStr, JweTheme.accentCyan, showDivider: true),
              _buildHealthRow(MdiIcons.run, 'ACTIVITY', activityStr, JweTheme.accentTeal, showDivider: false),
            ],
          ),
        ),
      ],
    );
  }
}
