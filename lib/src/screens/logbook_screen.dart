import 'package:flutter/material.dart';
import 'package:missions/src/widgets/views/daily_summary_view.dart';

class LogbookScreen extends StatelessWidget {
  const LogbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return  Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900),
        child: DailySummaryView(),
      ),
    );
  }
}