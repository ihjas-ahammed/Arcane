import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:missions/src/models/health_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/sleep_advisor_helper.dart';
import 'package:missions/src/widgets/health/add_sleep_dialog.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class CircadianAdvisorCard extends StatelessWidget {
  final AppProvider provider;
  final DateTime refDate;
  final String dateStr;

  const CircadianAdvisorCard({
    super.key,
    required this.provider,
    required this.refDate,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    final advisor = SleepAdvisorHelper.calculate(provider, refDate);

    Color badgeBg;
    Color badgeBorder;
    Color badgeText;
    String badgeLabel;

    switch (advisor.napStatus) {
      case NapWindowStatus.activeNow:
        badgeBg = JweTheme.accentTeal.withValues(alpha: 0.2);
        badgeBorder = JweTheme.accentTeal;
        badgeText = JweTheme.accentTeal;
        badgeLabel = 'ACTIVE WINDOW';
        break;
      case NapWindowStatus.recalibrated:
        badgeBg = JweTheme.accentAmber.withValues(alpha: 0.2);
        badgeBorder = JweTheme.accentAmber;
        badgeText = JweTheme.accentAmber;
        badgeLabel = 'RECALIBRATED';
        break;
      case NapWindowStatus.upcoming:
        badgeBg = JweTheme.accentAmber.withValues(alpha: 0.15);
        badgeBorder = JweTheme.accentAmber.withValues(alpha: 0.5);
        badgeText = JweTheme.accentAmber;
        badgeLabel = 'RECOMMENDED';
        break;
      case NapWindowStatus.tomorrowScheduled:
        badgeBg = JweTheme.accentCyan.withValues(alpha: 0.15);
        badgeBorder = JweTheme.accentCyan.withValues(alpha: 0.5);
        badgeText = JweTheme.accentCyan;
        badgeLabel = 'SCHEDULED TOMORROW';
        break;
      case NapWindowStatus.completedToday:
        badgeBg = JweTheme.accentCyan.withValues(alpha: 0.15);
        badgeBorder = JweTheme.accentCyan.withValues(alpha: 0.5);
        badgeText = JweTheme.accentCyan;
        badgeLabel = 'NAP RECORDED';
        break;
      case NapWindowStatus.windowPassed:
        badgeBg = JweTheme.bgCanvas.withValues(alpha: 0.3);
        badgeBorder = JweTheme.border;
        badgeText = JweTheme.textMuted;
        badgeLabel = 'WINDOW CONCLUDED';
        break;
    }

    final isTomorrowNap = advisor.napStatus == NapWindowStatus.tomorrowScheduled ||
        advisor.napWindowStart.day != refDate.day;
    final napTimeText =
        "${DateFormat('h:mm a').format(advisor.napWindowStart)} — ${DateFormat('h:mm a').format(advisor.napWindowEnd)}";
    final bedtimeAccent = advisor.isBedtimeRecalibrated ? JweTheme.accentAmber : JweTheme.accentCyan;

    return HudPanel(
      clip: HudClip.br,
      accent: JweTheme.accentAmber,
      brackets: true,
      allBrackets: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(MdiIcons.weatherNight, size: 14, color: JweTheme.accentAmber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CIRCADIAN SLEEP & NAP ADVISOR',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentAmber,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: JweTheme.accentAmber.withValues(alpha: 0.12),
                  border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.35)),
                ),
                child: Text(
                  advisor.fromHistory ? '7-DAY TELEMETRY' : 'RESEARCH BASELINE',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. NEXT SUGGESTED POWER NAP TIME
          Text(
            'NEXT SUGGESTED POWER NAP',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textMuted,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      isTomorrowNap ? "Tomorrow: $napTimeText" : napTimeText,
                      style: GoogleFonts.chakraPetch(
                        color: JweTheme.accentAmber,
                        fontSize: isTomorrowNap ? 15 : 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "(${advisor.napDurationMinutes}m ideal)",
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  badgeLabel,
                  style: GoogleFonts.jetBrainsMono(
                    color: badgeText,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: JweTheme.bgCanvas.withValues(alpha: 0.35),
              border: Border.all(color: JweTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(MdiIcons.batteryChargingOutline, size: 14, color: JweTheme.accentAmber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    advisor.napReasoning,
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMid,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick Power Nap Action Buttons when window is active or upcoming
          if (advisor.napStatus == NapWindowStatus.activeNow ||
              advisor.napStatus == NapWindowStatus.recalibrated ||
              advisor.napStatus == NapWindowStatus.upcoming) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(MdiIcons.batteryChargingOutline, size: 14, color: JweTheme.accentAmber),
                    label: Text(
                      advisor.napStatus == NapWindowStatus.activeNow ? 'LOG 20M NAP NOW' : 'QUICK LOG 20M NAP',
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: JweTheme.accentAmber,
                      side: BorderSide(color: JweTheme.accentAmber.withValues(alpha: 0.5)),
                      shape: const BeveledRectangleBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onPressed: () {
                      final start = DateTime.now();
                      final end = start.add(const Duration(minutes: 20));
                      provider.addSleepLog(
                        dateStr,
                        SleepLog(
                          id: const Uuid().v4(),
                          startTime: start,
                          endTime: end,
                          isNapExplicit: true,
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Power nap logged (20m). Refreshing alertness and working memory!',
                            style: GoogleFonts.jetBrainsMono(fontSize: 12),
                          ),
                          backgroundColor: JweTheme.panel,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.textMid,
                    side: BorderSide(color: JweTheme.border),
                    shape: const BeveledRectangleBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AddSleepDialog(dateStr: dateStr, isNapDefault: true),
                    );
                  },
                  child: Text(
                    'CUSTOM...',
                    style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                ),
              ],
            ),
          ],

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: JweTheme.border.withValues(alpha: 0.5), height: 1),
          ),

          // 2. NEXT SLEEP TIME (BELOW POWER NAP)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'NEXT RECOMMENDED SLEEP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: bedtimeAccent.withValues(alpha: 0.15),
                  border: Border.all(color: bedtimeAccent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  advisor.isBedtimeRecalibrated
                      ? 'RECALIBRATED: ${advisor.targetSleepCycles} CYCLES (${(advisor.targetSleepCycles * 1.5).toStringAsFixed(1)}H)'
                      : 'TARGET: ${advisor.targetSleepCycles} CYCLES (7.5H)',
                  style: GoogleFonts.jetBrainsMono(
                    color: bedtimeAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(advisor.nextBedtime),
                      style: GoogleFonts.chakraPetch(
                        color: JweTheme.textWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      advisor.nextBedtime.day == refDate.day
                          ? "TONIGHT"
                          : (advisor.nextBedtime.difference(DateTime.now()).inHours.abs() < 8 ? "LATE TONIGHT" : "TOMORROW NIGHT"),
                      style: GoogleFonts.jetBrainsMono(
                        color: bedtimeAccent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(MdiIcons.alarm, size: 12, color: JweTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    "Wake: ${DateFormat('h:mm a').format(advisor.nextWakeTime)}",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMid,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: JweTheme.bgCanvas.withValues(alpha: 0.35),
              border: Border.all(color: JweTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.weatherSunset, size: 14, color: bedtimeAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Wind-down routine: ${DateFormat('h:mm a').format(advisor.windDownTime)} (dim lights, screens off)",
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textWhite,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  advisor.bedtimeReasoning,
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted,
                    fontSize: 9.5,
                    height: 1.3,
                  ),
                ),
                if (advisor.fromHistory) ...[
                  const SizedBox(height: 4),
                  Text(
                    "7-Day Baseline: ${(advisor.avgWeeklySleepMinutes / 60).floor()}h ${advisor.avgWeeklySleepMinutes % 60}m avg • Habitual Wake: ${DateFormat('h:mm a').format(DateTime(2026, 1, 1, advisor.habitualWakeMinute ~/ 60, advisor.habitualWakeMinute % 60))}",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMid.withValues(alpha: 0.7),
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
