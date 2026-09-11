import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'today_planner_models.dart';

class AnimatedPlanEntry extends StatefulWidget {
  final Widget child;
  final bool animateIn;
  final LeaveKind? leaving;
  final VoidCallback onLeft;

  const AnimatedPlanEntry({
    super.key,
    required this.child,
    required this.animateIn,
    required this.leaving,
    required this.onLeft,
  });

  @override
  State<AnimatedPlanEntry> createState() => _AnimatedPlanEntryState();
}

class _AnimatedPlanEntryState extends State<AnimatedPlanEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _leaveStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
      value: widget.animateIn ? 0.0 : 1.0,
    );
    if (widget.animateIn) _controller.forward();
    _maybeStartLeave();
  }

  @override
  void didUpdateWidget(covariant AnimatedPlanEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeStartLeave();
  }

  void _maybeStartLeave() {
    if (widget.leaving == null || _leaveStarted) return;
    _leaveStarted = true;
    _controller.reverse().whenComplete(widget.onLeft);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final veil = switch (widget.leaving) {
      LeaveKind.completed => AppTheme.fhAccentGreen.withValues(alpha: 0.12),
      LeaveKind.removed => AppTheme.fhAccentRed.withValues(alpha: 0.10),
      null => null,
    };
    Widget body = widget.child;
    if (veil != null) {
      body = Stack(children: [
        body,
        Positioned.fill(child: IgnorePointer(child: Container(color: veil))),
      ]);
    }
    Widget result = SizeTransition(
      sizeFactor: curved,
      alignment: const Alignment(-1.0, -1.0),
      child: FadeTransition(opacity: curved, child: body),
    );
    if (widget.leaving != null) {
      result = IgnorePointer(child: result);
    }
    return result;
  }
}
