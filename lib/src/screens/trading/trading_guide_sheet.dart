import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class TradingGuideSheet extends StatelessWidget {
  const TradingGuideSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TradingGuideSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guides = TradingGuideCard.allGuides;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: JweTheme.border, width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: JweTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(
              children: [
                Icon(Icons.school_rounded, color: JweTheme.accentCyan, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRADING PROTOCOL & MECHANICS',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Foundational market realities in plain language',
                        style: GoogleFonts.inter(
                          color: JweTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: JweTheme.textMuted, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Scrollable Card List
          Flexible(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 20 + bottomInset),
              itemCount: guides.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final card = guides[index];
                return _GuideCardWidget(card: card, index: index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCardWidget extends StatefulWidget {
  final TradingGuideCard card;
  final int index;

  const _GuideCardWidget({required this.card, required this.index});

  @override
  State<_GuideCardWidget> createState() => _GuideCardWidgetState();
}

class _GuideCardWidgetState extends State<_GuideCardWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final themeAccent = widget.index == 1
        ? JweTheme.accentCyan
        : widget.index == 2
            ? JweTheme.accentAmber
            : widget.index == 3
                ? JweTheme.accentTeal
                : JweTheme.accentRed;

    final wordCount = widget.card.content.split(RegExp(r'\s+')).length;

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: JweTheme.panel2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isExpanded ? themeAccent.withValues(alpha: 0.6) : JweTheme.border,
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: themeAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(widget.card.icon, color: themeAccent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.card.title,
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textWhite,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            widget.card.subtitle.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              color: themeAccent,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            '• $wordCount WORDS',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textMuted,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: JweTheme.textMuted,
                  size: 18,
                ),
              ],
            ),

            if (_isExpanded) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: JweTheme.bgCanvas.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: JweTheme.border.withValues(alpha: 0.5)),
                ),
                child: Text(
                  widget.card.content,
                  style: GoogleFonts.inter(
                    color: JweTheme.textMid,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
