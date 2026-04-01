import 'dart:async';
import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;

class ValorantTimerText extends StatefulWidget {
  final bool isRunning;
  final DateTime? startTime;
  final double accumulatedTime;
  final TextStyle? style;

  const ValorantTimerText({
    super.key,
    required this.isRunning,
    required this.startTime,
    required this.accumulatedTime,
    this.style,
  });

  @override
  State<ValorantTimerText> createState() => _ValorantTimerTextState();
}

class _ValorantTimerTextState extends State<ValorantTimerText> {
  Timer? _timer;
  String _displayTime = "00:00";

  @override
  void initState() {
    super.initState();
    _updateTime();
    if (widget.isRunning) {
      _startTicker();
    }
  }

  @override
  void didUpdateWidget(ValorantTimerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning || 
        widget.startTime != oldWidget.startTime || 
        widget.accumulatedTime != oldWidget.accumulatedTime) {
      if (widget.isRunning) {
        _startTicker();
      } else {
        _stopTicker();
      }
      _updateTime();
    }
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  void _startTicker() {
    _stopTicker();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTime();
    });
  }

  void _stopTicker() {
    _timer?.cancel();
    _timer = null;
  }

  void _updateTime() {
    double seconds = widget.accumulatedTime;
    
    if (widget.isRunning && widget.startTime != null) {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      
      // Fix for "104 hours" bug:
      // If start time was days ago, we clamp effective start to today's midnight.
      // This ensures we only display the portion of the current session that occurred today.
      final effectiveStart = widget.startTime!.isBefore(midnight) 
          ? midnight 
          : widget.startTime!;
      
      final elapsedToday = now.difference(effectiveStart).inSeconds.toDouble();
      
      // accumulatedTime passed from parent should be Historical (Completed) Today
      // So Total Today = Historical + Current Session Today
      seconds = widget.accumulatedTime + (elapsedToday < 0 ? 0 : elapsedToday);
    }
    
    if (mounted) {
      setState(() {
        _displayTime = helper.formatTime(seconds);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayTime,
      style: widget.style ?? const TextStyle(
        fontFamily: "RobotoMono",
        color: AppTheme.fhTextSecondary,
        fontSize: 12,
        fontWeight: FontWeight.bold
      ),
    );
  }
}