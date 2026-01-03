import 'package:flutter/material.dart';
import 'package:arcane/src/models/timeline_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter/gestures.dart';
import 'dart:collection';

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

  // --- Logic to handle overlapping entries ---
  List<_LayoutEntry> _calculateLayout(List<TimelineEntry> entries) {
    if (entries.isEmpty) return [];
    
    // Sort by start time
    final sorted = List<TimelineEntry>.from(entries)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
      
    final List<_LayoutEntry> layout = [];
    final List<List<_LayoutEntry>> columns = [];

    for (var entry in sorted) {
      int columnIndex = 0;
      bool placed = false;
      
      while (!placed) {
        if (columnIndex >= columns.length) {
          columns.add([]);
        }
        
        // Check if this column has an overlap
        bool hasOverlap = false;
        for (var colEntry in columns[columnIndex]) {
          if (entry.startTime.isBefore(colEntry.entry.endTime) &&
              entry.endTime.isAfter(colEntry.entry.startTime)) {
            hasOverlap = true;
            break;
          }
        }
        
        if (!hasOverlap) {
          final le = _LayoutEntry(entry, columnIndex);
          columns[columnIndex].add(le);
          layout.add(le);
          placed = true;
        } else {
          columnIndex++;
        }
      }
    }
    
    // Set total columns for each entry in a conflict group
    for (var le in layout) {
      le.totalCols = columns.length;
    }
    
    return layout;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    DateTime minStart = now;
    DateTime maxEnd = now;

    if (widget.entries.isNotEmpty) {
      minStart = widget.entries.first.startTime;
      maxEnd = widget.entries.first.endTime;
      for (var s in widget.entries) {
        if (s.startTime.isBefore(minStart)) minStart = s.startTime;
        if (s.endTime.isAfter(maxEnd)) maxEnd = s.endTime;
      }
    }

    final startHour = minStart.hour;
    int endHour = maxEnd.hour + (maxEnd.minute > 0 ? 1 : 0);
    if (endHour <= startHour + 2) endHour = startHour + 4;
    if (endHour > 24) endHour = 24;

    final int hoursCount = endHour - startHour;
    final double pixelsPerHour = _basePixelsPerHour * _scale;
    final double totalHeight = pixelsPerHour * hoursCount;
    
    final layoutEntries = _calculateLayout(widget.entries);

    return Stack(
      children: [
        Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              setState(() => _scale = (_scale - event.scrollDelta.dy * 0.001).clamp(0.5, 10.0));
            }
          },
          child: GestureDetector(
            onScaleUpdate: (details) => setState(() => _scale = (_scale * details.scale).clamp(0.5, 10.0)),
            child: Container(
              height: totalHeight,
              width: double.infinity,
              color: Colors.transparent,
              child: Stack(
                children: [
                  // Hour Grid
                  ...List.generate(hoursCount, (index) {
                    final currentHour = (startHour + index) % 24;
                    return Positioned(
                      top: index * pixelsPerHour,
                      left: 0, right: 0,
                      child: Container(
                        height: pixelsPerHour,
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: AppTheme.fhAccentTeal.withOpacity(0.1), width: 1)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, top: 2),
                          child: Text("${currentHour.toString().padLeft(2, '0')}:00", style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 9)),
                        ),
                      ),
                    );
                  }),

                  // Entries with Overlap Handling
                  ...layoutEntries.map((le) {
                    final entry = le.entry;
                    final startOffset = (entry.startTime.hour * 3600 + entry.startTime.minute * 60 + entry.startTime.second) - (startHour * 3600);
                    final top = (startOffset / 3600.0) * pixelsPerHour;
                    final height = (entry.durationSeconds / 3600.0) * pixelsPerHour;
                    
                    // Horizontal distribution
                    const double leftGutter = 50.0;
                    final double availableWidth = MediaQuery.of(context).size.width - leftGutter - 40;
                    final double widthPerCol = availableWidth / le.totalCols;
                    final double left = leftGutter + (le.col * widthPerCol);

                    return Positioned(
                      top: top,
                      left: left,
                      width: widthPerCol - 4,
                      height: height.clamp(15.0, 9999.0),
                      child: GestureDetector(
                        onTap: entry.isEditable ? () => widget.onEditEntry(entry) : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: entry.color.withOpacity(entry.isEditable ? 0.5 : 0.2),
                            border: Border.all(color: entry.color.withOpacity(0.8), width: entry.isEditable ? 1.5 : 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: height > 20 
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.title, style: TextStyle(color: Colors.white, fontSize: (widthPerCol < 80) ? 9 : 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (height > 35) Text("${DateFormat('HH:mm').format(entry.startTime)}", style: const TextStyle(color: Colors.white70, fontSize: 9)),
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
        Positioned(
          right: 8, top: 8,
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
      height: 32, width: 32,
      decoration: BoxDecoration(color: AppTheme.fhBgDark.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
      child: IconButton(padding: EdgeInsets.zero, icon: Icon(icon, size: 18, color: AppTheme.fhTextPrimary), onPressed: onPressed),
    );
  }
}

class _LayoutEntry {
  final TimelineEntry entry;
  final int col;
  int totalCols;
  _LayoutEntry(this.entry, this.col, {this.totalCols = 1});
}