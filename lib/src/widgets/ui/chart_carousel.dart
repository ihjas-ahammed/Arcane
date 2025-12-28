import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_card.dart';

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
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ValorantCard(
                  borderColor: AppTheme.fhAccentRed.withValues(alpha: 0.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        page.title.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.fhTextSecondary,
                          fontFamily: AppTheme.fontDisplay,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                          fontSize: 14
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: page.chart),
                    ],
                  ),
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
              activeDotColor: AppTheme.fhAccentRed,
              dotColor: AppTheme.fhBorderColor,
            ),
          ),
      ],
    );
  }
}