import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/gratitude_intel_card.dart';
import 'weekly_common_widgets.dart';

class WeeklyGratitudeDividedByDaysWidget extends StatefulWidget {
  final List<Map<String, dynamic>> dailyGratitudes;
  final List<dynamic> highlights;

  const WeeklyGratitudeDividedByDaysWidget({
    super.key,
    required this.dailyGratitudes,
    required this.highlights,
  });

  @override
  State<WeeklyGratitudeDividedByDaysWidget> createState() => _WeeklyGratitudeDividedByDaysWidgetState();
}

class _WeeklyGratitudeDividedByDaysWidgetState extends State<WeeklyGratitudeDividedByDaysWidget> {
  int _expandAllTrigger = 0;
  bool _expandAllValue = true;

  void _toggleAll(bool expand) {
    setState(() {
      _expandAllTrigger++;
      _expandAllValue = expand;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalNotes = widget.dailyGratitudes.fold<int>(0, (sum, day) => sum + ((day['items'] as List?)?.length ?? 0));

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
                    title: 'DAILY GRATITUDE BREAKDOWN',
                    icon: MdiIcons.heartPulse,
                    color: JweTheme.accentCyan,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.dailyGratitudes.length} DAYS • $totalNotes GRATITUDE NOTES',
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
                        Icon(MdiIcons.expandAll, size: 14, color: JweTheme.accentCyan),
                        const SizedBox(width: 2),
                        Text(
                          'EXPAND ALL',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
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
                        Icon(MdiIcons.collapseAll, size: 14, color: JweTheme.accentCyan),
                        const SizedBox(width: 2),
                        Text(
                          'COLLAPSE ALL',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
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
        ...widget.dailyGratitudes.map((dayData) {
          return GratitudeDayTile(
            dayData: dayData,
            expandTrigger: _expandAllTrigger,
            expandValue: _expandAllValue,
          );
        }),
        if (widget.highlights.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionLabel(
            title: 'WEEKLY HIGHLIGHTS',
            icon: MdiIcons.starFourPointsOutline,
            color: JweTheme.accentAmber,
          ),
          const SizedBox(height: 10),
          ...List.generate(widget.highlights.length, (i) {
            final raw = widget.highlights[i];
            final map = raw is Map<String, dynamic>
                ? raw
                : (raw is Map ? Map<String, dynamic>.from(raw) : {'text': raw.toString()});
            final text = map['text']?.toString() ?? '';
            final iconType = map['icon_type']?.toString() ?? 'general';
            if (text.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GratitudeIntelCard(
                text: text,
                iconType: iconType,
                index: i + 1,
              ),
            );
          }),
        ],
      ],
    );
  }
}

class GratitudeDayTile extends StatefulWidget {
  final Map<String, dynamic> dayData;
  final int expandTrigger;
  final bool expandValue;

  const GratitudeDayTile({
    super.key,
    required this.dayData,
    required this.expandTrigger,
    required this.expandValue,
  });

  @override
  State<GratitudeDayTile> createState() => _GratitudeDayTileState();
}

class _GratitudeDayTileState extends State<GratitudeDayTile> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = true;
  }

  @override
  void didUpdateWidget(covariant GratitudeDayTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expandTrigger != oldWidget.expandTrigger) {
      _isExpanded = widget.expandValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayName = widget.dayData['day_name']?.toString() ?? '';
    final dateStr = widget.dayData['date']?.toString() ?? '';
    final label = widget.dayData['label']?.toString() ?? (dayName.isNotEmpty ? '$dayName ($dateStr)' : dateStr);
    final rawItems = widget.dayData['items'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.45),
        border: Border(
          left: BorderSide(
            color: rawItems.isNotEmpty ? JweTheme.accentCyan : JweTheme.textMuted.withOpacity(0.4),
            width: 2.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    MdiIcons.calendarTodayOutline,
                    size: 14,
                    color: rawItems.isNotEmpty ? JweTheme.accentCyan : JweTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          label.toUpperCase(),
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: JweTheme.accentCyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '${rawItems.length} NOTE${rawItems.length == 1 ? '' : 'S'}',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentCyan,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                    color: JweTheme.textMuted,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: rawItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Text(
                        'No reflections or gratitude notes recorded on this day.',
                        style: TextStyle(color: JweTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: rawItems.map((item) {
                        final map = item is Map<String, dynamic>
                            ? item
                            : (item is Map ? Map<String, dynamic>.from(item) : {'text': item.toString()});
                        final text = map['text']?.toString() ?? '';
                        final iconType = map['icon_type']?.toString() ?? 'general';
                        if (text.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: GratitudeIntelCard(
                            text: text,
                            iconType: iconType,
                            index: 0,
                          ),
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
