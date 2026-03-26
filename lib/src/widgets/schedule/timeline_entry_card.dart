import 'package:flutter/material.dart';
import 'package:arcane/src/models/timeline_models.dart';
import 'package:intl/intl.dart';

class TimelineEntryCard extends StatelessWidget {
  final TimelineEntry entry;
  final double height;
  final double width;
  final VoidCallback onTap;

  const TimelineEntryCard({
    super.key,
    required this.entry,
    required this.height,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPredicted = entry.isPredicted;
    final effectiveColor = isPredicted ? entry.color.withOpacity(0.15) : entry.color.withOpacity(0.25);
    final borderColor = isPredicted ? entry.color.withOpacity(0.3) : entry.color;
    
    // Hide content if height is extremely small to prevent overflow UI breaks
    final bool showTitle = height >= 14;
    final bool showTime = height >= 30;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: effectiveColor,
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: ClipRect(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showTitle)
                  Row(
                    children: [
                      if (isPredicted)
                        Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: Icon(Icons.auto_awesome, size: 8, color: borderColor),
                        ),
                      Expanded(
                        child: Text(
                          entry.title,
                          style: TextStyle(
                            color: isPredicted ? Colors.white70 : Colors.white,
                            fontSize: 9,
                            fontWeight: isPredicted ? FontWeight.normal : FontWeight.bold
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (showTime)
                  Text(
                    "${DateFormat('HH:mm').format(entry.startTime)} - ${DateFormat('HH:mm').format(entry.endTime)}",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 8,
                      fontFamily: 'RobotoMono'
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}