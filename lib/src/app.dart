import 'package:flutter/material.dart';
import 'package:arcane/src/screens/home_screen.dart';
import 'package:arcane/src/screens/login_screen.dart';
import 'package:arcane/src/providers/game_provider.dart';
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
    // Watch the GameProvider for changes.
    // When the GameProvider notifies its listeners (e.g., selected task changes),
    // this build method will be re-executed.
    final gameProvider = context.watch<GameProvider>();

    // Determine the current accent color based on the selected task.
    // If no task is selected, default to AppTheme.fhAccentTealFixed.
    final Color currentTaskColor =
        gameProvider.getSelectedTask()?.taskColor ?? AppTheme.fhAccentTealFixed;

    print(
        "[MyApp] Building MaterialApp with theme based on color: $currentTaskColor"); // DEBUG

    return MaterialApp(
      title: 'Task Dominion',
      // The theme data is now dynamically generated in the build method.
      // Any change to `currentTaskColor` (which comes from `gameProvider`)
      // will cause this `MaterialApp` to rebuild with the new theme.
      theme: AppTheme.getThemeData(primaryAccent: currentTaskColor),
      debugShowCheckedModeBanner: false,
      home: Consumer<GameProvider>(
        builder: (context, gameProvider, child) {
          print(
              "[MyApp Consumer] AuthLoading: ${gameProvider.authLoading}, CurrentUser: ${gameProvider.currentUser?.uid}, DataLoadingAfterLogin: ${gameProvider.isDataLoadingAfterLogin}"); // DEBUG

          // Show a loading indicator if authentication is in progress or
          // if a user is logged in but data is still loading.
          if (gameProvider.authLoading ||
              (gameProvider.currentUser != null &&
                  gameProvider.isDataLoadingAfterLogin)) {
            print("[MyApp Consumer] Showing loading indicator"); // DEBUG
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // If no user is logged in, show the LoginScreen.
          if (gameProvider.currentUser == null) {
            print("[MyApp Consumer] Showing LoginScreen"); // DEBUG
            return const LoginScreen();
          }
          // Otherwise, show the HomeScreen for authenticated users.
          print("[MyApp Consumer] Showing HomeScreen"); // DEBUG
          return const HomeScreen();
        },
      ),
    );
  }
}
