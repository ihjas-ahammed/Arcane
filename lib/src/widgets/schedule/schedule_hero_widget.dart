import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/atoms/hero_stat_item.dart'; // Modularized
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;

class ScheduleHeroWidget extends StatelessWidget {
  final String latestTaskName;
  final String mostSpentTaskName;
  final int mostSpentTimeSeconds;
  final String greeting;

  const ScheduleHeroWidget({
    super.key,
    required this.latestTaskName,
    required this.mostSpentTaskName,
    required this.mostSpentTimeSeconds,
    this.greeting = "SYSTEM ONLINE",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.fhBgDark,
            AppTheme.fhBgDeepDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color: AppTheme.fhAccentTeal,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Icon(MdiIcons.chartTimelineVariant, color: AppTheme.fhAccentTeal, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: HeroStatItem(
                  label: "LATEST OP",
                  value: latestTaskName.isNotEmpty ? latestTaskName : "N/A",
                  icon: MdiIcons.clockFast,
                  color: AppTheme.fhTextPrimary,
                ),
              ),
              Container(width: 1, height: 40, color: AppTheme.fhBorderColor.withOpacity(0.3), margin: const EdgeInsets.symmetric(horizontal: 12)),
              Expanded(
                child: HeroStatItem(
                  label: "PRIMARY FOCUS",
                  value: mostSpentTaskName.isNotEmpty ? mostSpentTaskName : "N/A",
                  subValue: mostSpentTimeSeconds > 0 ? helper.formatTime(mostSpentTimeSeconds.toDouble()) : null,
                  icon: MdiIcons.fire,
                  color: AppTheme.fhAccentOrange,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}