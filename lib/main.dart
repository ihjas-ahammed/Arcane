import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dart/firebase_dart.dart' as fd;
import 'package:firedart/firedart.dart' as firedart;
import 'package:path_provider/path_provider.dart';
import 'package:missions/src/app.dart';
import 'package:missions/firebase_options.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/ai_service.dart';
import 'package:missions/src/services/notification_service.dart';
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

  try {
    await _initFirebase();
  } catch (e) {
    debugPrint("Firebase init error (Native modules might be missing): $e");
  }

  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint("Notification init error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        Provider(create: (_) => AIService()),
      ],
      child: const MyApp(),
    ),
  );
}
