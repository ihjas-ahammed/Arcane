import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ScheduleHeroWidget extends StatelessWidget {
  final String nextTaskName;
  final String nextSubTaskName;
  final Color nextTaskColor;
  final bool isRunning;
  final VoidCallback onPlayPause;
  final VoidCallback onOpenPlan;

  const ScheduleHeroWidget({
    super.key,
    required this.nextTaskName,
    required this.nextSubTaskName,
    required this.nextTaskColor,
    required this.isRunning,
    required this.onPlayPause,
    required this.onOpenPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nextTaskColor.withOpacity(0.5), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            nextTaskColor.withOpacity(0.15),
            AppTheme.fhBgDeepDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: nextTaskColor.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.targetAccount, color: nextTaskColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "UP NEXT",
                      style: TextStyle(
                        color: nextTaskColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontFamily: AppTheme.fontDisplay,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: onOpenPlan,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhTextSecondary.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(MdiIcons.formatListBulleted, size: 12, color: AppTheme.fhTextSecondary),
                        const SizedBox(width: 4),
                        const Text("DAY PLAN", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextSubTaskName.toUpperCase(),
                        style: GoogleFonts.chakraPetch(
                          color: AppTheme.fhTextPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        nextTaskName.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.fhTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.fontDisplay,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Play/Pause Button
                if (nextSubTaskName != "NONE")
                  GestureDetector(
                    onTap: onPlayPause,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isRunning ? AppTheme.fhAccentRed : nextTaskColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: isRunning ? AppTheme.fhAccentRed.withOpacity(0.4) : nextTaskColor.withOpacity(0.4), blurRadius: 10)
                        ]
                      ),
                      child: Icon(
                        isRunning ? MdiIcons.pause : MdiIcons.play,
                        color: Colors.black,
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}