import 'package:flutter/material.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class LastInsightDialog extends StatelessWidget {
  final ReflectionLog log;

  const LastInsightDialog({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
       backgroundColor: JweTheme.panel,
       shape: Border.all(color: JweTheme.accentCyan, width: 2),
       title: Row(
         children: [
           Icon(MdiIcons.brain, color: JweTheme.accentCyan, size: 18),
           const SizedBox(width: 8),
           Text("TACTICAL INSIGHT", style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16)),
         ]
       ),
       content: SingleChildScrollView(
         child: Text(log.aiFeedback, style: const TextStyle(color: JweTheme.textMuted, fontSize: 13, height: 1.4)),
       ),
       actions: [
         TextButton(
           onPressed: ()=>Navigator.pop(context), 
           child: const Text("ACKNOWLEDGE", style: TextStyle(color: JweTheme.accentCyan))
         ),
       ]
     );
  }
}