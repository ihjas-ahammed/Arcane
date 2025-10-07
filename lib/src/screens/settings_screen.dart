import 'package:flutter/material.dart';
import 'package:arcane/src/widgets/views/settings_view.dart';
import 'package:arcane/src/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Configuration'),
        backgroundColor: AppTheme.fhBgMedium, // Match header style
      ),
      body: Center( // Center the content
        child: ConstrainedBox( // Limit width for larger screens
          constraints: const BoxConstraints(maxWidth: 800), 
          child: const SettingsView(),
        ),
      ),
    );
  }
}
