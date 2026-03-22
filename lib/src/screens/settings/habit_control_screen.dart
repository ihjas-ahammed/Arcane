import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/widgets/ui/jwe_panel.dart';
import 'package:arcane/src/widgets/dialogs/add_habit_rule_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HabitControlScreen extends StatelessWidget {
  const HabitControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final rules = provider.settings.habitRules;

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        title: Text("BEHAVIORAL OVERRIDE", style: GoogleFonts.rajdhani(color: JweTheme.accentAmber, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: JweTheme.bgBase,
        iconTheme: const IconThemeData(color: JweTheme.accentAmber),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  JwePanel(
                    title: "ATOMIC FRAMEWORK",
                    accentColor: JweTheme.textMuted,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Habits are driven by a continuous loop. Overriding the loop requires attacking these specific vectors:", style: TextStyle(color: JweTheme.textWhite, fontSize: 12, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 12),
                        _buildFrameworkItem(MdiIcons.eyeOff, "CUE REMOVAL", "Hide triggers. Enable scheduled grayscale.", JweTheme.textMuted),
                        _buildFrameworkItem(MdiIcons.timerSand, "FRICTION BOOST", "Mandatory delay before response execution.", JweTheme.accentCyan),
                        _buildFrameworkItem(MdiIcons.lockAlert, "USAGE CAP", "Hard daily limit restrictions on response.", JweTheme.accentAmber),
                        _buildFrameworkItem(MdiIcons.history, "ACCOUNTABILITY LOG", "Visibility of lost streaks to remove reward.", JweTheme.accentRed),
                      ],
                    )
                  ),
                  
                  JwePanel(
                    title: "GLOBAL CUE REMOVAL",
                    accentColor: JweTheme.accentCyan,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text("SYSTEM GRAYSCALE", style: TextStyle(color: JweTheme.textWhite, fontSize: 14)),
                          subtitle: const Text("Desaturate interface to reduce dopamine response.", style: TextStyle(color: JweTheme.textMuted, fontSize: 11)),
                          value: false, // Mock toggle
                          activeColor: JweTheme.accentCyan,
                          onChanged: (val) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("To enable grayscale, use your device's native Digital Wellbeing / Accessibility settings.")));
                          },
                        ),
                      ],
                    )
                  ),

                  JwePanel(
                    title: "ACTIVE RESTRICTIONS",
                    accentColor: JweTheme.accentRed,
                    child: Column(
                      children: [
                        if (rules.isEmpty)
                           const Padding(
                             padding: EdgeInsets.all(16.0),
                             child: Text("No behavioral overrides configured.", style: TextStyle(color: JweTheme.textMuted, fontStyle: FontStyle.italic)),
                           )
                        else
                           ...rules.map((r) => Container(
                             margin: const EdgeInsets.only(bottom: 12),
                             decoration: BoxDecoration(
                               border: Border.all(color: JweTheme.border),
                               color: JweTheme.panel,
                             ),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 // Header
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                   decoration: const BoxDecoration(
                                     border: Border(bottom: BorderSide(color: JweTheme.border)),
                                     color: Color(0x0DFFFFFF),
                                   ),
                                   child: Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                     children: [
                                       Text(r.appName.toUpperCase(), style: GoogleFonts.chakraPetch(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 16)),
                                       IconButton(
                                         icon: const Icon(Icons.delete, color: JweTheme.accentRed, size: 18),
                                         padding: EdgeInsets.zero,
                                         constraints: const BoxConstraints(),
                                         onPressed: () => provider.deleteHabitRule(r.id),
                                       )
                                     ],
                                   ),
                                 ),
                                 // Stats
                                 Padding(
                                   padding: const EdgeInsets.all(12.0),
                                   child: Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                     children: [
                                       _buildStatCol("FRICTION", "${r.frictionDelaySeconds}s", JweTheme.accentCyan),
                                       _buildStatCol("LIMIT", "${r.dailyLimitMinutes}m", JweTheme.accentAmber),
                                       _buildStatCol("STREAK", "${r.currentStreakDays}d", JweTheme.textWhite),
                                     ],
                                   ),
                                 ),
                                 // Actions
                                 Padding(
                                   padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                   child: Row(
                                     children: [
                                       Expanded(
                                         child: OutlinedButton(
                                           style: OutlinedButton.styleFrom(
                                             foregroundColor: JweTheme.textWhite,
                                             side: const BorderSide(color: JweTheme.border),
                                             shape: const BeveledRectangleBorder()
                                           ),
                                           onPressed: () {
                                             final updated = r..currentStreakDays += 1;
                                             provider.updateHabitRule(updated);
                                           },
                                           child: const Text("LOG CLEAN DAY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                         ),
                                       ),
                                       const SizedBox(width: 8),
                                       Expanded(
                                         child: OutlinedButton(
                                           style: OutlinedButton.styleFrom(
                                             foregroundColor: JweTheme.accentRed,
                                             side: const BorderSide(color: JweTheme.accentRed),
                                             shape: const BeveledRectangleBorder()
                                           ),
                                           onPressed: () {
                                             final updated = r..currentStreakDays = 0;
                                             provider.updateHabitRule(updated);
                                           },
                                           child: const Text("RESET STREAK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                         ),
                                       )
                                     ],
                                   ),
                                 )
                               ],
                             ),
                           )),

                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("ADD OVERRIDE"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: JweTheme.accentRed,
                              foregroundColor: Colors.white,
                              shape: const BeveledRectangleBorder()
                            ),
                            onPressed: () {
                              showDialog(context: context, builder: (_) => const AddHabitRuleDialog());
                            },
                          ),
                        )
                      ],
                    )
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrameworkItem(IconData icon, String title, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.rajdhani(color: color, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.0)),
                Text(desc, style: const TextStyle(color: JweTheme.textMuted, fontSize: 11)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: JweTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.rajdhani(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
      ],
    );
  }
}