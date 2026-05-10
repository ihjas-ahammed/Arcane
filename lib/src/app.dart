import 'package:flutter/material.dart';
import 'package:missions/src/screens/home_screen.dart';
import 'package:missions/src/screens/login_screen.dart';
import 'package:missions/src/screens/onboarding/app_tour_screen.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:provider/provider.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Missions',
      builder: (context, child) {
        // Enforce maximum width for proper viewing on desktop/web (ideal screen 720x1520 constraint)
        return Container(
          color: Colors.black, 
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: child,
            ),
          ),
        );
      },
      theme: AppTheme.getThemeData(primaryAccent: AppTheme.fhAccentTealFixed),
      debugShowCheckedModeBanner: false,
      home: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          
          if (appProvider.authLoading) {
            return const Scaffold(
              backgroundColor: AppTheme.fhBgDeepDark,
              body: Center(child: CircularProgressIndicator(color: AppTheme.fhAccentTeal)),
            );
          }

          if (appProvider.currentUser == null) {
            return const LoginScreen();
          }

          // Check if onboarding is completed
          if (!appProvider.settings.hasCompletedTour) {
            return Theme(
              data: AppTheme.getThemeData(primaryAccent: AppTheme.fhAccentTealFixed),
              child: const AppTourScreen(),
            );
          }

          final Color currentTaskColor =
              appProvider.getSelectedTask()?.taskColor ?? AppTheme.fhAccentTealFixed;

          return Theme(
            data: AppTheme.getThemeData(primaryAccent: currentTaskColor),
            child: const HomeScreen(),
          );
        },
      ),
    );
  }
}