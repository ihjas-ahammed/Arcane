import 'package:flutter/material.dart';
import 'package:arcane/src/models/time_sync_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TimeSyncBlockCard extends StatelessWidget {
  final TimeSyncBlock block;
  final VoidCallback onTap;

  const TimeSyncBlockCard({
    super.key,
    required this.block,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final duration = block.durationMinutes;
    final durationStr = duration < 60 
        ? "${duration}m" 
        : "${(duration/60).floor()}h ${duration%60}m";
        
    final startStr = DateFormat('HH:mm').format(block.startTime);
    final endStr = DateFormat('HH:mm').format(block.endTime);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: block.color, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Time Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(startStr, style: const TextStyle(color: Colors.white, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold, fontSize: 13)),
                  Container(width: 1, height: 12, color: Colors.white24, margin: const EdgeInsets.only(left: 4, top: 2, bottom: 2)),
                  Text(endStr, style: TextStyle(color: Colors.white54, fontFamily: 'RobotoMono', fontSize: 11)),
                ],
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.title.toUpperCase(),
                      style: TextStyle(
                        color: AppTheme.fhTextPrimary,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppTheme.fontDisplay,
                        letterSpacing: 1.0,
                        fontSize: 16
                      ),
                    ),
                    if (block.description.isNotEmpty)
                      Text(
                        block.description,
                        style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              
              // Duration Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: block.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: block.color.withOpacity(0.3))
                ),
                child: Row(
                  children: [
                    Icon(MdiIcons.clockTimeFourOutline, size: 10, color: block.color),
                    const SizedBox(width: 4),
                    Text(durationStr, style: TextStyle(color: block.color, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}