import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/views/projects_view.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        title: Text("PROJECT PROTOCOLS", style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: JweTheme.bgBase,
        iconTheme: const IconThemeData(color: JweTheme.accentCyan),
      ),
      body:  SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1000),
            child: ProjectsView()
          )
        )
      ),
    );
  }
}