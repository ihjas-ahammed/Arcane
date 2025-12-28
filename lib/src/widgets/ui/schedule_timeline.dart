import 'package:flutter/material.dart';
import 'package:arcane/src/models/timeline_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter/gestures.dart';

class ScheduleTimeline extends StatefulWidget {
  final List<TimelineEntry> entries;
  final VoidCallback onAddSession;
  final Function(TimelineEntry) onEditEntry;

  const ScheduleTimeline({
    super.key,
    required this.entries,
    required this.onAddSession,
    required this.onEditEntry,
  });

  @override
  State<ScheduleTimeline> createState() => _ScheduleTimelineState();
}

class _ScheduleTimelineState extends State<ScheduleTimeline> {
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
    // Sort entries by time, prioritize editable ones on top if overlapping (handled by painter order ideally, but simple sort works for rendering list)
    final sortedEntries = List<TimelineEntry>.from(widget.entries)
      ..sort((a, b) {
        final cmp = a.startTime.compareTo(b.startTime);
        if (cmp != 0) return cmp;
        // If same start time, put editable ones later so they render on top?
        // Actually rendering order: last is top.
        return a.isEditable ? 1 : -1;
      });

    DateTime startBoundary;
    DateTime endBoundary;
    final now = DateTime.now();

    if (sortedEntries.isEmpty) {
      startBoundary = DateTime(now.year, now.month, now.day, 0, 0);
      endBoundary = DateTime(now.year, now.month, now.day, 23, 59);
    } else {
      startBoundary = sortedEntries.first.startTime;
      // Find min start and max end
      DateTime minStart = sortedEntries.first.startTime;
      DateTime maxEnd = sortedEntries.first.endTime;

      for (var s in sortedEntries) {
        if (s.startTime.isBefore(minStart)) minStart = s.startTime;
        if (s.endTime.isAfter(maxEnd)) maxEnd = s.endTime;
      }

      startBoundary = minStart;

      final reference = minStart;
      final isToday = reference.year == now.year &&
          reference.month == now.month &&
          reference.day == now.day;

      if (isToday && now.isAfter(maxEnd)) {
        endBoundary = now;
      } else {
        endBoundary = maxEnd;
      }
    }

    // Adjust boundaries to nearest hour
    final startHour = startBoundary.hour;
    int endHour = endBoundary.hour;
    if (endBoundary.minute > 0) {
      endHour++;
    }
    if (endHour > 24) endHour = 24;
    // Ensure we have at least a few hours visible
    if (endHour <= startHour + 2) endHour = startHour + 4;
    if (endHour > 24) endHour = 24;

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
                              color:
                                  AppTheme.fhAccentTeal.withValues(alpha: 0.3),
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

                  // Entries
                  ...sortedEntries.map((entry) {
                    final startSecondsVal = entry.startTime.hour * 3600 +
                        entry.startTime.minute * 60 +
                        entry.startTime.second;
                    final offsetSeconds = startHour * 3600;
                    final relativeStartSeconds =
                        startSecondsVal - offsetSeconds;
                    final durationSeconds = entry.durationSeconds;

                    final double top =
                        (relativeStartSeconds / 3600.0) * pixelsPerHour;
                    final double height =
                        (durationSeconds / 3600.0) * pixelsPerHour;
                    // Min height for visibility
                    final double visualHeight = height < 15 ? 15 : height;

                    if (top + visualHeight < 0 || top > totalHeight) {
                      return const SizedBox.shrink();
                    }

                    // For background items, reduce opacity
                    final Color baseColor = entry.color;
                    final Color displayColor = entry.isEditable
                        ? baseColor.withOpacity(0.4)
                        : baseColor.withOpacity(0.15);
                    final Color borderColor = entry.isEditable
                        ? baseColor.withOpacity(0.8)
                        : baseColor.withOpacity(0.3);

                    return Positioned(
                      top: top,
                      left: 60,
                      right: 16,
                      height: visualHeight,
                      child: GestureDetector(
                        onTap: entry.isEditable
                            ? () => widget.onEditEntry(entry)
                            : null, // Read-only for background tasks
                        child: Container(
                          decoration: BoxDecoration(
                            color: displayColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: borderColor,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.centerLeft,
                          child: visualHeight > 10
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (visualHeight > 25)
                                      Text(
                                        entry.title,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(
                                              entry.isEditable ? 1.0 : 0.7),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    Text(
                                      "${DateFormat('HH:mm').format(entry.startTime)} - ${DateFormat('HH:mm').format(entry.endTime)}",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(
                                            entry.isEditable ? 0.9 : 0.5),
                                        fontSize: 9,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
