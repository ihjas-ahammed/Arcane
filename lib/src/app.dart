import 'package:flutter/material.dart';
import 'package:arcane/src/screens/home_screen.dart';
import 'package:arcane/src/screens/login_screen.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
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
      title: 'Arcane',
      // We use a builder to inject the theme based on the provider state
      builder: (context, child) {
        // Pillarbox constraint for desktop/web and ideal screen 720x1520 constraint
        final constrainedApp = Container(
          color: Colors.black, 
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: child,
            ),
          ),
        );

        return constrainedApp;
      },
      // Default theme, will be overridden by local Theme widgets in screens
      theme: AppTheme.getThemeData(primaryAccent: AppTheme.fhAccentTealFixed),
      debugShowCheckedModeBanner: false,
      home: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          if (appProvider.authLoading) {
            return const Scaffold(
              backgroundColor: AppTheme.fhBgDeepDark,
              body: Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.fhAccentTeal)),
            );
          }

          if (appProvider.currentUser == null) {
            return const LoginScreen();
          }

          // Apply dynamic theme based on selected task
          final Color currentTaskColor =
              appProvider.getSelectedTask()?.taskColor ?? AppTheme.fhAccentTealFixed;

          return Theme(
            data: AppTheme.getThemeData(primaryAccent: currentTaskColor),
            child: Stack(
              children: [
                const HomeScreen(),

                // Sync indicator has been entirely removed to hide the background sync note

                // Blocking overlay ONLY for critical manual loads (Restore/Import)
                if (appProvider.isManuallyLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppTheme.fhAccentTeal),
                            SizedBox(height: 16),
                            Text(
                              "RESTORING DATABASE...",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: AppTheme.fontDisplay,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ),
                    ),
                  )
              ],
            ),
          );
        },
      ),
    );
  }
}