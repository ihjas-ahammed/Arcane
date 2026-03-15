import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:arcane/src/app.dart';
import 'package:arcane/firebase_options.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/services/ai_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Safe Firebase Initialization
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init error (Native modules might be missing): $e");
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