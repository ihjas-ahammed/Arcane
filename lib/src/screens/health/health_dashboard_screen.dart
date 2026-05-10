import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/views/health_dashboard_view.dart';
import 'package:google_fonts/google_fonts.dart';

class HealthDashboardScreen extends StatelessWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        title: Text("BIOMETRICS & NUTRITION", style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: JweTheme.bgBase,
        iconTheme: const IconThemeData(color: JweTheme.accentCyan),
      ),
      body:  SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800),
            child: HealthDashboardView(),
          ),
        ),
      ),
    );
  }
}