import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ChartCarouselData {
  final String title;
  final Widget chart;

  ChartCarouselData({required this.title, required this.chart});
}

class ChartCarousel extends StatefulWidget {
  final List<ChartCarouselData> pages;
  final double height;

  const ChartCarousel({
    super.key,
    required this.pages,
    this.height = 280,
  });

  @override
  State<ChartCarousel> createState() => _ChartCarouselState();
}

class _ChartCarouselState extends State<ChartCarousel> {
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView(
            controller: _controller,
            children: widget.pages.map((page) {
              // Constructing the JWE Panel manually here to safely use Expanded 
              // and prevent the "infinite height" fl_chart render error.
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: JweTheme.panel.withOpacity(0.85),
                  border: Border.all(color: JweTheme.accentCyan.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children:[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: JweTheme.accentCyan, width: 4),
                          bottom: BorderSide(color: JweTheme.accentCyan.withOpacity(0.2)),
                        ),
                        gradient: LinearGradient(
                          colors:[JweTheme.accentCyan.withOpacity(0.15), Colors.transparent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Text(
                        page.title.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          color: JweTheme.textWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    Expanded( // <-- The fix: Forces the chart to respect the boundaries
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: page.chart,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.pages.length > 1)
          SmoothPageIndicator(
            controller: _controller,
            count: widget.pages.length,
            effect: ExpandingDotsEffect(
              dotHeight: 4,
              dotWidth: 4,
              expansionFactor: 4,
              activeDotColor: JweTheme.accentCyan,
              dotColor: JweTheme.border,
            ),
          ),
      ],
    );
  }
}