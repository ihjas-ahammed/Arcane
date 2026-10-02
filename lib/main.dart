import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dart/firebase_dart.dart' as fd;
import 'package:firedart/firedart.dart' as firedart;
import 'package:path_provider/path_provider.dart';
import 'package:missions/src/app.dart';
import 'package:missions/firebase_options.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/providers/paper_trading_provider.dart';
import 'package:missions/src/services/ai_service.dart';
import 'package:missions/src/services/debug_user.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'package:missions/src/services/notification_service.dart';
import 'package:missions/src/services/widget_action_router.dart';
import 'package:provider/provider.dart';

Future<void> _initFirebase() async {
  if (!kIsWeb && Platform.isLinux) {
    // Linux: spin up firebase_dart (Auth + RTDB) + firedart (Firestore) using
    // the same project config the web FlutterFire build uses.
    const opts = DefaultFirebaseOptions.web;
    final dir = await getApplicationSupportDirectory();
    fd.FirebaseDart.setup(storagePath: dir.path);
    await fd.Firebase.initializeApp(
      options: fd.FirebaseOptions(
        apiKey: opts.apiKey,
        appId: opts.appId,
        messagingSenderId: opts.messagingSenderId,
        projectId: opts.projectId,
        authDomain: opts.authDomain,
        databaseURL: opts.databaseURL,
        storageBucket: opts.storageBucket,
      ),
    );
    firedart.Firestore.initialize(opts.projectId);
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Performance & RAM: constrain image cache to prevent unbounded heap allocations on Android
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 * 1024 * 1024; // 40MB
  PaintingBinding.instance.imageCache.maximumSize = 100;

  // Launcher anti-kill safety: prevent unhandled exceptions from terminating the launcher process
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[LauncherSafety] FlutterError handled: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[LauncherSafety] Uncaught async error suppressed: $error');
    return true; // Mark as handled to prevent OS/process kill
  };

  try {
    await _initFirebase();
  } catch (e) {
    debugPrint("Firebase init error (Native modules might be missing): $e");
  }

  await DebugUser.ensureSignedIn();

  // Wire the widget-action channel synchronously so a cold-start widget click
  // isn't dropped; the async service inits below run without blocking the
  // first frame (pending actions are drained post-frame in MyApp).
  try {
    HomeWidgetService.instance.onAction =
        (action) => WidgetActionRouter.instance.handle(action);
    WidgetActionRouter.instance.attachPlatformChannel();
  } catch (e) {
    debugPrint("HomeWidget channel error: $e");
  }

  NotificationService.instance.init().catchError((e) {
    debugPrint("Notification init error: $e");
  });
  HomeWidgetService.instance.init().catchError((e) {
    debugPrint("HomeWidget init error: $e");
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider.value(value: PaperTradingProvider.instance),
        Provider(create: (_) => AIService()),
      ],
      child: const MyApp(),
    ),
  );
}
