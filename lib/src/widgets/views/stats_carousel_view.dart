import 'package:flutter/material.dart';
import 'package:arcane/src/widgets/charts/weekly_bar_charts.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class StatsCarouselView extends StatefulWidget {
  final Map<int, double> activityData;
  final Map<int, Color> activityColors;
  final Map<int, double> virtueData;

  const StatsCarouselView({
    super.key,
    required this.activityData,
    required this.activityColors,
    required this.virtueData,
  });

  @override
  State<StatsCarouselView> createState() => _StatsCarouselViewState();
}

class _StatsCarouselViewState extends State<StatsCarouselView> {
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
          height: 220,
          child: PageView(
            controller: _controller,
            children: [
              _buildChartCard(
                "Last 7 Days Activity", 
                WeeklyActivityBarChart(weeklyData: widget.activityData, dominantColors: widget.activityColors)
              ),
              _buildChartCard(
                "Last 7 Days Growth", 
                WeeklyVirtueBarChart(weeklyXp: widget.virtueData)
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SmoothPageIndicator(
          controller: _controller,
          count: 2,
          effect: ExpandingDotsEffect(
            dotHeight: 6,
            dotWidth: 6,
            activeDotColor: AppTheme.fhAccentTeal,
            dotColor: AppTheme.fhBgLight,
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Card(
      color: AppTheme.fhBgMedium.withValues(alpha: 0.5),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              color: AppTheme.fhTextSecondary, 
              fontSize: 14, 
              fontWeight: FontWeight.bold
            )),
            const SizedBox(height: 16),
            Expanded(child: chart),
          ],
        ),
      ),
    );
  }
}