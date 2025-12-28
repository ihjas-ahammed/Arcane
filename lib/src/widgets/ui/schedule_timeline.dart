import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter/gestures.dart';

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

  void _zoomIn() {
    setState(() {
      _scale = (_scale + 0.5).clamp(0.5, 10.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _scale = (_scale - 0.5).clamp(0.5, 10.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedSessions = List<TaskSession>.from(widget.sessions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    DateTime startBoundary;
    DateTime endBoundary;
    final now = DateTime.now();

    if (sortedSessions.isEmpty) {
      startBoundary = DateTime(now.year, now.month, now.day, 0, 0);
      endBoundary = DateTime(now.year, now.month, now.day, 23, 59);
    } else {
      startBoundary = sortedSessions.first.startTime;
      final reference = sortedSessions.first.startTime;
      final isToday = reference.year == now.year &&
          reference.month == now.month &&
          reference.day == now.day;

      DateTime lastSessionEnd = sortedSessions.last.endTime;
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
    int endHour = endBoundary.hour;
    if (endBoundary.minute > 0) {
      endHour++;
    }
    if (endHour > 24) endHour = 24;
    if (endHour <= startHour) endHour = startHour + 1;

    final int hoursCount = endHour - startHour;
    final double pixelsPerHour = _basePixelsPerHour * _scale;
    final double totalHeight = pixelsPerHour * hoursCount;

    return Stack(
      children: [
        Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              final double dy = event.scrollDelta.dy;
              setState(() {
                if (dy < 0) {
                  _scale = (_scale + 0.1).clamp(0.5, 10.0);
                } else {
                  _scale = (_scale - 0.1).clamp(0.5, 10.0);
                }
              });
            }
          },
          child: GestureDetector(
            onScaleUpdate: (details) {
              setState(() {
                _scale = (_scale * details.scale).clamp(0.5, 10.0);
              });
            },
            child: Container(
              height: totalHeight,
              width: double.infinity,
              color: Colors.transparent,
              child: Stack(
                children: [
                  // Background Grid
                  Column(
                    children: List.generate(hoursCount, (index) {
                      final currentHour = startHour + index;
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
                                padding:
                                    const EdgeInsets.only(top: 2.0, right: 8.0),
                                child: Text(
                                  "${displayHour.toString().padLeft(2, '0')}:00",
                                  style: TextStyle(
                                    color: AppTheme.fhTextSecondary
                                        .withOpacity(0.5),
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ),
                            Expanded(child: Container()),
                          ],
                        ),
                      );
                    }),
                  ),

                  // Sessions
                  ...sortedSessions.map((session) {
                    final startSecondsVal = session.startTime.hour * 3600 +
                        session.startTime.minute * 60 +
                        session.startTime.second;
                    final offsetSeconds = startHour * 3600;
                    final relativeStartSeconds =
                        startSecondsVal - offsetSeconds;
                    final durationSeconds = session.durationSeconds;

                    final double top =
                        (relativeStartSeconds / 3600.0) * pixelsPerHour;
                    final double height =
                        (durationSeconds / 3600.0) * pixelsPerHour;
                    final double visualHeight = height < 2 ? 2 : height;

                    if (top + visualHeight < 0 || top > totalHeight) {
                      return const SizedBox.shrink();
                    }

                    return Positioned(
                      top: top,
                      left: 60,
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
                                      "${DateFormat('HH:mm:ss').format(session.startTime)} - ${DateFormat('HH:mm:ss').format(session.endTime)}",
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
                                        durationSeconds < 60
                                            ? "${durationSeconds}s"
                                            : "${(durationSeconds / 60).toStringAsFixed(1)} min",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 9,
                                        ),
                                      )
                                  ],
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),

        // Manual Zoom Controls
        Positioned(
          right: 8,
          top: 8,
          child: Column(
            children: [
              _buildZoomButton(Icons.add, _zoomIn),
              const SizedBox(height: 8),
              _buildZoomButton(Icons.remove, _zoomOut),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return Container(
      height: 32,
      width: 32,
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: AppTheme.fhTextPrimary),
        onPressed: onPressed,
      ),
    );
  }
}
