import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';

class DraggableStepWrapper extends StatefulWidget {
  final String stepId;
  final Widget child;
  final Function(String draggedId, String targetId, String position) onMove;

  const DraggableStepWrapper({
    super.key,
    required this.stepId,
    required this.child,
    required this.onMove,
  });

  @override
  State<DraggableStepWrapper> createState() => _DraggableStepWrapperState();
}

class _DraggableStepWrapperState extends State<DraggableStepWrapper> {
  String? _hoverPosition;

  @override
  void didUpdateWidget(covariant DraggableStepWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hoverPosition != null) {
      _hoverPosition = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<String>(
      data: widget.stepId,
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
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data != widget.stepId,
        onAcceptWithDetails: (details) {
          final pos = _hoverPosition ?? 'inside';
          setState(() => _hoverPosition = null);
          widget.onMove(details.data, widget.stepId, pos);
        },
        onMove: (details) {
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          
          final Offset localOffset = box.globalToLocal(details.offset);
          final double y = localOffset.dy;
          final double height = box.size.height;
          
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