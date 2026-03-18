import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/widgets/screens/reflection_editor_screen.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ReflectionProgressWidget extends StatelessWidget {
  final List<ReflectionLog> logs;
  final String dateStr;

  const ReflectionProgressWidget({
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

    // Auto-fill logic
    if (night) { eve = true; aft = true; morn = true; wake = true; }
    else if (eve) { aft = true; morn = true; wake = true; }
    else if (aft) { morn = true; wake = true; }
    else if (morn) { wake = true; }

    final total = [wake, morn, aft, eve, night].where((e) => e).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "REFLECTION PROTOCOL",
                style: TextStyle(
                  color: AppTheme.fhTextSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                "$total/5 LOGS",
                style: const TextStyle(
                  color: AppTheme.fhAccentTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoMono',
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

          const SizedBox(height: 16),
          
          if (lastLog != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                "LAST LOGGED AT: ${DateFormat('HH:mm').format(lastLog.timestamp)}", 
                style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono')
              ),
            ),
          
          SizedBox(
            width: double.infinity,
            child: ValorantButton(
              label: "LOG INSIGHT",
              icon: MdiIcons.notebookEditOutline,
              isPrimary: false,
              color: AppTheme.fhAccentTeal,
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
            color: isComplete ? AppTheme.fhAccentTeal : AppTheme.fhBgMedium,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isComplete ? AppTheme.fhAccentTeal : AppTheme.fhTextSecondary,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}