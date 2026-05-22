import 'package:flutter/material.dart';
import 'package:missions/src/theme/spidey_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/health_models.dart';
import 'package:missions/src/widgets/health/spidey_panel.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ActivityPanel extends StatelessWidget {
  final String dateStr;
  const ActivityPanel({super.key, required this.dateStr});

  void _showAddDialog(BuildContext context, AppProvider provider) {
    double d = 0.0;
    int m = 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpideyTheme.bgPanel,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: SpideyTheme.spideyRed.withOpacity(0.6)),
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
        ),
        title: Row(
          children: [
            Container(width: 3, height: 16, color: SpideyTheme.spideyRed),
            const SizedBox(width: 8),
            Text("LOG PHYSICAL ACTIVITY",
                style: GoogleFonts.rajdhani(
                    color: SpideyTheme.textWhite, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                decoration: const InputDecoration(
                    labelText: "WALK DISTANCE (KM)",
                    labelStyle: TextStyle(color: SpideyTheme.textMuted, fontSize: 12)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => d = double.tryParse(v) ?? d,
                style: const TextStyle(color: SpideyTheme.textWhite, fontFamily: 'RobotoMono')),
            const SizedBox(height: 16),
            TextField(
                decoration: const InputDecoration(
                    labelText: "WORKOUT DURATION (MIN)",
                    labelStyle: TextStyle(color: SpideyTheme.textMuted, fontSize: 12)),
                keyboardType: TextInputType.number,
                onChanged: (v) => m = int.tryParse(v) ?? m,
                style: const TextStyle(color: SpideyTheme.textWhite, fontFamily: 'RobotoMono')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: SpideyTheme.textMuted))),
          ElevatedButton(
              onPressed: () {
                if (d > 0 || m > 0) {
                  provider.addActivityLog(
                      dateStr, ActivityLog(id: const Uuid().v4(), walkDistanceKm: d, workoutMinutes: m, timestamp: DateTime.now()));
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SpideyTheme.spideyRed,
                foregroundColor: Colors.white,
                shape: const BeveledRectangleBorder(
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
                ),
              ),
              child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final log = provider.getDailyHealthLog(dateStr);

    final totalKm = log.activityLogs.fold(0.0, (sum, item) => sum + item.walkDistanceKm);
    final totalMin = log.activityLogs.fold(0, (sum, item) => sum + item.workoutMinutes);

    return SpideyPanel(
      title: "PHYSICAL ACTIVITY",
      accentColor: SpideyTheme.spideyRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("DISTANCE",
                      style: GoogleFonts.rajdhani(
                          color: SpideyTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  Text("${totalKm.toStringAsFixed(1)} KM",
                      style: GoogleFonts.rajdhani(
                          fontSize: 24, fontWeight: FontWeight.bold, color: SpideyTheme.spideyRed)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("WORKOUT",
                      style: GoogleFonts.rajdhani(
                          color: SpideyTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  Text("$totalMin MIN",
                      style: GoogleFonts.rajdhani(
                          fontSize: 24, fontWeight: FontWeight.bold, color: SpideyTheme.spideyRed)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (log.activityLogs.isEmpty)
            const Text("No activity data recorded for this cycle.",
                style: TextStyle(color: SpideyTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 12))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: log.activityLogs.length,
              itemBuilder: (ctx, i) {
                final aLog = log.activityLogs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(MdiIcons.run, color: SpideyTheme.textGrey, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              "${aLog.walkDistanceKm > 0 ? '${aLog.walkDistanceKm.toStringAsFixed(1)} KM' : ''}${aLog.walkDistanceKm > 0 && aLog.workoutMinutes > 0 ? ' | ' : ''}${aLog.workoutMinutes > 0 ? '${aLog.workoutMinutes} MIN' : ''}",
                              style: const TextStyle(color: SpideyTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold))),
                      Text(DateFormat('HH:mm').format(aLog.timestamp),
                          style: const TextStyle(color: SpideyTheme.textMuted, fontSize: 11, fontFamily: 'RobotoMono')),
                      IconButton(
                        icon: const Icon(Icons.close, color: SpideyTheme.spideyRed, size: 16),
                        onPressed: () => provider.deleteActivityLog(dateStr, aLog.id),
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
            label: Text("LOG ACTIVITY",
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            style: OutlinedButton.styleFrom(
              foregroundColor: SpideyTheme.spideyRed,
              side: const BorderSide(color: SpideyTheme.spideyRed),
              shape: const BeveledRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6), bottomRight: Radius.circular(6))),
            ),
            onPressed: () => _showAddDialog(context, provider),
          ),
        ],
      ),
    );
  }
}
