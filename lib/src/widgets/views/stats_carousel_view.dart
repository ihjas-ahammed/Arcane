import 'package:flutter/material.dart';
import 'package:arcane/src/widgets/charts/weekly_bar_charts.dart';
import 'package:arcane/src/widgets/charts/time_pie_chart.dart'; // New Import
import 'package:arcane/src/theme/app_theme.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class StatsCarouselView extends StatefulWidget {
  final Map<int, double> activityData;
  final Map<int, Color> activityColors;
  final Map<int, double> virtueData;
  final Map<int, Color> virtueColors;
  
  // New Data for Time Pie Chart
  final Map<String, double> dailyTaskTimeData;
  final Map<String, Color> taskColors;

  const StatsCarouselView({
    super.key,
    required this.activityData,
    required this.activityColors,
    required this.virtueData,
    required this.virtueColors,
    required this.dailyTaskTimeData,
    required this.taskColors,
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
  
  void _nextPage() {
    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }
  
  void _prevPage() {
    _controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 250, // Increased height slightly to accommodate pie chart legend if needed
          child: Stack(
            children: [
              PageView(
                controller: _controller,
                children: [
                   // 1. Daily Mission Time Pie Chart (New)
                  _buildChartCard(
                    "Today's Mission Focus",
                    TimePieChart(taskData: widget.dailyTaskTimeData, taskColors: widget.taskColors),
                  ),
                  // 2. Weekly Activity Bar Chart
                  _buildChartCard(
                    "Last 7 Days Activity", 
                    WeeklyActivityBarChart(weeklyData: widget.activityData, dominantColors: widget.activityColors)
                  ),
                  // 3. Weekly Virtue Bar Chart
                  _buildChartCard(
                    "Last 7 Days Growth", 
                    WeeklyVirtueBarChart(weeklyXp: widget.virtueData, dominantVirtueColors: widget.virtueColors)
                  ),
                ],
              ),
              // Left Arrow
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: Icon(MdiIcons.chevronLeft, color: AppTheme.fhTextSecondary.withOpacity(0.5)),
                    onPressed: _prevPage,
                  ),
                ),
              ),
              // Right Arrow
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: Icon(MdiIcons.chevronRight, color: AppTheme.fhTextSecondary.withOpacity(0.5)),
                    onPressed: _nextPage,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SmoothPageIndicator(
          controller: _controller,
          count: 3, // Updated count
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
      margin: const EdgeInsets.symmetric(horizontal: 16), // Added horizontal margin for arrows
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