import 'package:flutter/material.dart';
import 'package:arcane/src/models/timeline_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/schedule/timeline_entry_card.dart';
import 'package:intl/intl.dart';

class ScheduleTimeline extends StatefulWidget {
  final List<TimelineEntry> entries;
  final VoidCallback onAddSession;
  final Function(TimelineEntry) onEditEntry;
  final double initialScrollOffset;

  const ScheduleTimeline({
    super.key,
    required this.entries,
    required this.onAddSession,
    required this.onEditEntry,
    this.initialScrollOffset = 0,
  });

  @override
  State<ScheduleTimeline> createState() => _ScheduleTimelineState();
}

class _ScheduleTimelineState extends State<ScheduleTimeline> {
  final double _basePixelsPerHour = 120.0;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(initialScrollOffset: widget.initialScrollOffset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.entries.isNotEmpty) {
        double earliestHour = 24;
        for (var e in widget.entries) {
          final h = e.startTime.hour + (e.startTime.minute / 60.0);
          if (h < earliestHour) earliestHour = h;
        }
        final offset = (earliestHour - 1).clamp(0, 24) * _basePixelsPerHour;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(offset);
        }
      } else {
        final offset = 8 * _basePixelsPerHour;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(offset);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<_LayoutEntry> _calculateLayout(List<TimelineEntry> entries) {
    // Exact representation, so no minimum duration required visually if drawn properly
    if (entries.isEmpty) return [];

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

    for (var le in layout) {
      le.totalCols = columns.length;
    }

    return layout;
  }

  @override
  Widget build(BuildContext context) {
    const int hoursCount = 24;
    final double pixelsPerHour = _basePixelsPerHour;
    final double totalHeight = pixelsPerHour * hoursCount;

    final layoutEntries = _calculateLayout(widget.entries);

    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        color: AppTheme.fhBgDeepDark,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: GestureDetector(
            onTapUp: (details) {
              widget.onAddSession();
            },
            child: Container(
              height: totalHeight,
              width: double.infinity,
              color: Colors.transparent,
              child: Stack(
                children: [
                  // Grid
                  ...List.generate(hoursCount, (index) {
                    return Positioned(
                      top: index * pixelsPerHour,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: pixelsPerHour,
                        decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(
                                  color: AppTheme.fhBorderColor.withOpacity(0.2),
                                  width: 1)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: Text("${index.toString().padLeft(2, '0')}:00",
                              style: TextStyle(
                                  color: AppTheme.fhTextSecondary.withOpacity(0.5),
                                  fontSize: 10,
                                  fontFamily: 'RobotoMono')),
                        ),
                      ),
                    );
                  }),

                  // Current Time
                  _buildCurrentTimeIndicator(pixelsPerHour),

                  // Entries
                  ...layoutEntries.map((le) {
                    final entry = le.entry;
                    final startTotalHours = entry.startTime.hour + (entry.startTime.minute / 60.0);
                    final top = startTotalHours * pixelsPerHour;
                    
                    // Exact Height Calculation
                    final height = (entry.durationSeconds / 3600.0) * pixelsPerHour;

                    const double leftGutter = 60.0;
                    final double availableWidth = (constraints.maxWidth - leftGutter - 10).clamp(0.0, double.infinity);
                    final double widthPerCol = availableWidth / le.totalCols;
                    final double left = leftGutter + (le.col * widthPerCol);

                    return Positioned(
                      top: top,
                      left: left,
                      child: TimelineEntryCard(
                        entry: entry,
                        height: height,
                        width: (widthPerCol - 4).clamp(0.0, double.infinity),
                        onTap: () => widget.onEditEntry(entry),
                      )
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCurrentTimeIndicator(double pixelsPerHour) {
    final now = DateTime.now();
    final currentHour = now.hour + (now.minute / 60.0);
    final top = currentHour * pixelsPerHour;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 55,
            padding: const EdgeInsets.only(right: 4),
            alignment: Alignment.centerRight,
            child: Text(
              DateFormat('HH:mm').format(now),
              style: const TextStyle(
                  color: AppTheme.fhAccentRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  fontFamily: 'RobotoMono'),
            ),
          ),
          const Expanded(
              child: Divider(color: AppTheme.fhAccentRed, thickness: 1)),
        ],
      ),
    );
  }
}

class _LayoutEntry {
  final TimelineEntry entry;
  final int col;
  int totalCols = 0;
  _LayoutEntry(this.entry, this.col);
}