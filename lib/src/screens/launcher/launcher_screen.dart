import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/views/launcher_drawer_view.dart';
import 'package:missions/src/screens/launcher/views/launcher_grid_view.dart';
import 'package:missions/src/screens/launcher/views/launcher_home_view.dart';
import 'package:missions/src/screens/launcher/views/launcher_search_view.dart';
import 'package:missions/src/screens/launcher/views/launcher_space_view.dart';
import 'package:missions/src/screens/launcher/views/launcher_widget_view.dart';
import 'package:missions/src/screens/launcher/launcher_swipe_detector.dart';
import 'package:missions/src/services/widget_action_router.dart';

class LauncherScreen extends StatefulWidget {
  final Widget arcaneChild;

  const LauncherScreen({
    super.key,
    required this.arcaneChild,
  });

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> {
  LauncherScreenType _currentScreen = LauncherScreenType.home;
  LauncherSpaceCategory _selectedCategory = LauncherSpaceCategory.all;
  String? _toastMessage;
  List<LauncherAppItem> _apps = [];

  @override
  void initState() {
    super.initState();
    LauncherService.instance.init().then((_) {
      if (mounted) {
        setState(() {
          _apps = LauncherService.instance.apps;
        });
      }
    });

    LauncherService.instance.appsNotifier.addListener(_onAppsChanged);

    // Register safe back press handler so launcher never kills the Android Activity
    WidgetActionRouter.instance.onBackPressed = _handleBackPress;
  }

  void _onAppsChanged() {
    if (mounted) {
      setState(() {
        _apps = LauncherService.instance.appsNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    LauncherService.instance.appsNotifier.removeListener(_onAppsChanged);
    if (WidgetActionRouter.instance.onBackPressed == _handleBackPress) {
      WidgetActionRouter.instance.onBackPressed = null;
    }
    super.dispose();
  }

  void _handleBackPress() {
    if (!mounted) return;
    if (_currentScreen == LauncherScreenType.arcane) {
      setState(() => _currentScreen = LauncherScreenType.home);
    } else if (_currentScreen != LauncherScreenType.home) {
      setState(() => _currentScreen = LauncherScreenType.home);
    }
    // If already at LauncherScreenType.home, do NOTHING. Never allow the app to finish.
  }

  void _showToast(String message) {
    if (!mounted) return;
    setState(() => _toastMessage = message);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _toastMessage == message) {
        setState(() => _toastMessage = null);
      }
    });
  }

  void _navigateTo(LauncherScreenType type) {
    setState(() => _currentScreen = type);
  }

  void _onLaunchApp(LauncherAppItem app) {
    if (app.isArcaneApp) {
      _navigateTo(LauncherScreenType.arcane);
      return;
    }

    _showToast('Launching ${app.label}...');
    LauncherService.instance.launchApp(app);
  }

  void _onAction(String action) {
    if (action == 'phone') {
      _showToast('Opening Phone...');
      LauncherService.instance.launchApp(
        const LauncherAppItem(
          id: 'phone',
          label: 'Phone',
          package: 'com.google.android.dialer',
          intentAction: 'phone',
          icon: Icons.phone,
        ),
      );
    } else if (action == 'messages') {
      _showToast('Opening Messages...');
      LauncherService.instance.launchApp(
        const LauncherAppItem(
          id: 'messages',
          label: 'Messages',
          package: 'com.google.android.apps.messaging',
          intentAction: 'messages',
          icon: Icons.message,
        ),
      );
    } else if (action == 'camera') {
      _showToast('Opening Camera...');
      LauncherService.instance.launchApp(
        const LauncherAppItem(
          id: 'camera',
          label: 'Camera',
          package: 'com.google.android.GoogleCamera',
          intentAction: 'camera',
          icon: Icons.camera,
        ),
      );
    } else if (action == 'clock') {
      _showToast('Opening Clock...');
      LauncherService.instance.launchApp(
        const LauncherAppItem(
          id: 'clock',
          label: 'Clock',
          package: 'com.google.android.deskclock',
          intentAction: 'clock',
          icon: Icons.access_time,
        ),
      );
    } else if (action == 'gallery') {
      _showToast('Opening Gallery...');
      LauncherService.instance.launchApp(
        const LauncherAppItem(
          id: 'gallery',
          label: 'Gallery',
          package: 'com.google.android.apps.photos',
          intentAction: 'gallery',
          icon: Icons.image,
        ),
      );
    } else if (action == 'notes') {
      _showToast('Opening Notes...');
      LauncherService.instance.launchApp(
        const LauncherAppItem(
          id: 'notes',
          label: 'Notes',
          package: 'com.google.android.keep',
          icon: Icons.note,
        ),
      );
    } else if (action == 'settings') {
      _showToast('Opening Settings...');
      LauncherService.instance.launchApp(
        const LauncherAppItem(
          id: 'settings',
          label: 'Settings',
          package: 'com.android.settings',
          intentAction: 'settings',
          icon: Icons.settings,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isDesktopOrWebMockup = (kIsWeb || screenWidth > 520);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: isDesktopOrWebMockup
            ? const Color(0xFF020203)
            : LauncherTheme.bg,
        body: isDesktopOrWebMockup
            ? _buildWebPhoneMockup(context)
            : _buildPhoneContent(context, isMockup: false),
      ),
    );
  }

  /// Web and Desktop Prototyping Phone Mockup frame conforming to the user's HTML design:
  /// width: 390px, height: min(844px, 94vh), border-radius: 44px, border: 2px solid var(--red),
  /// box-shadow: 0 0 0 6px #0a0b0e, 0 0 0 7px #25070c, 0 0 40px rgba(255,43,63,.35)
  Widget _buildWebPhoneMockup(BuildContext context) {
    final mediaHeight = MediaQuery.of(context).size.height;
    final phoneHeight = math.min(844.0, mediaHeight * 0.94);
    const phoneWidth = 390.0;
    final isLight = LauncherTheme.isLight;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isLight ? const Color(0xFFE2DDD2) : const Color(0xFF040609),
      child: Center(
        child: Container(
          width: phoneWidth,
          height: phoneHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(44),
            border: Border.all(
              color: isLight ? const Color(0xFFCBC4B6) : const Color(0xFF1E222B),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.65),
                blurRadius: 36,
                spreadRadius: 4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(42),
            child: _buildPhoneContent(context, isMockup: true),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneContent(BuildContext context, {required bool isMockup}) {
    return Container(
      color: LauncherTheme.bg,
      child: SafeArea(
        top: !isMockup,
        bottom: !isMockup,
        child: Stack(
          children: [
            // Active Screen View
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, animation) {
                if (child.key == const ValueKey('drawer')) {
                  // Drawer slides up from bottom
                  final offsetAnim = Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                  return SlideTransition(
                    position: offsetAnim,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                } else if (child.key == const ValueKey('arcane')) {
                  // Arcane slides up smoothly
                  final offsetAnim = Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                  return SlideTransition(
                    position: offsetAnim,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                }
                return FadeTransition(opacity: animation, child: child);
              },
              child: _buildCurrentView(),
            ),

            // Toast Floating Notification
            if (_toastMessage != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 40,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14070A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: LauncherTheme.red, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: LauncherTheme.redDim,
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      _toastMessage!,
                      textAlign: TextAlign.center,
                      style: LauncherTheme.rajdhani(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentScreen) {
      case LauncherScreenType.home:
        return LauncherHomeView(
          key: const ValueKey('home'),
          onOpenSpace: () => _navigateTo(LauncherScreenType.space),
          onOpenSearch: () => _navigateTo(LauncherScreenType.search),
          onOpenWidget: () => _navigateTo(LauncherScreenType.widget),
          onOpenDrawer: () => _navigateTo(LauncherScreenType.drawer),
          onSwipeUpToArcane: () => _navigateTo(LauncherScreenType.arcane),
          onAction: _onAction,
        );

      case LauncherScreenType.space:
        return LauncherSpaceView(
          key: const ValueKey('space'),
          onBack: () => _navigateTo(LauncherScreenType.home),
          onSelectSpace: (category) {
            setState(() => _selectedCategory = category);
            _navigateTo(LauncherScreenType.grid);
          },
          onAddSpace: () {
            _showToast('Configure New App Space');
            _navigateTo(LauncherScreenType.widget);
          },
          onHome: () => _navigateTo(LauncherScreenType.home),
        );

      case LauncherScreenType.grid:
        final filteredApps = _selectedCategory == LauncherSpaceCategory.all
            ? _apps
            : _apps.where((a) => a.category == _selectedCategory || a.isHot).toList();

        return LauncherGridView(
          key: const ValueKey('grid'),
          apps: filteredApps.isNotEmpty ? filteredApps : _apps,
          onOpenSearch: () => _navigateTo(LauncherScreenType.search),
          onOpenDrawer: () => _navigateTo(LauncherScreenType.drawer),
          onLaunchApp: _onLaunchApp,
          onHome: () => _navigateTo(LauncherScreenType.home),
        );

      case LauncherScreenType.search:
        return LauncherSearchView(
          key: const ValueKey('search'),
          apps: _apps,
          onBack: () => _navigateTo(LauncherScreenType.home),
          onLaunchApp: _onLaunchApp,
          onAction: _onAction,
          onHome: () => _navigateTo(LauncherScreenType.home),
        );

      case LauncherScreenType.widget:
        return LauncherWidgetView(
          key: const ValueKey('widget'),
          onBack: () => _navigateTo(LauncherScreenType.home),
          onWidgetAdded: (name) => _showToast('Widget $name Updated'),
          onHome: () => _navigateTo(LauncherScreenType.home),
          onOpenArcane: () => _navigateTo(LauncherScreenType.arcane),
          onAction: _onAction,
        );

      case LauncherScreenType.drawer:
        return LauncherDrawerView(
          key: const ValueKey('drawer'),
          apps: _apps,
          onLaunchApp: _onLaunchApp,
          onClose: () => _navigateTo(LauncherScreenType.grid),
          onHome: () => _navigateTo(LauncherScreenType.home),
        );

      case LauncherScreenType.arcane:
        // App's original screens with pull-down gesture or top handle tap to return to launcher home
        return LauncherSwipeDetector(
          key: const ValueKey('arcane'),
          behavior: HitTestBehavior.translucent,
          onSwipeDown: () => _navigateTo(LauncherScreenType.home),
          child: Stack(
            children: [
              widget.arcaneChild,
              // Top pull-down bar with pill handle (tap or swipe down returns to launcher)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: InkWell(
                    onTap: () => _navigateTo(LauncherScreenType.home),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: LauncherTheme.text.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}
