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
    final appProvider = context.watch<AppProvider>();

    final Color currentTaskColor =
        appProvider.getSelectedTask()?.taskColor ?? AppTheme.fhAccentTealFixed;

    return MaterialApp(
      title: 'Arcane',
      theme: AppTheme.getThemeData(primaryAccent: currentTaskColor),
      debugShowCheckedModeBanner: false,
      home: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          // If purely auth loading (initial startup), show spinner
          if (appProvider.authLoading) {
            return const Scaffold(
              backgroundColor: AppTheme.fhBgDeepDark,
              body: Center(child: CircularProgressIndicator(color: AppTheme.fhAccentTeal)),
            );
          }
          
          if (appProvider.currentUser == null) {
            return const LoginScreen();
          }
          
          // Once authenticated, even if syncing in background, show Home
          return Stack(
            children: [
              const HomeScreen(),
              // Optional: Small sync indicator
              if ( appProvider.isManuallySaving || appProvider.isManuallyLoading)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20)
                      ),
                      child: const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)
                      ),
                    ),
                  ),
                )
            ],
          );
        },
      ),
    );
  }
}