import 'package:flutter/material.dart';
import 'package:missions/src/theme/spidey_theme.dart';
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

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AddSleepDialog(dateStr: dateStr),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final log = provider.getDailyHealthLog(dateStr);
    final totalMinutes = log.sleepLogs.fold(0, (sum, item) => sum + item.durationMinutes);

    return SpideyPanel(
      title: "SLEEP METRICS",
      accentColor: SpideyTheme.spideyCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("TOTAL SLEEP",
                  style: GoogleFonts.rajdhani(
                      color: SpideyTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Text("${(totalMinutes / 60).floor()}h ${totalMinutes % 60}m",
                  style: GoogleFonts.rajdhani(
                      fontSize: 24, fontWeight: FontWeight.bold, color: SpideyTheme.spideyCyan)),
            ],
          ),
          const SizedBox(height: 12),
          if (log.sleepLogs.isEmpty)
            const Text("No sleep data recorded for this cycle.",
                style: TextStyle(color: SpideyTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 12))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: log.sleepLogs.length,
              itemBuilder: (ctx, i) {
                final sLog = log.sleepLogs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(MdiIcons.bedOutline, color: SpideyTheme.textGrey, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${DateFormat('HH:mm').format(sLog.startTime)} - ${DateFormat('HH:mm').format(sLog.endTime)}",
                              style: const TextStyle(
                                  color: SpideyTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono'),
                            ),
                            Text(
                              "${(sLog.durationMinutes / 60).floor()}h ${sLog.durationMinutes % 60}m",
                              style: const TextStyle(color: SpideyTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: SpideyTheme.spideyRed, size: 16),
                        onPressed: () => provider.deleteSleepLog(dateStr, sLog.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text("ADD SLEEP RECORD",
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            style: OutlinedButton.styleFrom(
              foregroundColor: SpideyTheme.spideyCyan,
              side: const BorderSide(color: SpideyTheme.spideyCyan),
              shape: const BeveledRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6), bottomRight: Radius.circular(6))),
            ),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
    );
  }
}
