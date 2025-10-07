import 'package:flutter/material.dart';
import 'package:arcane/src/widgets/views/daily_summary_view.dart';
// import 'package:arcane/src/widgets/views/chatbot_view.dart'; // REMOVE
import 'package:arcane/src/screens/chatbot_screen.dart'; // NEW
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
// Provider imports remain if DailySummaryView needs them directly or indirectly.

class LogbookScreen extends StatelessWidget { // Can be StatelessWidget now
  const LogbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intelligence Archives'),
        backgroundColor: AppTheme.fhBgMedium,
        // REMOVE TabBar from here
      ),
      body: Center( // DailySummaryView is the main content now
        child:  ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 900),
          child: DailySummaryView(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatbotScreen()),
          );
        },
        label: const Text('Advisor'),
        icon: Icon(MdiIcons.robotHappyOutline),
        backgroundColor: theme.colorScheme.secondary, // Use dynamic accent
        foregroundColor: ThemeData.estimateBrightnessForColor(theme.colorScheme.secondary) == Brightness.dark 
                            ? AppTheme.fhTextPrimary 
                            : AppTheme.fhBgDark,
      ),
    );
  }
}