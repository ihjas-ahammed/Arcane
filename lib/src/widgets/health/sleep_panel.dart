import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/widgets/health/spidey_panel.dart';
import 'package:missions/src/widgets/health/add_sleep_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SleepPanel extends StatelessWidget {
  final String dateStr;
  const SleepPanel({super.key, required this.dateStr});

  void _showAddDialog(BuildContext context, {bool isNap = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AddSleepDialog(dateStr: dateStr, isNapDefault: isNap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final log = provider.getDailyHealthLog(dateStr);
    final totalMinutes = log.sleepLogs.fold(0, (sum, item) => sum + item.durationMinutes);
    final nightMinutes = log.sleepLogs.where((s) => !s.isNap).fold(0, (sum, item) => sum + item.durationMinutes);
    final napMinutes = log.sleepLogs.where((s) => s.isNap).fold(0, (sum, item) => sum + item.durationMinutes);

    return SpideyPanel(
      title: "SLEEP METRICS",
      accentColor: JweTheme.accentCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TOTAL SLEEP",
                style: GoogleFonts.rajdhani(
                  color: JweTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                "${(totalMinutes / 60).floor()}h ${totalMinutes % 60}m",
                style: GoogleFonts.rajdhani(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: JweTheme.accentCyan,
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
                  "BREAKDOWN",
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Night: ${(nightMinutes / 60).floor()}h ${nightMinutes % 60}m • Nap: ${napMinutes}m",
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMid,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (log.sleepLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Text(
                "No sleep data recorded for this cycle.",
                style: TextStyle(color: JweTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 12),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: log.sleepLogs.length,
              itemBuilder: (ctx, i) {
                final sLog = log.sleepLogs[i];
                final isNap = sLog.isNap;
                final itemAccent = isNap ? JweTheme.accentAmber : JweTheme.accentCyan;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        isNap ? MdiIcons.batteryChargingOutline : MdiIcons.bedOutline,
                        color: itemAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: itemAccent.withValues(alpha: 0.15),
                          border: Border.all(color: itemAccent.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          isNap ? 'NAP' : 'NIGHT',
                          style: GoogleFonts.jetBrainsMono(
                            color: itemAccent,
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${DateFormat('HH:mm').format(sLog.startTime)} - ${DateFormat('HH:mm').format(sLog.endTime)}",
                              style: TextStyle(
                                color: JweTheme.textWhite,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'RobotoMono',
                              ),
                            ),
                            Text(
                              "${(sLog.durationMinutes / 60).floor()}h ${sLog.durationMinutes % 60}m",
                              style: TextStyle(color: JweTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: JweTheme.accentRed, size: 16),
                        onPressed: () => provider.deleteSleepLog(dateStr, sLog.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 14),
                  label: Text("ADD SLEEP",
                      style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.accentCyan,
                    side: BorderSide(color: JweTheme.accentCyan.withValues(alpha: 0.5)),
                    shape: const BeveledRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                  ),
                  onPressed: () => _showAddDialog(context, isNap: false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(MdiIcons.batteryChargingOutline, size: 14, color: JweTheme.accentAmber),
                  label: Text("LOG NAP",
                      style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 11, color: JweTheme.accentAmber)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.accentAmber,
                    side: BorderSide(color: JweTheme.accentAmber.withValues(alpha: 0.5)),
                    shape: const BeveledRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                  ),
                  onPressed: () => _showAddDialog(context, isNap: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
