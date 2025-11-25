// lib/src/widgets/ui/chart_carousel.dart
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:arcane/src/theme/app_theme.dart';

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
    this.height = 250,
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

  void _nextPage() {
    _controller.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _prevPage() {
    _controller.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              PageView(
                controller: _controller,
                children: widget.pages.map((page) {
                  return Card(
                    color: AppTheme.fhBgMedium.withValues(alpha: 0.5),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(page.title,
                              style: const TextStyle(
                                  color: AppTheme.fhTextSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Expanded(child: page.chart),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Invisible Hit Box - Left 20%
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * 0.2,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _prevPage,
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Invisible Hit Box - Right 20%
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * 0.2,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _nextPage,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (widget.pages.length > 1)
          SmoothPageIndicator(
            controller: _controller,
            count: widget.pages.length,
            effect: const ExpandingDotsEffect(
              dotHeight: 6,
              dotWidth: 6,
              activeDotColor: AppTheme.fhAccentTeal,
              dotColor: AppTheme.fhBgLight,
            ),
          ),
      ],
    );
  }
}