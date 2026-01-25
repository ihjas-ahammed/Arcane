import 'package:flutter/material.dart';
import 'package:arcane/src/services/timetable_service.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TimetableSessionCard extends StatelessWidget {
  final String label;
  final TimetableSession? session;
  final bool isHighlight;

  const TimetableSessionCard({
    super.key,
    required this.label,
    required this.session,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return ValorantCard(
        borderColor: AppTheme.fhBorderColor.withOpacity(0.1),
        backgroundColor: AppTheme.fhBgDark.withOpacity(0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            const Center(child: Text("NO DATA", style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: AppTheme.fontDisplay, fontSize: 16))),
          ],
        ),
      );
    }

    final color = session!.color;
    
    return ValorantCard(
      borderColor: isHighlight ? color : AppTheme.fhBorderColor.withOpacity(0.2),
      backgroundColor: isHighlight ? color.withOpacity(0.1) : AppTheme.fhBgDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: isHighlight ? color : AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${session!.startTime.format(context)} - ${session!.endTime.format(context)}",
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            session!.subject.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.fhTextPrimary,
              fontFamily: AppTheme.fontDisplay,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              height: 0.9
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(width: 4, height: 4, color: color),
              const SizedBox(width: 6),
              Text(
                session!.type.toUpperCase(),
                style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          )
        ],
      ),
    ).animate(target: isHighlight ? 1 : 0).shimmer(duration: 2000.ms, color: color.withOpacity(0.3));
  }
}