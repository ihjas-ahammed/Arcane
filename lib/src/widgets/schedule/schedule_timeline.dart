import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/schedule/timeline_entry_card.dart';

class ScheduleTimeline extends StatefulWidget {
  final List<TimelineEntry> entries;
  final DateTime? selectedDate;
  final Function(DateTime start, DateTime end)? onRangeCreated;
  final Function(TimelineEntry entry, DateTime newStart, DateTime newEnd)? onUpdateEntryTimeRange;
  final VoidCallback onAddSession;
  final Function(TimelineEntry) onEditEntry;
  final Function(TimelineEntry entry)? onSwitchTask;
  final double initialScrollOffset;
  final bool scrollToNow;
  final ValueListenable<int>? scrollToNowTick;

  const ScheduleTimeline({
    super.key,
    required this.entries,
    this.selectedDate,
    this.onRangeCreated,
    this.onUpdateEntryTimeRange,
    required this.onAddSession,
    required this.onEditEntry,
    this.onSwitchTask,
    this.initialScrollOffset = 0,
    this.scrollToNow = false,
    this.scrollToNowTick,
  });

  /// Calculates layout for timeline entries, clustering overlapping entries into side-by-side columns
  /// while allowing isolated entries without concurrent overlap to take full width.
  static List<TimelineLayoutEntry> calculateTimelineLayout(
    List<TimelineEntry> entries, {
    double basePixelsPerHour = 60.0,
  }) {
    if (entries.isEmpty) return [];

    final sorted = List<TimelineEntry>.from(entries)
      ..sort((a, b) {
        final cmp = a.startTime.compareTo(b.startTime);
        if (cmp != 0) return cmp;
        return b.endTime.compareTo(a.endTime);
      });

    final minVisualHours = 3.0 / basePixelsPerHour;

    // Group sorted entries into connected clusters of overlapping entries
    final List<List<TimelineEntry>> clusters = [];
    List<TimelineEntry> currentCluster = [];
    double currentClusterMaxEnd = -1.0;

    for (var entry in sorted) {
      final entryStartHours = entry.startTime.hour + (entry.startTime.minute / 60.0) + (entry.startTime.second / 3600.0);
      final entryDurationHours = math.max(minVisualHours, entry.durationSeconds / 3600.0);
      final entryEndHours = entryStartHours + entryDurationHours;

      if (currentCluster.isEmpty) {
        currentCluster.add(entry);
        currentClusterMaxEnd = entryEndHours;
      } else if (entryStartHours < currentClusterMaxEnd) {
        currentCluster.add(entry);
        if (entryEndHours > currentClusterMaxEnd) {
          currentClusterMaxEnd = entryEndHours;
        }
      } else {
        clusters.add(currentCluster);
        currentCluster = [entry];
        currentClusterMaxEnd = entryEndHours;
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    final List<TimelineLayoutEntry> layout = [];

    // Assign columns per cluster so isolated entries take full width
    for (var cluster in clusters) {
      final List<List<TimelineLayoutEntry>> clusterColumns = [];
      final List<TimelineLayoutEntry> clusterLayout = [];

      for (var entry in cluster) {
        final entryStartHours = entry.startTime.hour + (entry.startTime.minute / 60.0) + (entry.startTime.second / 3600.0);
        final entryDurationHours = math.max(minVisualHours, entry.durationSeconds / 3600.0);
        final entryEndHours = entryStartHours + entryDurationHours;

        int columnIndex = 0;
        bool placed = false;

        while (!placed) {
          if (columnIndex >= clusterColumns.length) {
            clusterColumns.add([]);
          }

          bool hasOverlap = false;
          for (var colEntry in clusterColumns[columnIndex]) {
            final colStartHours = colEntry.entry.startTime.hour + (colEntry.entry.startTime.minute / 60.0) + (colEntry.entry.startTime.second / 3600.0);
            final colDurationHours = math.max(minVisualHours, colEntry.entry.durationSeconds / 3600.0);
            final colEndHours = colStartHours + colDurationHours;

            if (entryStartHours < colEndHours && entryEndHours > colStartHours) {
              hasOverlap = true;
              break;
            }
          }

          if (!hasOverlap) {
            final le = TimelineLayoutEntry(entry, columnIndex);
            clusterColumns[columnIndex].add(le);
            clusterLayout.add(le);
            placed = true;
          } else {
            columnIndex++;
          }
        }
      }

      final int clusterTotalCols = clusterColumns.length;
      for (var le in clusterLayout) {
        le.totalCols = clusterTotalCols;

        // Calculate if this entry can expand to the right into empty adjacent columns
        final leStartHours = le.entry.startTime.hour + (le.entry.startTime.minute / 60.0) + (le.entry.startTime.second / 3600.0);
        final leDurationHours = math.max(minVisualHours, le.entry.durationSeconds / 3600.0);
        final leEndHours = leStartHours + leDurationHours;

        int span = 1;
        for (int c = le.col + 1; c < clusterTotalCols; c++) {
          bool hasColOverlap = false;
          for (var other in clusterColumns[c]) {
            final oStart = other.entry.startTime.hour + (other.entry.startTime.minute / 60.0) + (other.entry.startTime.second / 3600.0);
            final oDuration = math.max(minVisualHours, other.entry.durationSeconds / 3600.0);
            final oEnd = oStart + oDuration;
            if (leStartHours < oEnd && leEndHours > oStart) {
              hasColOverlap = true;
              break;
            }
          }
          if (hasColOverlap) break;
          span++;
        }
        le.colSpan = span;
      }

      layout.addAll(clusterLayout);
    }

    return layout;
  }

  @override
  State<ScheduleTimeline> createState() => _ScheduleTimelineState();
}

class _ScheduleTimelineState extends State<ScheduleTimeline> {
  final double _basePixelsPerHour = 120.0;
  late ScrollController _scrollController;

  // Selection & Resize State (Google Calendar style)
  String? _selectedEntryId;
  String? _resizingEntryId;
  bool? _resizingIsTop;
  DateTime? _resizingStartTime;
  DateTime? _resizingEndTime;
  DateTime? _initialEntryStartTime;
  DateTime? _initialEntryEndTime;
  double _initialDragGlobalY = 0.0;
  TimelineEntry? _activeResizingOriginalEntry;

  // Whole-Card Move Through Time State (Google Calendar style)
  String? _movingEntryId;
  DateTime? _movingStartTime;
  DateTime? _movingEndTime;
  DateTime? _initialMovingStartTime;
  DateTime? _initialMovingEndTime;
  double _initialMoveGlobalY = 0.0;
  TimelineEntry? _activeMovingOriginalEntry;

  // Drag-to-Create Range State
  bool _isCreatingRange = false;
  DateTime? _creatingStart;
  DateTime? _creatingEnd;
  int? _anchorMinutes;

  DateTime get _effectiveDate => widget.selectedDate ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(initialScrollOffset: widget.initialScrollOffset);
    widget.scrollToNowTick?.addListener(_handleScrollToNowTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      double targetHour;
      if (widget.scrollToNow) {
        final now = DateTime.now();
        targetHour = now.hour + (now.minute / 60.0);
      } else if (widget.entries.isNotEmpty) {
        targetHour = 24;
        for (var e in widget.entries) {
          final h = e.startTime.hour + (e.startTime.minute / 60.0);
          if (h < targetHour) targetHour = h;
        }
      } else {
        targetHour = 8;
      }
      // Keep target near the top of the viewport, with ~1.5h of lookback for context.
      final offset = (targetHour - 1.5).clamp(0, 24) * _basePixelsPerHour;
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(offset.clamp(0.0, maxScroll));
      }
    });
  }

  @override
  void didUpdateWidget(ScheduleTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _selectedEntryId = null;
      _resizingEntryId = null;
      _movingEntryId = null;
    }
    if (oldWidget.scrollToNowTick != widget.scrollToNowTick) {
      oldWidget.scrollToNowTick?.removeListener(_handleScrollToNowTick);
      widget.scrollToNowTick?.addListener(_handleScrollToNowTick);
    }
  }

  @override
  void dispose() {
    widget.scrollToNowTick?.removeListener(_handleScrollToNowTick);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScrollToNowTick() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final now = DateTime.now();
      final targetHour = now.hour + (now.minute / 60.0);
      final offset = (targetHour - 1.5).clamp(0, 24) * _basePixelsPerHour;
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        offset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '${hours}h' : '${hours}h ${rem}m';
  }

  void _startRangeCreation(Offset localPosition) {
    _selectedEntryId = null;
    final totalMinutes = (localPosition.dy / _basePixelsPerHour * 60).round();
    final snappedAnchor = ((totalMinutes / 2).round() * 2).clamp(0, 23 * 60 + 58);
    _anchorMinutes = snappedAnchor;

    final date = _effectiveDate;
    final start = DateTime(date.year, date.month, date.day, snappedAnchor ~/ 60, snappedAnchor % 60);
    final end = start.add(const Duration(minutes: 30));

    HapticFeedback.selectionClick();
    setState(() {
      _isCreatingRange = true;
      _creatingStart = start;
      _creatingEnd = end;
    });
  }

  void _updateRangeCreation(Offset localPosition) {
    if (!_isCreatingRange || _anchorMinutes == null) return;

    final totalMinutes = (localPosition.dy / _basePixelsPerHour * 60).round();
    final snappedCurrent = ((totalMinutes / 2).round() * 2).clamp(0, 24 * 60);

    final date = _effectiveDate;
    DateTime newStart;
    DateTime newEnd;

    if (snappedCurrent >= _anchorMinutes!) {
      final endMin = math.max(_anchorMinutes! + 2, snappedCurrent).clamp(0, 24 * 60);
      newStart = DateTime(date.year, date.month, date.day, _anchorMinutes! ~/ 60, _anchorMinutes! % 60);
      newEnd = DateTime(date.year, date.month, date.day, endMin ~/ 60, endMin % 60);
    } else {
      final startMin = math.min(_anchorMinutes! - 2, snappedCurrent).clamp(0, 24 * 60);
      newStart = DateTime(date.year, date.month, date.day, startMin ~/ 60, startMin % 60);
      newEnd = DateTime(date.year, date.month, date.day, _anchorMinutes! ~/ 60, _anchorMinutes! % 60);
    }

    if (newStart != _creatingStart || newEnd != _creatingEnd) {
      HapticFeedback.selectionClick();
      setState(() {
        _creatingStart = newStart;
        _creatingEnd = newEnd;
      });
    }
  }

  void _finishRangeCreation() {
    if (!_isCreatingRange) return;
    final start = _creatingStart;
    final end = _creatingEnd;

    HapticFeedback.mediumImpact();
    setState(() {
      _isCreatingRange = false;
      _creatingStart = null;
      _creatingEnd = null;
      _anchorMinutes = null;
    });

    if (start != null && end != null && end.difference(start).inMinutes >= 2) {
      widget.onRangeCreated?.call(start, end);
    }
  }

  void _onHandleDragStart(TimelineEntry entry, bool isTop, DragStartDetails details) {
    _initialDragGlobalY = details.globalPosition.dy;
    _activeResizingOriginalEntry = entry;
    _initialEntryStartTime = entry.startTime;
    _initialEntryEndTime = entry.endTime;
    _resizingEntryId = entry.id;
    _resizingIsTop = isTop;
    _resizingStartTime = entry.startTime;
    _resizingEndTime = entry.endTime;
    HapticFeedback.selectionClick();
    setState(() {});
  }

  DateTime _snapTo2Min(DateTime dt) {
    final totalMinutes = dt.hour * 60 + dt.minute;
    final snappedMinutes = ((totalMinutes / 2).round() * 2).clamp(0, 24 * 60 - 2);
    final hours = snappedMinutes ~/ 60;
    final mins = snappedMinutes % 60;
    return DateTime(dt.year, dt.month, dt.day, hours, mins);
  }

  void _onHandleDragUpdate(DragUpdateDetails details) {
    if (_resizingEntryId == null ||
        _initialEntryStartTime == null ||
        _initialEntryEndTime == null) {
      return;
    }

    final totalDeltaY = details.globalPosition.dy - _initialDragGlobalY;
    final rawDeltaMinutes = (totalDeltaY / _basePixelsPerHour * 60).round();

    if (_resizingIsTop == true) {
      final candidateStart = _snapTo2Min(_initialEntryStartTime!.add(Duration(minutes: rawDeltaMinutes)));
      final minAllowed = DateTime(_initialEntryStartTime!.year, _initialEntryStartTime!.month, _initialEntryStartTime!.day, 0, 0);
      final maxAllowed = _initialEntryEndTime!.subtract(const Duration(minutes: 2));
      final clampedStart = candidateStart.isBefore(minAllowed)
          ? minAllowed
          : (candidateStart.isAfter(maxAllowed) ? maxAllowed : candidateStart);

      if (clampedStart != _resizingStartTime) {
        HapticFeedback.selectionClick();
        setState(() {
          _resizingStartTime = clampedStart;
        });
      }
    } else {
      final candidateEnd = _snapTo2Min(_initialEntryEndTime!.add(Duration(minutes: rawDeltaMinutes)));
      final minAllowed = _initialEntryStartTime!.add(const Duration(minutes: 2));
      final maxAllowed = DateTime(_initialEntryEndTime!.year, _initialEntryEndTime!.month, _initialEntryEndTime!.day, 23, 58);
      final clampedEnd = candidateEnd.isBefore(minAllowed)
          ? minAllowed
          : (candidateEnd.isAfter(maxAllowed) ? maxAllowed : candidateEnd);

      if (clampedEnd != _resizingEndTime) {
        HapticFeedback.selectionClick();
        setState(() {
          _resizingEndTime = clampedEnd;
        });
      }
    }
  }

  void _onHandleDragEnd() {
    if (_resizingEntryId == null) return;

    final original = _activeResizingOriginalEntry;
    final finalStart = _resizingStartTime;
    final finalEnd = _resizingEndTime;

    HapticFeedback.mediumImpact();
    setState(() {
      _resizingEntryId = null;
      _activeResizingOriginalEntry = null;
      _initialEntryStartTime = null;
      _initialEntryEndTime = null;
      _resizingStartTime = null;
      _resizingEndTime = null;
    });

    if (original != null &&
        finalStart != null &&
        finalEnd != null &&
        widget.onUpdateEntryTimeRange != null &&
        (finalStart != original.startTime || finalEnd != original.endTime)) {
      widget.onUpdateEntryTimeRange!(original, finalStart, finalEnd);
    }
  }

  void _onHandleDragCancel() {
    if (_resizingEntryId == null) return;
    setState(() {
      _resizingEntryId = null;
      _activeResizingOriginalEntry = null;
      _initialEntryStartTime = null;
      _initialEntryEndTime = null;
      _resizingStartTime = null;
      _resizingEndTime = null;
    });
  }

  // Whole-Card Move Through Time (Google Calendar style)
  void _onCardMoveStart(TimelineEntry entry, LongPressStartDetails details) {
    if (!entry.isEditable) return;
    _initialMoveGlobalY = details.globalPosition.dy;
    _activeMovingOriginalEntry = entry;
    _initialMovingStartTime = entry.startTime;
    _initialMovingEndTime = entry.endTime;
    _movingEntryId = entry.id;
    _movingStartTime = entry.startTime;
    _movingEndTime = entry.endTime;
    _selectedEntryId = entry.id;
    HapticFeedback.heavyImpact();
    setState(() {});
  }

  void _onCardMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_movingEntryId == null ||
        _initialMovingStartTime == null ||
        _initialMovingEndTime == null) {
      return;
    }

    final totalDeltaY = details.globalPosition.dy - _initialMoveGlobalY;
    final rawDeltaMinutes = (totalDeltaY / _basePixelsPerHour * 60).round();

    final duration = _initialMovingEndTime!.difference(_initialMovingStartTime!);
    final candidateStart = _snapTo2Min(_initialMovingStartTime!.add(Duration(minutes: rawDeltaMinutes)));

    final dayStart = DateTime(_initialMovingStartTime!.year, _initialMovingStartTime!.month, _initialMovingStartTime!.day, 0, 0);
    final dayEnd = DateTime(_initialMovingStartTime!.year, _initialMovingStartTime!.month, _initialMovingStartTime!.day, 23, 58);

    DateTime clampedStart = candidateStart;
    if (clampedStart.isBefore(dayStart)) {
      clampedStart = dayStart;
    }
    if (clampedStart.add(duration).isAfter(dayEnd)) {
      clampedStart = dayEnd.subtract(duration);
    }
    final clampedEnd = clampedStart.add(duration);

    if (clampedStart != _movingStartTime || clampedEnd != _movingEndTime) {
      HapticFeedback.selectionClick();
      setState(() {
        _movingStartTime = clampedStart;
        _movingEndTime = clampedEnd;
      });
    }
  }

  void _onCardMoveEnd() {
    if (_movingEntryId == null) return;

    final original = _activeMovingOriginalEntry;
    final finalStart = _movingStartTime;
    final finalEnd = _movingEndTime;

    HapticFeedback.mediumImpact();
    setState(() {
      _movingEntryId = null;
      _activeMovingOriginalEntry = null;
      _initialMovingStartTime = null;
      _initialMovingEndTime = null;
      _movingStartTime = null;
      _movingEndTime = null;
    });

    if (original != null && finalStart != null && finalEnd != null) {
      if (finalStart != original.startTime || finalEnd != original.endTime) {
        widget.onUpdateEntryTimeRange?.call(original, finalStart, finalEnd);
      }
    }
  }

  void _onCardMoveCancel() {
    setState(() {
      _movingEntryId = null;
      _activeMovingOriginalEntry = null;
      _initialMovingStartTime = null;
      _initialMovingEndTime = null;
      _movingStartTime = null;
      _movingEndTime = null;
    });
  }

  List<TimelineLayoutEntry> _calculateLayout(List<TimelineEntry> entries) {
    if (entries.isEmpty) return [];

    final effectiveEntries = entries.map((e) {
      if (e.id == _resizingEntryId && _resizingStartTime != null && _resizingEndTime != null) {
        return e.copyWith(startTime: _resizingStartTime!, endTime: _resizingEndTime!);
      }
      if (e.id == _movingEntryId && _movingStartTime != null && _movingEndTime != null) {
        return e.copyWith(startTime: _movingStartTime!, endTime: _movingEndTime!);
      }
      return e;
    }).toList();

    return ScheduleTimeline.calculateTimelineLayout(effectiveEntries, basePixelsPerHour: _basePixelsPerHour);
  }

  bool _isTouchOnEntry(Offset localPosition, List<TimelineLayoutEntry> layoutEntries, double maxWidth) {
    const double leftGutter = 60.0;
    final double availableWidth = (maxWidth - leftGutter - 10).clamp(0.0, double.infinity);

    for (final le in layoutEntries) {
      final entry = le.entry;
      final startTotalHours = entry.startTime.hour + (entry.startTime.minute / 60.0) + (entry.startTime.second / 3600.0);
      final top = startTotalHours * _basePixelsPerHour;
      final rawHeight = (entry.durationSeconds / 3600.0) * _basePixelsPerHour;
      final height = math.max(3.0, rawHeight);

      final double widthPerCol = availableWidth / le.totalCols;
      final double left = leftGutter + (le.col * widthPerCol);
      final double cardWidth = (widthPerCol * le.colSpan - 4).clamp(0.0, double.infinity);

      final rect = Rect.fromLTWH(left, top, cardWidth, height);
      if (rect.inflate(8.0).contains(localPosition)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const int hoursCount = 24;
    final double pixelsPerHour = _basePixelsPerHour;
    final double totalHeight = pixelsPerHour * hoursCount;

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final bottomPadding = isLargeScreen ? 0.0 : (0 + MediaQuery.of(context).padding.bottom);

    final layoutEntries = _calculateLayout(widget.entries);

    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        color: JweTheme.bgCanvas,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: (_resizingEntryId != null || _movingEntryId != null)
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (_) {
              if (_selectedEntryId != null) {
                setState(() {
                  _selectedEntryId = null;
                });
              }
            },
            onLongPressStart: (details) {
              if (_isTouchOnEntry(details.localPosition, layoutEntries, constraints.maxWidth)) {
                return;
              }
              _startRangeCreation(details.localPosition);
            },
            onLongPressMoveUpdate: (details) {
              if (!_isCreatingRange) return;
              _updateRangeCreation(details.localPosition);
            },
            onLongPressEnd: (_) {
              if (!_isCreatingRange) return;
              _finishRangeCreation();
            },
            onLongPressCancel: () {
              setState(() {
                _isCreatingRange = false;
                _creatingStart = null;
                _creatingEnd = null;
                _anchorMinutes = null;
              });
            },
            child: Container(
              height: totalHeight + bottomPadding,
              width: double.infinity,
              color: Colors.transparent,
              child: Stack(
                children: [
                  // Hairline gutter divider
                  Positioned(
                    top: 0, bottom: 0, left: 55,
                    width: 1,
                    child: ColoredBox(color: JweTheme.lineSoft),
                  ),
                  // Grid
                  ...List.generate(hoursCount, (index) {
                    final isMajor = index % 3 == 0;
                    return Positioned(
                      top: index * pixelsPerHour,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: pixelsPerHour,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: isMajor ? JweTheme.lineAmber : JweTheme.lineSoft,
                              width: isMajor ? 1 : 0.5,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6, top: 4),
                          child: Text(
                            '${index.toString().padLeft(2, '0')}:00',
                            style: GoogleFonts.jetBrainsMono(
                              color: isMajor ? JweTheme.accentAmber : JweTheme.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Current Time
                  _buildCurrentTimeIndicator(pixelsPerHour),

                  // Entries
                  ...layoutEntries.map((le) {
                    final entry = le.entry;
                    final isSelected = entry.id == _selectedEntryId;
                    final startTotalHours = entry.startTime.hour + (entry.startTime.minute / 60.0) + (entry.startTime.second / 3600.0);
                    final top = startTotalHours * pixelsPerHour;
                    
                    final rawHeight = (entry.durationSeconds / 3600.0) * pixelsPerHour;
                    final height = math.max(3.0, rawHeight);

                    const double leftGutter = 60.0;
                    final double availableWidth = (constraints.maxWidth - leftGutter - 10).clamp(0.0, double.infinity);
                    final double widthPerCol = availableWidth / le.totalCols;
                    final double left = leftGutter + (le.col * widthPerCol);
                    final double cardWidth = (widthPerCol * le.colSpan - 4).clamp(0.0, double.infinity);

                    return Positioned(
                      top: top,
                      left: left,
                      child: TimelineEntryCard(
                        entry: entry,
                        height: height,
                        width: cardWidth,
                        isSelected: isSelected,
                        isResizing: _resizingEntryId == entry.id,
                        isMoving: _movingEntryId == entry.id,
                        onTap: () {
                          if (!entry.isEditable) {
                            widget.onEditEntry(entry);
                            return;
                          }
                          if (_selectedEntryId == entry.id) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedEntryId = null;
                            });
                          } else {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedEntryId = entry.id;
                            });
                          }
                        },
                        onDoubleTap: () {
                          if (entry.isEditable) {
                            if (widget.onSwitchTask != null) {
                              widget.onSwitchTask!(entry);
                            } else {
                              widget.onEditEntry(entry);
                            }
                          }
                        },
                        onLongPressStart: entry.isEditable
                            ? (details) => _onCardMoveStart(entry, details)
                            : null,
                        onLongPressMoveUpdate: entry.isEditable
                            ? (details) => _onCardMoveUpdate(details)
                            : null,
                        onLongPressEnd: entry.isEditable
                            ? (_) => _onCardMoveEnd()
                            : null,
                        onLongPressCancel: entry.isEditable
                            ? () => _onCardMoveCancel()
                            : null,
                      ),
                    );
                  }),

                  // Drag-to-Create Ghost Range Box
                  if (_isCreatingRange && _creatingStart != null && _creatingEnd != null)
                    _buildRangeCreationGhost(
                      start: _creatingStart!,
                      end: _creatingEnd!,
                      pixelsPerHour: pixelsPerHour,
                      maxWidth: constraints.maxWidth,
                    ),

                  // Animated Handles for editable entries (Google Calendar style)
                  ...layoutEntries.where((le) => le.entry.isEditable).expand((le) {
                    final isSelected = le.entry.id == _selectedEntryId;
                    return _buildAnimatedHandles(
                      le: le,
                      isSelected: isSelected,
                      pixelsPerHour: pixelsPerHour,
                      maxWidth: constraints.maxWidth,
                    );
                  }),

                  // Active Resize Guideline & Duration Tag
                  if (_resizingEntryId != null) ...[
                    ..._buildActiveResizeGuideline(
                      layoutEntries: layoutEntries,
                      pixelsPerHour: pixelsPerHour,
                    ),
                  ],

                  // Active Move Through Time Guideline & Duration Tag
                  if (_movingEntryId != null) ...[
                    ..._buildActiveMoveGuideline(
                      layoutEntries: layoutEntries,
                      pixelsPerHour: pixelsPerHour,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildAnimatedHandles({
    required TimelineLayoutEntry le,
    required bool isSelected,
    required double pixelsPerHour,
    required double maxWidth,
  }) {
    final entry = le.entry;
    final startTotalHours = entry.startTime.hour + (entry.startTime.minute / 60.0) + (entry.startTime.second / 3600.0);
    final top = startTotalHours * pixelsPerHour;
    final rawHeight = (entry.durationSeconds / 3600.0) * pixelsPerHour;
    final height = math.max(16.0, rawHeight);

    const double leftGutter = 60.0;
    final double availableWidth = (maxWidth - leftGutter - 10).clamp(0.0, double.infinity);
    final double widthPerCol = availableWidth / le.totalCols;
    final double left = leftGutter + (le.col * widthPerCol);
    final double cardWidth = (widthPerCol * le.colSpan - 4).clamp(0.0, double.infinity);

    final handleColor = JweTheme.isLight ? JweTheme.calibrate(entry.color) : entry.color;
    final handleInset = math.min(22.0, cardWidth * 0.12);
    final topHandleCenterX = left + handleInset;
    final bottomHandleCenterX = left + cardWidth - handleInset;

    return [
      // Top Handle (Top-Left, vertically flush on top border)
      Positioned(
        top: top - 22 + 1.0,
        left: topHandleCenterX - 22,
        width: 44,
        height: 44,
        child: IgnorePointer(
          ignoring: !isSelected,
          child: AnimatedScale(
            scale: isSelected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: isSelected ? Curves.easeOutBack : Curves.easeInCubic,
            child: AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (details) => _onHandleDragStart(entry, true, details),
                onVerticalDragUpdate: _onHandleDragUpdate,
                onVerticalDragEnd: (_) => _onHandleDragEnd(),
                onVerticalDragCancel: _onHandleDragCancel,
                child: Center(
                  child: _buildHandle(color: handleColor),
                ),
              ),
            ),
          ),
        ),
      ),

      // Bottom Handle (Bottom-Right, vertically flush on bottom border)
      Positioned(
        top: top + height - 22 - 1.0,
        left: bottomHandleCenterX - 22,
        width: 44,
        height: 44,
        child: IgnorePointer(
          ignoring: !isSelected,
          child: AnimatedScale(
            scale: isSelected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: isSelected ? Curves.easeOutBack : Curves.easeInCubic,
            child: AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (details) => _onHandleDragStart(entry, false, details),
                onVerticalDragUpdate: _onHandleDragUpdate,
                onVerticalDragEnd: (_) => _onHandleDragEnd(),
                onVerticalDragCancel: _onHandleDragCancel,
                child: Center(
                  child: _buildHandle(color: handleColor),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildActiveResizeGuideline({
    required List<TimelineLayoutEntry> layoutEntries,
    required double pixelsPerHour,
  }) {
    if (_resizingEntryId == null) return [];

    TimelineLayoutEntry? resizingLe;
    for (final le in layoutEntries) {
      if (le.entry.id == _resizingEntryId) {
        resizingLe = le;
        break;
      }
    }
    if (resizingLe == null) return [];

    final entry = resizingLe.entry;
    final startTotalHours = entry.startTime.hour + (entry.startTime.minute / 60.0) + (entry.startTime.second / 3600.0);
    final top = startTotalHours * pixelsPerHour;
    final rawHeight = (entry.durationSeconds / 3600.0) * pixelsPerHour;
    final height = math.max(16.0, rawHeight);
    final handleColor = JweTheme.isLight ? JweTheme.calibrate(entry.color) : entry.color;

    return [
      _buildResizeGuideline(
        y: _resizingIsTop == true ? top : top + height,
        time: _resizingIsTop == true ? entry.startTime : entry.endTime,
        duration: entry.endTime.difference(entry.startTime),
        isTop: _resizingIsTop == true,
        color: handleColor,
      ),
    ];
  }

  List<Widget> _buildActiveMoveGuideline({
    required List<TimelineLayoutEntry> layoutEntries,
    required double pixelsPerHour,
  }) {
    if (_movingEntryId == null) return [];

    TimelineLayoutEntry? movingLe;
    for (final le in layoutEntries) {
      if (le.entry.id == _movingEntryId) {
        movingLe = le;
        break;
      }
    }
    if (movingLe == null) return [];

    final entry = movingLe.entry;
    final startTotalHours = entry.startTime.hour + (entry.startTime.minute / 60.0) + (entry.startTime.second / 3600.0);
    final top = startTotalHours * pixelsPerHour;
    final rawHeight = (entry.durationSeconds / 3600.0) * pixelsPerHour;
    final height = math.max(16.0, rawHeight);
    final handleColor = JweTheme.isLight ? JweTheme.calibrate(entry.color) : entry.color;
    final duration = entry.endTime.difference(entry.startTime);

    return [
      _buildResizeGuideline(
        y: top,
        time: entry.startTime,
        duration: duration,
        isTop: true,
        color: handleColor,
      ),
      _buildResizeGuideline(
        y: top + height,
        time: entry.endTime,
        duration: duration,
        isTop: false,
        color: handleColor,
      ),
    ];
  }

  Widget _buildHandle({required Color color}) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildResizeGuideline({
    required double y,
    required DateTime time,
    required Duration duration,
    required bool isTop,
    required Color color,
  }) {
    final fgText = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Positioned(
      top: y - 10,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 55,
              padding: const EdgeInsets.only(right: 6),
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  DateFormat('HH:mm').format(time),
                  style: GoogleFonts.jetBrainsMono(
                    color: fgText,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.8),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: JweTheme.panel,
                border: Border.all(color: color, width: 1.2),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                'DUR: ${_formatDuration(duration)}',
                style: GoogleFonts.jetBrainsMono(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeCreationGhost({
    required DateTime start,
    required DateTime end,
    required double pixelsPerHour,
    required double maxWidth,
  }) {
    final startHours = start.hour + (start.minute / 60.0);
    final endHours = end.hour + (end.minute / 60.0);
    final top = startHours * pixelsPerHour;
    final height = math.max(30.0, (endHours - startHours) * pixelsPerHour);
    final duration = end.difference(start);
    const double leftGutter = 60.0;
    final double blockWidth = (maxWidth - leftGutter - 12).clamp(0.0, double.infinity);

    return Stack(
      children: [
        // Top Guideline Line & Tag
        Positioned(
          top: top - 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Row(
              children: [
                Container(
                  width: 55,
                  padding: const EdgeInsets.only(right: 4),
                  alignment: Alignment.centerRight,
                  child: Text(
                    DateFormat('HH:mm').format(start),
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentCyan,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: JweTheme.accentCyan.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom Guideline Line & Tag
        Positioned(
          top: top + height - 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Row(
              children: [
                Container(
                  width: 55,
                  padding: const EdgeInsets.only(right: 4),
                  alignment: Alignment.centerRight,
                  child: Text(
                    DateFormat('HH:mm').format(end),
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentCyan,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: JweTheme.accentCyan.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Ghost Box
        Positioned(
          top: top,
          left: leftGutter,
          width: blockWidth,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              color: JweTheme.accentCyan.withValues(alpha: JweTheme.isLight ? 0.2 : 0.25),
              border: Border.all(color: JweTheme.accentCyan, width: 2),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: JweTheme.accentCyan.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: JweTheme.accentCyan),
                    const SizedBox(width: 6),
                    Text(
                      'NEW MISSION BLOCK',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: JweTheme.accentCyan,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _formatDuration(duration),
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.isLight ? Colors.white : Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (height >= 40)
                  Row(
                    children: [
                      Text(
                        '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.isLight ? JweTheme.textWhite : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'RELEASE TO ASSIGN',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentCyan.withValues(alpha: 0.8),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTimeIndicator(double pixelsPerHour) {
    final now = DateTime.now();
    final currentHour = now.hour + (now.minute / 60.0);
    final top = currentHour * pixelsPerHour;

    return Positioned(
      top: top - 6,
      left: 0,
      right: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 55,
            padding: const EdgeInsets.only(right: 4),
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NOW',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                Text(
                  DateFormat('HH:mm').format(now),
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: JweTheme.accentAmber,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: JweTheme.accentAmber.withValues(alpha: 0.7), blurRadius: 6)],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                color: JweTheme.accentAmber,
                boxShadow: [BoxShadow(color: JweTheme.accentAmber.withValues(alpha: 0.6), blurRadius: 6)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TimelineLayoutEntry {
  final TimelineEntry entry;
  final int col;
  int totalCols = 1;
  int colSpan = 1;
  TimelineLayoutEntry(this.entry, this.col);
}