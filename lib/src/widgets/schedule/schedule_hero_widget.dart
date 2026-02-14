import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
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
            children: [
              Expanded(
                child: _buildStatItem(
                  label: "LATEST OP",
                  value: latestTaskName.isNotEmpty ? latestTaskName : "N/A",
                  icon: MdiIcons.clockFast,
                  color: AppTheme.fhTextPrimary,
                ),
              ),
              Container(width: 1, height: 40, color: AppTheme.fhBorderColor.withOpacity(0.3)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: _buildStatItem(
                    label: "PRIMARY FOCUS",
                    value: mostSpentTaskName.isNotEmpty ? mostSpentTaskName : "N/A",
                    subValue: mostSpentTimeSeconds > 0 ? helper.formatTime(mostSpentTimeSeconds.toDouble()) : null,
                    icon: MdiIcons.fire,
                    color: AppTheme.fhAccentOrange,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    String? subValue,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppTheme.fhTextSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.fhTextSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontFamily: AppTheme.fontDisplay,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        if (subValue != null)
          Text(
            subValue,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 10,
              fontFamily: 'RobotoMono',
            ),
          )
      ],
    );
  }
}