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
    return MaterialApp(
      title: 'Arcane',
      // We use a builder to inject the theme based on the provider state
      builder: (context, child) {
        // Pillarbox constraint for desktop/web
        final constrainedApp = Container(
          color: Colors.black, 
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: child,
            ),
          ),
        );

        // We need to listen to the provider for theme changes
        // Since we can't access context.watch above MaterialApp, we do it here inside builder
        // However, standard practice is wrapping MaterialApp with Consumer or using a stateful parent.
        // Given the structure, we pass the child (Home/Login) which will have the correct theme context below.
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

                // Non-blocking Sync Indicator (Bottom Center)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SyncIndicator(isVisible: appProvider.isSyncing),
                  ),
                ),

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