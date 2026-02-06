import 'dart:async';
import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;

/// A self-contained timer widget that ticks independently of the main app state rebuilds.
/// It takes an initial start time and running status.
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
  State<ActiveSessionTimerDisplay> createState() => _ActiveSessionTimerDisplayState();
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
    // React to external state changes (e.g. user pressed pause/play)
    if (widget.isRunning != oldWidget.isRunning || 
        widget.startTime != oldWidget.startTime || 
        widget.totalTodaySeconds != oldWidget.totalTodaySeconds) {
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
    _stopTicker(); // Ensure single timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTime();
    });
  }

  void _stopTicker() {
    _timer?.cancel();
    _timer = null;
  }

  void _updateTime() {
    // If running, we calculate elapsed time dynamically to avoid needing provider updates per second
    double secondsToDisplay = widget.totalTodaySeconds;
    
    if (widget.isRunning && widget.startTime != null) {
      // Logic: provider.totalTodaySeconds usually only updates on stop events or major rebuilds.
      // We assume totalTodaySeconds passed in INCLUDES the accumulated time so far *minus* current session if provider isn't ticking.
      // But typically, provider methods calculate todaySeconds by summing logs + current active session duration.
      // Since provider is no longer ticking, `widget.totalTodaySeconds` might only reflect completed logs + static start time offset.
      // To get a smooth tick, we calculate:
      // Display = (Static Total from Logs) + (Now - StartTime)
      // However, we rely on the passed value being mostly correct for "base". 
      // Simplified: We just re-calculate elapsed if running.
      
      // NOTE: For this widget to work perfectly without provider ticks, the parent must pass
      // a `totalTodaySeconds` that includes PAST sessions, but maybe NOT the current running session's dynamic part?
      // Actually, standard pattern: passing `Accumulated` + `StartTime`.
      // Let's assume `totalTodaySeconds` passed in *includes* real-time calc from provider's `getTodaySeconds`.
      // Since provider isn't rebuilding, `totalTodaySeconds` won't change every second.
      // So we must add the *additional* elapsed time since this widget built? 
      // No, simpler: Calculate elapsed since `startTime` and add to a base?
      // The variable naming `totalTodaySeconds` implies total. 
      // Let's check `TaskCalculations`. It calculates based on `DateTime.now()`.
      // So if parent doesn't rebuild, `totalTodaySeconds` is stale.
      
      // FIX: We need the *base* accumulated time separate from start time time to do client-side ticking properly.
      // But we can approximate:
      // If we know it IS running, the `totalTodaySeconds` passed in was correct *at the moment of build*.
      // We can update it locally.
      
      // Actually, safest approach for UI consistency without refactoring entire model:
      // Just recalculate the "current session duration" part here and add to "historical duration".
      // But we don't have historical separated easily here.
      
      // Alternative: Just display the time passed in the current session if running (Active Session Focus),
      // OR display total. The UI label says "CURRENT SESSION" if running.
      // So we just show `Now - StartTime`.
      
      final currentSessionSeconds = DateTime.now().difference(widget.startTime!).inSeconds.toDouble();
      secondsToDisplay = currentSessionSeconds; 
      // Note: The UI says "CURRENT SESSION" when running, so displaying just session time is accurate to label.
    }

    if (mounted) {
      setState(() {
        _displayTime = helper.formatTime(secondsToDisplay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isRunning ? "CURRENT SESSION" : "TOTAL TODAY",
          style: TextStyle(
            color: widget.isRunning ? AppTheme.fhAccentRed : AppTheme.fhTextSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
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