import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:missions/src/models/timeline_models.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class TimelineEntryCard extends StatelessWidget {
  final TimelineEntry entry;
  final double height;
  final double width;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;
  final bool isSelected;
  final bool isResizing;
  final bool isMoving;

  const TimelineEntryCard({
    super.key,
    required this.entry,
    required this.height,
    required this.width,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    this.onLongPressCancel,
    this.isSelected = false,
    this.isResizing = false,
    this.isMoving = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPredicted = entry.isPredicted;
    
    final calColor = JweTheme.isLight ? JweTheme.calibrate(entry.color) : entry.color;
    final effectiveColor = JweTheme.isLight
        ? (isSelected ? calColor.withValues(alpha: 0.22) : calColor.withValues(alpha: 0.12))
        : (isSelected
            ? calColor.withValues(alpha: 0.35)
            : (isPredicted ? entry.color.withValues(alpha: 0.15) : entry.color.withValues(alpha: 0.25)));
    final borderColor = isSelected
        ? calColor
        : (JweTheme.isLight
            ? calColor.withValues(alpha: 0.4)
            : (isPredicted ? entry.color.withValues(alpha: 0.3) : entry.color));

    final textColor = JweTheme.isLight
        ? (isSelected ? JweTheme.textWhite : calColor)
        : (isPredicted ? Colors.white70 : Colors.white);
    
    final timeColor = JweTheme.isLight
        ? (isSelected ? JweTheme.textWhite.withValues(alpha: 0.85) : calColor.withValues(alpha: 0.8))
        : Colors.white.withValues(alpha: 0.7);
    
    // Hide content if height is extremely small to prevent overflow UI breaks
    final bool showTitle = height >= 14;
    final bool showTime = height >= 30;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      onLongPressEnd: onLongPressEnd,
      onLongPressCancel: onLongPressCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: (isResizing || isMoving) ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: width,
        height: math.max(3.0, height),
        decoration: BoxDecoration(
          color: effectiveColor,
          border: Border.all(
            color: isMoving ? calColor : borderColor,
            width: (isSelected || isMoving) ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular((isSelected || isMoving) ? 6 : 4),
          boxShadow: (isSelected || isMoving)
              ? [
                  BoxShadow(
                    color: calColor.withValues(alpha: isMoving ? 0.6 : 0.35),
                    blurRadius: isMoving ? 14 : 8,
                    spreadRadius: isMoving ? 1.5 : 0.5,
                  ),
                ]
              : null,
        ),
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxHeight: double.infinity,
            child: Padding(
              padding: EdgeInsets.only(
                left: isSelected ? 28 : 6,
                right: isSelected ? 28 : 6,
                top: 3,
                bottom: 3,
              ),
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
                              color: textColor,
                              fontSize: 9,
                              fontWeight: isPredicted ? FontWeight.normal : FontWeight.bold,
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
                        color: timeColor,
                        fontSize: 8,
                        fontFamily: 'RobotoMono',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}