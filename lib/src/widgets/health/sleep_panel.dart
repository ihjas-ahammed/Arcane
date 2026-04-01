import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/widgets/ui/jwe_panel.dart';
import 'package:arcane/src/widgets/health/add_sleep_dialog.dart';
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

    return JwePanel(
      title: "SLEEP METRICS",
      accentColor: JweTheme.accentCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("TOTAL SLEEP", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("${(totalMinutes / 60).floor()}h ${totalMinutes % 60}m", style: GoogleFonts.rajdhani(fontSize: 24, fontWeight: FontWeight.bold, color: JweTheme.accentCyan)),
            ],
          ),
          const SizedBox(height: 12),
          
          if (log.sleepLogs.isEmpty)
             const Text("No sleep data recorded for this cycle.", style: TextStyle(color: JweTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 12))
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
                    children:[
                      Icon(MdiIcons.bedOutline, color: JweTheme.textMuted, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${DateFormat('HH:mm').format(sLog.startTime)} - ${DateFormat('HH:mm').format(sLog.endTime)}", 
                              style: const TextStyle(color: JweTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono')
                            ),
                            Text(
                              "${(sLog.durationMinutes / 60).floor()}h ${sLog.durationMinutes % 60}m", 
                              style: const TextStyle(color: JweTheme.textMuted, fontSize: 11)
                            ),
                          ],
                        )
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: JweTheme.accentRed, size: 16),
                        onPressed: () => provider.deleteSleepLog(dateStr, sLog.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    ],
                  ),
                );
              }
            ),

          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text("ADD SLEEP RECORD", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            style: OutlinedButton.styleFrom(
              foregroundColor: JweTheme.accentCyan,
              side: const BorderSide(color: JweTheme.accentCyan),
              shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
            ),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
    );
  }
}