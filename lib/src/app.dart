import 'package:flutter/material.dart';
import 'package:arcane/src/screens/home_screen.dart';
import 'package:arcane/src/screens/login_screen.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/ui/sync_indicator.dart';
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

          return Stack(
            children: [
              const HomeScreen(),

              // Floating Sync Indicator - HIDDEN per user request
              /*
              Positioned(
                top: 100,
                right: 0,
                child: SyncIndicator(
                  isVisible: appProvider.isSyncing &&
                      !appProvider.isManuallySaving &&
                      !appProvider.isManuallyLoading,
                ),
              ),
              */

              // Blocking loading overlay for critical manual operations remains
              if (appProvider.isManuallySaving || appProvider.isManuallyLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                              color: AppTheme.fhAccentTeal),
                          const SizedBox(height: 16),
                          Text(
                            appProvider.isManuallyLoading
                                ? "LOADING DATA..."
                                : "SYNCING...",
                            style: const TextStyle(
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
          );
        },
      ),
    );
  }
}