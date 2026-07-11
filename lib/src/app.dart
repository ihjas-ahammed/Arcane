import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:missions/src/screens/home_screen.dart';
import 'package:missions/src/screens/login_screen.dart';
import 'package:missions/src/screens/onboarding/app_tour_screen.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/home_widget_publisher.dart';
import 'package:missions/src/services/widget_action_router.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/widgets/common/insight_watcher.dart';
import 'package:provider/provider.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Drain any widget click that arrived before the navigator existed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetActionRouter.instance.flushPending();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        final themeMode = appProvider.settings.themeMode;
        final isSystemDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        final bool isLightTheme = themeMode == 'light' || (themeMode == 'system' && !isSystemDark);

        // Sync JweTheme brightness
        JweTheme.isLight = isLightTheme;

        final Color currentTaskColor =
            appProvider.getSelectedTask()?.taskColor ?? AppTheme.fhAccentTealFixed;

        // Sync JweTheme and AppTheme accent colors dynamically
        JweTheme.accentAmber = currentTaskColor;
        JweTheme.amberDim = currentTaskColor.withValues(alpha: 0.8);
        JweTheme.amberSoft = currentTaskColor.withValues(alpha: 0.14);
        JweTheme.amberGlow = currentTaskColor.withValues(alpha: 0.55);
        JweTheme.lineAmber = currentTaskColor.withValues(alpha: 0.3);
        AppTheme.fhAccentGold = currentTaskColor;
        AppTheme.fhAccentOrange = currentTaskColor;

        return MaterialApp(
          title: 'Missions',
          navigatorKey: WidgetActionRouter.instance.navigatorKey,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          builder: (context, child) {
            final isDesktop = defaultTargetPlatform == TargetPlatform.linux ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.windows;
            if (isDesktop) return child!;
            // On mobile/web constrain to phone-sized column
            return Container(
              color: isLightTheme ? AppTheme.fhLightBgDeepDark : Colors.black,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: child,
                ),
              ),
            );
          },
          theme: AppTheme.getThemeData(
              primaryAccent: isLightTheme
                  ? JweTheme.calibrate(AppTheme.fhAccentTealFixed)
                  : AppTheme.fhAccentTealFixed,
              isLightTheme: isLightTheme),
          debugShowCheckedModeBanner: false,
          home: appProvider.authLoading
              ? Scaffold(
                  backgroundColor: isLightTheme ? AppTheme.fhLightBgDeepDark : AppTheme.fhBgDeepDark,
                  body: Center(
                    child: CircularProgressIndicator(
                      color: isLightTheme ? AppTheme.fhLightTextPrimary : AppTheme.fhAccentTeal,
                    ),
                  ),
                )
              : appProvider.currentUser == null
                  ? const LoginScreen()
                  : !appProvider.settings.hasCompletedTour
                      ? Theme(
                          data: AppTheme.getThemeData(
                              primaryAccent: AppTheme.fhAccentTealFixed,
                              isLightTheme: isLightTheme),
                          child: const AppTourScreen(),
                        )
                      : Theme(
                          data: AppTheme.getThemeData(
                              primaryAccent: currentTaskColor,
                              isLightTheme: isLightTheme),
                          child: HomeWidgetHost(
                            provider: appProvider,
                            child: const InsightWatcher(child: HomeScreen()),
                          ),
                        ),
        );
      },
    );
  }
}
