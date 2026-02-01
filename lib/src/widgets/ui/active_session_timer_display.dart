import 'dart:async';
import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;

class ActiveSessionTimerDisplay extends StatefulWidget {
  final bool isRunning;
  final DateTime? startTime;
  final double totalTodaySeconds;

  const ActiveSessionTimerDisplay({
    super.key,
    required this.isRunning,
    required this.startTime,
    required this.totalTodaySeconds,
  });

  @override
  State<ActiveSessionTimerDisplay> createState() =>
      _ActiveSessionTimerDisplayState();
}

class _ActiveSessionTimerDisplayState extends State<ActiveSessionTimerDisplay> {
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
  void didUpdateWidget(ActiveSessionTimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _startTicker();
      } else {
        _stopTicker();
      }
    }
    _updateTime();
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
    setState(() {
      if (widget.isRunning && widget.startTime != null) {
        // Show Current Session Elapsed Time
        final elapsed =
            DateTime.now().difference(widget.startTime!).inSeconds.toDouble();
        _displayTime = helper.formatTime(elapsed);
      } else {
        // Show Total Day Time
        _displayTime = helper.formatTime(widget.totalTodaySeconds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isRunning ? "CURRENT SESSION" : "TOTAL TODAY",
          style: TextStyle(
            color: widget.isRunning
                ? AppTheme.fhAccentRed
                : AppTheme.fhTextSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        // Use FittedBox to prevent overflow on smaller screens
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _displayTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontFamily: AppTheme.fontDisplay,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}