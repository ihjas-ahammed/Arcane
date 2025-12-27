import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ScheduleTimeline extends StatefulWidget {
  final List<TaskSession> sessions;
  final VoidCallback onAddSession;
  final Function(TaskSession) onEditSession;

  const ScheduleTimeline({
    super.key,
    required this.sessions,
    required this.onAddSession,
    required this.onEditSession,
  });

  @override
  State<ScheduleTimeline> createState() => _ScheduleTimelineState();
}

class _ScheduleTimelineState extends State<ScheduleTimeline> {
  // Base scale: 60px per hour.
  // Scale factor allows zooming from 0.5x (30px/hr) to 10x (600px/hr)
  double _scale = 2.0;
  final double _basePixelsPerHour = 60.0;

  @override
  Widget build(BuildContext context) {
    // Sort sessions
    final sortedSessions = List<TaskSession>.from(widget.sessions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Determine bounds
    DateTime startBoundary;
    DateTime endBoundary;
    final now = DateTime.now();

    if (sortedSessions.isEmpty) {
      // Default to 00:00 - 24:00 if no sessions
      // Or if we want to default to "Now" centered?
      // User said "save space", but with 0 sessions we have no anchor.
      // Let's stick to a safe 08:00 - 18:00 or similar default if empty?
      // Or just 0-24 for full day freedom until initialized.
      startBoundary = DateTime(now.year, now.month, now.day, 0, 0);
      endBoundary = DateTime(now.year, now.month, now.day, 23, 59);
    } else {
      startBoundary = sortedSessions.first.startTime;

      // Determine end boundary (Last session end vs Now)
      // Check if sessions are for "Today" to decide if "Now" is relevant
      final reference = sortedSessions.first.startTime;
      final isToday = reference.year == now.year &&
          reference.month == now.month &&
          reference.day == now.day;

      DateTime lastSessionEnd = sortedSessions.last.endTime;
      // Find the absolute latest end time among all sessions
      for (var s in sortedSessions) {
        if (s.endTime.isAfter(lastSessionEnd)) {
          lastSessionEnd = s.endTime;
        }
      }

      if (isToday && now.isAfter(lastSessionEnd)) {
        endBoundary = now;
      } else {
        endBoundary = lastSessionEnd;
      }
    }

    final startHour = startBoundary.hour;
    // For end hour, we want to include the full hour of the end time.
    // e.g. if end is 10:15, we need to show up to 11:00 (index 10) or cover index 10 fully?
    // We render grid lines for hours.
    // If range is 10:00 to 12:00 -> Hours 10, 11, 12.
    int endHour = endBoundary.hour;
    if (endBoundary.minute > 0) {
      endHour++;
    }
    // Ensure endHour doesn't exceed 24 (next day start)
    if (endHour > 24) endHour = 24;
    // Ensure endHour >= startHour
    if (endHour <= startHour) endHour = startHour + 1;

    final int hoursCount = endHour - startHour;

    final double pixelsPerHour = _basePixelsPerHour * _scale;
    final double totalHeight = pixelsPerHour * hoursCount;

    return GestureDetector(
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_scale * details.scale).clamp(0.5, 10.0);
        });
      },
      child: Container(
        height: totalHeight,
        width: double.infinity,
        color: Colors.transparent, // Ensure hits
        child: Stack(
          children: [
            // Background Grid & Time Labels
            Column(
              children: List.generate(hoursCount, (index) {
                final currentHour = startHour + index;
                // If we go past 24, it's next day? (simplified for single day view)
                // View assumes single day mostly.
                final displayHour = currentHour % 24;

                return Container(
                  height: pixelsPerHour,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: AppTheme.fhBorderColor.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 50,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2.0, right: 8.0),
                          child: Text(
                            "${displayHour.toString().padLeft(2, '0')}:00",
                            style: TextStyle(
                              color: AppTheme.fhTextSecondary.withOpacity(0.5),
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                      Expanded(child: Container()), // Grid line area
                    ],
                  ),
                );
              }),
            ),

            // Sessions
            ...sortedSessions.map((session) {
              // Calculate position relative to startHour
              final startMinutesVal =
                  session.startTime.hour * 60 + session.startTime.minute;
              final offsetMinutes = startHour * 60;
              final relativeStartMinutes = startMinutesVal - offsetMinutes;

              final durationMinutes = session.durationMinutes;

              final double top = (relativeStartMinutes / 60.0) * pixelsPerHour;
              final double height = (durationMinutes / 60.0) * pixelsPerHour;

              // Min visual height to be clickable
              final double visualHeight = height < 2 ? 2 : height;

              // Check if session is roughly within view bounds (simple clipping check)
              if (top + visualHeight < 0 || top > totalHeight) {
                return const SizedBox.shrink();
              }

              return Positioned(
                top: top,
                left: 60, // Offset for time labels
                right: 16,
                height: visualHeight,
                child: GestureDetector(
                  onTap: () => widget.onEditSession(session),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.fhAccentTeal.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppTheme.fhAccentTeal.withOpacity(0.6),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.centerLeft,
                    child: visualHeight > 20
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${DateFormat('HH:mm').format(session.startTime)} - ${DateFormat('HH:mm').format(session.endTime)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (visualHeight > 35)
                                Text(
                                  "${session.durationMinutes} min",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 9,
                                  ),
                                )
                            ],
                          )
                        : null, // Hide text if too small
                  ),
                ),
              );
            }),

            // Optional: Current Time Indicator could be added here if needed
            // But logic needs to account for relative positioning
          ],
        ),
      ),
    );
  }
}
