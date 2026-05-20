import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// A single full-width horizontal bar split into one tappable segment per
/// [SubSubTask]. Designed to sit under a card so users can power through
/// nested steps without opening the detail view.
///
/// Collapsed by default: only the `STEPS · X/Y` caption is visible. Tapping
/// the caption reveals the segmented bar. Pass [collapsible]: false to
/// always show the bar (used by the missions hero strip).
class StepBarsRow extends StatefulWidget {
  final List<SubSubTask> steps;
  final Color accent;
  final void Function(SubSubTask step) onToggle;

  /// Height of the visible segmented bar (the tap target extends taller).
  final double barHeight;

  /// Spacing inserted around the bar. Pass [EdgeInsets.zero] to opt out.
  final EdgeInsets padding;

  /// When true, the bar is hidden behind a tap-to-reveal caption. When
  /// false, the bar is permanently visible (no toggle, no chevron).
  final bool collapsible;

  /// Initial expanded state when [collapsible] is true.
  final bool initiallyExpanded;

  const StepBarsRow({
    super.key,
    required this.steps,
    required this.accent,
    required this.onToggle,
    this.barHeight = 10,
    this.padding = const EdgeInsets.only(top: 10),
    this.collapsible = true,
    this.initiallyExpanded = false,
  });

  @override
  State<StepBarsRow> createState() => _StepBarsRowState();
}

class _StepBarsRowState extends State<StepBarsRow> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.collapsible || widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final completedCount =
        widget.steps.where((s) => s.type == 'check' && s.completed).length;
    final checkableCount =
        widget.steps.where((s) => s.type == 'check').length;
    final allDone = checkableCount > 0 && completedCount == checkableCount;

    final caption = _buildCaption(
      checkableCount: checkableCount,
      completedCount: completedCount,
      allDone: allDone,
    );

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (checkableCount > 0) caption,
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded ? _buildBar() : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildCaption({
    required int checkableCount,
    required int completedCount,
    required bool allDone,
  }) {
    final captionRow = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            'STEPS',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              color: JweTheme.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 2,
            height: 8,
            color: widget.accent.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 6),
          Text(
            '$completedCount/$checkableCount',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: allDone ? widget.accent : JweTheme.textMid,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          if (allDone) ...[
            const SizedBox(width: 4),
            Text(
              '· COMPLETE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                color: widget.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ],
          if (widget.collapsible) ...[
            const Spacer(),
            Icon(
              _expanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
              size: 14,
              color: JweTheme.textMuted,
            ),
          ],
        ],
      ),
    );

    if (!widget.collapsible) return captionRow;

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: captionRow,
    );
  }

  Widget _buildBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            for (var i = 0; i < widget.steps.length; i++) ...[
              Expanded(
                child: _Segment(
                  step: widget.steps[i],
                  accent: widget.accent,
                  barHeight: widget.barHeight,
                  onTap: () => widget.onToggle(widget.steps[i]),
                ),
              ),
              if (i != widget.steps.length - 1) const SizedBox(width: 3),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final SubSubTask step;
  final Color accent;
  final double barHeight;
  final VoidCallback onTap;

  const _Segment({
    required this.step,
    required this.accent,
    required this.barHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isInfo = step.type == 'info';
    final isDone = !isInfo && step.completed;

    final Color fill;
    final Color borderColor;
    if (isInfo) {
      fill = JweTheme.textMuted.withValues(alpha: 0.18);
      borderColor = JweTheme.textMuted.withValues(alpha: 0.32);
    } else if (isDone) {
      fill = accent;
      borderColor = accent;
    } else {
      fill = Colors.transparent;
      borderColor = accent.withValues(alpha: 0.45);
    }

    final bar = Container(
      height: barHeight,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isDone
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.55),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
    );

    final body = Tooltip(
      message: step.name,
      waitDuration: const Duration(milliseconds: 350),
      child: Center(child: bar),
    );

    if (isInfo) return body;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: body,
    );
  }
}
