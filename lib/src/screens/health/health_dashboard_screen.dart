import 'package:flutter/material.dart';
import 'package:missions/src/theme/spidey_theme.dart';
import 'package:missions/src/widgets/views/health_dashboard_view.dart';
import 'package:google_fonts/google_fonts.dart';

class HealthDashboardScreen extends StatelessWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 4, height: 22, color: SpideyTheme.spideyRed),
            const SizedBox(width: 10),
            Text(
              "BIOMETRICS",
              style: GoogleFonts.rajdhani(
                color: SpideyTheme.textWhite,
                fontWeight: FontWeight.bold,
                letterSpacing: 3.0,
                fontSize: 22,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: SpideyTheme.spideyCyan),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: SpideyTheme.backdropGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: const HealthDashboardView(),
            ),
          ),
        ),
      ),
    );
  }
}
