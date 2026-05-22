import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:missions/src/widgets/ui/wellbeing_card.dart';
import 'package:missions/src/widgets/dialogs/wellbeing_detail_dialog.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class WellbeingDrawer extends StatelessWidget {
  const WellbeingDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return Drawer(
      width: 360,
      backgroundColor: PersonInfoTheme.bgDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1f2f40), width: 2)),
              color: PersonInfoTheme.bgPanel,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.dna, color: PersonInfoTheme.spideyCyan, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      "WELL-BEING",
                      style: GoogleFonts.rajdhani(
                        color: PersonInfoTheme.textWhite,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "// PSYCHOLOGICAL & EMOTIONAL METRICS",
                  style: GoogleFonts.rajdhani(
                    color: PersonInfoTheme.textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // List of Well-Being Sources
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: appProvider.skills.length,
              itemBuilder: (context, index) {
                final skill = appProvider.skills[index];
                return WellbeingCard(
                  skill: skill,
                  onTap: () {
                    final xpToday = appProvider.get7DayWellbeingMomentum(skill.name) ~/ 7;
                    
                    Map<int, double> weeklyXp = {};
                    for (int i = 6; i >= 0; i--) {
                      final date = DateTime.now().subtract(Duration(days: i));
                      double dayXp = 0;
                      for (var log in appProvider.reflectionLogs) {
                        if (log.timestamp.year == date.year && log.timestamp.month == date.month && log.timestamp.day == date.day) {
                          dayXp += (log.xpGained[skill.name] ?? 0).toDouble();
                        }
                      }
                      weeklyXp[6 - i] = dayXp;
                    }

                    showDialog(
                      context: context,
                      builder: (_) => WellbeingDetailDialog(
                        skill: skill,
                        xpGainedToday: xpToday,
                        weeklyXp: weeklyXp,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Sync Action
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: appProvider.loadingTaskName == "Analyzing Weekly Wellbeing..."
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Icon(MdiIcons.sync, size: 18, color: Colors.black),
              label: Text(
                appProvider.loadingTaskName == "Analyzing Weekly Wellbeing..." ? "PROCESSING..." : "SYNC 7-DAY PROGRESS",
                style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PersonInfoTheme.spideyCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
              ),
              onPressed: appProvider.loadingTaskName != null ? null : () async {
                try {
                  await appProvider.syncWeeklyWellbeing();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Well-Being Progress Synchronized"), backgroundColor: AppTheme.fhAccentGreen)
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.fhAccentRed)
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}