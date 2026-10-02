import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/launcher_wallpaper_painter.dart';
import 'package:missions/src/screens/launcher/views/launcher_drawer_view.dart';
import 'package:missions/src/screens/launcher/views/launcher_home_view.dart';
import 'package:missions/src/screens/launcher/views/launcher_items.dart';
import 'package:missions/src/screens/launcher/views/launcher_sheets.dart';
import 'package:missions/src/screens/launcher/views/launcher_widget_view.dart';
import 'package:missions/src/services/widget_action_router.dart';

/// Arcane home-screen launcher.
///
/// Flow (Pixel-style, one surface):
///   ┌ Arcane widgets ◀ swipe ▶ Home ┐   swipe up   → app drawer (search on top)
///   └──────── PageView ─────────────┘   swipe down → system notification shade
///   Arcane (the Missions app) slides over everything from its dock/drawer icon and
///   stays alive underneath while hidden. HOME always returns here.
///
/// Off Android the launcher has no meaning, so the Arcane app is shown directly.
class LauncherScreen extends StatefulWidget {
  final Widget arcaneChild;

  const LauncherScreen({super.key, required this.arcaneChild});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> with TickerProviderStateMixin {
  static const int _homePage = 1;

  late final AnimationController _arcane = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final AnimationController _drawer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  final PageController _pages = PageController(initialPage: _homePage);
  final GlobalKey<LauncherDrawerViewState> _drawerKey = GlobalKey<LauncherDrawerViewState>();

  bool _arcaneBuilt = false;
  bool _launchedAsApp = false;

  @override
  void initState() {
    super.initState();
    if (!LauncherNative.isSupported) return;

    LauncherService.instance.init();
    LauncherNative.attach();
    LauncherNative.homePressed.addListener(_goHome);
    LauncherNative.openArcaneRequested.addListener(_openArcaneFromIntent);
    WidgetActionRouter.instance.tabRequest.addListener(_onTabRequest);
    // Tapping the Arcane mark in the app header returns to the launcher.
    WidgetActionRouter.instance.onBackPressed = _closeArcane;
    LauncherActions.launch = _launch;
    LauncherActions.dragMoved = _onItemDragMoved;
    LauncherActions.dragEnded = _onItemDragEnded;
    LauncherService.instance.fullscreen.addListener(_applySystemUiMode);
    _arcane.addStatusListener((_) => _applySystemUiMode());
    _applySystemUiMode();

    // Build Arcane right after the launcher's first frame so its services (widget publishing,
    // insight watcher, tab routing) run even if the user never opens it — without delaying boot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_arcaneBuilt) setState(() => _arcaneBuilt = true);
    });

    // Opened from another launcher's icon, a widget deep link or the assistant: show Arcane at once.
    LauncherNative.launchMode().then((mode) {
      if (!mounted || mode == 'home') return;
      _launchedAsApp = true;
      _openArcane(animate: false);
    });
  }

  @override
  void dispose() {
    LauncherService.instance.fullscreen.removeListener(_applySystemUiMode);
    LauncherNative.homePressed.removeListener(_goHome);
    LauncherNative.openArcaneRequested.removeListener(_openArcaneFromIntent);
    WidgetActionRouter.instance.tabRequest.removeListener(_onTabRequest);
    if (WidgetActionRouter.instance.onBackPressed == _closeArcane) {
      WidgetActionRouter.instance.onBackPressed = null;
    }
    if (LauncherActions.launch == _launch) {
      LauncherActions.launch = null;
      LauncherActions.dragMoved = null;
      LauncherActions.dragEnded = null;
    }
    _edgeTimer?.cancel();
    _arcane.dispose();
    _drawer.dispose();
    _pages.dispose();
    super.dispose();
  }

  // ── Fullscreen ──────────────────────────────────────────────

  bool? _immersive;

  /// Launcher surface in view and fullscreen on → hide the status and navigation bars
  /// (a swipe from an edge reveals them briefly). Arcane opening over it brings them back.
  void _applySystemUiMode() {
    final arcaneShowing =
        _arcane.status == AnimationStatus.forward || _arcane.status == AnimationStatus.completed;
    LauncherNative.arcaneVisible.value = arcaneShowing;
    final immersive = LauncherService.instance.fullscreen.value && !arcaneShowing;
    if (immersive == _immersive) return;
    _immersive = immersive;
    SystemChrome.setEnabledSystemUIMode(immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  // ── Navigation ──────────────────────────────────────────────

  void _openArcane({bool animate = true}) {
    if (LauncherNative.isSupported) {
      _closeDrawer(animate: false);
      LauncherService.instance.recordArcaneOpen();
      LauncherNative.launchApp(kArcanePackage, '$kArcanePackage.MainActivity');
      return;
    }
    if (!_arcaneBuilt) setState(() => _arcaneBuilt = true);
    _closeDrawer(animate: false);
    LauncherService.instance.recordArcaneOpen();
    if (animate) {
      _arcane.forward();
    } else {
      _arcane.value = 1;
    }
  }

  void _openArcaneFromIntent() {
    _launchedAsApp = true;
    _openArcane();
  }

  void _onTabRequest() {
    if (WidgetActionRouter.instance.tabRequest.value != null) _openArcane();
  }

  void _closeArcane() => _arcane.reverse();

  /// HOME button: dismiss everything and land on the home page.
  void _goHome() {
    final instant = LauncherNative.lastHomeInstant;
    final nav = WidgetActionRouter.instance.navigatorKey.currentState;
    nav?.popUntil((r) => r.isFirst);
    FocusManager.instance.primaryFocus?.unfocus();
    _launchedAsApp = false;
    if (instant) {
      // Takeover swap over the stock launcher: be on home in the very first frame.
      _arcane.value = 0;
      _closeDrawer(animate: false);
      if (_pages.hasClients && (_pages.page ?? _homePage).round() != _homePage) _pages.jumpToPage(_homePage);
      return;
    }
    if (_arcane.value > 0) {
      _arcane.reverse();
      _closeDrawer(animate: false);
    } else if (_drawer.value > 0) {
      _closeDrawer();
    }
    if (_pages.hasClients && (_pages.page ?? _homePage).round() != _homePage) {
      _pages.animateToPage(_homePage, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  void _openDrawer({bool focusSearch = false}) {
    _drawer.animateTo(1, curve: Curves.easeOutCubic);
    if (focusSearch) _drawerKey.currentState?.focusSearch();
    if (_drawer.value == 0) HapticFeedback.selectionClick();
  }

  void _closeDrawer({bool animate = true}) {
    _drawerKey.currentState?.reset();
    if (animate) {
      _drawer.animateBack(0, curve: Curves.easeOutCubic);
    } else {
      _drawer.value = 0;
    }
  }

  Future<void> _handleBack() async {
    if (_drawer.value > 0) {
      _closeDrawer();
    } else if (_arcane.value > 0) {
      if (_launchedAsApp && !await LauncherNative.actsAsHome()) {
        // Opened like a normal app while another launcher is home (and no takeover): back leaves the app.
        SystemNavigator.pop();
        return;
      }
      _closeArcane();
    } else if (_pages.hasClients && (_pages.page ?? _homePage).round() != _homePage) {
      _pages.animateToPage(_homePage, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else if (!await LauncherNative.actsAsHome()) {
      SystemNavigator.pop();
    }
    // Acting as home (default or takeover) on its home page: back does nothing, like any home screen.
  }

  void _launch(LauncherApp app) {
    if (app.isArcane) {
      _openArcane();
      return;
    }
    LauncherService.instance.launch(app).then((ok) {
      if (!ok && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('${app.displayLabel} could not be opened')));
      }
    });
    // Collapse the drawer after the app window has covered it.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && _drawer.value > 0) _closeDrawer(animate: false);
    });
  }

  // ── Drag & drop ─────────────────────────────────────────────

  bool _resetDrawerAfterDrag = false;
  Timer? _edgeTimer;

  /// An app started moving: dragged out of the drawer → reveal home underneath (without
  /// resetting the drawer, which would dispose the tile carrying the drag).
  void _onItemDragMoved(LauncherDragData data) {
    if (_drawer.value > 0) {
      _resetDrawerAfterDrag = true;
      FocusManager.instance.primaryFocus?.unfocus();
      _drawer.animateBack(0, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    }
  }

  void _onItemDragEnded() {
    _edgeTimer?.cancel();
    if (_resetDrawerAfterDrag) {
      _resetDrawerAfterDrag = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _drawerKey.currentState?.reset());
    }
  }

  /// Hovering a screen edge while dragging flips between the widgets page and home.
  void _hoverEdge(int page) {
    if (_edgeTimer?.isActive ?? false) return;
    _edgeTimer = Timer(const Duration(milliseconds: 420), () {
      if (!_pages.hasClients || (_pages.page ?? _homePage).round() == page) return;
      HapticFeedback.selectionClick();
      _pages.animateToPage(page, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    });
  }

  Widget _buildDragChrome() {
    return ValueListenableBuilder<LauncherDragData?>(
      valueListenable: LauncherActions.active,
      builder: (context, drag, _) {
        if (drag == null) return const SizedBox.shrink();
        final top = MediaQuery.paddingOf(context).top;
        Widget edge({required bool left}) => Positioned(
              top: top + 70,
              bottom: 120,
              left: left ? 0 : null,
              right: left ? null : 0,
              width: 26,
              child: DragTarget<LauncherDragData>(
                onWillAcceptWithDetails: (_) {
                  _hoverEdge(left ? 0 : _homePage);
                  return false;
                },
                onLeave: (_) => _edgeTimer?.cancel(),
                builder: (_, __, ___) => const SizedBox.expand(),
              ),
            );
        return Stack(
          children: [
            edge(left: true),
            edge(left: false),
            if (drag.from != null)
              Positioned(
                top: top + 6,
                left: 40,
                right: 40,
                child: DragTarget<LauncherDragData>(
                  onAcceptWithDetails: (d) {
                    HapticFeedback.mediumImpact();
                    final from = d.data.from;
                    if (from != null) LauncherService.instance.removeFromArea(from, d.data.key);
                  },
                  builder: (context, candidates, _) {
                    final hot = candidates.isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      height: 48,
                      decoration: BoxDecoration(
                        color: hot ? LauncherTheme.red : LauncherTheme.panel.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: LauncherTheme.red),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MdiIcons.closeCircleOutline, size: 18, color: hot ? Colors.white : LauncherTheme.red),
                          const SizedBox(width: 8),
                          Text(
                            'REMOVE',
                            style: LauncherTheme.rajdhani(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: hot ? Colors.white : LauncherTheme.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Home gestures ───────────────────────────────────────────

  double _dragStartDrawer = 0;

  void _onVerticalDragStart(DragStartDetails d) => _dragStartDrawer = _drawer.value;

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    final h = MediaQuery.sizeOf(context).height;
    final delta = -(d.primaryDelta ?? 0) / (h * 0.85);
    if (_dragStartDrawer == 0 && _drawer.value == 0 && delta < 0) return; // downward: handled on end
    _drawer.value = (_drawer.value + delta).clamp(0.0, 1.0);
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_drawer.value == 0 && v > 300) {
      LauncherNative.expandNotifications();
      return;
    }
    if (v < -300 || (v.abs() <= 300 && _drawer.value > 0.35)) {
      _openDrawer();
    } else {
      _closeDrawer();
    }
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!LauncherNative.isSupported) return widget.arcaneChild;

    final isLight = LauncherTheme.isLight;
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Launcher surface — skipped entirely (no layout/paint/tickers) while Arcane covers it.
          AnimatedBuilder(
            animation: _arcane,
            builder: (context, child) => Offstage(
              offstage: _arcane.value == 1,
              child: TickerMode(enabled: _arcane.value < 1, child: child!),
            ),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlay,
              // A Scaffold (not bare Material) so launcher snackbars have a host; the drawer
              // handles the keyboard inset itself.
              child: Scaffold(
                backgroundColor: LauncherTheme.bg,
                resizeToAvoidBottomInset: false,
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(painter: LauncherWallpaperPainter(isLight: isLight)),
                    ),
                    _buildPages(),
                    _buildDrawer(),
                    _buildDragChrome(),
                  ],
                ),
              ),
            ),
          ),

          // Arcane — built on first open, then kept alive (state, timers, services) while hidden.
          if (_arcaneBuilt)
            AnimatedBuilder(
              animation: _arcane,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(_arcane.value);
                return Offstage(
                  offstage: _arcane.value == 0,
                  child: TickerMode(
                    enabled: _arcane.value > 0,
                    child: FractionalTranslation(
                      translation: Offset(0, 1 - t),
                      child: child,
                    ),
                  ),
                );
              },
              child: RepaintBoundary(child: widget.arcaneChild),
            ),
        ],
      ),
    );
  }

  Widget _buildPages() {
    return AnimatedBuilder(
      animation: _drawer,
      builder: (context, child) {
        final t = _drawer.value;
        return IgnorePointer(
          ignoring: t > 0.5,
          child: Opacity(opacity: (1 - t * 1.4).clamp(0.0, 1.0), child: child),
        );
      },
      child: PageView(
        controller: _pages,
        physics: const ClampingScrollPhysics(),
        children: [
          LauncherWidgetView(onOpenArcane: _openArcane),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            onLongPress: () => showLauncherHomeMenu(context, onOpenArcaneWidgets: () {
              _pages.animateToPage(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
            }),
            child: LauncherHomeView(
              onLaunch: _launch,
              onOpenDrawer: () => _openDrawer(),
              onOpenSearch: () => _openDrawer(focusSearch: true),
              onOpenArcane: _openArcane,
              onOpenWidgetsPage: () =>
                  _pages.animateToPage(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return AnimatedBuilder(
      animation: _drawer,
      builder: (context, child) {
        final t = _drawer.value;
        // Kept mounted (offstage) so search text, scroll offset and focus survive, but costs nothing hidden.
        return Offstage(
          offstage: t == 0,
          child: TickerMode(
            enabled: t > 0,
            child: FractionalTranslation(
              translation: Offset(0, (1 - Curves.easeOut.transform(t)) * 0.9),
              child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
            ),
          ),
        );
      },
      child: LauncherDrawerView(
        key: _drawerKey,
        onLaunch: _launch,
        onClose: () => _closeDrawer(),
        onDragClose: (delta) {
          final h = MediaQuery.sizeOf(context).height;
          _drawer.value = (_drawer.value - delta / (h * 0.85)).clamp(0.0, 1.0);
        },
        onDragCloseEnd: (velocity) {
          if (velocity > 300 || _drawer.value < 0.65) {
            _closeDrawer();
          } else {
            _openDrawer();
          }
        },
      ),
    );
  }
}
