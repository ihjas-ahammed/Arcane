import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Highly responsive swipe detector that works across touch, mouse click-and-drag,
/// trackpad gestures, and mouse wheel scrolling on Web and Desktop.
class LauncherSwipeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final HitTestBehavior behavior;

  const LauncherSwipeDetector({
    super.key,
    required this.child,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.behavior = HitTestBehavior.translucent,
  });

  @override
  State<LauncherSwipeDetector> createState() => _LauncherSwipeDetectorState();
}

class _LauncherSwipeDetectorState extends State<LauncherSwipeDetector> {
  double _dragDx = 0.0;
  double _dragDy = 0.0;
  bool _triggeredInDrag = false;
  DateTime _lastScrollTrigger = DateTime.now();

  void _handleScroll(PointerScrollEvent event) {
    final now = DateTime.now();
    // Throttle scroll wheel triggers to avoid multiple rapid fires
    if (now.difference(_lastScrollTrigger).inMilliseconds < 450) {
      return;
    }

    if (event.scrollDelta.dy > 12) {
      // Mouse wheel / trackpad scrolled down -> corresponds to swipe up
      if (widget.onSwipeUp != null) {
        _lastScrollTrigger = now;
        widget.onSwipeUp!();
      }
    } else if (event.scrollDelta.dy < -12) {
      // Mouse wheel / trackpad scrolled up -> corresponds to swipe down
      if (widget.onSwipeDown != null) {
        _lastScrollTrigger = now;
        widget.onSwipeDown!();
      }
    } else if (event.scrollDelta.dx > 12) {
      if (widget.onSwipeLeft != null) {
        _lastScrollTrigger = now;
        widget.onSwipeLeft!();
      }
    } else if (event.scrollDelta.dx < -12) {
      if (widget.onSwipeRight != null) {
        _lastScrollTrigger = now;
        widget.onSwipeRight!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: widget.behavior,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _handleScroll(event);
        }
      },
      child: GestureDetector(
        behavior: widget.behavior,
        onPanStart: (_) {
          _dragDx = 0.0;
          _dragDy = 0.0;
          _triggeredInDrag = false;
        },
        onPanUpdate: (details) {
          _dragDx += details.delta.dx;
          _dragDy += details.delta.dy;

          // Proactive trigger during continuous mouse drag
          if (!_triggeredInDrag) {
            if (_dragDy.abs() > _dragDx.abs()) {
              if (_dragDy < -35 && widget.onSwipeUp != null) {
                _triggeredInDrag = true;
                widget.onSwipeUp!();
              } else if (_dragDy > 35 && widget.onSwipeDown != null) {
                _triggeredInDrag = true;
                widget.onSwipeDown!();
              }
            } else {
              if (_dragDx < -35 && widget.onSwipeLeft != null) {
                _triggeredInDrag = true;
                widget.onSwipeLeft!();
              } else if (_dragDx > 35 && widget.onSwipeRight != null) {
                _triggeredInDrag = true;
                widget.onSwipeRight!();
              }
            }
          }
        },
        onPanEnd: (details) {
          if (_triggeredInDrag) return;

          final vel = details.velocity.pixelsPerSecond;
          if (vel.dy.abs() > vel.dx.abs()) {
            if ((vel.dy < -80 || _dragDy < -25) && widget.onSwipeUp != null) {
              widget.onSwipeUp!();
            } else if ((vel.dy > 80 || _dragDy > 25) && widget.onSwipeDown != null) {
              widget.onSwipeDown!();
            }
          } else {
            if ((vel.dx < -80 || _dragDx < -25) && widget.onSwipeLeft != null) {
              widget.onSwipeLeft!();
            } else if ((vel.dx > 80 || _dragDx > 25) && widget.onSwipeRight != null) {
              widget.onSwipeRight!();
            }
          }
        },
        child: widget.child,
      ),
    );
  }
}
