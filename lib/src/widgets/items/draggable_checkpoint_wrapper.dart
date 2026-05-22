import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';

class DraggableCheckpointWrapper extends StatefulWidget {
  final String checkpointId;
  final Widget child;
  final Function(String draggedId, String targetId, String position) onMove;

  const DraggableCheckpointWrapper({
    super.key,
    required this.checkpointId,
    required this.child,
    required this.onMove,
  });

  @override
  State<DraggableCheckpointWrapper> createState() => _DraggableCheckpointWrapperState();
}

class _DraggableCheckpointWrapperState extends State<DraggableCheckpointWrapper> {
  String? _hoverPosition;

  @override
  void didUpdateWidget(covariant DraggableCheckpointWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear hover state when the widget reconstructs (e.g., after a drop reorders the list)
    // This prevents the green indicator line from getting stuck.
    if (_hoverPosition != null) {
      _hoverPosition = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<String>(
      data: widget.checkpointId,
      // Enforce a slight delay so normal taps (like opening details, toggling checkbox) are never stolen
      delay: const Duration(milliseconds: 250), 
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8, 
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 60, 
            child: widget.child
          )
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: widget.child),
      // We wrap the child entirely inside the DragTarget instead of overlaying zones.
      // This prevents the DragTarget from invisibly blocking gesture hits to the child below it.
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data != widget.checkpointId,
        onAcceptWithDetails: (details) {
          final pos = _hoverPosition ?? 'inside';
          setState(() => _hoverPosition = null);
          widget.onMove(details.data, widget.checkpointId, pos);
        },
        onMove: (details) {
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          
          final Offset localOffset = box.globalToLocal(details.offset);
          final double y = localOffset.dy;
          final double height = box.size.height;
          
          // Calculate the relative vertical drop position 
          String pos = 'inside';
          if (y < height * 0.3) {
            pos = 'before';
          } else if (y > height * 0.7) {
            pos = 'after';
          }

          if (_hoverPosition != pos) {
            setState(() => _hoverPosition = pos);
          }
        },
        onLeave: (_) {
          setState(() => _hoverPosition = null);
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: BoxDecoration(
              border: _hoverPosition == 'before' 
                  ? const Border(top: BorderSide(color: AppTheme.fhAccentTeal, width: 3)) 
                  : _hoverPosition == 'after' 
                      ? const Border(bottom: BorderSide(color: AppTheme.fhAccentTeal, width: 3)) 
                      : _hoverPosition == 'inside' 
                          ? Border.all(color: AppTheme.fhAccentTeal, width: 2) 
                          : null,
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}