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
  // Scale factor allows zooming from 0.5x (30px/hr) to 3x (180px/hr)
  double _scale = 1.0;
  final double _basePixelsPerHour = 60.0;

  @override
  Widget build(BuildContext context) {
    // Sort sessions
    final sortedSessions = List<TaskSession>.from(widget.sessions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final double pixelsPerHour = _basePixelsPerHour * _scale;
    final double totalHeight = pixelsPerHour * 24;

    return GestureDetector(
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_scale * details.scale).clamp(0.5, 4.0);
        });
      },
      child: SingleChildScrollView(
        child: SizedBox(
          height: totalHeight,
          child: Stack(
            children: [
              // Background Grid & Time Labels
              Column(
                children: List.generate(24, (index) {
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
                              "${index.toString().padLeft(2, '0')}:00",
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
                // Calculate position relative to 00:00 of the session's day
                // We assume filtered sessions are for the same day or we project time onto 0-24h
                final startMinutes = session.startTime.hour * 60 + session.startTime.minute;
                final durationMinutes = session.durationMinutes;

                final double top = (startMinutes / 60.0) * pixelsPerHour;
                final double height = (durationMinutes / 60.0) * pixelsPerHour;

                // Min visual height to be clickable
                final double visualHeight = height < 2 ? 2 : height;

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

              // Current Time Indicator (if today)
              // Optional: Calculate current time line if it falls within view
            ],
          ),
        ),
      ),
    );
  }
}