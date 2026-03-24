import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/widgets/ui/jwe_panel.dart';
import 'package:arcane/src/widgets/screens/reflection_editor_screen.dart';
import 'package:arcane/src/widgets/dialogs/last_insight_dialog.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class JweReflectionProgress extends StatelessWidget {
  final List<ReflectionLog> logs;
  final String dateStr;

  const JweReflectionProgress({
    super.key,
    required this.logs,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    bool wake = false;
    bool morn = false;
    bool aft = false;
    bool eve = false;
    bool night = false;

    ReflectionLog? lastLog;

    for (var log in logs) {
      if (lastLog == null || log.timestamp.isAfter(lastLog.timestamp)) {
        lastLog = log;
      }
      
      final h = log.timestamp.hour;
      if (h >= 0 && h < 8) wake = true;
      else if (h >= 8 && h < 12) morn = true;
      else if (h >= 12 && h < 16) aft = true;
      else if (h >= 16 && h < 19) eve = true;
      else if (h >= 19 && h <= 23) night = true;
    }

    if (night) { eve = true; aft = true; morn = true; wake = true; }
    else if (eve) { aft = true; morn = true; wake = true; }
    else if (aft) { morn = true; wake = true; }
    else if (morn) { wake = true; }

    final total = [wake, morn, aft, eve, night].where((e) => e).length;

    return JwePanel(
      title: "REFLECTION PROTOCOL",
      accentColor: JweTheme.accentAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "COMPLETION",
                style: TextStyle(
                  color: JweTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                "$total / 5 LOGS",
                style: GoogleFonts.robotoMono(
                  color: JweTheme.accentAmber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _buildSegment("WAKE", wake)),
              const SizedBox(width: 4),
              Expanded(child: _buildSegment("MORN", morn)),
              const SizedBox(width: 4),
              Expanded(child: _buildSegment("AFT", aft)),
              const SizedBox(width: 4),
              Expanded(child: _buildSegment("EVE", eve)),
              const SizedBox(width: 4),
              Expanded(child: _buildSegment("NIGHT", night)),
            ],
          ),

          const SizedBox(height: 20),
          
          if (lastLog != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "LAST LOGGED: ${DateFormat('HH:mm').format(lastLog.timestamp)}", 
                    style: const TextStyle(color: JweTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono')
                  ),
                  if (lastLog.aiFeedback.isNotEmpty)
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => LastInsightDialog(log: lastLog!),
                        );
                      },
                      child: const Text(
                        "VIEW LAST INSIGHT",
                        style: TextStyle(color: JweTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)
                      )
                    )
                ],
              ),
            ),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(MdiIcons.notebookEditOutline, size: 16),
              label: Text("LOG INSIGHT", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              style: OutlinedButton.styleFrom(
                foregroundColor: JweTheme.accentAmber,
                side: const BorderSide(color: JweTheme.accentAmber),
                shape: const BeveledRectangleBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => ReflectionEditorScreen(dateStr: dateStr))
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSegment(String label, bool isComplete) {
    return Column(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: isComplete ? JweTheme.accentAmber : JweTheme.border,
            border: Border.all(color: JweTheme.border, width: 1),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isComplete ? JweTheme.textWhite : JweTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}