import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/health_models.dart';
import 'package:arcane/src/widgets/ui/jwe_panel.dart';
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
        backgroundColor: JweTheme.panel,
        title: Text("LOG PHYSICAL ACTIVITY", style: GoogleFonts.rajdhani(color: JweTheme.accentAmber, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children:[
            TextField(decoration: const InputDecoration(labelText: "WALK DISTANCE (KM)", labelStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12)), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => d = double.tryParse(v) ?? d, style: const TextStyle(color: JweTheme.textWhite, fontFamily: 'RobotoMono')),
            const SizedBox(height: 16),
            TextField(decoration: const InputDecoration(labelText: "WORKOUT DURATION (MIN)", labelStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12)), keyboardType: TextInputType.number, onChanged: (v) => m = int.tryParse(v) ?? m, style: const TextStyle(color: JweTheme.textWhite, fontFamily: 'RobotoMono')),
          ],
        ),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: JweTheme.textMuted))),
          ElevatedButton(
            onPressed: () {
              if (d > 0 || m > 0) {
                 provider.addActivityLog(dateStr, ActivityLog(id: const Uuid().v4(), walkDistanceKm: d, workoutMinutes: m, timestamp: DateTime.now()));
              }
              Navigator.pop(ctx);
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentAmber, foregroundColor: Colors.black), 
            child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final log = provider.getDailyHealthLog(dateStr);
    
    final totalKm = log.activityLogs.fold(0.0, (sum, item) => sum + item.walkDistanceKm);
    final totalMin = log.activityLogs.fold(0, (sum, item) => sum + item.workoutMinutes);

    return JwePanel(
      title: "PHYSICAL ACTIVITY",
      accentColor: JweTheme.accentAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("DISTANCE", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text("${totalKm.toStringAsFixed(1)} KM", style: GoogleFonts.rajdhani(fontSize: 24, fontWeight: FontWeight.bold, color: JweTheme.accentAmber)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("WORKOUT", style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text("${totalMin} MIN", style: GoogleFonts.rajdhani(fontSize: 24, fontWeight: FontWeight.bold, color: JweTheme.accentAmber)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (log.activityLogs.isEmpty)
             const Text("No activity data recorded for this cycle.", style: TextStyle(color: JweTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 12))
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
                    children:[
                      Icon(MdiIcons.run, color: JweTheme.textMuted, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text("${aLog.walkDistanceKm > 0 ? '${aLog.walkDistanceKm.toStringAsFixed(1)} KM' : ''}${aLog.walkDistanceKm > 0 && aLog.workoutMinutes > 0 ? ' | ' : ''}${aLog.workoutMinutes > 0 ? '${aLog.workoutMinutes} MIN' : ''}", style: const TextStyle(color: JweTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold))),
                      Text(DateFormat('HH:mm').format(aLog.timestamp), style: const TextStyle(color: JweTheme.textMuted, fontSize: 11, fontFamily: 'RobotoMono')),
                      IconButton(
                        icon: const Icon(Icons.close, color: JweTheme.accentRed, size: 16),
                        onPressed: () => provider.deleteActivityLog(dateStr, aLog.id),
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
            label: Text("LOG ACTIVITY", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            style: OutlinedButton.styleFrom(
              foregroundColor: JweTheme.accentAmber,
              side: const BorderSide(color: JweTheme.accentAmber),
              shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
            ),
            onPressed: () => _showAddDialog(context, provider),
          ),
        ],
      ),
    );
  }
}