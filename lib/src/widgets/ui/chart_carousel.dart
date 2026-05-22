import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class ChartCarouselData {
  final String title;
  final Widget chart;
  final HudTone tone;
  ChartCarouselData({required this.title, required this.chart, this.tone = HudTone.amber});
}

/// Operator HUD chart carousel — clip-corner panels, tone-tinted header,
/// page indicator chips with code labels.
class ChartCarousel extends StatefulWidget {
  final List<ChartCarouselData> pages;
  final double height;

  const ChartCarousel({super.key, required this.pages, this.height = 280});

  @override
  State<ChartCarousel> createState() => _ChartCarouselState();
}

class _ChartCarouselState extends State<ChartCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _toneColor(HudTone t) {
    switch (t) {
      case HudTone.cyan: return JweTheme.accentCyan;
      case HudTone.teal: return JweTheme.accentTeal;
      case HudTone.red: return JweTheme.accentRed;
      case HudTone.amber: return JweTheme.accentAmber;
      case HudTone.neutral: return JweTheme.textMid;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: widget.height,
        child: PageView(
          controller: _controller,
          onPageChanged: (i) => setState(() => _index = i),
          children: List.generate(widget.pages.length, (i) {
            final page = widget.pages[i];
            final c = _toneColor(page.tone);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: HudPanel(
                clip: HudClip.br,
                accent: c,
                allBrackets: true,
                padding: EdgeInsets.zero,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: c.withValues(alpha: 0.20))),
                    ),
                    child: Row(children: [
                      Container(width: 4, height: 12, color: c),
                      const SizedBox(width: 10),
                      Text(
                        page.title.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          color: c,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(i + 1).toString().padLeft(2, '0')}/${widget.pages.length.toString().padLeft(2, '0')}',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: page.chart,
                    ),
                  ),
                ]),
              ),
            );
          }),
        ),
      ),
      const SizedBox(height: 10),
      if (widget.pages.length > 1)
        SmoothPageIndicator(
          controller: _controller,
          count: widget.pages.length,
          effect: const ExpandingDotsEffect(
            dotHeight: 3,
            dotWidth: 6,
            expansionFactor: 4,
            activeDotColor: JweTheme.accentAmber,
            dotColor: Color(0x3FA8B3C7),
            spacing: 6,
          ),
        ),
    ]);
  }
}
