import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'weekly_common_widgets.dart';

class CompletedNode {
  final String id;
  final String name;
  final String nodeType; // 'mission' | 'subtask' | 'checkpoint'
  final Color color;
  final String? date;
  final bool isCompleted;
  final List<CompletedNode> children;

  CompletedNode({
    required this.id,
    required this.name,
    required this.nodeType,
    required this.color,
    this.date,
    this.isCompleted = false,
    List<CompletedNode>? children,
  }) : children = children ?? [];

  int get totalCompletedCount {
    int count = (isCompleted && nodeType != 'mission') ? 1 : 0;
    for (final child in children) {
      count += child.totalCompletedCount;
    }
    return count;
  }
}

class WeeklyCompletedLogWidget extends StatefulWidget {
  final List<CompletedNode> missions;

  const WeeklyCompletedLogWidget({super.key, required this.missions});

  @override
  State<WeeklyCompletedLogWidget> createState() => _WeeklyCompletedLogWidgetState();
}

class _WeeklyCompletedLogWidgetState extends State<WeeklyCompletedLogWidget> {
  int _expandAllTrigger = 0;
  bool _expandAllValue = false;

  void _toggleAll(bool expand) {
    setState(() {
      _expandAllTrigger++;
      _expandAllValue = expand;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.missions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            title: 'WEEKLY OPERATION LOG (COMPLETED)',
            icon: MdiIcons.checkboxMarkedCircleOutline,
            color: JweTheme.accentTeal,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: JweTheme.bgBase.withOpacity(0.3),
              border: Border.all(color: JweTheme.lineSoft),
            ),
            child: Text(
              'NO COMPLETED TASKS OR CHECKPOINTS DETECTED THIS WEEK.',
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final totalCompletedCount = widget.missions.fold<int>(0, (sum, m) => sum + m.totalCompletedCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(
                    title: 'WEEKLY OPERATION LOG',
                    icon: MdiIcons.checkboxMarkedCircleOutline,
                    color: JweTheme.accentTeal,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.missions.length} MISSIONS • $totalCompletedCount COMPLETED',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _toggleAll(true),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.expandAll, size: 14, color: JweTheme.accentTeal),
                        const SizedBox(width: 2),
                        Text(
                          'EXPAND ALL',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentTeal,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _toggleAll(false),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.collapseAll, size: 14, color: JweTheme.accentTeal),
                        const SizedBox(width: 2),
                        Text(
                          'COLLAPSE ALL',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentTeal,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...widget.missions.map((missionNode) {
          return NestedCompletedNodeWidget(
            node: missionNode,
            depth: 0,
            expandAllTrigger: _expandAllTrigger,
            expandAllValue: _expandAllValue,
          );
        }),
      ],
    );
  }
}

class NestedCompletedNodeWidget extends StatefulWidget {
  final CompletedNode node;
  final int depth;
  final int expandAllTrigger;
  final bool expandAllValue;

  const NestedCompletedNodeWidget({
    super.key,
    required this.node,
    required this.depth,
    required this.expandAllTrigger,
    required this.expandAllValue,
  });

  @override
  State<NestedCompletedNodeWidget> createState() => _NestedCompletedNodeWidgetState();
}

class _NestedCompletedNodeWidgetState extends State<NestedCompletedNodeWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = false;
  }

  @override
  void didUpdateWidget(covariant NestedCompletedNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expandAllTrigger != oldWidget.expandAllTrigger) {
      _isExpanded = widget.expandAllValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final hasChildren = node.children.isNotEmpty;
    final color = node.color;
    final isMission = widget.depth == 0;
    final isSubtask = node.nodeType == 'subtask';

    if (!hasChildren) {
      return Container(
        margin: EdgeInsets.only(
          bottom: 6,
          left: widget.depth == 0 ? 0 : 10.0 * widget.depth,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: JweTheme.bgBase.withOpacity(0.5),
          border: Border(
            left: BorderSide(
              color: isSubtask ? color : JweTheme.textMuted.withOpacity(0.5),
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSubtask ? MdiIcons.bookmarkCheckOutline : MdiIcons.checkCircleOutline,
              size: 14,
              color: isSubtask ? color : JweTheme.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                node.name.toUpperCase(),
                style: GoogleFonts.saira(
                  color: JweTheme.textWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            if (node.date != null) ...[
              const SizedBox(width: 8),
              Text(
                node.date!,
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 9,
                ),
              ),
            ]
          ],
        ),
      );
    }

    if (isMission) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: JweTheme.bgBase.withOpacity(0.4),
          border: Border.all(
            color: _isExpanded ? color.withOpacity(0.6) : JweTheme.lineSoft,
            width: _isExpanded ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(color: color.withOpacity(0.5), blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            node.name.toUpperCase(),
                            style: GoogleFonts.saira(
                              color: JweTheme.textWhite,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${node.children.length} DIRECT ITEM${node.children.length > 1 ? 'S' : ''} • ${node.totalCompletedCount} COMPLETED',
                            style: GoogleFonts.jetBrainsMono(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                      color: _isExpanded ? color : JweTheme.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: color.withOpacity(0.2))),
                  color: color.withOpacity(0.04),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: node.children.map((child) {
                    return NestedCompletedNodeWidget(
                      node: child,
                      depth: widget.depth + 1,
                      expandAllTrigger: widget.expandAllTrigger,
                      expandAllValue: widget.expandAllValue,
                    );
                  }).toList(),
                ),
              ),
              crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(
        bottom: 6,
        left: 8.0 * widget.depth,
      ),
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.35),
        border: Border(
          left: BorderSide(color: color.withOpacity(0.7), width: 2.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isSubtask ? MdiIcons.folderCheckOutline : MdiIcons.checkboxMultipleMarkedOutline,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.name.toUpperCase(),
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${node.children.length} SUB-ITEM${node.children.length > 1 ? 'S' : ''}',
                              style: GoogleFonts.jetBrainsMono(
                                color: color.withOpacity(0.9),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (node.isCompleted && node.date != null) ...[
                              Text(
                                ' • DONE ${node.date}',
                                style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.textMuted,
                                  fontSize: 8,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? MdiIcons.chevronDown : MdiIcons.chevronRight,
                    color: color,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: node.children.map((child) {
                  return NestedCompletedNodeWidget(
                    node: child,
                    depth: widget.depth + 1,
                    expandAllTrigger: widget.expandAllTrigger,
                    expandAllValue: widget.expandAllValue,
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
